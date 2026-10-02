# CN_Project_Team-Axis — Section D

Computer Networks course project: a fully local, private network service platform —
DNS, an nginx reverse-proxy/load-balancer edge with TLS, and two backend servers,
across 4 machines.

## Team & roles

| Machine | Owner | Role |
|---|---|---|
| Mac 1 | Kartikey | Private DNS server (dnsmasq) + test client |
| Mac 2 | Agnik | nginx edge reverse proxy + load balancer + TLS termination |
| Mac 3 | Vishuti | Backend A (REST API, port 3001) |
| Mac 4 | Anwesha | Backend B (REST API, port 3002) + test client / evidence |

## Request flow
```
Client → DNS query (Mac 1) → HTTPS request (Mac 2 / nginx)
    → Backend A (Mac 3, port 3001)  or  Backend B (Mac 4, port 3002)
```

## Branches
Each member works on their own branch (`Agnik`, `Kartikey`, `Vishuti`, `Anwesha`)
for their machine's config, source code, and evidence, merged into `main` once
Phase 1 is approved.

## Domain
`app.cnteam.test` / `api.cnteam.test`, resolved by the team's private DNS server.
