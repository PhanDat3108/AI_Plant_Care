# Đồng bộ lịch theo thời tiết

Backend dùng Open-Meteo trước, rồi WeatherAPI nếu nguồn chính không trả dự báo hợp lệ. Cả hai được chuẩn hóa thành Forecast (ngày, lượng mưa mm, xác suất mưa %, nhiệt độ tối đa °C, timezone và source) trước khi đưa vào quy tắc lập lịch. Frontend không cần API key.

## Cấu hình

- Open-Meteo không cần key trong cấu hình hiện tại.
- `WEATHERAPI_API_KEY` trong backend/.env hoặc Render Environment bật nguồn dự phòng; để trống thì không gọi WeatherAPI. Sau đổi env cần khởi động lại/deploy.
- Key chỉ ở backend. Vị trí cây được gửi tới nhà cung cấp để lấy dự báo.
- Cache, gộp request đang chạy và cooldown giảm gọi lặp; bộ nhớ này thuộc từng tiến trình, không chia sẻ giữa nhiều instance và mất khi restart.

## Hành vi

Thời tiết dùng để điều chỉnh hạn tưới cho cây ngoài trời khi có vị trí phù hợp; không tự thay chu kỳ/giờ người dùng đã đặt và không đổi lịch bón phân theo mưa. Cây trong nhà, thiếu vị trí hoặc chưa có dữ liệu chu kỳ có thể không áp dụng dự báo. Nếu cả hai nguồn lỗi, giữ lịch hiện có và trả cảnh báo; không báo rằng đã áp dụng thời tiết mới.

Cron nhắc chăm sóc cũng gọi planner; chỉ chạy tự động khi scheduler được bật. Nút đồng bộ chạy theo yêu cầu. Kết quả không đổi có thể do dự báo chưa đạt điều kiện điều chỉnh, không nhất thiết là lỗi.

## Chẩn đoán

Đối chiếu request ID của POST /plants/:id/care-plan/sync với log Render và warnings/weather_source trong response. `WEATHER_HTTP_ERROR 429` là nguồn chính giới hạn yêu cầu, không chứng minh IP điện thoại bị chặn. Kiểm tra log nguồn dự phòng khi dùng WeatherAPI. Không log URL chứa key hoặc đưa key vào ảnh chụp. Unit tests dùng HTTP giả lập, không chứng minh quota/cloud hiện tại còn hoạt động.

Code: backend/src/services/weather.ts, weather-api.ts và care-planner.ts. Hướng dẫn scheduler: [FREE_REMINDERS_SETUP.md](FREE_REMINDERS_SETUP.md).
