#!/bin/sh
# Generates a private CA and a TLS certificate for the MQTT broker, for local
# development and CI. In Azure, Terraform generates its own (see infra/tls.tf).
#
# Usage: sh scripts/gen-certs.sh        (writes ./certs, ignored by git)
set -eu

DIR="$(cd "$(dirname "$0")/.." && pwd)/certs"
mkdir -p "$DIR"
cd "$DIR"

if [ -f ca.crt ] && [ -f server.crt ] && [ -f server.key ]; then
  echo "certs already exist in $DIR (delete the folder to regenerate)"
  exit 0
fi

# 1. Certificate authority (CA): the clients trust this, and only this.
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes \
  -keyout ca.key -out ca.crt -days 3650 -subj "/CN=telemetry-dev-ca" 2>/dev/null

# 2. Broker key + certificate signed by the CA. The names in subjectAltName
#    must match the hostname the clients connect to.
openssl req -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes \
  -keyout server.key -out server.csr -subj "/CN=mosquitto" 2>/dev/null
printf 'subjectAltName=DNS:mosquitto,DNS:localhost\nextendedKeyUsage=serverAuth\n' > server.ext
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -days 825 -extfile server.ext 2>/dev/null
rm -f server.csr server.ext ca.srl

chmod 600 ca.key server.key   # private keys: owner only
chmod 644 ca.crt server.crt   # certificates are public

echo "certs written to $DIR"
