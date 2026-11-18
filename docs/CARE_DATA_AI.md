# Bổ sung dữ liệu chăm sóc bằng Gemini

Backend đọc định danh trong `plant_species`, gọi Gemini, kiểm tra JSON bằng Zod rồi lưu đồng thời vào `species_care_drafts` và các cột chăm sóc chính. **Từ 18/11/2026, kết quả Gemini thật được dùng ngay, không chờ duyệt thủ công.** Trạng thái `ai_suggested` phân biệt với `verified` (đã được người kiểm tra); không tạo người duyệt hoặc thời điểm duyệt giả. Demo vẫn chỉ lưu bản mô phỏng.

API lịch, nhiệm vụ, hồ sơ và thông báo giữ nguyên URL/body/response để frontend tiếp tục dùng hai tài liệu đã bàn giao. Không cần màn hình phê duyệt. API care-data thêm giá trị trạng thái `ai_suggested`; nếu một client khác đã lọc riêng `verified` thì client đó phải chấp nhận thêm trạng thái mới. Các trường hướng dẫn trong `species` được trả ngay. Không tự bịa chu kỳ khi AI trả null.

Chạy migration `202611180001_auto_ai_care` trước khi chạy code mới (`npm run db:migrate` từ backend). Migration chỉ mở rộng CHECK trạng thái, không sửa dữ liệu cũ. Bản draft thật cũ sẽ được đưa vào dữ liệu chính khi gọi enrich lại; bản rejected/demo không tự được đưa vào. Dữ liệu đã được người duyệt giữ nguyên khi tạo lại, vẫn có thể cập nhật qua API review tùy chọn.

Module quét cây cần lưu species_id rồi gọi `careDataService.enrichForPlant(ownerId, plantId)` (hoặc API enrich đã có). Sau đó gọi sync hoặc đợi worker tạo lịch. Việc thêm một dòng DB tự nó không gọi Gemini. Backend quét ảnh chưa có trong phạm vi module này.

## Cấu hình

Trong `backend/.env` (không commit):

```dotenv
CARE_AI_MODE=auto
GEMINI_API_KEY=
GEMINI_MODEL=gemini-3.5-flash-lite
CARE_REVIEWER_IDS=
```

- `auto`: có key → Gemini thật; thiếu key → demo có `is_mock=true`.
- `demo`: luôn dùng mẫu minh họa, không gọi Google.
- `live`: cần key; thiếu key thì từ chối khởi động. Lỗi Gemini thật không bị đổi thành demo một cách âm thầm.
- `GEMINI_MODEL`: model text hỗ trợ structured output và `generateContent` mà project được phép gọi; có thể thay bằng model hiện khả dụng trong AI Studio. Không tự chuyển sang model khác khi lỗi.
- `CARE_REVIEWER_IDS`: UUID **Supabase Auth** của người quản lý dữ liệu, phân cách dấu phẩy. Lấy `id` từ `GET /api/v1/me` sau đăng nhập hoặc từ Supabase Authentication → Users. Đây là quyền sửa dữ liệu chung cho mọi người dùng. Để trống thì API duyệt trả 403; metadata `role/admin` do client gửi không cấp quyền. Development auth bypass không được duyệt.

Khởi động lại API sau khi sửa `.env`. Key Gemini chỉ ở backend, không gửi xuống Flutter hoặc trả trong lỗi/log. Kiểm tra quota/billing của model trong AI Studio; không đảm bảo mọi model và mọi tài khoản đều có quota miễn phí.

```sh
cd backend
npm ci
npm run db:generate
# Người phụ trách DB áp migration mới một lần:
npm run db:migrate
npm run dev
```

Kiểm tra provider độc lập, **không đọc/ghi DB**, mặc định dùng tên công khai `Epipremnum aureum`:

```sh
npm run care:check
# Hoặc truyền đúng tên khoa học:
npm run care:check -- "Aloe vera"
```

Kết quả có `is_mock`, `model`, `saved_to_database=false` và bản đề xuất. Đây chưa phải dữ liệu đã duyệt và chưa tự tạo lịch.

## Hợp đồng dữ liệu

Gemini nhận tên khoa học, tên thường gọi từ DB và các đoạn tài liệu được người quản lý cung cấp nếu có. Không nhận DB URL, token người dùng, vị trí GPS hoặc quyền ghi DB. Kết quả bắt buộc có đủ tên trường, nhưng **giá trị chưa đủ căn cứ phải là null**:

```json
{
  "scientific_name": "Epipremnum aureum",
  "care": {
    "watering_days": null,
    "fertilizing_days": null,
    "water_guide": "Hướng dẫn cần được kiểm tra; chưa đủ căn cứ cho một chu kỳ cụ thể.",
    "light_guide": null,
    "soil_guide": null,
    "temperature_guide": null,
    "fertilizer_guide": null
  },
  "assumptions": ["Chưa đối chiếu nguồn."],
  "source_ids": []
}
```

