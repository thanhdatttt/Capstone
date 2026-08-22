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
| Nguyen Van Minh | 23127423 | R2 — Reverse Proxy & Web Security |
| Pham Thanh Dat | 23127170 | R3 — Application & systemd |
| Mai Xuan Hung | 23127372 | R4 — Database & Backup |
| Nguyen Tan Loc | 23127406 | R5 — Automation Toolkit & Alerting |

---

# 📁 Project Structure

```
Capstone/                        ← Repository root
├── README.md
├── docs/                              ← Technical reports, audit, and demo runbook
│   ├── demo_runbook.md                ← 12-15 min demo walkthrough & speaking script
│   ├── cmd.txt                        ← Fast copy-paste command checklist
│   ├── lynis_remediation_report.md    ← Lynis audit & 3 remediation items (61 -> 63)
│   ├── audit_compliance_report.md     ← Rubrics compliance audit report
│   └── task_plan.md                   ← Team execution plan
│
├── vm1/                               ← Filesystem mirror for VM1 (Service Host)
│   ├── etc/
│   │   ├── audit/rules.d/
│   │   │   └── sensitive_files.rules  ← Auditd rules for /etc/passwd & /etc/shadow
│   │   ├── capstoneapp/
│   │   │   └── .env.example           ← Secrets template (real .env is 0600)
│   │   ├── fail2ban/
│   │   │   └── jail.local             ← Fail2ban jail configuration (sshd)
│   │   ├── nginx/sites-available/
│   │   │   ├── capstone.conf          ← VHost #1 (app.lab.local :3000 + TLS)
│   │   │   └── sysinfo.conf           ← VHost #2 (status.lab.local :4000 + TLS)
│   │   ├── systemd/system/
│   │   │   ├── capstone-app.service   ← Main app unit (Restart=on-failure)
│   │   │   ├── info-app.service       ← Sysinfo app unit
│   │   │   ├── capstone-backup.service← Backup service with OnFailure alert
│   │   │   ├── capstone-backup.timer  ← Scheduled backup timer (02:00 daily)
│   │   │   ├── capstone-backup-alert.service ← Alert service triggered on backup failure
│   │   │   ├── health-check.service   ← Monitoring service
│   │   │   └── health-check.timer     ← Periodic health check timer (every 10m)
│   │   └── issue                      ← Security Legal Warning Banner
│   │
│   └── opt/
│       ├── capstone-app/              ← Node.js CRUD App (server.js, public UI)
│       ├── info-app/                  ← SysInfo Microservice (localhost:4000)
│       ├── postgres-svc/              ← Docker Compose PostgreSQL 17 + seed.sql
│       └── scripts/                   ← ShellCheck Clean 100% Operations Toolkit
│           ├── menu.sh                ← Interactive CLI Menu
│           ├── deploy.sh              ← Safe Deployment with Auto-Rollback
│           ├── health-check.sh        ← Health Monitoring & Email Alerting
│           ├── log-rotate.sh          ← Log Rotation & Gzip Compression
│           ├── backup.sh              ← Automated Backup & Retention & Rsync
│           └── restore.sh             ← Full Disaster Recovery & Database Import
│
└── vm2/                               ← Filesystem mirror for VM2 (Backup Host)
    ├── data/backups/capstoneapp/      ← Rsync destination directory (opsadmin:opsadmin)
    └── etc/
        ├── audit/rules.d/
        │   └── sensitive_files.rules  ← Auditd baseline rules
        └── fail2ban/
            └── jail.local             ← Fail2ban SSH protection
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
