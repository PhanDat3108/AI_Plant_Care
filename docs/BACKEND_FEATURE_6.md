# Tài liệu API: Nhật ký Chăm sóc Cây (Backend Feature 6)

Tài liệu này mô tả chi tiết các API phục vụ tính năng **Nhật ký Chăm sóc (Care Logs)**: ghi nhận lịch sử tưới nước, bón phân, chữa bệnh và theo dõi dòng thời gian tiến triển của từng cây trong vườn cá nhân.

---

## 1. Thông tin chung & Quy ước

* **Base URL:** `<API_PREFIX>` *(theo cấu hình mount `apiRoutes` trong `app.ts`, ví dụ `/api` hoặc `/api/v1`)*
* **Xác thực (Authentication):** Tất cả endpoint bên dưới đều yêu cầu đăng nhập. Frontend cần gửi kèm Token ở Header:
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
      "error": null
    }
    ```
  * **Thất bại (400 / 401 / 403 / 404 / 500):**
    ```json
    {
      "success": false,
      "data": null,
      "error": {
        "code": "ERROR_CODE",
        "message": "Mô tả chi tiết lỗi"
      }
    }
    ```

### Lưu ý quan trọng cho Frontend
1. **Giá trị hợp lệ của `kind`:** Trường `kind` được validate theo enum `CARE_LOG_KINDS` định nghĩa tại `backend/src/services/care-logs.ts` (ví dụ: `watering`, `fertilizing`, `pruning`, `treatment`,...). Nếu truyền sai giá trị, API sẽ trả về lỗi `400` kèm danh sách các giá trị hợp lệ.
2. **Chống gửi trùng dữ liệu (`request_id`):** Bảng `care_logs` có ràng buộc duy nhất `@@unique([plant_id, request_id])`. Frontend có thể tự sinh một UUID v4 cho mỗi thao tác bấm nút lưu và gửi lên qua `request_id`. Nếu mạng lag khiến request bị gửi lặp lại 2 lần, Backend sẽ trả về bản ghi đã tạo trước đó thay vì tạo trùng lặp. Nếu không gửi, Backend sẽ tự sinh `request_id`.
3. **Liên kết với nhiệm vụ (`task_id`):** Khi người dùng tick hoàn thành một task từ danh sách việc cần làm (`care_tasks`), Frontend truyền thêm `task_id` tương ứng (lưu ý `plant_id` và `kind` phải khớp với task đó).

---

## 2. Chi tiết các Endpoints

### 2.1. Ghi nhận nhật ký chăm sóc mới
Tạo một bản ghi lịch sử chăm sóc mới (tưới nước, chữa bệnh, bón phân, ghi chú tiến triển...) cho một cây cụ thể.

* **Endpoint:** `POST /plants/:id/care-logs`
* **Path Parameters:**
  * `id` *(string, UUID, bắt buộc)*: ID của cây (`plant_id`) trong vườn của người dùng.
* **Request Body (JSON):**
  ```json
  {
    "kind": "watering",
    "note": "Tưới đẫm buổi sáng, cây bắt đầu nhú 2 lá non mới",
    "performed_at": "2026-11-19T08:30:00.000Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000",
    "task_id": null
  }
  ```
  * `kind` *(string, bắt buộc)*: Loại hoạt động chăm sóc (thuộc `CARE_LOG_KINDS`).
  * `note` *(string | null, tùy chọn)*: Ghi chú tình trạng, biểu hiện hoặc tiến triển của cây.
  * `performed_at` *(ISO 8601 Date String | null, tùy chọn)*: Thời điểm thực hiện chăm sóc. Mặc định lấy thời gian hiện tại của server nếu bỏ trống.
  * `request_id` *(string UUID | null, tùy chọn)*: Khóa chống trùng lặp (idempotency key).
  * `task_id` *(string UUID | null, tùy chọn)*: ID của nhiệm vụ trong `care_tasks` nếu nhật ký này gắn với việc hoàn thành một lịch nhắc.

* **Response Thành công (`201 Created`):**
  ```json
  {
    "success": true,
    "data": {
      "id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
      "plant_id": "123e4567-e89b-12d3-a456-426614174000",
      "request_id": "550e8400-e29b-41d4-a716-446655440000",
      "task_id": null,
      "kind": "watering",
      "performed_at": "2026-11-19T08:30:00.000Z",
      "note": "Tưới đẫm buổi sáng, cây bắt đầu nhú 2 lá non mới"
    },
    "error": null,
    "message": "Tạo nhật ký chăm sóc thành công."
  }
  ```

---

### 2.2. Xem lịch sử chăm sóc & tiến triển của cây
Lấy danh sách các bản ghi nhật ký của một cây, sắp xếp theo dòng thời gian mới nhất lên đầu (`performed_at DESC`).

* **Endpoint:** `GET /plants/:id/care-logs`
* **Path Parameters:**
  * `id` *(string, UUID, bắt buộc)*: ID của cây (`plant_id`).
* **Query Parameters (Tùy chọn):**
  * `kind` *(string)*: Lọc theo loại hoạt động chăm sóc cụ thể (ví dụ: `?kind=watering`).
  * `limit` *(number, từ `1` đến `100`)*: Giới hạn số lượng bản ghi trả về (ví dụ: `?limit=20`).
* **Ví dụ Request:**
  ```http
  GET /plants/123e4567-e89b-12d3-a456-426614174000/care-logs?kind=watering&limit=10
  ```

* **Response Thành công (`200 OK`):**
  ```json
  {
    "success": true,
    "data": [
      {
        "id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
        "plant_id": "123e4567-e89b-12d3-a456-426614174000",
        "request_id": "550e8400-e29b-41d4-a716-446655440000",
        "task_id": null,
        "kind": "watering",
        "performed_at": "2026-11-19T08:30:00.000Z",
        "note": "Tưới đẫm buổi sáng, cây bắt đầu nhú 2 lá non mới"
      },
      {
        "id": "8a0cda3c-2a6c-3abc-8acc-1a0c6a2cba5c",
        "plant_id": "123e4567-e89b-12d3-a456-426614174000",
        "request_id": "440d7300-d18a-30c3-9605-335544330000",
        "task_id": null,
        "kind": "watering",
        "performed_at": "2026-11-16T07:45:00.000Z",
        "note": "Lá hơi rũ, đã tưới bổ sung"
      }
    ],
    "error": null
  }
  ```

---

### 2.3. Cập nhật nội dung nhật ký chăm sóc
Chỉnh sửa loại chăm sóc, ghi chú tiến triển hoặc thời gian thực hiện của một bản ghi nhật ký đã có.

* **Endpoint:** `PATCH /care-logs/:logId`
* **Path Parameters:**
  * `logId` *(string, UUID, bắt buộc)*: ID của bản ghi nhật ký cần sửa.
* **Request Body (JSON):** *(Truyền các trường cần cập nhật)*
  ```json
  {
    "kind": "treatment",
    "note": "Đã phun thuốc trị nấm lá, theo dõi thêm 3 ngày",
    "performed_at": "2026-11-19T09:00:00.000Z"
  }
  ```
  * `kind` *(string, tùy chọn)*: Loại hoạt động chăm sóc mới (thuộc `CARE_LOG_KINDS`).
  * `note` *(string | null, tùy chọn)*: Nội dung ghi chú cập nhật.
  * `performed_at` *(ISO 8601 Date String | null, tùy chọn)*: Thời gian thực hiện cập nhật.

* **Response Thành công (`200 OK`):**
  ```json
  {
    "success": true,
    "data": {
      "id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
      "plant_id": "123e4567-e89b-12d3-a456-426614174000",
      "request_id": "550e8400-e29b-41d4-a716-446655440000",
      "task_id": null,
      "kind": "treatment",
      "performed_at": "2026-11-19T09:00:00.000Z",
      "note": "Đã phun thuốc trị nấm lá, theo dõi thêm 3 ngày"
    },
    "error": null
  }
  ```

---

### 2.4. Xóa một mục nhật ký chăm sóc
Xóa vĩnh viễn một bản ghi nhật ký khỏi lịch sử của cây (chỉ chủ sở hữu cây mới có quyền xóa).

* **Endpoint:** `DELETE /care-logs/:logId`
* **Path Parameters:**
  * `logId` *(string, UUID, bắt buộc)*: ID của bản ghi nhật ký cần xóa.
* **Request Body:** Không có.

* **Response Thành công (`200 OK`):**
  ```json
  {
    "success": true,
    "data": {
      "id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
      "deleted": true
    },
    "error": null
  }
  ```

---

## 3. Bảng mã lỗi HTTP thường gặp

| HTTP Status | Ý nghĩa | Nguyên nhân phổ biến |
| :--- | :--- | :--- |
| **400 Bad Request** | Dữ liệu đầu vào không hợp lệ | Thiếu trường `kind`, `kind` không nằm trong `CARE_LOG_KINDS`, `limit` vượt quá `100`, hoặc sai định dạng UUID/ngày tháng. |
| **401 Unauthorized** | Chưa xác thực | Thiếu header `Authorization: Bearer <token>` hoặc token hết hạn. |
| **403 Forbidden** | Không có quyền truy cập | Cây (`plant_id`) hoặc bản ghi (`logId`) không thuộc quyền sở hữu của user đang đăng nhập. |
| **404 Not Found** | Không tìm thấy dữ liệu | `plant_id` hoặc `logId` không tồn tại trong hệ thống. |
| **500 Internal Server Error** | Lỗi hệ thống | Lỗi kết nối database hoặc ngoại lệ không xác định từ server. |