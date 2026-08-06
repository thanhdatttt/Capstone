# Capstone Linux - Kế hoạch công việc (2 - 3 tuần)

## 0. Stack đã chọn

- **OS:** Ubuntu 22.04 LTS Server
- **App:** Node.js + Express, chạy dưới systemd
- **DB:** PostgreSQL
- **Other**: hypervisor (VirtualBox), kênh alert (Mail), network mode, có bonus TLS

Cài đặt: `nodejs`, `postgresql`, `nginx`, `ufw`, `fail2ban`, `auditd`, `lynis`, `rsync`, `shellcheck`

---

## 1. Chia task theo 5 role

### (1) Infrastructure & Networking
- [ ] Tạo VM1 (service host) và VM2 (backup/bastion), đặt hostname rõ nghĩa
- [ ] Cấu hình network nội bộ (Host-only/Internal) để 2 VM thấy nhau
- [ ] Tạo user sudo non-root, tắt SSH root login
- [ ] Tạo phân vùng/ổ backup, mount qua `/etc/fstab`, test sống sau reboot
- [ ] Cấu hình SSH key auth giữa các VM, ProxyJump nếu VM2 là bastion
- [ ] Vẽ sơ đồ kiến trúc 2 VM cho báo cáo

### (2) Reverse Proxy & Web Security
- [ ] Cài Nginx/Apache, làm reverse proxy trỏ tới app (proxy_pass, forward header đúng)
- [ ] Thêm virtual host thứ 2 (trang status hoặc site tĩnh) → đủ ≥2 virtual host
- [ ] Cài UFW/firewalld, default-deny inbound, chỉ mở port cần và giải thích được vì sao
- [ ] Hardening SSH: key auth, tắt root login, đổi port hoặc AllowUsers
- [ ] Cài fail2ban bảo vệ SSH, test trigger 1 ban thật
- [ ] Cài auditd, theo dõi `/etc/passwd`, `/etc/shadow`
- [ ] Chạy Lynis, ghi điểm, sửa ≥3 lỗi, chạy lại so sánh
- [ ] (Bonus) TLS self-signed, redirect HTTP→HTTPS, mở port 443

### (3) Application & systemd
- [ ] Viết app Node/Express: ≥1 API đọc, ≥1 API viết, kết nối Postgres
- [ ] App chỉ lắng nghe localhost (không expose port ra ngoài)
- [ ] Đưa secrets (DB URL...) vào file env riêng, quyền hạn chế (600)
- [ ] Viết unit systemd: `Restart=on-failure`, log ra journald
- [ ] Test kill process app → xác nhận systemd tự restart, thấy trong journalctl

### (4) Database & Backup
- [ ] Cài PostgreSQL, tạo DB riêng cho app
- [ ] Tạo user DB quyền hạn chế (không dùng superuser postgres)
- [ ] Cấu hình Postgres chỉ nghe localhost, verify bằng `ss`
- [ ] Viết `backup.sh`: dump DB + tar web content, nén, đặt tên theo timestamp
- [ ] Thêm retention (xoá backup cũ) ngay trong script
- [ ] rsync backup sang VM2
- [ ] Lên lịch chạy bằng cron/systemd timer, ghi rõ lịch
- [ ] Viết `restore.sh`, **test thật**: xoá dữ liệu rồi phục hồi, kiểm tra đúng dữ liệu

### (5) Automation Toolkit & Alerting
- [ ] Viết menu CLI Bash, điều hướng tới từng tool, xử lý input sai
- [ ] Viết `deploy.sh`: copy file, set quyền, test config trước reload, tự rollback nếu lỗi
- [ ] Viết `health-check.sh`: CPU/RAM/disk, service, port đang nghe, có ngưỡng cảnh báo
- [ ] Nối kênh alert (Telegram/mail), test bằng cách tắt 1 service thật
- [ ] Viết action log rotation: xoay/nén log, giữ N bản, xoá bản cũ
- [ ] Mọi script: `set -euo pipefail`, `trap`, có `--help`, chạy sạch shellcheck

**Lưu ý phối hợp:** Role 2 và 5 đều đụng tới auditd/Lynis/alerting — có thể để R2 build phần bảo mật (auditd, Lynis) còn R5 build phần vận hành (health-check, deploy, backup toolkit dispatch), miễn là thống nhất trước khi code để không làm trùng.

Ai cũng phải hiểu toàn bộ hệ thống, không chỉ phần mình, vì lúc bảo vệ có thể bị hỏi bất kỳ phần nào.

---

## 2. Thứ tự phụ thuộc

Tạo VM trước → App + DB có thể làm song song → Nginx cần app đã chạy → Backup cần DB/app đã có dữ liệu → Toolkit/health-check cần mọi service đã sống. Vì vậy tuần 1 ưu tiên dựng khung, tuần 2 mới đến bảo mật/backup/automation.

---

## 3. Kế hoạch theo tuần

### Tuần 1 — Dựng khung hệ thống

**Ngày 1**
- [x] Chốt stack, tạo repo/drive chung
- [x] (R1) Tạo VM1, VM2, đặt hostname, cấu hình mạng nội bộ giữa 2 VM

