<p align="center"><h1 align="center">CAPSTONE</h1></p>
<p align="center">
<em>LINUX OPERATING SYSTEM & APPLICATIONS — CAPSTONE PROJECT</em>
</p>
<br>

## 🔗 Table of Contents

- [📍 Overview](#-overview)
- [👥 Team members](#-team-members)
- [📁 Project Structure](#-project-structure)
- [👾 Features](#-features)
- [📜 License](#-license)
---

# 📍 Overview

This project deploys and hardens a small production-style Linux service across **2 virtual machines** (service host + backup/bastion), running on **Ubuntu 22.04 LTS**.

The system consists of three mandatory components:
1. **Infrastructure, Web & Security** — Nginx reverse proxy with ≥2 virtual hosts, UFW firewall (default-deny inbound), hardened SSH, fail2ban, auditd, and a Lynis hardening pass.
2. **Application & Database** — a Node.js/Express app (read + write API) backed by PostgreSQL, running as a `systemd` service with auto-restart, localhost-only binding, and secrets kept out of the codebase.
3. **Operations & Automation** — a Bash CLI toolkit for deploy (with rollback), backup/restore (with rsync to the second VM), health-check with alerting, and log rotation — every script passing `shellcheck` with `set -euo pipefail` and `trap`.

A bonus self-signed TLS setup (HTTP → HTTPS redirect) is also included.

---

# 👥 Team members

| Fullname | Student ID | Role |
|---|---|---|
| Huynh Hao Nam | 23127431 | R1 — Infrastructure & Networking |
| Nguyen Tan Loc | 23127406 | R2 — Reverse Proxy & Web Security |
| Pham Thanh Dat | 23127170 | R3 — Application & systemd |
| Mai Xuan Hung | 23127372 | R4 — Database & Backup |
| Nguyen Van Minh | 23127423 | R5 — Automation Toolkit & Alerting |

---

# 📁 Project Structure

```
Capstone/                        ← Repository root
├── README.md
├── docs/                              ← Technical report, architecture diagrams
│   ├── report.pdf
│   └── vm-architecture.png
│
├── app/                               ← Node.js + Express application
│   ├── src/
│   │   └── server.js                  ← PostgreSQL connection pool, Read (GET) & write (POST) API endpoints
│   ├── package.json
│   ├── .env.example                   ← Template for secrets (real .env is 600, never committed)
│   └── app.service                    ← systemd unit (Restart=on-failure, journald)
│
├── nginx/                             ← Reverse proxy configs
│   ├── app.conf                       ← Virtual host #1 — proxy_pass to app
│   ├── status.conf                    ← Virtual host #2 — static status page
│   └── tls/                           ← (Bonus) self-signed cert + HTTP→HTTPS redirect
│
├── db/                                ← PostgreSQL setup
│   ├── seed.sql                       ← seed DB + least-privilege role creation
│   └── postgresql.conf.d/             ← localhost-only listen config
│
├── security/                          ← Hardening configs
│   ├── sshd_config.d/                 ← Key auth, no root login, custom port/AllowUsers
│   ├── ufw-rules.sh
│   ├── fail2ban/
│   └── auditd/                        ← Watch rules for /etc/passwd, /etc/shadow
│
├── backup/
│   ├── backup.sh                      ← Dump DB + tar web content, compress, timestamp, retention, rsync to VM2
│   ├── restore.sh                     ← Restore procedure (tested against real data loss)
│   └── crontab / backup.timer         ← Scheduled run
│
├── toolkit/                           ← Automation CLI menu
│   ├── menu.sh                        ← Entry point, dispatches to each tool
│   ├── deploy.sh                      ← Copy, set perms, test config, reload, auto-rollback
│   ├── health-check.sh                ← CPU/RAM/disk/service/port checks + alert thresholds
│   ├── alert.sh                       ← Mail/Telegram notification channel
│   └── logrotate.sh                   ← Rotate, compress, retain N, purge old logs
│
└── lynis/                             ← Before/after hardening scan results
    ├── before.txt
    └── after.txt
```

---

# 👾 Features

- 🖥️ **2-VM architecture** — dedicated service host and backup/bastion node on an internal network, with SSH key auth and ProxyJump.
- 🌐 **Reverse proxy** — Nginx in front of the app with correct header forwarding, plus a second virtual host for a static status page.
- 🔐 **Security hardening** — UFW default-deny inbound, SSH hardening, fail2ban with a live-triggered ban, auditd watching sensitive files, and a Lynis score with ≥3 remediated findings.
- 🚀 **Application layer** — Express API (read + write) on PostgreSQL, localhost-only, managed by `systemd` with automatic restart on failure.
- 🗄️ **Backup & restore** — compressed, timestamped, retention-aware backups synced to VM2, scheduled via cron/systemd timer, with a real, rehearsed restore.
- 🛠️ **Automation toolkit** — a single Bash menu driving deploy (with rollback), health-check (with alerting), and log rotation, all `shellcheck`-clean with `set -euo pipefail` and `trap`.
- 🔒 **(Bonus) TLS** — self-signed certificate with HTTP→HTTPS redirect on port 443.

---

# 📜 License

This project is developed for educational purposes only.

Copyright © 2026
All rights reserved by the project team.

This software may not be copied, modified, or distributed for commercial purposes without permission from the authors.
