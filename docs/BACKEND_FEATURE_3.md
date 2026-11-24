# Tài liệu API: Quét & Nhận diện AI (Backend Feature 3)

Tài liệu này hướng dẫn chi tiết cho đội ngũ Frontend cách tích hợp bộ API **Quét & Nhận diện AI (Scans)**: bao gồm tính năng nhận diện loài cây qua hình ảnh (sử dụng Pl@ntNet API) và chẩn đoán sức khỏe, phát hiện sâu bệnh (sử dụng Gemini Vision AI).

---

## 1. Thông tin chung & Quy ước

* **Base URL:** `/api/v1` *(hoặc prefix theo cấu hình môi trường)*
* **Xác thực (Authentication):** Tất cả các endpoint đều yêu cầu người dùng đã đăng nhập. Frontend phải gửi kèm Token ở Header:
  ```http
  Authorization: Bearer <access_token>
  ```
* **Định dạng Upload ảnh:** Hỗ trợ linh hoạt 2 cách gửi ảnh:
  1. **Multipart Form (`multipart/form-data`):** Khuyến nghị dùng khi chụp từ camera hoặc tải file từ thiết bị (field name: `image`).
  2. **JSON Base64 (`application/json`):** Truyền chuỗi base64 qua trường `image_base64` (hỗ trợ cả Data URL `data:image/jpeg;base64,...` hoặc chuỗi base64 thuần).
* **Định dạng file hỗ trợ:** `image/jpeg`, `image/png`, `image/webp`. Dung lượng tối đa: **10MB**.
* **Định dạng Response chuẩn:**
  * **Thành công:**
    ```json
    {
      "success": true,
      "data": { ... },
      "error": null,
      "message": "OK"
    }
    ```
  * **Thất bại (400, 401, 404, 422, 502, 500):**
    ```json
    {
      "success": false,
      "data": null,
      "error": {
        "code": "ERROR_CODE"
      },
      "message": "Mô tả chi tiết nguyên nhân lỗi"
    }
    ```

---

## 2. Các Chế độ Quét (`mode`)

API hỗ trợ các chế độ quét thông qua tham số `mode`:

| Chế độ (`mode`) | Mục đích & Công nghệ | Mô tả hoạt động |
| :--- | :--- | :--- |
| `"identify"` *(mặc định)* | **Nhận diện loài**<br>*(Pl@ntNet API)* | Phân tích ảnh để tìm ra tên khoa học (`scientific_name`), tên thông thường tiếng Việt (`common_name`), định dạng hiển thị `reported_species_name: "Tên tiếng Việt (Tên khoa học)"`, độ chính xác (`species_confidence`) và liên kết/tạo mới bản ghi trong từ điển thực vật `plant_species`. |
| `"diagnose"` | **Chẩn đoán sâu bệnh**<br>*(Gemini Vision AI)* | Đánh giá tình trạng lá/thân cây, trả về trạng thái sức khỏe (`health_status`: `"healthy"`, `"suspected"`, `"unknown"`) cùng mảng danh sách triệu chứng, nguyên nhân và các bước điều trị cụ thể (`scan_findings`). |
| `"both"` | **Kết hợp cả hai** | Chạy nhận diện loài trước, sau đó đưa thông tin loài vào prompt chẩn đoán của Gemini Vision để kết quả bệnh học có độ chuẩn xác cao nhất. |

> [!NOTE]
> Hệ thống tích hợp sẵn cơ chế **Mock tự động** (`CARE_AI_MODE="demo"` hoặc khi chưa cấu hình API Key ở môi trường dev). Frontend có thể tích hợp và kiểm thử giao diện ngay mà không bị chặn bởi giới hạn quota API.

---

## 3. Chi tiết các Endpoints

### 3.1. Tạo phiên quét mới (Identify / Diagnose)

Gửi ảnh cây lên hệ thống để nhận diện loài hoặc chẩn đoán bệnh.

* **Endpoint:** `POST /api/v1/scans`
* **Content-Type:** `multipart/form-data` hoặc `application/json`
* **Headers:**
  ```http
  Authorization: Bearer <access_token>
  ```

#### Các tham số Request:

