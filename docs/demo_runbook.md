# 🚀 KỊCH BẢN DEMO CAPSTONE LINUX (DEMO RUNBOOK)
**Thời lượng mục tiêu:** 12–15 phút | **Học phần:** Hệ điều hành Linux & Ứng dụng
**Cấu hình mạng:** VM1 (`192.168.56.103`) ⟷ VM2 (`192.168.56.104`)

---

## 🖥️ Chuẩn bị Màn hình & Terminal trước Demo

| Terminal | Mục đích | Lệnh kết nối |
| :--- | :--- | :--- |
| **Terminal 1** | **VM1** (Service Host - App / Nginx / DB) | `ssh -p 3333 opsadmin@howname.viewdns.net` |
| **Terminal 2** | **VM2** (Backup Host / Bastion) | `ssh -p 4444 opsadmin@howname.viewdns.net` |
| **Terminal 3** | **Client Test** (Gọi curl từ ngoài hoặc tab riêng) | Tab terminal tại máy cá nhân |

> [!TIP]
> **Quy tắc vàng:** Chụp **Snapshot** VM1 và VM2 ở trạng thái sạch trước khi demo. Nếu gặp trục trặc bất ngờ, chỉ cần Revert Snapshot và tiếp tục, không để bị gián đoạn.

---

## ⏱️ PHẦN 1: Khởi động & Tổng quan Hệ thống (1–2 phút)

> **🗣️ Lời dẫn thuyết trình:**
> *"Kính thưa Thầy/Cô, hệ thống của nhóm em được thiết kế theo mô hình 2 máy ảo độc lập, kết nối qua mạng nội bộ Host-Only 192.168.56.0/24. VM1 đóng vai trò Application/Web/DB Host và VM2 đóng vai trò Backup Host. Sau đây em xin kiểm tra tường lửa và trạng thái các dịch vụ cốt lõi."*

### 1. Kiểm tra thông tin Host & Tường lửa Firewall UFW:
*(Chạy trên **Terminal 1 - VM1**)*
```bash
hostnamectl
sudo ufw status verbose
```
* **Giải thích:** Firewall bật chế độ mặc định `deny incoming`, chỉ mở đúng cổng 22 (SSH), 80 (HTTP) và 443 (HTTPS).

### 2. Kiểm tra trạng thái 5 dịch vụ cốt lõi:
```bash
systemctl status nginx --no-pager
systemctl status docker --no-pager
systemctl status capstone-app --no-pager
systemctl status info-app --no-pager
systemctl status fail2ban --no-pager
```

---

## ⏱️ PHẦN 2: Hệ thống chạy End-to-End & Nginx Virtual Hosts (2–3 phút)

> **🗣️ Lời dẫn thuyết trình:**
> *"Tiếp theo, em xin chứng minh luồng hoạt động End-to-End: Nginx tiếp nhận HTTPS, reverse proxy về 2 ứng dụng nội bộ riêng biệt trên 2 Virtual Hosts và kết nối CSDL PostgreSQL."*

### 1. Gọi Health Check & Virtual Host chính (`app.lab.local` - Port 3000):
```bash
curl -s -k https://127.0.0.1/api/health -H "Host: app.lab.local"
```
* **Kết quả:** `{"status":"ok","db":"connected"}`

### 2. Đọc danh sách Notes hiện tại trong Database (GET):
```bash
curl -s -k https://127.0.0.1/api/notes -H "Host: app.lab.local"
```

### 3. Ghi dữ liệu mới vào DB qua API (POST):
```bash
curl -k -X POST https://127.0.0.1/api/notes \
  -H "Host: app.lab.local" \
  -H "Content-Type: application/json" \
  -d '{"content": "DEMO RECORD - END TO END TEST LIVE"}'
```

### 4. Đọc lại để chứng minh dữ liệu vừa ghi đã lưu vào DB thành công:
```bash
curl -s -k https://127.0.0.1/api/notes -H "Host: app.lab.local"
```

### 5. Chứng minh Virtual Host thứ 2 (`status.lab.local` - Port 4000) hoạt động độc lập:
```bash
curl -s -k https://127.0.0.1/ -H "Host: status.lab.local"
```

### 6. Chứng minh HTTP (Port 80) tự động Redirect 301 sang HTTPS (Port 443):
```bash
curl -s -I http://127.0.0.1/ -H "Host: app.lab.local" | head -n 5
```

### 7. Chứng minh PostgreSQL và Info-App CHỈ lắng nghe trên Localhost (`127.0.0.1`):
```bash
ss -tulpn | grep -E ':(4000|5432) '
```
* **Kết quả:** Cả 2 cổng đều hiển thị `127.0.0.1:4000` và `127.0.0.1:5432`, không lộ `0.0.0.0` ra ngoài.

---

## ⏱️ PHẦN 3: Bảo mật: Fail2ban & Auditd (2 phút)

> **🗣️ Lời dẫn thuyết trình:**
> *"Em xin demo cơ chế bảo mật chủ động: Fail2ban tự động phát hiện và chặn brute-force SSH, kết hợp Auditd ghi vết truy cập file nhạy cảm."*

### 1. Xem trạng thái Fail2ban trước khi tấn công *(Terminal 1 - VM1)*:
```bash
sudo fail2ban-client status sshd
```

### 2. Giả lập Brute-Force từ VM2 vào VM1 *(Terminal 2 - VM2)*:
```bash
ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password opsadmin@192.168.56.103
```
* **Thao tác:** Gõ sai mật khẩu 3 lần liên tiếp cho đến khi bị ngắt kết nối.

### 3. Chứng minh IP của VM2 (`192.168.56.104`) đã bị Ban tự động *(Terminal 1 - VM1)*:
```bash
sudo fail2ban-client status sshd
```
* **Kết quả:** `Currently banned: 1` và `Banned IP list: 192.168.56.104`.

