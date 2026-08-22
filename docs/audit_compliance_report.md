# Linux Capstone Audit Compliance Report

**Initial audit:** 2026-08-21 01:56–02:00 UTC (08:56–09:00 Asia/Ho_Chi_Minh)<br>
**Recheck:** 2026-08-21 02:28–02:29 UTC (09:28–09:29 Asia/Ho_Chi_Minh)<br>
**Privileged evidence received:** 2026-08-21 after the live recheck<br>
**Focused TLS/mail/VM2 recheck:** 2026-08-21 02:45 UTC (09:45 Asia/Ho_Chi_Minh)<br>
**PostgreSQL ownership/grant evidence received:** 2026-08-21<br>
**Auditor role:** Senior Linux System Auditor<br>
**Scope:** Workspace deliverables plus live read-only SSH verification of VM1 and VM2<br>
**VM1:** `vm1`, Ubuntu 22.04.5 LTS, `192.168.56.103`, SSH via port 3333<br>
**VM2:** `vm2`, Ubuntu 22.04.5 LTS, `192.168.56.104`, SSH via port 4444

**Authoritative inputs reviewed:**

- `Capstone_Project_Linux.md` — English requirements, deliverables, full grading rubric, compliance matrix, and pre-submission checklist.
- `Do_An_Cuoi_Ky_Linux.md` — Vietnamese source specification; its mandatory components and grading weights align with the English version.
- `lynis_remediation_report.md` — documented Lynis baseline 61, remediated score 63, suggestions 48→44, and three selected hardening actions.

## Executive Summary

**Recheck conclusion: the infrastructure is still not 100% ready for final submission or the live defense, but the TLS technical blocker is now resolved.** The core runtime remains healthy, the certificate now carries every required DNS/IP SAN, both msmtp files have correct `0600` access boundaries, and VM2 has active/enabled UFW, auditd, and fail2ban with its SSH jail configured. Remaining blockers are submission/demo evidence and the toolkit/storage/backup gaps listed below.

Submission readiness is blocked by the following findings:

1. **FAIL — submission package remains incomplete:** the workspace and both checked home directories have no project `README.md`, final technical report PDF, exported service configurations, work-allocation table, or assembled submission archive.
2. **FAIL — application DB role is not least-privileged:** `app_user` owns `public.notes` and holds DELETE, UPDATE, TRUNCATE, TRIGGER, and REFERENCES in addition to the SELECT/INSERT privileges used by the current read/write endpoints.
3. **WARN — audit demo evidence remains:** passwd/shadow rules are confirmed, but no matching write/attribute audit event has been produced and shown.
4. **WARN — toolkit gaps remain:** VM1 scripts retain the prior timestamps/content. `menu.sh` traps only INT, deploy uses service restart rather than the exact test→reload flow, and `log-rotate.sh` still uses `chmod 666` when creating a missing log.
5. **WARN — mandatory destructive demonstrations not performed:** no live database restore, app-process kill/restart, fail2ban ban, audit event, health-check fault alert, retention deletion, or broken-deploy rollback was triggered during this read-only recheck.
6. **WARN — storage and backup risks remain:** both `/data` mounts are loop-backed files, and the replicated backup still contains application `.env` files.

The system should be treated as **technically promising but submission-blocked** until every FAIL is remediated and every live-demo WARN is rehearsed with recorded evidence.

## Status Rules and Limitations

- **PASS:** directly confirmed by live output or a readable canonical configuration plus matching runtime behavior.
- **WARN:** partially compliant, unable to verify because of privilege/read-only limits, or requires a live demonstration not safely performed during this audit.
- **FAIL:** live state contradicts the requirement or a mandatory artifact/control is absent.
- SSH used public-key authentication and `BatchMode=yes`. Both VMs permit sudo, but non-interactive sudo failed with `a password is required`.
- No `.env` contents, mail passwords, private keys, or tokens were printed or copied.
- The audit did not mutate application data, stop services, trigger bans, restore backups, send test mail, or change configuration.
- VM clocks use `Etc/UTC`. Consequently, the configured 02:00 backup runs at 02:00 UTC (09:00 in Vietnam), not 02:00 Asia/Ho_Chi_Minh.

