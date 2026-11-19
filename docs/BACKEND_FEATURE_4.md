# Tài liệu Backend Feature 4: Quản lý Vườn cá nhân (Personal Garden Management)

Tài liệu này tổng hợp cấu trúc database, các endpoint API backend và hướng dẫn triển khai cho tính năng quản lý vườn cây cá nhân của người dùng, sử dụng Node.js, TypeScript, Prisma và Supabase.

---

## 1. Cấu trúc Database (Prisma Model)
Tính năng này sử dụng model `plants` đã được định nghĩa sẵn trong `schema.prisma`:

```prisma
model plants {
  id                 String            @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  owner_id           String            @db.Uuid
  species_id         String?           @db.Uuid
  nickname           String
  cover_image_key    String?
  environment        String            @default("unknown")
  region_name        String?
  latitude           Decimal?          @db.Decimal(7, 4)
  longitude          Decimal?          @db.Decimal(7, 4)
  created_at         DateTime          @default(now()) @db.Timestamptz(6)
  reference_image_id String?           @db.Uuid
  profiles           profiles          @relation(fields: [owner_id], references: [id], onDelete: Cascade, onUpdate: NoAction)
  @@schema("plantcare")
}
```

---

## 2. Kiến trúc phân tầng (Layered Architecture)
Nhóm phát triển theo mô hình:
1. **Service (`src/services/garden.ts`):** Tương tác trực tiếp với Prisma để xử lý logic database (Thêm, Lấy, Sửa, Xóa).
2. **Controller (`src/controllers/garden.ts`):** Nhận request/response từ Express, gọi service và trả về HTTP status phù hợp.
3. **Routes (`src/routes/garden.ts`):** Khai báo các đường dẫn API gắn liền với controller và tích hợp middleware xác thực token.

---

## 3. Danh sách các API Endpoints

### 3.1. Thêm cây vào vườn
* **Endpoint:** `POST /api/v1/garden`
* **Authentication:** Yêu cầu Bearer Token trong Header.
* **Request Body (JSON):**
  ```json
  {
    "nickname": "Cây trầu bà phòng khách",
    "species_id": "uuid-cua-giong-loai-neu-co",
    "cover_image_key": "path/to/image.jpg",
    "environment": "indoor"
  }
  ```
* **Response Thành công (201 Created):**
  ```json
  {
    "success": true,
    "message": "Thêm cây vào vườn thành công",
    "data": {
      "id": "uuid-cay-vua-tao",
      "nickname": "Cây trầu bà phòng khách",
      "created_at": "2026-11-17T..."
    }
  }
  ```

### 3.2. Xem danh sách cây trong vườn
* **Endpoint:** `GET /api/v1/garden`
* **Authentication:** Yêu cầu Bearer Token.
* **Request Body:** Không có.
* **Response Thành công (200 OK):**
  ```json
  {
    "success": true,
    "data": [
      {
        "id": "uuid-cay-1",
        "nickname": "Cây trầu bà phòng khách",
        "cover_image_key": "path/to/image.jpg",
        "created_at": "2026-11-17T..."
      }
    ]
  }
  ```

### 3.3. Sửa biệt danh cây
* **Endpoint:** `PATCH /api/v1/garden/:id/nickname`
* **Authentication:** Yêu cầu Bearer Token.
* **Request Body (JSON):**
  ```json
  {
    "nickname": "Trầu bà đại phú gia"
  }
  ```
* **Response Thành công (200 OK):**
  ```json
  {
    "success": true,
    "message": "Cập nhật biệt danh thành công"
  }
  ```

### 3.4. Xóa cây khỏi vườn
* **Endpoint:** `DELETE /api/v1/garden/:id`
* **Authentication:** Yêu cầu Bearer Token.
* **Request Body:** Không có.
* **Response Thành công (200 OK):**
  ```json
  {
    "success": true,
    "message": "Đã xóa cây khỏi danh sách theo dõi"
  }
  ```