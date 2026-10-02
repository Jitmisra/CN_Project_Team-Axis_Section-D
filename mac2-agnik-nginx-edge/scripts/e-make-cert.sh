#!/usr/bin/env bash
# Task E - generate a self-signed TLS cert for the team domain.
set -euo pipefail
cd "$(dirname "$0")/.."
source team.env
mkdir -p certs evidence

CRT="certs/${TEAM_DOMAIN}.crt"
KEY="certs/${TEAM_DOMAIN}.key"

if [ -f "$CRT" ] && [ -f "$KEY" ]; then
  echo "Cert already exists at $CRT - delete it first if you want to regenerate."
else
  openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$KEY" -out "$CRT" \
    -days 365 -subj "/CN=app.${TEAM_DOMAIN}" \
    -addext "subjectAltName=DNS:app.${TEAM_DOMAIN},DNS:api.${TEAM_DOMAIN}"
  chmod 600 "$KEY"
  echo "Generated $CRT and $KEY"
fi

openssl x509 -in "$CRT" -noout -text > evidence/cert-details.txt
echo "Cert details saved to evidence/cert-details.txt"
echo
echo "Give teammates the .crt file ONLY (never the .key) so they can trust it:"
echo "  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain $CRT"