## Compliance Matrix

### Module 1 — Architecture and Storage

| Rubric Requirement | Live System Verification Output | Command Used | Status |
| --- | --- | --- | --- |
| Supported server OS and meaningful hostname | VM1=`vm1`, VM2=`vm2`; both Ubuntu 22.04.5 LTS on VirtualBox | `hostnamectl`; `/etc/os-release` | PASS |
| Non-root administrative user | `opsadmin` is UID 1001 and belongs to `sudo` on both VMs | `id`; `groups` | PASS |
| Two-VM architecture | Distinct machines and Host-Only addresses: VM1 `.103`, VM2 `.104` | `hostnamectl`; `ip -br addr` | PASS |
| Host-Only connectivity VM1→VM2 | 2/2 ICMP replies, 0% packet loss, average 0.503 ms | VM1: `ping -c 2 192.168.56.104` | PASS |
| Host-Only connectivity VM2→VM1 | 2/2 ICMP replies, 0% packet loss, average 0.471 ms | VM2: `ping -c 2 192.168.56.103` | PASS |
| Dedicated 5 GB `/data` on VM1, persistent in fstab | `/dev/loop5`, 4.9 GiB ext4 at `/data`; fstab uses `/var/data_disk.img ... loop,defaults` | `df -h /data`; `findmnt /data`; `lsblk`; `grep /data /etc/fstab` | WARN — persistent 5 GiB loop filesystem, not a true partition/separate virtual disk |
| Dedicated 5 GB `/data` on VM2, persistent in fstab | `/dev/loop0`, 4.9 GiB ext4 at `/data`; same loop-image persistence pattern | Same storage commands on VM2 | WARN — persistent 5 GiB loop filesystem, not a true partition/separate virtual disk |
| VM2 backup directory ownership and permissions | `/data/backups/capstoneapp` is `opsadmin:opsadmin`, mode `0775`; backup files are mode `0640` | `ls -ld /data/backups/capstoneapp`; `find ... -printf` | PASS |
| Passwordless VM1→VM2 SSH | Batch-mode internal SSH returned `vm2` without prompting | VM1: `ssh -F /dev/null -o BatchMode=yes opsadmin@192.168.56.104 hostname` | PASS |

### Module 2 — Security and Auditing

| Rubric Requirement | Live System Verification Output | Command Used | Status |
| --- | --- | --- | --- |
| VM1 firewall enabled, default-deny, minimum ports | Privileged output: active; deny incoming/routed; allow outgoing; only 22, 80, and 443 allowed for IPv4/IPv6 | `sudo ufw status verbose` | PASS |
| VM2 firewall enabled, default-deny, minimum ports | Privileged output: active; deny incoming, allow outgoing; only SSH/rsync port 22 allowed for IPv4/IPv6 | `sudo ufw status verbose` | PASS |
| SSH root login disabled and key auth configured | Both configs show `PermitRootLogin no`, `PubkeyAuthentication yes`; key login worked | config grep plus live BatchMode SSH | PASS |
| Non-default SSH port or AllowUsers restriction | VM1 `AllowUsers vm1 opsadmin`; VM2 `AllowUsers opsadmin vm2`; SSH daemon listens on 22 internally | `grep` in `/etc/ssh/sshd_config*`; `ss -lntup` | PASS |
| Password-authentication trade-off documented | Both VMs show `PasswordAuthentication yes`; no final report exists to document the trade-off | config grep; workspace inventory | WARN |
| VM1 auditd watches `/etc/passwd` and `/etc/shadow` with readable trail | Active rules: passwd and shadow both watched with `-p wa` and distinct keys; `ausearch` was readable but returned no event | `sudo auditctl -l`; `sudo ausearch -f ...` | WARN — rule compliance confirmed; live matching event still unproven |
| VM2 audit baseline | 02:45 recheck: auditd active/enabled and tool installed; prior privileged output confirmed `-p wa` passwd/shadow rules; no matching event yet | `systemctl`; `command -v auditctl`; prior `sudo auditctl -l` | WARN — service/rules confirmed; live event still unproven |
| VM1 fail2ban protects SSH and can show/trigger a ban | One active `sshd` jail; 38 total failures and 1 historical ban | `sudo fail2ban-client status`; `status sshd` | PASS |
| VM2 fail2ban baseline | 02:45 recheck: fail2ban active/enabled with `[sshd] enabled = true`; prior privileged output confirmed one active jail using `/var/log/auth.log` | `systemctl`; config grep; prior `sudo fail2ban-client status sshd` | PASS — protection active; no ban history yet |
| All four environment files are strict and correctly owned | All mode `0600`: capstone=`svc-capstone`, info=`svc-info`, postgres=`svc-postgres`, `/etc/capstoneapp`=`root` | `stat -Lc '%n mode=%a owner=%U:%G' ...` | PASS |
| Lynis run and live hardening index | Live privileged result is `hardening_index=63`, matching the documented 61→63 remediation | `sudo grep '^hardening_index=' /var/log/lynis-report.dat` | PASS |
| At least three Lynis findings remediated | Remediation report lists banners, UMASK 027, and compiler restriction; live UMASK/compiler state and final index 63 corroborate it | remediation report; live filesystem and Lynis checks | PASS |
| Alert credentials protected | 02:45 live recheck: `/etc/msmtprc`=`0600 root:root`, user config=`0600 opsadmin:opsadmin`; system file is unreadable by `opsadmin` | `stat -Lc ...`; `[ -r /etc/msmtprc ]` | PASS — file-permission exposure fixed; credential rotation is not externally verifiable |

