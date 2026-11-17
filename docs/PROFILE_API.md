# Backend màn hình Hồ sơ

Đã có xem/cập nhật hồ sơ, thống kê cây/quét/chăm sóc thực tế và đăng xuất. Frontend chưa được viết trong phần này. Không cần migration hoặc cấu hình env mới.

## Cấu trúc

- `src/routes/profile.ts`: khai báo route dưới `/api/v1/me`, được index.ts gắn sau authenticate.
- `src/controllers/profile.ts`: nhận request, kiểm tra tên/múi giờ và trả response.
- `src/services/profile.ts`: đọc/tạo/cập nhật hồ sơ, tính thống kê theo người đăng nhập.
- Đăng xuất dùng module Auth đã tách `routes/auth.ts` → `controllers/auth.ts` → `services/auth.ts`; không tạo endpoint đăng xuất trùng trong Profile.

## Màn hình frontend và API

Mọi request cần `Authorization: Bearer <access_token>`. Response chung `{success,data,error,message}`; các trường bên dưới nằm trong `data`.

| Màn hình/thành phần | Trường hiển thị hoặc nhập | API |
| --- | --- | --- |
| Hồ sơ | Ảnh `avatar_url` (null dùng ảnh mặc định), `display_name`, `email`, `timezone`, `created_at` | `GET /api/v1/me` |
| Thống kê trên hồ sơ | Số cây `total_plants`, số quét `total_ai_scans`; tổng chăm sóc và tưới/bón/điều trị trong `care_stats` | Có sẵn trong GET /me; tải riêng bằng `GET /api/v1/me/stats` |
| Sửa hồ sơ, có thể là hộp thoại | `display_name` 1–100 ký tự; `timezone` là mã IANA, ví dụ `Asia/Ho_Chi_Minh` | `PATCH /api/v1/me` |
| Hộp thoại xác nhận đăng xuất | Nút Hủy và Đăng xuất | `POST /api/v1/auth/logout`, không cần body |

Đổi tên/múi giờ gửi một hoặc cả hai trường, ví dụ:

```json
{"display_name":"Đạt","timezone":"Asia/Ho_Chi_Minh"}
```

Không gửi email, role, id, avatar hoặc thống kê trong PATCH. Email/ảnh Google lấy từ Supabase Auth đã xác minh; API upload avatar và đổi email chưa có. PATCH trả hồ sơ cập nhật, frontend gọi GET /me để nạp đầy đủ thông tin và thống kê.

Ví dụ phần thống kê (cũng nằm trong GET /me):

```json
{
  "total_plants": 5,
  "total_ai_scans": 12,
  "care_stats": {
    "total_actions": 20,
    "watering_count": 14,
    "fertilizing_count": 4,
    "treatment_count": 2,
    "last_cared_at": "2026-11-17T01:00:00.000Z"
  }
}
```

## Cách hiểu số liệu

- Phạm vi toàn bộ dữ liệu hiện còn lưu của tài khoản; không phải riêng tháng này. Không nhận user_id để đổi chủ dữ liệu.
- `total_plants`: số cây hiện trong vườn. `total_ai_scans`: số bản ghi scans, bao gồm bản demo nếu được lưu.
- `care_stats`: đếm care_logs loại water/fertilize/treat, có performed_at không nằm trong tương lai. Một bản ghi nhật ký tương ứng một lần chăm sóc; không đếm note, thông báo, lịch hoặc việc pending như đã chăm sóc.
- `last_cared_at`: thời điểm thực hiện mới nhất trong các nhật ký đó; null nếu chưa có. Frontend định dạng theo timezone hồ sơ.
- Chưa có dữ liệu: trả các số 0 và last_cared_at=null, không phải lỗi. Khi xóa cây, nhật ký của cây bị cascade xóa nên tổng chăm sóc giảm; đây không phải bộ đếm tích lũy vĩnh viễn.
- Module ghi nhật ký của thành viên khác cần lưu care_logs đúng chủ cây/loại/thời điểm và chống trùng request_id. Backend hồ sơ đã đọc được dữ liệu này, không tự giả lập đã tưới để tăng thống kê.

## Đăng xuất và trạng thái giao diện

Khi logout thành công, frontend xóa access_token, refresh_token và cache cá nhân, chuyển về đăng nhập. API logout thu hồi phiên refresh hiện tại; không coi nó là xóa tài khoản hoặc đăng xuất mọi thiết bị. JWT access token có thể còn hiệu lực đến hạn, frontend phải xóa token trên thiết bị. Không báo đăng xuất server thành công khi lỗi mạng; nếu hỗ trợ đăng xuất cục bộ thì phân biệt rõ.

UI cần loading, lỗi có nút thử lại, ảnh mặc định, thống kê 0 và ô tên bắt buộc. 401: thử refresh theo luồng Auth, không được thì yêu cầu đăng nhập; 400: báo input không hợp lệ; 503: báo dịch vụ tạm thời chưa sẵn sàng. Dark Mode và thông tin ứng dụng thuộc frontend, không có API riêng.
