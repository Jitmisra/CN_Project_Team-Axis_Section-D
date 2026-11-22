# Phase 2 edge pre-test (localhost, 2026-11-22)

Before the joint session I tested `config/edge.conf.tmpl` on a separate nginx instance on Mac 2 (ports 18080/18443),
with two stand-in backends on `127.0.0.1:13001` (A) and `:13002` (B). The stand-ins run exactly the shared
`/api/info` + ETag code from the Phase 2 prompts. The live edge wasn't touched during the test.
**This is a config pre-test, not demo evidence.** The real evidence comes from the joint session with the real backends.

| # | Test | Result |
|---|---|---|
| T1 | TLS + HTTP/2 + `X-Edge` + round-robin | `SSL certificate verify ok` (no `-k`), `ALPN: server accepted h2`, `HTTP/2 200`, `x-edge` present, A/B alternating |
| T2 | 8080 → 301 | `Location: https://app.cnteam.test:<https port>/…`, `X-Edge` present |
| T3 | ETag + `If-None-Match` on `/api/info` | **304 from both A and B** (same body → same ETag `"39464b4ed106dad1"` across the pool) |
| T4 | `HEAD /` | 200 from both backends (Backend B currently returns 501 until `do_HEAD` is added) |
| T5 | Backend A **stopped** (connection refused) | 8/8 requests `200` from B, ~5 ms each. Access log: `upstream=127.0.0.1:13001, 127.0.0.1:13002` (retry inside one request). Error log: `connect() failed (61: Connection refused)` then `upstream server temporarily disabled` |
| T6 | Backend A restarted | rejoined after **12.7 s** (`fail_timeout` 10 s + its next round-robin turn) |
| T7 | Both backends stopped | `502`, `x-edge` still present (the edge is up, the app tier is down) |
| T8 | Backend A **hung** (accepts, never replies) | first request **5.0 s** (`proxy_read_timeout`) then `200` from B; next requests ~5 ms (A disabled). Error log: `upstream timed out … while reading response header` |
| live | Stale/unreachable backend IPs (teammates offline) | each attempt waits **2.0 s** (`proxy_connect_timeout`), `504`, then `no live upstreams` → instant `502` |

**Viva takeaway:** the failure *type* sets the latency cost of failover. A refused connection costs nothing.
A silent host costs 2 s (connect timeout) for the first request. A hung backend costs 5 s (read timeout).
After that first failure, passive health checking takes the backend out for 10 s, so later requests pay nothing.
