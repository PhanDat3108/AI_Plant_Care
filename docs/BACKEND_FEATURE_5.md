# Tài liệu API: Vườn Cây Cá Nhân (Backend Feature 5)

Tài liệu này hướng dẫn chi tiết cho đội ngũ Frontend cách tích hợp bộ API **Vườn Cây Cá Nhân (Garden)**: bao gồm quản lý danh sách cây trồng, thêm cây mới từ kết quả quét AI, chỉnh sửa biệt danh, xem chi tiết cây và tích hợp ảnh bìa có chữ ký số (Signed URLs) từ Supabase Storage.

---

## 1. Thông tin chung & Quy ước

* **Base URL:** `/api/v1/garden` *(hoặc prefix theo cấu hình môi trường)*
* **Xác thực (Authentication):** Tất cả các endpoint đều yêu cầu người dùng đã đăng nhập. Frontend phải gửi kèm Token ở Header:
  ```http
  Authorization: Bearer <access_token>
  Content-Type: application/json
  ```
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
  * **Thất bại (400, 401, 404, 500):**
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

## 2. Điểm mới quan trọng (Security & Media Storage)

1. **Bảo mật ảnh bìa (`cover_image_key`):**
   - Khi gửi `cover_image_key` trong request `POST /api/v1/garden`, Backend sẽ kiểm tra trong bảng `scans` xem ảnh này có thực sự thuộc về tài khoản (`owner_id`) hiện tại hay không.
   - Nếu `cover_image_key` không tồn tại hoặc thuộc về tài khoản khác, API sẽ từ chối và trả về lỗi **`400 INVALID_COVER_IMAGE`**.
2. **Ký URL ảnh bìa tự động (`cover_image_url`):**
   - Backend tuyệt đối **không lưu signed URL** vào database vì URL này có thời hạn hết hạn (mặc định 1 giờ).
   - Mỗi khi gọi các API lấy thông tin cây (`POST /api/v1/garden`, `GET /api/v1/garden`, `GET /api/v1/garden/:id`), Backend sẽ tự động sinh signed URL từ Supabase Storage và đính kèm vào trường **`cover_image_url`** bên cạnh trường gốc **`cover_image_key`**.
   - Đối với danh sách cây (`GET /api/v1/garden`), Backend sử dụng cơ chế ký theo lô (`batch signing`) tối ưu tốc độ phản hồi.

---

## 3. Chi tiết các Endpoints

### 3.1. Thêm cây mới vào vườn (`POST /api/v1/garden`)

Tạo một cây mới trong vườn cá nhân của người dùng. Thường được gọi sau khi quét nhận diện hoặc khi người dùng tạo thủ công.

* **Endpoint:** `POST /api/v1/garden`
* **Request Body (JSON):**
  ```json
  {
    "nickname": "Cây Trầu bà bàn làm việc",
    "species_id": "018f3a25-e5f8-7db0-b389-9e8c46ea4823",
    "cover_image_key": "scans/018f3a22-38d1-72ef-b570-5b4cf5796277/d9b4be11-2e29-4d61-b4d6-849c0953a918.jpg",
    "environment": "indoor",
    "latitude": 10.7769,
    "longitude": 106.7009,
    "region_name": "TP. Hồ Chí Minh"
  }
  ```

#### Các trường Request:
| Trường | Kiểu | Bắt buộc | Mô tả |
| :--- | :--- | :--- | :--- |
| `nickname` | String | **Có** | Biệt danh/tên cây do người dùng đặt (tối thiểu 1 ký tự). |
| `species_id` | UUID | Không | ID loài cây trong từ điển `plant_species`. *(Nếu có, cây sẽ tự động được kích hoạt lịch chăm sóc)*. |
| `cover_image_key` | String | Không | Đường dẫn ảnh trong storage (`scans/...`). **Phải thuộc về user hiện tại**. |
| `environment` | String | Không | Môi trường trồng: `"indoor"` (trong nhà), `"outdoor"` (ngoài trời), hoặc `"unknown"` (mặc định). |
| `latitude` | Number | Không | Vĩ độ (-90 đến 90). Nếu gửi phải gửi kèm cả `longitude`. |
| `longitude` | Number | Không | Kinh độ (-180 đến 180). Nếu gửi phải gửi kèm cả `latitude`. |
| `region_name` | String | Không | Tên vùng/thành phố (tối đa 200 ký tự). |

* **Response thành công (`201 Created`):**
  ```json
  {
    "success": true,
    "data": {
      "id": "e5b871c4-1234-4a56-b789-0123456789ab",
      "owner_id": "018f3a22-38d1-72ef-b570-5b4cf5796277",
      "nickname": "Cây Trầu bà bàn làm việc",
      "species_id": "018f3a25-e5f8-7db0-b389-9e8c46ea4823",
      "cover_image_key": "scans/018f3a22-38d1-72ef-b570-5b4cf5796277/d9b4be11-2e29-4d61-b4d6-849c0953a918.jpg",
      "cover_image_url": "https://<supabase-url>/storage/v1/object/sign/plant-images/scans/...token=...",
      "environment": "indoor",
      "latitude": "10.7769",
      "longitude": "106.7009",
      "region_name": "TP. Hồ Chí Minh",
      "reference_image_id": null,
      "created_at": "2026-11-24T16:00:00.000Z"
    },
    "error": null,
    "message": "Thêm cây vào vườn thành công."
  }
  ```

---

### 3.2. Lấy danh sách cây trong vườn (`GET /api/v1/garden`)

Lấy toàn bộ cây trồng thuộc sở hữu của người dùng, sắp xếp theo thời gian tạo mới nhất lên đầu (`created_at DESC`).