| Tham số | Vị trí | Kiểu | Bắt buộc | Mô tả |
| :--- | :--- | :--- | :--- | :--- |
| `image` | FormData | File (Binary) | Có * | File ảnh (`jpg`, `png`, `webp`). *(Bắt buộc nếu không dùng `image_base64`)* |
| `image_base64` | Body | String | Có * | Chuỗi base64 của ảnh. *(Bắt buộc nếu không gửi file qua `image`)* |
| `mode` | Form / Body | String | Không | `"identify"` (mặc định), `"diagnose"`, hoặc `"both"`. |
| `organ` | Form / Body | String | Không | Bộ phận cây chụp (dành cho Pl@ntNet): `"auto"` (mặc định), `"leaf"`, `"flower"`, `"fruit"`, `"bark"`. |
| `plant_id` | Form / Body | UUID | Không | ID cây trong vườn cá nhân (`plants.id`). Dùng khi quét chẩn đoán cho cây đã có trong vườn. |
| `request_id` | Form / Body | UUID | Không | Client UUID để **chống gửi lặp** (Idempotency). Nếu gửi lại cùng một `request_id`, server sẽ trả về kết quả quét trước đó với mã HTTP `200`. |

---

#### Ví dụ 1: Request & Response cho chế độ Nhận diện loài (`mode="identify"`)

**Request (Multipart Form-Data):**
```http
POST /api/v1/scans
Authorization: Bearer eyJhbGciOi...
Content-Type: multipart/form-data; boundary=----WebKitFormBoundary

------WebKitFormBoundary
Content-Disposition: form-data; name="image"; filename="trauba.jpg"
Content-Type: image/jpeg

<binary data>
------WebKitFormBoundary
Content-Disposition: form-data; name="mode"

identify
------WebKitFormBoundary
Content-Disposition: form-data; name="organ"

leaf
------WebKitFormBoundary
Content-Disposition: form-data; name="request_id"

3fa85f64-5717-4562-b3fc-2c963f66afa6
------WebKitFormBoundary--
```

**Response thành công (`201 Created` - hoặc `200 OK` nếu trùng `request_id`):**
```json
{
  "success": true,
  "data": {
    "id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
    "owner_id": "018f3a22-38d1-72ef-b570-5b4cf5796277",
    "request_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
    "plant_id": null,
    "image_key": "scans/018f3a22-38d1-72ef-b570-5b4cf5796277/d9b4be11-2e29-4d61-b4d6-849c0953a918.jpg",
    "image_url": "https://<supabase-url>/storage/v1/object/sign/plant-images/scans/...token=...",
    "mode": "identify",
    "source": "plantnet",
    "is_mock": false,
    "scanned_at": "2026-11-20T08:45:00.000Z",
    "species_id": "018f3a25-e5f8-7db0-b389-9e8c46ea4823",
    "reported_species_name": "Trầu bà (Epipremnum aureum)",
    "species_confidence": 0.9452,
    "health_status": "unknown",
    "scan_findings": []
  },
  "error": null,
  "message": "OK"
}
```

---

#### Ví dụ 2: Request & Response cho chế độ Chẩn đoán sâu bệnh (`mode="diagnose"`)

**Request (JSON Base64):**
```http
POST /api/v1/scans
Authorization: Bearer eyJhbGciOi...
Content-Type: application/json

{
  "mode": "diagnose",
  "plant_id": "9a7516d3-2f22-4876-b638-316239fb8c1a",
  "request_id": "8d3e2304-436f-47dc-9db8-500e28f11ec3",
  "image_base64": "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD/..."
}
```

