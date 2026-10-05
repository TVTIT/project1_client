# IoT Flutter Web Client

Ứng dụng Web Dashboard giám sát và vận hành hệ thống IoT Gateway–Server (Đồ án 1 — ET3290).

## 1. Yêu cầu môi trường & Thiết lập (Prerequisites & Setup)

Ứng dụng chạy trên Flutter Web với phiên bản Flutter được hỗ trợ (`flutter: ">=3.47.0"`, CI ghim `3.47.1`).

### Cấu hình biến môi trường (`.env`)

Mọi thông số cấu hình đóng gói trong Flutter Web đều là **CÔNG KHAI (PUBLIC)**. Tuyệt đối không thêm secret keys, service_role keys hoặc database passwords vào tệp `.env`.

1. Sao chép tệp mẫu cấu hình sang `.env`:
```bash
cp .env.example .env
```

2. Cập nhật các biến môi trường trong `.env`:
- `BACKEND_API_BASE_URL`: URL gốc của Go REST API qua Nginx (ví dụ `http://localhost/v1/`). Phải luôn kết thúc bằng `/v1/`.
- `SUPABASE_URL`: URL gốc của Supabase Gateway (ví dụ `http://localhost`). Không thêm `/auth/v1` hay `/v1`.
- `SUPABASE_ANON_KEY`: Khóa public anon key do hệ thống Supabase cung cấp (`sb_publishable_...` hoặc JWT với `role: "anon"`).
- `ENVIRONMENT`: `development`, `staging`, hoặc `production`.
- `BACKEND_WS_URL`: WebSocket endpoint cho tương lai (`ws://localhost/v1/ws`).

3. Bắt buộc tạo asset công khai trước mỗi run/build (không đóng gói `.env` gốc):
```bash
dart scripts/validate_client_env.dart
# Hoặc với template placeholder trong CI smoke test:
# dart scripts/validate_client_env.dart --allow-placeholder
```

Chạy `flutter pub get` trước script trong checkout mới để tạo package config.

Script chỉ đọc `.env`, không sửa tệp người dùng, tạo `assets/client.env`
đã kiểm tra allowlist và loại toàn bộ comment; lỗi sẽ xóa asset cũ.
Runtime dùng cùng parser/validator rồi nạp bản chuẩn hóa vào dotenv.
Subset hỗ trợ: `KEY=value`, nháy đơn/đôi ghép cặp, dòng trống và comment
nguyên dòng. Không hỗ trợ export, nội suy, escape, comment cuối dòng,
multiline, biến lạ hoặc khai báo trùng. Giá trị không chứa khoảng trắng.
Chỉ chấp nhận public publishable key hoặc JWT có payload role đúng `anon`;
kiểm tra này không xác minh chữ ký JWT. `--allow-placeholder` chỉ dùng CI
smoke build; runtime vẫn từ chối placeholder và hiển thị màn hình cấu hình.
Có thể dùng `--input /path/public.env` để kiểm tra cấu hình tổng hợp, không đọc `.env`.

### Khởi chạy ứng dụng

```bash
flutter pub get
dart scripts/validate_client_env.dart
flutter run -d chrome
```

### Xây dựng bản phân phối Web Release

```bash
bash scripts/build_web.sh
```

*Lưu ý về CORS & Nginx:* Khi phát triển web qua các origin khác nhau, cần sử dụng reverse proxy cùng origin hoặc cấu hình CORS proxy thích hợp. Không sử dụng cờ `--disable-web-security` của trình duyệt.

## 2. License

This project uses the MIT License.

Original additions and modifications:
Copyright (c) 2026 Trần Vĩnh Trung.

Code incorporated from Kite Flutter Admin Dashboard:
Copyright (c) 2026 Colorlib.

See [LICENSE](LICENSE) for the complete license notices.
