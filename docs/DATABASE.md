# Database

PostgreSQL 16 local dùng volume của Compose. Từ gốc repo chạy `npm run db:generate`, `npm run db:migrate`, `npm run db:seed`. Seed dùng upsert trong transaction, tạo hai loài, hai cây và hai lịch thuộc user demo cố định. Chạy seed trên database demo của nhóm.

| Model | Quan hệ và vai trò |
| --- | --- |
| UserProfile | UUID trùng Supabase Auth user ID hoặc UUID demo, sở hữu cây và thông báo |
| PlantSpecies | Tên khoa học unique, nhiều cây có thể cùng loài |
| UserPlant | Thuộc một chủ, loài tùy chọn, ghi chú và object key |
| ScanHistory | Thuộc cây, kết quả JSON, cờ mock, object key và bệnh tham chiếu tùy chọn |
| Disease | Danh mục tên bệnh unique |
| CareSchedule | Công việc và thời điểm đến hạn theo cây |
| CareLog | Ghi nhận thực hiện theo lịch |
| Notification | Nội dung và thời điểm đã đọc theo chủ |

Các quan hệ cá nhân xóa cascade theo cha. Migration bật RLS trên tám bảng, mặc định chặn truy cập từ client qua Data API. Express dùng role DB đủ quyền và lọc theo owner đã xác thực. UUID hồ sơ liên kết logic với Supabase để migration cũng chạy trên PostgreSQL thuần.

Trên Supabase lấy connection strings từ **Connect**. Đặt `DATABASE_URL` cho Prisma runtime, `DIRECT_URL` cho migration (direct connection hoặc session pooler nếu mạng chỉ có IPv4). URL-encode ký tự đặc biệt trong password, dùng SSL theo hướng dẫn project. Không đặt URL DB ở Flutter.

Khi sửa schema, tạo migration trên DB phát triển riêng bằng `npx prisma migrate dev --name ten_thay_doi` trong apps/api. Review SQL và commit cả migration. Database chung áp dụng bằng `npm run db:migrate`. Thêm policy RLS khi tạo bảng mới.
