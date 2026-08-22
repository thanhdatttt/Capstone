# BÁO CÁO GIA CỐ HỆ THỐNG VỚI LYNIS (LYNIS AUDIT & REMEDIATION)
**Hệ điều hành:** Ubuntu 22.04 LTS Server | **Máy chủ:** VM1 (`opsadmin@vm1`)

---

## 1. Kết quả kiểm toán ban đầu (Before Remediation)
* **Công cụ sử dụng:** Lynis 3.0.7
* **Lệnh quét:** `sudo lynis audit system --quick`
* **Điểm gia cố ban đầu (Hardening Index):** **61 / 100**
* **Tổng số kiểm tra (Tests):** 271
* **Số gợi ý (Suggestions):** 48

---

## 2. Ba mục cảnh báo đã lựa chọn khắc phục

### 1. [BANN-7126 & BANN-7130] Thêm Banner cảnh báo pháp lý đăng nhập
* **Vấn đề:** Chưa có thông báo cảnh báo người dùng trái phép tại màn hình đăng nhập console và mạng.
* **Biện pháp:** Thêm Legal Warning Banner vào `/etc/issue` và `/etc/issue.net`.
* **Lệnh thực hiện:**
  ```bash
  sudo bash -c 'cat << "EOF" > /etc/issue
  ********************************************************************
  * WARNING: Unauthorized access to this system is strictly forbidden *
  * and will be prosecuted. All activities are monitored and logged. *
  ********************************************************************
  EOF'
  sudo cp /etc/issue /etc/issue.net
  ```

---

### 2. [AUTH-9328] Siết chặt Umask mặc định `027`
* **Vấn đề:** Mặc định `umask 022` cho phép người dùng khác (`others`) đọc được các file mới tạo.
* **Biện pháp:** Đổi sang `umask 027` trong `/etc/login.defs` để file mới tạo mặc định không cho phép `others` đọc/ghi/thực thi.
* **Lệnh thực hiện:**
  ```bash
  sudo sed -i 's/^UMASK.*/UMASK\t\t027/' /etc/login.defs
  ```

---

### 3. [HRDN-7222] Khóa quyền thực thi trình biên dịch với User thường
* **Vấn đề:** User thường có thể dùng `gcc`/`make` để biên dịch mã độc hoặc exploit leo quyền trực tiếp trên server.
* **Biện pháp:** Giới hạn quyền thực thi của compiler chỉ dành cho `root` (`chmod 750`).
* **Lệnh thực hiện:**
  ```bash
  sudo chmod 750 /usr/bin/gcc* /usr/bin/g++* /usr/bin/as /usr/bin/make 2>/dev/null || true
  ```

---

## 3. Kết quả sau khi khắc phục (After Remediation)

| Tiêu chí | Trước khi fix | Sau khi fix | Kết quả |
| :--- | :---: | :---: | :---: |
| **Hardening Index** | **61** | **63** | 🟢 **Tăng 2 điểm** |
| **Suggestions** | **48** | **44** | 🟢 **Giảm 4 cảnh báo** |
| **Banner Status** | `WEAK` | `OK` | 🟢 Đạt chuẩn |
| **Umask Status** | `SUGGESTION` | `OK` | 🟢 Đạt chuẩn |