**Response thành công (`201 Created`):**
```json
{
  "success": true,
  "data": {
    "id": "e4465b89-a228-4e08-8314-e6df5b9d2f21",
    "owner_id": "018f3a22-38d1-72ef-b570-5b4cf5796277",
    "request_id": "8d3e2304-436f-47dc-9db8-500e28f11ec3",
    "plant_id": "9a7516d3-2f22-4876-b638-316239fb8c1a",
    "image_key": "scans/018f3a22-38d1-72ef-b570-5b4cf5796277/a18fcbb4-1b77-4b14-87cf-45371a53c9ff.jpg",
    "image_url": "https://<supabase-url>/storage/v1/object/sign/plant-images/scans/...token=...",
    "mode": "diagnose",
    "source": "gemini",
    "is_mock": false,
    "scanned_at": "2026-11-20T08:46:12.000Z",
    "species_id": "018f3a25-e5f8-7db0-b389-9e8c46ea4823",
    "reported_species_name": "Trầu bà (Epipremnum aureum)",
    "species_confidence": null,
    "health_status": "suspected",
    "scan_findings": [
      {
        "scan_id": "e4465b89-a228-4e08-8314-e6df5b9d2f21",
        "position": 0,
        "disease_id": null,
        "reported_name": "Bệnh đốm lá nấm (Cercospora leaf spot)",
        "confidence": 0.88,
        "symptoms": "Lá xuất hiện nhiều đốm nhỏ màu nâu viền vàng, tập trung nhiều ở mặt trên lá già.",
        "possible_cause": "Tưới nước đọng trên lá qua đêm và độ ẩm môi trường quá cao.",
        "treatment_steps": [
          "Cắt tỉa và tiêu hủy ngay các lá có triệu chứng bệnh nặng.",
          "Chuyển cây đến nơi thoáng gió, có ánh sáng gián tiếp tốt.",
          "Chỉ tưới gốc, tuyệt đối không phun sương hay làm ướt bề mặt lá.",
          "Phun dung dịch nano đồng hoặc thuốc diệt nấm phổ biến định kỳ 7 ngày/lần."
        ],
        "guidance_source": "gemini"
      }
    ]
  },
  "error": null,
  "message": "OK"
}
```

---

### 3.2. Xem lịch sử các lần quét (`GET /api/v1/scans`)

Lấy danh sách các lần quét của người dùng, sắp xếp mới nhất lên đầu (`scanned_at DESC`).

* **Endpoint:** `GET /api/v1/scans`
* **Query Parameters:**
  * `mode` *(string, tùy chọn)*: Lọc theo chế độ (`identify` hoặc `diagnose`).
  * `plant_id` *(UUID, tùy chọn)*: Lọc theo ID của một cây cụ thể.
  * `limit` *(number, tùy chọn, mặc định `50`, tối đa `100`)*: Số lượng bản ghi cần lấy.
* **Ví dụ:** `GET /api/v1/scans?mode=diagnose&limit=10`

**Response (`200 OK`):**
```json
{
  "success": true,
  "data": [
    {
      "id": "e4465b89-a228-4e08-8314-e6df5b9d2f21",
      "owner_id": "018f3a22-38d1-72ef-b570-5b4cf5796277",
      "request_id": "8d3e2304-436f-47dc-9db8-500e28f11ec3",
      "plant_id": "9a7516d3-2f22-4876-b638-316239fb8c1a",
      "image_key": "scans/018f3a22-38d1-72ef-b570-5b4cf5796277/a18fcbb4-1b77-4b14-87cf-45371a53c9ff.jpg",
      "image_url": "https://<supabase-url>/storage/v1/object/sign/plant-images/scans/...token=...",
      "mode": "diagnose",
      "source": "gemini",
      "is_mock": false,
      "scanned_at": "2026-11-20T08:46:12.000Z",
      "species_id": "018f3a25-e5f8-7db0-b389-9e8c46ea4823",
      "reported_species_name": "Trầu bà (Epipremnum aureum)",
      "species_confidence": null,
      "health_status": "suspected"
    }
  ],
  "error": null,
  "message": "OK"
}
```

---

### 3.3. Xem chi tiết một lần quét (`GET /api/v1/scans/:id`)

Lấy toàn bộ thông tin chi tiết một lần quét kèm theo danh sách kết quả bệnh học (`scan_findings`).

* **Endpoint:** `GET /api/v1/scans/:id`
* **Path Parameter:**
  * `id` *(UUID, bắt buộc)*: ID của bản ghi scan.

**Response (`200 OK`):**
*(Cấu trúc tương tự Response chi tiết của POST /api/v1/scans ở mục 3.1)*

---

### 3.4. Xóa một kết quả quét (`DELETE /api/v1/scans/:id`)

Xóa bản ghi quét và các phát hiện liên quan (cascade).

* **Endpoint:** `DELETE /api/v1/scans/:id`
* **Path Parameter:**
  * `id` *(UUID, bắt buộc)*: ID của bản ghi scan.

**Response (`200 OK`):**
```json
{
  "success": true,
  "data": {
    "id": "e4465b89-a228-4e08-8314-e6df5b9d2f21",
    "deleted": true
  },
  "error": null,
  "message": "OK"
}
```

---

## 4. Hướng dẫn Luồng "Thêm vào vườn" (From Scan to Garden)

