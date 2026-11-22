# Standby edge for Ext E: runs on Mac 3 (Vishuti)

A second nginx edge, rendered from the **same template** as Mac 2's primary
(`../config/edge.conf.tmpl`), so "same configuration" is literally true. Only three things differ:

| | Primary (Mac 2) | Standby (Mac 3) |
|---|---|---|
| `X-Edge` header | `mac2-primary` | `mac3-standby` |
| Backend A upstream | `<MAC3_IP>:3001` | `127.0.0.1:3001` (A is local) |
| Rendered by | `scripts/d-install-nginx.sh` | `install-standby.sh` |

Same cert, same key, same ports (8080 → 8443), same failover directives, same HTTP/2.

## Before the joint session (Vishuti)
1. `git pull`, then use the whole `mac2-agnik-nginx-edge/` folder (the script needs `../config/` and `../certs/`).
2. Get **`cnteam.test.key` from Agnik by AirDrop** and put it in `standby-edge/certs/`.
   Never commit it (`*.key` is gitignored), never post it in chat.
   Why the key is needed: clients already trust *this* cert, and only the matching private key can complete the TLS handshake.
   Every real edge node of a service holds that service's cert and key.
3. Edit `standby.env`: set `MAC4_BACKEND_B_IP` to Anwesha's **current** IP.
4. Make sure `backend_a.py` is running on `:3001`.
5. `./install-standby.sh`. It checks the cert/key pair, installs nginx if needed, renders the config, reloads, and
   self-tests through `127.0.0.1` with `--cacert` (cert verification, **not** `-k`). The output is saved to
   `backend_a/evidence/phase2/E-standby-selftest-*.txt`.
   - If macOS asks "Allow nginx to accept incoming connections?", click **Allow**.
   - "Backend B never answered" means a wrong `MAC4_BACKEND_B_IP`, or Anwesha's pf `<edges>` table doesn't include
     Mac 3's IP yet.
6. Tell the team your IP. Someone on another Mac runs:
   `curl --resolve app.cnteam.test:8443:<MAC3_IP> https://app.cnteam.test:8443/api/status -D - -o /dev/null`
   and expects `x-edge: mac3-standby` and A/B alternating.

## During the cutover
Keep the standby's log visible: `tail -f $(brew --prefix)/var/log/nginx/edge-access.log`. Requests start arriving
as client DNS caches expire (≤ TTL 30 s after Kartikey's `cutover.sh`). Screenshot it.

## After the demo
`./uninstall-standby.sh` stops nginx, removes the config and **deletes the key copy**. Tell Agnik it's done.