Ví dụ trên chỉ minh họa hợp đồng, không phải hướng dẫn thực vật học. Chu kỳ là số nguyên 1–365 hoặc null; không dùng 0 để diễn tả không cần bón. Có chu kỳ thì phải có hướng dẫn tương ứng. Chặn JSON sai, trường thừa, sai tên loài, source ID không được cung cấp, phản hồi bị cắt hoặc bị chặn. Kiểm tra cấu trúc không chứng minh nội dung thực vật học đúng; dữ liệu AI dùng ngay là dữ liệu tham khảo, chưa được người kiểm tra.

## API

Tất cả API dùng tiền tố `/api/v1`, header `Authorization: Bearer <access_token>` và response chung `{success,data,error,message}`.

| API | Quyền | Mục đích |
| --- | --- | --- |
| `GET /plants/:id/care-data` | Chủ cây | Đọc dữ liệu chính, trạng thái và bản đề xuất |
| `POST /plants/:id/care-data/enrich` | Chủ cây | Body `{}`; bổ sung nếu chưa có, dùng lại cache theo loài |
| `GET /species/:id/care-data` | Reviewer | Đọc thêm tài liệu nguồn, ghi chú và người duyệt |
| `POST /species/:id/care-data/enrich` | Reviewer | Tạo/tạo lại bản đề xuất và cung cấp tài liệu nguồn |
| `PATCH /species/:id/care-data/review` | Reviewer | Duyệt hoặc từ chối bản đề xuất |

`:id` ở API plants là UUID chậu cây; ở API species là UUID loài trong DB. Không dùng GBIF ID hoặc tên loài thay cho UUID. Cây chưa có `species_id` trả `409 SPECIES_REQUIRED`. Sai chủ trả 404 trước khi gọi Gemini.

### Tạo đề xuất

Chủ cây gửi `{}` đến endpoint enrich. Backend kiểm tra cache và chỉ gửi tên loài cho Gemini nếu cần. Request đầu chờ Gemini (timeout 45 giây, mức suy luận LOW với model Gemini 3/4); request đồng thời có thể nhận **202**, `data.draft.status=generating` và đọc lại GET sau vài giây. Đây không phải hàng đợi nền; nếu tiến trình chết, request sau có thể nhận lại việc sau 90 giây.

Reviewer có thể yêu cầu tạo lại bằng body:

```json
{
  "force": true,
  "sources": [
    {
      "title": "Tên tài liệu chăm sóc đã kiểm tra",
      "url": "https://example.org/plant-care",
      "excerpt": "Dán đoạn nội dung được phép sử dụng liên quan đúng loài ở đây."
    }
  ]
}
```

Tối đa 5 đoạn, 6000 ký tự/đoạn. **URL chỉ là thông tin nguồn, backend không tự tải trang.** Chỉ truyền nội dung nhóm được phép sử dụng/lưu. Khi có nguồn, prompt yêu cầu trích xuất từ đoạn trích và để null phần không được hỗ trợ. Backend đánh số `source_1`... để model không tự tạo nguồn. Dùng `force:true` khi đổi tài liệu hoặc muốn thử lại bản bị từ chối; `sources:[]` bỏ tài liệu cũ. Bỏ `sources` thì giữ lại tài liệu của lần trước.

Không có nguồn → `source_mode=model_knowledge`, là đề xuất từ kiến thức mô hình. **Adapter chưa dùng tìm kiếm web/Google Search grounding**, không giả vờ đã tìm nguồn. Grounding có điều khoản lưu/tái sử dụng riêng và không được mặc định dùng để gom dữ liệu vào danh mục dùng chung.

### Duyệt hoặc từ chối (tùy chọn, không chặn luồng tự động)

Lấy `generation_id` từ GET rồi gửi:

```json
{
  "action": "approve",
  "generation_id": "UUID-cua-ban-de-xuat-vua-doc",
  "note": "Đã đối chiếu tài liệu và kiểm tra chu kỳ, điều kiện áp dụng."
}
```

Có thể thêm `care` với **đủ 7 trường** như hợp đồng để sửa các giá trị trước khi duyệt. `null` có nghĩa xóa giá trị đó, không phải giữ giá trị cũ. Không được duyệt bản demo hoặc toàn bộ 7 trường đều null. Chu kỳ null vẫn có thể duyệt hướng dẫn; planner cảnh báo thiếu chu kỳ và không tự đoán.

Từ chối: cùng body nhưng `action="reject"`, ghi lý do trong `note`, không gửi `care`. Duyệt lại một bản đã xử lý hoặc dùng generation ID cũ trả 409 để tránh ghi đè bản mới. Người quản lý phải tải lại trước khi tiếp tục.

Sau duyệt, `plant_species` có `care_status=verified`, `care_model`, `care_generated_at`, `care_reviewed_at`, `care_reviewed_by`. `care_source` lưu chuỗi JSON gồm nhà cung cấp, nguồn đã cung cấp, giả định và ghi chú duyệt; bản ghi cũ có thể vẫn là văn bản thường. UI đọc hướng dẫn từ các trường `*_guide`, không coi chuỗi provenance này là đoạn hướng dẫn.