Khi người dùng thực hiện quét nhận diện thành công (`mode="identify"`), Frontend hiển thị kết quả loài cây (`reported_species_name`, `species_confidence`) cùng nút hành động **"Thêm cây này vào vườn"**.

Để đưa cây vào vườn cá nhân, Frontend lấy trực tiếp 2 trường từ response của `POST /api/v1/scans`:
1. `data.species_id`: Định danh loài cây trong hệ thống.
2. `data.image_key`: Đường dẫn file ảnh vừa chụp/quét để làm ảnh đại diện (`cover_image_key`).

### Gọi tiếp sang API Vườn (`POST /api/v1/garden`):

```http
POST /api/v1/garden
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "nickname": "Trầu bà bàn làm việc",
  "species_id": "018f3a25-e5f8-7db0-b389-9e8c46ea4823",
  "cover_image_key": "scans/018f3a22-38d1-72ef-b570-5b4cf5796277/d9b4be11-2e29-4d61-b4d6-849c0953a918.jpg",
  "environment": "indoor"
}
```

### Lợi ích của luồng này:
- Người dùng **không phải tải lại ảnh lần thứ hai**, tiết kiệm băng thông và tăng tốc độ trải nghiệm.
- **Bảo mật:** Backend kiểm tra quyền sở hữu `cover_image_key` đối chiếu với bảng `scans` của chính tài khoản đó (nếu truyền key của tài khoản khác sẽ bị từ chối với lỗi `400 INVALID_COVER_IMAGE`).
- Response của `POST /api/v1/garden` sẽ tự động trả kèm **`cover_image_url`** (signed URL từ Supabase Storage) để Frontend hiển thị ngay ảnh đại diện cho cây mới.
- Cây mới tạo sẽ tự động được liên kết với từ điển loài (`species_id`). Hệ thống sẽ tự động kích hoạt tạo lịch trình tưới nước, bón phân và kế hoạch chăm sóc chuẩn cho cây.

---

## 5. Bảng mã lỗi HTTP (Error Codes Reference)

Khi gặp lỗi, API sẽ trả về HTTP status code tương ứng kèm body `{ "success": false, "error": { "code": "..." }, "message": "..." }`:

| HTTP Status | Error Code (`error.code`) | Nguyên nhân & Hướng xử lý cho Frontend |
| :---: | :--- | :--- |
| **`400`** | `INVALID_INPUT` | Dữ liệu đầu vào sai định dạng (ví dụ `plant_id` hoặc `request_id` không phải UUID hợp lệ). |
| **`400`** | `MISSING_IMAGE` | Không tìm thấy ảnh trong request (cần truyền file qua form-data `image` hoặc chuỗi `image_base64`). |
| **`400`** | `INVALID_IMAGE_TYPE` | Định dạng ảnh không được hỗ trợ. Chỉ chấp nhận `image/jpeg`, `image/png`, `image/webp`. |
| **`400`** | `INVALID_MODE` | Giá trị `mode` không hợp lệ (phải là một trong: `identify`, `diagnose`, `both`). |
| **`401`** | `UNAUTHORIZED` | Chưa đăng nhập hoặc Access Token hết hạn / không hợp lệ. Frontend cần chuyển hướng người dùng đến màn hình Đăng nhập. |
| **`404`** | `PLANT_NOT_FOUND` | `plant_id` gửi lên không tồn tại hoặc không thuộc sở hữu của tài khoản hiện tại. |
| **`404`** | `SCAN_NOT_FOUND` | Không tìm thấy kết quả quét với ID tương ứng khi gọi GET/DELETE. |
| **`422`** | `PLANTNET_NO_RESULT` | Pl@ntNet không tìm thấy bất kỳ loài cây nào khớp với hình ảnh gửi lên. Frontend nên nhắc người dùng chụp rõ nét lá/hoa hơn. |
| **`502`** | `PLANTNET_ERROR` | Lỗi kết nối hoặc phản hồi không thành công từ máy chủ Pl@ntNet API. |
| **`502`** | `GEMINI_ERROR` | Lỗi kết nối hoặc phản hồi không thành công từ Google Gemini API. |
| **`502`** | `GEMINI_PARSE_ERROR` | Gemini trả về cấu trúc JSON không đúng định dạng mong đợi. |
| **`500`** | `INTERNAL_ERROR` | Lỗi máy chủ nội bộ. Frontend hiển thị thông báo lỗi chung và gợi ý người dùng thử lại sau. |