### 4. Gỡ ban (Unban) để VM2 kết nối lại bình thường *(Terminal 1 - VM1)*:
```bash
sudo fail2ban-client set sshd unbanip 192.168.56.104
sudo fail2ban-client status sshd
```

### 5. Demo Auditd bắt sự kiện tác động vào `/etc/passwd`:
```bash
sudo touch /etc/passwd
sudo ausearch -k passwd_changes -i | tail -n 25
```

### 6. Báo cáo điểm số Lynis:
> *"Điểm gia cố hệ thống ban đầu của nhóm là **61/100**. Sau khi khắc phục 3 mục gợi ý (Legal Banner, Umask 027, Restrict Compilers), điểm đã tăng lên **63/100**."*

---

## ⏱️ PHẦN 4: Sao lưu & Khôi phục (Backup & Restore) (2–3 phút) — ⭐ 20% ĐIỂM

> **🗣️ Lời dẫn thuyết trình:**
> *"Đây là phần quan trọng nhất: Em sẽ chạy backup dữ liệu mới, sau đó cố tình xóa sạch CSDL trong database, và chạy script khôi phục để chứng minh phục hồi nguyên vẹn."*

### 1. Xem dữ liệu trước khi backup *(Terminal 1 - VM1)*:
```bash
curl -s -k https://127.0.0.1/api/notes -H "Host: app.lab.local"
```

### 2. Chạy Script Backup (Dump DB, nén App, xóa bản cũ > 7 ngày, rsync sang VM2):
```bash
sudo /opt/scripts/backup.sh
```

### 3. Kiểm tra file backup mới tạo trên VM1 và VM2:
```bash
# Trên VM1:
ls -lh /data/backups/capstoneapp/

# Chứng minh đã rsync sang VM2:
ssh -o BatchMode=yes opsadmin@192.168.56.104 "ls -lh /data/backups/capstoneapp/"
```

### 4. 💥 PHÁ HỦY DỮ LIỆU THẬT (Xóa sạch bảng notes trong Database):
```bash
sudo bash -c 'source /etc/capstoneapp/.env && docker exec -i "$DB_CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "TRUNCATE TABLE notes;"'
```

### 5. Kiểm tra lại Web App (Dữ liệu đã biến mất hoàn toàn: `[]`):
```bash
curl -s -k https://127.0.0.1/api/notes -H "Host: app.lab.local"
```

### 6. 🔄 Chạy RESTORE khôi phục từ bản backup mới nhất:
```bash
LATEST_BACKUP=$(ls -t /data/backups/capstoneapp/backup_*.tar.gz | head -n 1)
sudo /opt/scripts/restore.sh "$LATEST_BACKUP"
```

### 7. ✅ KIỂM TRA LẠI: Toàn bộ dữ liệu đã được phục hồi nguyên vẹn 100%!
```bash
curl -s -k https://127.0.0.1/api/notes -H "Host: app.lab.local"
```

---

## ⏱️ PHẦN 5: Tự động hóa & Cảnh báo Sự cố (1–2 phút)

> **🗣️ Lời dẫn thuyết trình:**
> *"Em xin demo bộ công cụ tự động hóa: Menu CLI điều phối, và kịch bản Health Check phát hiện sự cố tự động bắn email cảnh báo."*

### 1. Khởi chạy Menu CLI tương tác:
```bash
sudo /opt/scripts/menu.sh
```
* **Thao tác:** Nhập `4` (Health check) $\rightarrow$ Nhấn Enter $\rightarrow$ Nhập `6` (Quick Status) $\rightarrow$ Nhập `0` (Thoát).

### 2. Tạo lỗi thật (Dừng service `info-app`):
```bash
sudo systemctl stop info-app
```

### 3. Chạy script Health-Check phát hiện sự cố:
```bash
sudo /opt/scripts/health-check.sh
```
* **Kết quả:** Màn hình in cảnh báo đỏ `[-] Service info-app: INACTIVE [ALERT]`, tự động gửi email cảnh báo về `namhaohuynh@gmail.com`.
* **Mở email** cho giảng viên xem thông báo vừa gửi đến tức thì!

### 4. Khởi động lại service và xác nhận hệ thống xanh trở lại:
```bash
sudo systemctl start info-app
sudo /opt/scripts/health-check.sh
```

### 5. Demo Triển khai An toàn (deploy.sh) với kiểm tra cú pháp & rollback:
```bash
sudo /opt/scripts/deploy.sh --app capstone-app
```

---

## ⏱️ PHẦN 6: Systemd Auto-Restart khi Process bị Crash (30 giây)

> **🗣️ Lời dẫn thuyết trình:**
> *"Cuối cùng, em chứng minh chính sách Restart=on-failure của systemd giúp ứng dụng tự phục hồi khi tiến trình bị tiêu diệt bất ngờ."*

```bash
# 1. Xem PID và số lần restart ban đầu:
systemctl show -p MainPID,NRestarts,ActiveState capstone-app.service

# 2. Bắn hạ tiến trình Node.js bằng kill -9:
OLD_PID=$(systemctl show -p MainPID --value capstone-app.service)
sudo kill -9 "$OLD_PID"

# 3. Kiểm tra lại sau 2 giây (PID mới đã sinh ra, NRestarts tăng lên, trạng thái active):
sleep 2
systemctl show -p MainPID,NRestarts,ActiveState capstone-app.service
journalctl -u capstone-app.service -n 8 --no-pager

# 4. Web App vẫn phản hồi bình thường:
curl -s -k https://127.0.0.1/api/health -H "Host: app.lab.local"
```
