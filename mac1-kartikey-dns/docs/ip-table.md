# Shared IP table (filled 2026-10-02, campus Wi-Fi "Rishihood_Learner", 10.7.0.0/19)

| Machine | Owner | Role | Private IPv4 | Subnet/Prefix | Gateway | Interface | MAC | Service port |
|---|---|---|---|---|---|---|---|---|
| Mac 1 | Kartikey | DNS (dnsmasq) | 10.7.8.82 | 255.255.224.0 (/19) | 10.7.0.1 | en0 | ee:03:6e:af:2b:e7 | UDP/TCP 53 |
| Mac 2 | Agnik | Edge / LB / TLS (nginx) | 10.7.14.242 | 255.255.224.0 (/19) | 10.7.0.1 | en0 | fa:4e:b4:04:d0:00 | 8443 (HTTPS), 8080 |
| Mac 3 | Vishuti | Backend A | 10.7.18.246 | 255.255.224.0 (/19) | 10.7.0.1 | en0 | 10:9f:41:a9:20:0d | 3001 |
| Mac 4 | Anwesha | Backend B + backup DNS | 10.7.5.197 | 255.255.224.0 (/19) | 10.7.0.1 | en0 | 0a:8f:b2:2d:a4:fb | 3002 (+53 in Phase 2) |

Ports: the edge uses 8443/8080 instead of 443/80 (Homebrew nginx runs unprivileged), which the project allows.
All pairs on one subnet, so traffic is switched directly with no routing through 10.7.0.1. Connectivity verified from Mac 1 (evidence/phase1/A-ping.txt).