### Module 3 — Web Server, Application, Database, and TLS

| Rubric Requirement | Live System Verification Output | Command Used | Status |
| --- | --- | --- | --- |
| Nginx installed, active, enabled | `nginx` is active and enabled | `systemctl is-active/is-enabled nginx` | PASS |
| At least two distinct virtual hosts | Two enabled symlinks: `capstone.conf`, `sysinfo.conf` | `ls -la /etc/nginx/sites-enabled` | PASS |
| App vhost domains and upstream | `howname.viewdns.net app.lab.local` → `127.0.0.1:3000` | config grep | PASS |
| Status vhost domains and upstream | `status.lab.local sysinfo.local` → `127.0.0.1:4000` | config grep | PASS |
| Correct reverse-proxy headers | Both vhosts set Host, X-Real-IP, X-Forwarded-For, X-Forwarded-Proto | config grep | PASS |
| HTTP redirects to HTTPS | All four hostnames returned `HTTP/1.1 301` with matching HTTPS Location | `curl -I http://127.0.0.1 -H 'Host: ...'` | PASS |
| Both HTTPS virtual hosts respond | App domains returned 200 HTML; status domains returned 200 JSON | `curl -k -D - https://127.0.0.1 -H 'Host: ...'` | PASS |
| Self-signed TLS certificate validity | Self-issued CN `howname.viewdns.net`, valid 2026-08-21 through 2027-08-21 | `openssl x509 ... -subject -issuer -dates` | PASS |
| TLS SAN covers all active domains and loopback/internal IPs | 02:45 live certificate SAN: `howname.viewdns.net`, `status.lab.local`, `app.lab.local`, `sysinfo.local`, `127.0.0.1`, `192.168.56.103` | both requested `openssl x509` SAN commands | PASS |
| Port 443 allowed by firewall | VM1 UFW explicitly allows `443/tcp` for IPv4 and IPv6; Nginx listens and responds | `sudo ufw status verbose`; `ss`; `curl -k` | PASS |
| App/status listeners restricted to loopback | `127.0.0.1:3000` and `127.0.0.1:4000` only | `ss -lntup` | PASS |
| PostgreSQL restricted to loopback | `127.0.0.1:5432`; Compose publishes `127.0.0.1:${POSTGRES_PORT}:5432` | `ss -lntup`; readable Compose file | PASS |
| End-to-end app read path through Nginx and DB | `/api/health` returned `{"status":"ok","db":"connected"}`; `/api/notes` returned data, both HTTP 200 through HTTPS vhost | `curl -k https://127.0.0.1/api/{health,notes} -H 'Host: app.lab.local'` | PASS |
| App has a working write endpoint | Source defines parameterized `POST /api/notes`; no data-changing request was sent | source inspection | WARN — implementation present, live write not demonstrated |
| Least-privilege DB role | In `capstone_app`, `public.notes` is owned by `app_user`; the role has SELECT/INSERT plus DELETE, UPDATE, TRUNCATE, TRIGGER, and REFERENCES. It has no cluster-level administrative attributes | privileged `psql \\du`; `pg_tables`; `role_table_grants` | **FAIL — table ownership grants more capability than the current GET/POST app requires** |
| App systemd service policy and secret file | `capstone-app` active/enabled; `User=svc-capstone`, `EnvironmentFile`, `Restart=on-failure`, stdout/stderr journal | `systemctl show/cat capstone-app` | PASS |
| Kill app → automatic restart visible in journal | Policy is configured, but current `NRestarts=0`; no process was killed in read-only audit | `systemctl show ... NRestarts`; journal query | WARN — live demo required |
| Nginx configuration test | Privileged validation reports syntax OK and configuration test successful | `sudo nginx -t` | PASS |

