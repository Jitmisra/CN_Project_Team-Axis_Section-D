# Mac 3 (Vishuti) — Backend Server A & Standby Edge (Phase 2)

Welcome to the Mac 3 (Backend A) node for the Computer Networks course project.

---

## 1. Quick Info & Shared IP Table Row (Phase 2 - 2026-11-22)

| Machine | Role | Private IPv4 | Subnet/Prefix | Gateway | Interface | MAC |
|---|---|---|---|---|---|---|
| **Mac 3** | **Backend A & Standby Edge** | **10.7.15.127** | **255.255.224.0 (/19)** | **10.7.0.1** | **en0** | **10:9f:41:a9:20:0d** |

### What to Share with Teammates:
- **To Agnik (Mac 2 - Nginx Edge: 10.7.3.251):**
  > "Vishuti's Mac 3 IP is `10.7.15.127` (port `3001`). Backend A is up and running with `/api/info` ETag/304 caching enabled! Update your upstream pool to `10.7.15.127:3001`."
- **To Anwesha (Mac 4 - Backend B: 10.7.5.197):**
  > "Mac 3 IP: `10.7.15.127`. Backend A has byte-identical `/api/info` with SHA256 ETag `39464b4ed106dad1`."
- **To Kartikey (Mac 1 - DNS: 10.7.8.82):**
  > "Mac 3 IP is `10.7.15.127` for the Extension E DNS cutover demo."

---

## 2. Directory Structure

```
backend_a/
├── backend_a.py            # Python 3 server on port 3001 (/api/status, /api/info, ETag/304)
├── team.env                # Central team IP and port configuration (updated for Phase 2)
├── scripts/
│   ├── capture-network.sh  # Task A network evidence generator
│   ├── a-ping.sh           # Ping test to gateway, Mac 1, Mac 2, Mac 4
│   ├── start-backend.sh    # Start Backend A in background
│   ├── stop-backend.sh     # Stop Backend A cleanly
│   ├── restart-backend.sh  # Restart Backend A
│   ├── status.sh           # Check PID, port 3001 listener, and logs
│   ├── verify-local.sh     # Curl tests for endpoints, ETag, and 304 Not Modified
│   ├── firewall-enable.sh  # Phase 2 Ext C: Enable PF cnteam anchor isolation
│   ├── firewall-disable.sh # Phase 2 Ext C: Revert and release PF token
│   ├── firewall-status.sh  # Phase 2 Ext C: Inspect active anchor rules & hit counters
│   ├── demo-isolation.sh   # Phase 2 Ext C: End-to-end isolation demo & logging
│   └── troubleshoot.sh     # Phase 2 Ext F: Full layer-by-layer diagnostic script
├── standby-edge/           # Phase 2 Ext E: Standby Nginx Edge on Mac 3
│   ├── nginx-standby.conf.tmpl # Standby edge server block with X-Edge: mac3-standby
│   ├── install-standby.sh  # Renders conf and restarts Homebrew nginx
│   ├── selftest-standby.sh # Verifies standby edge via HTTPS
│   └── uninstall-standby.sh# Restores clean state after demo
├── config/
│   ├── app.cnteam.test.crt     # Trusted public certificate
│   ├── pf.cnteam.anchor.tmpl   # Anchor template with <edges> table
│   └── pf.root.conf.tmpl       # Root PF conf template preserving Apple anchors
├── evidence/
│   └── phase2/                 # Phase 2 test records (C-isolation, F-caching, etc.)
└── docs/
    ├── ARCHITECTURE_BACKEND_A.md
    └── VIVA_PREP.md            # Comprehensive viva preparation (all Phase 2 questions)
```

---

## 3. Phase 2 Demonstration Run Order

### Step 1: ETag & Caching Demo (Step 7 of Final Sequence — Driven by Vishuti)
1. Request resource:
   ```bash
   curl -sI https://app.cnteam.test:8443/api/info
   ```
   *Shows `Cache-Control: max-age=60`, `ETag: "39464b4ed106dad1"`, and `X-Backend: A` or `B`.*
2. Send conditional request with cached ETag:
   ```bash
   curl -sI -H 'If-None-Match: "39464b4ed106dad1"' https://app.cnteam.test:8443/api/info
   ```
   *Returns `HTTP/1.1 304 Not Modified` with zero body bytes from either backend!*

---

### Step 2: Service Isolation Demo (Extension C — Lead: Vishuti)
1. **Before:** Show direct access works from client:
   ```bash
   curl http://10.7.15.127:3001/api/status
   ```
2. **Enable Anchor Isolation:**
   ```bash
   sudo ./scripts/firewall-enable.sh return
   ```
   *Loads `cnteam` anchor into Darwin PF without destroying system anchors.*
3. **Verify:**
   - Kartikey (Mac 1) direct curl fails: `Connection refused` (instant RST).
   - Agnik (Mac 2: `10.7.3.251`) direct connect succeeds: `nc -vz 10.7.15.127 3001`.
   - Client HTTPS request `https://app.cnteam.test:8443` still alternates A/B!
4. **Inspect Hit Counters:**
   ```bash
   sudo ./scripts/firewall-status.sh
   ```
5. **Rollback:**
   ```bash
   sudo ./scripts/firewall-disable.sh
   ```

---

### Step 3: Standby Edge Host (Extension E)
1. Place `cnteam.test.key` (from Agnik via AirDrop) into `standby-edge/certs/cnteam.test.key`.
2. Start standby edge:
   ```bash
   cd standby-edge && ./install-standby.sh
   ./selftest-standby.sh
   ```
3. After DNS cutover to `10.7.15.127`, monitor incoming requests:
   ```bash
   tail -f $(brew --prefix)/var/log/nginx/access.log
   ```
   *Requests arrive displaying `X-Edge: mac3-standby`.*
4. Uninstall after demo:
   ```bash
   ./uninstall-standby.sh
   ```

---

### Step 4: Faculty-Injected Fault Diagnosis (Extension F)
Run the automated diagnostic:
```bash
./scripts/troubleshoot.sh
```
Narrate out loud:
1. Physical / Network Link (`en0` IP, gateway ping, edge ping)
2. Transport Layer (`lsof -nP -iTCP:3001 -sTCP:LISTEN`, 0.0.0.0 binding)
3. Firewall Layer (PF status, `cnteam` anchor, `<edges>` table)
4. Application Layer (`/api/status`, `/api/info`, ETag/304)