* **Endpoint:** `GET /api/v1/garden`
* **Response thành công (`200 OK`):**
  ```json
  {
    "success": true,
    "data": [
      {
        "id": "e5b871c4-1234-4a56-b789-0123456789ab",
        "owner_id": "018f3a22-38d1-72ef-b570-5b4cf5796277",
        "nickname": "Cây Trầu bà bàn làm việc",
        "species_id": "018f3a25-e5f8-7db0-b389-9e8c46ea4823",
        "cover_image_key": "scans/018f3a22-38d1-72ef-b570-5b4cf5796277/d9b4be11-2e29-4d61-b4d6-849c0953a918.jpg",
        "cover_image_url": "https://<supabase-url>/storage/v1/object/sign/plant-images/scans/...token=...",
        "environment": "indoor",
        "latitude": "10.7769",
        "longitude": "106.7009",
        "region_name": "TP. Hồ Chí Minh",
        "reference_image_id": null,
        "created_at": "2026-11-24T16:00:00.000Z"
      }
    ],
    "error": null,
    "message": "OK"
  }
  ```

---

### 3.3. Xem chi tiết 1 cây (`GET /api/v1/garden/:id`)

Lấy thông tin chi tiết một cây, kèm thông tin loài thực vật (`species`), ảnh hướng dẫn mẫu (`referenceImage`) và signed URL ảnh bìa (`cover_image_url`).

* **Endpoint:** `GET /api/v1/garden/:id`
* **Path Parameter:**
  * `id` *(UUID, bắt buộc)*: ID của cây (`plants.id`).
* **Response thành công (`200 OK`):**
  ```json
  {
    "success": true,
    "data": {
      "id": "e5b871c4-1234-4a56-b789-0123456789ab",
      "owner_id": "018f3a22-38d1-72ef-b570-5b4cf5796277",
      "nickname": "Cây Trầu bà bàn làm việc",
      "species_id": "018f3a25-e5f8-7db0-b389-9e8c46ea4823",
      "cover_image_key": "scans/018f3a22-38d1-72ef-b570-5b4cf5796277/d9b4be11-2e29-4d61-b4d6-849c0953a918.jpg",
      "cover_image_url": "https://<supabase-url>/storage/v1/object/sign/plant-images/scans/...token=...",
      "environment": "indoor",
      "species": {
        "id": "018f3a25-e5f8-7db0-b389-9e8c46ea4823",
        "scientific_name": "Epipremnum aureum",
        "common_name": "Trầu bà",
        "common_name_locale": "vi",
        "light_guide": "Ưa bóng râm hoặc ánh sáng tán xạ nhẹ.",
        "water_guide": "Tưới khi bề mặt đất khô khoảng 2-3 cm.",
        "watering_days": 5,
        "fertilizing_days": 30,
        "care_status": "ai_suggested"
      },
      "referenceImage": null
    },
    "error": null,
    "message": "OK"
  }
  ```

---

### 3.4. Đổi biệt danh cây (`PATCH /api/v1/garden/:id/nickname`)

Cập nhật lại tên/biệt danh cho cây.

* **Endpoint:** `PATCH /api/v1/garden/:id/nickname`
* **Path Parameter:**
  * `id` *(UUID, bắt buộc)*: ID của cây.
* **Request Body (JSON):**
  ```json
  {
    "nickname": "Trầu bà leo cột phòng khách"
  }
  ```
* **Response thành công (`200 OK`):**
  ```json
  {
    "success": true,
    "data": {
      "id": "e5b871c4-1234-4a56-b789-0123456789ab",
      "nickname": "Trầu bà leo cột phòng khách"
    },
    "error": null,
    "message": "Cập nhật tên cây thành công."
  }
  ```

---

### 3.5. Xóa cây khỏi vườn (`DELETE /api/v1/garden/:id`)

Xóa cây và toàn bộ lịch chăm sóc, nhiệm vụ liên quan.

* **Endpoint:** `DELETE /api/v1/garden/:id`
* **Path Parameter:**
  * `id` *(UUID, bắt buộc)*: ID của cây.
* **Response thành công (`200 OK`):**
  ```json
  {
    "success": true,
    "data": {
      "id": "e5b871c4-1234-4a56-b789-0123456789ab"
    },
    "error": null,
    "message": "Xóa cây khỏi vườn thành công."
  }
  ```

---

## 4. Bảng mã lỗi HTTP (Error Codes Reference)

| HTTP Status | Error Code (`error.code`) | Nguyên nhân & Hướng xử lý cho Frontend |
| :---: | :--- | :--- |
| **`400`** | `INVALID_INPUT` | Thiếu nickname hoặc dữ liệu gửi lên sai định dạng (ví dụ gửi latitude mà thiếu longitude). |
| **`400`** | `INVALID_COVER_IMAGE` | **Bảo mật:** `cover_image_key` không tồn tại trong bảng scans hoặc không thuộc về người dùng đang đăng nhập. |
| **`400`** | `INVALID_REFERENCE` | `species_id` không tồn tại trong từ điển `plant_species`. |
| **`401`** | `UNAUTHORIZED` | Token đăng nhập thiếu hoặc không hợp lệ. Điều hướng người dùng tới màn hình đăng nhập. |
| **`404`** | `NOT_FOUND` | Không tìm thấy cây với ID được yêu cầu hoặc cây không thuộc về người dùng này. |
| **`500`** | `CREATE_PLANT_FAILED` / `INTERNAL_ERROR` | Lỗi máy chủ khi thao tác cơ sở dữ liệu. |