### Module 4 — Backup and Disaster Recovery

| Rubric Requirement | Live System Verification Output | Command Used | Status |
| --- | --- | --- | --- |
| Backup dumps PostgreSQL and archives app content | `backup.sh` uses Docker `pg_dump`, compressed timestamped tar, and includes both app trees | script inspection; `tar -tzvf` | PASS |
| Retention policy exceeds/seven days | `RETENTION_DAYS=7`; `find ... -mtime +7 -exec rm` | script inspection | PASS |
| Rsync replication to VM2 | 02:00 run logged rsync success; latest file exists on both VMs | service status; backup inventory | PASS |
| Replicated backup integrity | VM1 and VM2 latest archive `backup_20260821_020016.tar.gz` share SHA-256 `f506805c...f86a5` | `sha256sum` on both VMs | PASS |
| Backup archive integrity and contents | `gzip -t` passed; prior latest archive contained 3,183-byte SQL plus both apps | `gzip -t`; `tar -tzvf` | PASS |
| Daily 02:00 systemd timer | Enabled/active; triggered at `2026-08-21 02:00:16 UTC`, result success/exit 0 | `systemctl status/show/list-timers` | PASS — note UTC timezone |
| Automated backup failure alert | Backup service has `OnFailure=capstone-backup-alert.service`; alert unit previously exited successfully | `systemctl show/cat`; unit result | PASS |
| Restore script restores DB/apps and restarts services | `restore.sh` validates archive, restores SQL via psql, restores both app trees, restarts services | script inspection; `bash -n`; `--help` | PASS — implementation evidence |
| Live restore recovers real data | Existing note suggests prior demo use, but no controlled destroy→restore→integrity test was observed | no destructive command run | **WARN — mandatory live-demo gate; rubric awards no Backup marks if restore fails** |
| Backup confidentiality | Archives are mode 0640 and include live `.env` files; archives are not encrypted | `tar -tzvf`; file-mode inventory | WARN — protect VM2 access and exclude/encrypt secrets where feasible |

### Module 5 — Automation and Script Toolkit