## Tích hợp với quét AI/vườn cây và lịch

1. Module Pl@ntNet chuẩn hóa tên khoa học, tìm/tạo loài và gắn `plants.species_id`. Không ghi các chu kỳ Gemini trực tiếp vào bảng chính. Nhận diện chưa chắc chắn thì cho xác nhận loài trước.
2. Sau khi transaction lưu cây đã commit, gọi endpoint enrich hoặc `careDataService(db, createCareProvider(config)).enrichForPlant(ownerId, plantId)`. Không gọi trong transaction đang giữ khóa DB. Có thể gọi thành request riêng sau khi lưu cây để không giữ request quét chờ Gemini.
3. Kết quả AI thật được lưu ngay thành `ai_suggested`. Nhiều cây cùng loài dùng chung dữ liệu, không chờ reviewer.
4. Worker `npm run reminders:watch` sẽ tạo lịch còn thiếu ở lượt tiếp theo; hoặc chủ cây gọi `POST /plants/:id/care-plan/sync` body `{}` ngay sau enrich.
5. Lịch đã tồn tại, kể cả người dùng chỉnh tay, giữ nguyên. Duyệt dữ liệu loài mới không tự ghi đè lịch của các chậu cũ. Endpoint PUT lịch vẫn cho chủ cây tự thiết lập khi chưa có dữ liệu loài đã duyệt.

Các ngưỡng thời tiết và cách tính ngày hiện có không đổi. Worker nhắc chăm sóc **không gọi Gemini**, không tìm thông tin mới mỗi phút. Chỉ tạo đề xuất theo yêu cầu enrich. Module lưu cây/quét của bạn khác chưa được tự nối vào vì chưa có thao tác tạo cây/quét trong backend hiện tại.

## Cache, lỗi và migration

- Cache bền vững theo UUID loài trong DB, dùng chung giữa các tiến trình. Bản đã duyệt không gọi AI lại nếu không có `force:true` từ reviewer.
- Bản draft/rejected cũng được cache. Khi chuyển demo sang live hoặc đổi model, bản chưa duyệt có thể được tạo lại khi gọi enrich.
- Lease DB 90 giây và generation ID ngăn phản hồi cũ ghi đè phản hồi mới. Không giữ transaction trong khi chờ mạng.
- Lỗi upstream → `AI_UNAVAILABLE`/`AI_RATE_LIMITED` (503), sai output → `AI_INVALID_RESPONSE` (502). Bản lỗi có `retry_after` 5 phút; request thường trong khoảng này trả bản cache failed, không gọi lại. `force` của reviewer có thể thử lại sớm. Không xóa dữ liệu chính đã duyệt khi tạo lại/lỗi/từ chối.
- Demo có cờ rõ ràng, không được approve hoặc tạo lịch tự động từ chu kỳ minh họa. Seed local cũ vẫn có lịch mẫu riêng để test.
- Migration `202611170001_species_care_ai` thêm bảng proposal và metadata. Các giá trị cũ được giữ nguyên nhưng đánh dấu draft nếu có nội dung; không tự phong là đã kiểm tra. Lịch đã tồn tại không bị xóa. Người phụ trách cần rà soát dữ liệu cũ trước khi dùng để tạo lịch tự động mới.
- Quyền reviewer hiện là cấu hình phía server; chưa có màn hình quản trị hay hệ thống RBAC trong DB. Không cần làm frontend để gọi các API này bằng Postman.

## Kiểm thử

```sh
npm test
npm run test:db:isolated
npm run typecheck
npm run lint
npm run build
```

Các test DB chỉ chạy trên PostgreSQL tạm: phân quyền, cache cùng loài, lease, phản hồi cũ, sửa/duyệt/từ chối, chống duyệt demo, bảo toàn dữ liệu đã duyệt và planner dùng chu kỳ `ai_suggested` hoặc `verified`, không dùng demo. Auth/Gemini/thời tiết được giả lập trong bộ test; `care:check` kiểm tra provider thật riêng khi có key.

Đã kiểm tra thật ngày 17/11/2026 với `gemini-3.5-flash-lite`: nhận JSON hợp lệ cho `Epipremnum aureum`, đủ 5 hướng dẫn dạng chữ, hai chu kỳ null khi thiếu căn cứ. Không ghi kết quả thử vào Supabase và không coi nội dung đó là đã được kiểm tra thực vật học. Migration mới đã áp trên Supabase của nhóm; `CARE_REVIEWER_IDS` vẫn cần người quản lý điền UUID tài khoản của mình.

Nguồn triển khai: [Structured outputs](https://aistudio.google.com/docs/structured-output), [REST generateContent](https://aistudio.google.com/api-reference/generate-content/generate-content), [điều khoản Grounding](https://aistudio.google.com/docs/terms#grounding-with-google-search).
