# Backend B (Mac 4 — Anwesha)

Python HTTP backend server on port 3002, plus backup DNS and test client.

## Quick Start

```bash
source team.env
./scripts/start-backend.sh     # start backend on :3002
./scripts/status.sh            # check if running
./scripts/stop-backend.sh      # stop it
```

## Endpoints

| Path | Response |
|------|----------|
| `/` | `Backend B is running` (text/plain) |
| `/api/status` | `{"backend":"B","status":"ok"}` (JSON) |
| `/api/info` | Shared info blob (identical on A and B, supports ETag/304) |

All responses include `X-Backend: B`, `Cache-Control: max-age=60`, and `ETag`.
HEAD requests are supported on all endpoints.

## Phase 2 Scripts

| Script | Purpose |
|--------|---------|
| `scripts/dns-backup.sh` | Manage backup DNS (Ext A): install, status, set-record, sync-check |
| `scripts/firewall-enable.sh` | Enable pf isolation on :3002 (Ext C) |
| `scripts/firewall-disable.sh` | Remove pf isolation |
| `scripts/firewall-status.sh` | Show current pf state |
| `scripts/a-ping.sh` | Ping all team machines |

## Team Tools (in `tools/`)

| Script | Purpose |
|--------|---------|
| `tools/diagnose.sh` | Layer-by-layer fault diagnosis (Ext F) |
| `tools/watch.sh` | Client-side watcher for failover/cutover demos |
| `tools/check-evidence.sh` | Verify EVIDENCE_INDEX.md paths exist |

## Evidence

- `evidence/phase1/` — Phase 1 failure demo #5
- `evidence/phase2/` — All Phase 2 extension evidence (A through F)