| Rubric Requirement | Live System Verification Output | Command Used | Status |
| --- | --- | --- | --- |
| Six required operational scripts | All present/executable/root-owned: menu, deploy, health-check, log-rotate, backup, restore | `ls -l /opt/scripts` | PASS |
| Shell syntax | `bash -n` returned 0 for all six scripts | `bash -n /opt/scripts/*.sh` individually | PASS |
| ShellCheck clean | ShellCheck produced no diagnostics; return code 0 | `shellcheck /opt/scripts/*.sh` | PASS |
| Strict mode and traps in every tool | All use `set -euo pipefail`; five use ERR/EXIT traps, but `menu.sh` traps only INT | source grep | WARN — does not fully meet “every script ERR/EXIT trap” |
| Help and argument handling | Five tools return help successfully; menu is interactive with no `--help` | `--help` runs; source inspection | WARN |
| Interactive menu and invalid input handling | Menu dispatches all five operations plus status and handles invalid choices | source inspection | PASS |
| Deploy safe test→reload→confirm→rollback | Syntax test, restart, HTTP confirmation, and rollback exist; it uses restart rather than config test→reload and does not test Nginx | source inspection | WARN — partial match to exact rubric flow |
| Health check covers CPU/RAM/disk/ports/services | All required categories and thresholds are implemented | source inspection | PASS |
| Health monitor every 10 minutes | Timer active/enabled; consecutive triggers show 10-minute cadence | `systemctl status/list-timers health-check.timer` | PASS |
| Simulated health failure fires alert | Alert path exists, timer run succeeds, but no controlled failure/mail delivery test was performed | script/unit inspection | WARN — live demo required |
| msmtp alerting configured | User and system configs select SMTP/TLS; backup alert unit has a successful execution | sanitized config inspection; `systemctl show` | PASS functionally, but security FAIL above |
| Log rotation compresses and retains N generations | Rotation/gzip/purge implemented; missing-log creation uses unsafe mode `0666` | source inspection | WARN — functional but permissions should be tightened |

### Report, Defense, Submission, and Bonus

| Rubric Requirement | Live System Verification Output | Command Used | Status |
| --- | --- | --- | --- |
| Final 6–12 page technical report with required sections/evidence | No project technical report PDF is present; only specifications and Lynis remediation notes exist | workspace file inventory | FAIL |
| README with architecture, VM layout, five-member allocation, reproduction | No `README.md` is present | workspace file inventory | FAIL |
| Connection diagram and five-member work allocation | Not found in workspace artifacts | document/file search | FAIL |
| Submission archive includes report, scripts, real configs, no secrets | No `capstone_<groupID>.tar.gz` or exported config bundle is present | workspace file inventory | FAIL |
| Known-good VM snapshot | Cannot be proven from guest/SSH state | not externally observable | WARN |
| Demo rehearsed in 12–15 minutes | No rehearsal log/video/timing evidence supplied | artifact review | WARN |
| Oral defense understanding across team | Cannot be established technically | requires live Q&A | WARN |
| TLS bonus reasoning in final report | TLS implementation and SAN are now technically compliant; reasoning exists in the specification, but no team final report artifact exists | document review; live certificate inspection | FAIL — add the reasoning to the team report |

## Priority Remediation Before Submission

1. Separate schema/table ownership from the runtime login role. Grant `app_user` only SELECT and INSERT on `public.notes` plus the minimum required sequence privilege; verify the application still starts, reads, and writes.
2. Rehearse and record a controlled write→backup→delete/corrupt→restore→integrity proof. This is the highest-risk grading gate.
3. Rehearse app kill/restart, an auditd write/attribute event, a simulated health failure with confirmed alert delivery, retention deletion of a safe dummy old backup, and broken-deploy rollback.
4. Add ERR/EXIT handling to `menu.sh`, make the deploy flow explicitly test/reload/confirm the relevant service configuration, and remove the `chmod 666` behavior from log rotation.
5. Decide whether loop-backed `/data` meets the lecturer's interpretation of “dedicated partition”; a separate virtual disk/partition is safer evidence.
6. Avoid putting live `.env` files into unencrypted replicated archives, or document and enforce a backup-encryption/access-control design.
7. Set `Asia/Ho_Chi_Minh` if “02:00 AM” means Vietnam local time, or clearly document that the current timer is 02:00 UTC.
8. Produce the final technical report, README, architecture diagram, team allocation, redacted configuration exports, and archive; scan the archive for secrets before submission.

## Remaining Live Evidence

All requested privileged read-only configuration checks are complete. Remaining validation requires controlled demonstrations: audit event generation, app restart, alert delivery, deploy rollback, retention deletion, and destructive restore/recovery.

The earlier `head` commands tested reads, while the installed audit rules use `-p wa`; therefore `<no matches>` was expected. A write/attribute event must be generated during the controlled live demo to prove the audit trail end to end.

Do not place real passwords, private keys, `.env` contents, SMTP credentials, or unredacted production payloads in screenshots, reports, or the submission archive.
