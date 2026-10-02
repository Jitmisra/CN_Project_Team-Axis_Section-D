# Mac 3 (Vishuti) — Backend Server A

Welcome to the Mac 3 (Backend A) node for the Computer Networks course project.

---

## 1. Quick Info & Shared IP Table Row

| Machine | Role | Private IPv4 | Subnet/Prefix | Gateway | Interface | MAC |
|---|---|---|---|---|---|---|
| **Mac 3** | **Backend A** | **10.7.18.246** | **255.255.224.0 (/19)** | **10.7.0.1** | **en0** | **10:9f:41:a9:20:0d** |

### What to Share with Teammates:
- **To Agnik (Mac 2 - Nginx Edge):**
  > "Vishuti's Mac 3 IP is `10.7.18.246` (port `3001`). Backend A is running and verified!"
- **To Kartikey (Mac 1 - DNS) & Anwesha (Mac 4):**
  > "Mac 3 IP: `10.7.18.246`, MAC: `10:9f:41:a9:20:0d`, Gateway: `10.7.0.1`."

---

## 2. Directory Structure

```
vishuti-mac3-backend/
├── backend_a.py            # Python 3 dependency-free HTTP server (port 3001)
├── team.env                # Central team IP and port configuration
├── scripts/
│   ├── capture-network.sh  # Task A network evidence generator
│   ├── a-ping.sh           # Ping test to gateway, Mac 1, Mac 2, Mac 4
│   ├── start-backend.sh    # Start Backend A in background
│   ├── stop-backend.sh     # Stop Backend A cleanly
│   ├── restart-backend.sh  # Restart Backend A
│   ├── status.sh           # Check PID, port 3001 listener, and logs
│   ├── verify-local.sh     # Curl tests for endpoints and headers
│   ├── firewall-enable.sh  # Phase 2: Enable PF service isolation (port 3001)
│   ├── firewall-disable.sh # Phase 2: Revert and disable PF firewall
│   ├── firewall-status.sh  # Phase 2: Inspect active PF rules
│   └── troubleshoot.sh     # Phase 2: Full layer-by-layer diagnostic script
├── config/
│   ├── pf_rules_isolation.conf # Generated PF rules (permits Mac 2 only)
│   └── pf_rules_template.conf  # Template for PF rules
├── evidence/               # Automated test outputs and captured proofs
│   ├── task-a-network.txt  # Ifconfig, gateway, and IP details
│   ├── task-a-ping.txt     # Ping outputs to gateway and peers
│   └── task-c-local-verify.txt # Curl output with X-Backend & Cache-Control
├── docs/
│   ├── ARCHITECTURE_BACKEND_A.md # Topology, socket binding, failure matrix
│   └── VIVA_PREP.md        # Comprehensive viva prep for all 4 individual Qs
└── logs/
    └── backend_a.log       # Live request logs showing client/proxy IP
```

---

## 3. Step-by-Step Run Order

### Phase 1 Execution

#### Step 1: Capture Network & Ping Teammates
```bash
./scripts/capture-network.sh
./scripts/a-ping.sh
```
*Confirms Wi-Fi link, gateway reachability, and ping to Mac 1 (`10.7.8.82`) and Mac 2 (`10.7.14.242`). Output saved to `evidence/`.*

#### Step 2: Start Backend A
```bash
./scripts/start-backend.sh
```
*Starts `backend_a.py` on `0.0.0.0:3001` in background.*

#### Step 3: Verify Status & Endpoints
```bash
./scripts/status.sh
./scripts/verify-local.sh
```
*Verifies `GET /`, `GET /api/status`, `X-Backend: A`, and `Cache-Control: max-age=60`.*

#### Step 4: Monitor Proxied Traffic from Agnik (Mac 2)
```bash
tail -f logs/backend_a.log
```
*Watch incoming requests arriving from Agnik's Nginx proxy (`10.7.14.242`).*

#### Step 5: Phase 1 Failure Demos
1. **One Backend Stopped Demo:**
   - On Agnik's cue: `./scripts/stop-backend.sh`
   - Agnik proves requests still succeed via Backend B (Mac 4).
   - On cue: `./scripts/start-backend.sh`
2. **Both Backends Stopped Demo:**
   - Coordinate with Anwesha to stop both backends: `./scripts/stop-backend.sh`
   - Agnik shows client receives `HTTP 502 Bad Gateway`.
   - Restart: `./scripts/start-backend.sh`

---

### Phase 2 Execution

#### Extension C: Service Isolation (Firewall)
Restrict direct client access to port 3001 so **only Mac 2** (`10.7.14.242`) can reach it:
1. Enable isolation:
   ```bash
   ./scripts/firewall-enable.sh
   ```
2. Verify active rules:
   ```bash
   ./scripts/firewall-status.sh
   ```
3. Demo:
   - Agnik's curl via Nginx still works.
   - Another teammate trying `curl http://10.7.18.246:3001` gets blocked.
4. Disable isolation after demo:
   ```bash
   ./scripts/firewall-disable.sh
   ```

#### Extension F: Faculty Troubleshooting Challenge
If faculty injects a fault or asks for live debugging:
```bash
./scripts/troubleshoot.sh
```
*Follow the diagnostic narration order in `docs/VIVA_PREP.md`.*
