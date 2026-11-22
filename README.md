# CN_Project_Team-Axis — Section D

Computer Networks course project: a fully local, private network service platform —
DNS, an nginx reverse-proxy/load-balancer edge with TLS, and two backend servers,
across 4 machines.

| Read this | For |
|---|---|
| **[Study guide (cn-guide)](https://github.com/Jitmisra/cn-guide)** | how the whole system works, every result, troubleshooting playbook, viva Q&A, plus a guide per member |
| **[`PHASE2_REPORT.md`](./PHASE2_REPORT.md)** | Phase 2 final report: what changed, test results with timestamps, findings, learning per extension |
| [`ARCHITECTURE.md`](./ARCHITECTURE.md) | topology, IP table, request flow by protocol layer, Phase 2 design |
| [`EVIDENCE_INDEX.md`](./EVIDENCE_INDEX.md) | every evidence file, by task / extension |

## Team & roles

| Machine | Owner | Role | Folder |
|---|---|---|---|
| Mac 1 | Kartikey | Private DNS server (dnsmasq) + test client | [`mac1-kartikey-dns/`](./mac1-kartikey-dns) |
| Mac 2 | Agnik | nginx edge reverse proxy + load balancer + TLS termination | [`mac2-agnik-nginx-edge/`](./mac2-agnik-nginx-edge) |
| Mac 3 | Vishuti | Backend A (REST API, port 3001) | [`backend_a/`](./backend_a) |
| Mac 4 | Anwesha | Backend B (REST API, port 3002) + test client / evidence | [`backend_b/`](./backend_b) |

## Request flow
```
Client → DNS query (Mac 1) → HTTPS request (Mac 2 / nginx)
    → Backend A (Mac 3, port 3001)  or  Backend B (Mac 4, port 3002)
```

## How to run the backends

No external dependencies — both backends use Python's built-in `http.server` module.

**Backend A (Mac 3 — Vishuti, port 3001):**
```bash
python3 backend_a/backend_a.py
```

**Backend B (Mac 4 — Anwesha, port 3002):**
```bash
python3 backend_b/backend_b.py
```

**Quick test** (from any machine on the LAN):
```bash
# Direct test (replace IP with the backend's IP)
curl http://10.7.18.246:3001/api/status   # Backend A
curl http://10.7.5.197:3002/api/status    # Backend B

# Through the full stack (DNS + TLS + load balancer)
curl https://app.cnteam.test:8443/api/status
```

> If you get `OSError: Address already in use`, kill the old process first:
> `kill -9 $(lsof -t -i:3001)` or `kill -9 $(lsof -t -i:3002)`

## Status: Phase 1 and Phase 2 complete

**Phase 2 (22 Nov 2026):** all six extensions demonstrated with evidence:
- **A** backup DNS on Mac 4: primary stopped, still resolved. Contrast: DNS failure vs app failure (502).
- **B** TTL 30: the client kept the old answer ≈30 s, a flush made the change instant.
- **C** pf isolation: 3001 refused and 3002 timed out from a client, the edge kept access, rollback confirmed.
- **D** HA failover: Backend A down 46 s, **252/252 requests HTTP 200**, retries inside the same request.
- **E** DNS cutover to a standby edge on Mac 3: client flip in 27–30 s (= TTL), 0 failed requests.
- **F** layered diagnosis tools, plus a real silent DNS fault found and fixed.

Details and numbers: [`PHASE2_REPORT.md`](./PHASE2_REPORT.md).

### Phase 1 (October)
All 4 machines are built, live, and cross-verified end to end:
- DNS resolves `app.cnteam.test` → Mac 2 from multiple clients (no `.local`, uses `.test`).
- HTTPS works through nginx with a trusted cert, **no `-k` flag anywhere** in the final evidence.
- Load balancing confirmed: `X-Backend` alternates `A`/`B` across repeated requests.
- All 5 required Phase 1 failure demonstrations captured as evidence:
  1. Wrong DNS server on a client (Kartikey)
  2. DNS record pointing to the wrong IP (Kartikey)
  3. One backend stopped → clean failover, zero errors (Vishuti + Agnik)
  4. Both backends stopped → `502 Bad Gateway` (Vishuti + Anwesha + Agnik)
  5. Wrong destination port on a client (Anwesha)

Each folder above has its own `README.md`, `scripts/`, `docs/` (architecture section +
viva prep), and `evidence/` for that machine's role.

## Branches
Phase 1: `Agnik`, `Kartikey`, `Vishuti`, `anwesha`. Phase 2: `agnik-phase2`, `Kartikey`, `Vishuti`,
`anwesha-phase2`. All are merged into `main`.

> IPs change between sessions (campus DHCP). Before any demo, every member checks `ipconfig getifaddr en0`
> and the DNS records, nginx upstreams and pf allow-lists are re-rendered from each folder's `team.env`.

## Domain
`app.cnteam.test` / `api.cnteam.test`, resolved by the team's private DNS server.

## Security note
Private TLS keys are intentionally excluded from this repo (`.gitignore`) — only the
public `.crt` certificate is committed. If you need to re-run the edge locally, generate
your own key with `mac2-agnik-nginx-edge/scripts/e-make-cert.sh`.
