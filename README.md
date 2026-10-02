# CN_Project_Team-Axis — Section D

Computer Networks course project: a fully local, private network service platform —
DNS, an nginx reverse-proxy/load-balancer edge with TLS, and two backend servers,
across 4 machines.

**See [`ARCHITECTURE.md`](./ARCHITECTURE.md)** for the full system design (topology
diagram, IP table, request-flow by protocol layer) and
**[`EVIDENCE_INDEX.md`](./EVIDENCE_INDEX.md)** for a task-by-task map of every piece
of evidence in this repo.

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

## Status: Phase 1 complete (build + verify + all 5 failure demos)
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
Each member worked on their own branch (`Agnik`, `Kartikey`, `Vishuti`, `anwesha`) for
their machine's config, source code, and evidence; all four are merged into `main` here.
Phase 2 (backup DNS, TTL, service isolation, HA failover, DNS cutover) will land in new
commits on `main` once Phase 1 is formally approved.

## Domain
`app.cnteam.test` / `api.cnteam.test`, resolved by the team's private DNS server.

## Security note
Private TLS keys are intentionally excluded from this repo (`.gitignore`) — only the
public `.crt` certificate is committed. If you need to re-run the edge locally, generate
your own key with `mac2-agnik-nginx-edge/scripts/e-make-cert.sh`.
