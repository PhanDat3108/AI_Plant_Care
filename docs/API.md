# REST API v1

Base URL local `http://localhost:3100/api/v1`. Health công khai. Các route khác yêu cầu `Authorization: Bearer ACCESS_TOKEN` trừ khi bật development bypass. Header user ID từ client không quyết định owner.

| Method | Path | Input → data |
| --- | --- | --- |
| GET | /health | status, isMock, demoAuth |
| GET | /plants | Mảng cây của owner, mới nhất trước |
| POST | /plants | JSON name (1–100), notes tùy chọn (≤2000) → cây, HTTP 201 |
| GET | /plants/:id | UUID → cây kèm species |
| PATCH | /plants/:id | Ít nhất một trong name, notes → cây |
| DELETE | /plants/:id | UUID → null |
| POST | /scans/analyze | multipart, một trường image (JPEG/PNG ≤5 MiB) → kết quả |
| GET | /care-schedules | Lịch theo dueAt tăng dần, kèm plant |
| GET | /weather/forecast | latitude, longitude bắt buộc → date, maxC, rainMm, isMock |

Ví dụ request tạo cây: `{"name":"Trầu bà bàn học","notes":"Cạnh cửa sổ"}`. Đọc dự báo bằng `GET /api/v1/weather/forecast?latitude=10.78&longitude=106.7`. Để gửi ảnh từ terminal dùng `curl -F "image=@leaf.jpg" http://localhost:3100/api/v1/scans/analyze` (PowerShell dùng curl.exe).

```json
{"success":true,"data":{"isMock":true,"species":{"name":"Epipremnum aureum","probability":0.94},"diseases":[{"name":"Đốm lá","probability":0.62},{"name":"Vàng lá","probability":0.28}],"care":"Đặt cây ở nơi có ánh sáng gián tiếp. Kiểm tra độ ẩm của đất trước khi tưới.","possibleCause":"Ví dụ minh họa: lá ẩm lâu trong môi trường ít thông thoáng."},"error":null,"message":"OK"}
```

```json
{"success":false,"data":null,"error":{"code":"UNAUTHORIZED"},"message":"Bạn cần đăng nhập."}
```

400 INVALID_INPUT/IMAGE_REQUIRED, 401 UNAUTHORIZED, 404 NOT_FOUND (bao gồm cây của người khác), 413 IMAGE_TOO_LARGE, 415 INVALID_IMAGE, 422 NO_PLANT, 502 PROVIDER_UNAVAILABLE, 503 AUTH_UNAVAILABLE/DATABASE_UNAVAILABLE. Xác suất từ 0 đến 1. possibleCause có thể null. Endpoint quét hiện trả kết quả ngay, chưa ghi lịch sử.