**Ngày 2**
- [x] (R1) Tạo user sudo non-root, tắt SSH root login
- [x] (R1) Tạo phân vùng/ổ backup, mount qua `/etc/fstab`, test reboot
- [ ] (R1) Cấu hình SSH key + ProxyJump (nếu VM2 là bastion)
- [ ] (R2) Bắt đầu hardening SSH (key auth, đổi port hoặc AllowUsers)
- [ ] (R3, R4) Cài Node.js và PostgreSQL trên VM1

**Ngày 3–4**
- [ ] (R3) Viết app Express cơ bản: 1 API đọc, 1 API viết, kết nối Postgres
- [ ] (R4) Tạo DB riêng + user quyền hạn chế (không dùng superuser postgres)
- [ ] (R4) Cấu hình Postgres chỉ nghe localhost, sẽ kiểm bằng `ss` sau
- [ ] (R2) Cài Nginx, dựng 1 virtual host tĩnh (trang status)
- [ ] (R2) Cài UFW, mặc định deny inbound, chỉ mở SSH + HTTP

**Ngày 5–6**
- [ ] (R3) App chỉ lắng nghe ở localhost (không public port)
- [ ] (R3) Đưa secrets (DB URL) vào file env riêng, quyền 600
- [ ] (R3) Viết unit systemd cho app: `Restart=on-failure`, log ra journald
- [ ] (R2) Thêm virtual host thứ 2 proxy_pass tới app, forward header đúng
- [ ] (R2) Cài fail2ban bảo vệ SSH, test thử ban 1 lần
- [ ] (R5) Dựng khung menu Bash + `set -euo pipefail` + `trap` cho mọi script từ đầu

**Ngày 7 — Check toàn team**
- [ ] Test end-to-end: curl → Nginx → app → DB có chạy được không, sửa ngay nếu lỗi

### Tuần 2 — Bảo mật, backup, automation

- [ ] (R2) Cài auditd, theo dõi `/etc/passwd` và `/etc/shadow`
- [ ] (R2) Chạy Lynis, ghi điểm, sửa ít nhất 3 lỗi, chạy lại để so sánh
- [ ] (R4) Viết `backup.sh`: dump DB + tar web content, gộp nén, đặt tên theo timestamp
- [ ] (R4) Thêm logic xoá backup cũ (retention) ngay trong script
- [ ] (R4) Thêm rsync backup sang VM2
- [ ] (R4) Đặt lịch chạy bằng cron/systemd timer, ghi rõ lịch trong docs
- [ ] (R4) Viết `restore.sh`, **test thật**: xoá dữ liệu rồi phục hồi, kiểm tra dữ liệu về đúng
- [ ] (R5) Viết `health-check.sh`: kiểm CPU/RAM/disk, service, port đang nghe
- [ ] (R5) Nối kênh alert (Telegram/mail), test bằng cách tắt 1 service thật
- [ ] (R5) Viết `deploy.sh`: copy file, set quyền, test config trước khi reload, tự rollback nếu config lỗi — test bằng config sai thật
- [ ] (R5) Viết action log rotation: xoay, nén log, giữ N bản, xoá bản cũ
- [ ] (R5) Chạy shellcheck liên tục, không để dồn tới cuối
- [ ] (R3, R4) Kill process app, xác nhận systemd tự restart, thấy log trong journalctl
- [ ] (Tuỳ chọn, R2) Làm TLS self-signed, redirect HTTP→HTTPS, mở port 443

**Check cuối tuần 2**
- [ ] Diễn tập toàn bộ demo 1 lần, đúng như sẽ trình bày thật, tìm điểm yếu nhất để sửa tuần 3

### Tuần 3 — Hoàn thiện & bảo vệ

- [ ] Mỗi người đọc lại phần của người khác, không chỉ phần mình
- [ ] Diễn tập demo đầy đủ 2 lần, có người đóng vai "phá hệ thống" giữa demo
- [ ] Diễn tập hỏi-đáp bảo vệ, hỏi nhau các câu mẫu trong đề bài
- [ ] Chụp snapshot VM ở trạng thái tốt trước khi demo thật
- [ ] Viết báo cáo kỹ thuật, mỗi người viết phần mình phụ trách
- [ ] Gộp archive nộp: báo cáo PDF + script + config thật + README, xoá hết secret thật
- [ ] Diễn tập lần cuối 1 ngày trước buổi báo cáo

---

## 4. Phân công viết báo cáo

| Phần | Người viết |
|---|---|
| Tổng quan hệ thống, sơ đồ VM | R1 |
| Bảo mật (firewall, SSH, fail2ban, auditd, Lynis) | R2 |
| Thiết kế app & database | R3 |
| Backup & restore | R4 |
| Automation, shellcheck, alerting | R5 |
| TLS (nếu làm bonus) | R2 |
| Reflection | Mỗi người vài câu |

---

## 5. Lỗi dễ mất điểm nhất

- Để lộ password/key thật trong bài nộp → bị trừ điểm Security
- Backup chưa từng restore thật → mất hết điểm Backup dù script đẹp
- Script thiếu `set -euo pipefail`/`trap`, hoặc fail shellcheck → mất điểm Automation
- Không giải thích được phần của người khác lúc bảo vệ → phần đó bị coi như "không hiểu", trừ điểm cá nhân
- Không snapshot VM trước demo → lỗi nhỏ có thể làm hỏng cả buổi
