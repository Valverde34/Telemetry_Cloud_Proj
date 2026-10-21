#!/bin/sh
# Prepares the broker's secrets at startup, then starts mosquitto.
# Nothing secret (passwords, hashes, private keys) is stored in git or in the image.
set -eu

DATA=/mosquitto/data
# Where the TLS certificate and key are mounted (overridable, e.g. in Azure).
TLS_CERT_FILE="${TLS_CERT_FILE:-/mosquitto/certs/server.crt}"
TLS_KEY_FILE="${TLS_KEY_FILE:-/mosquitto/certs/server.key}"

umask 077   # files created below are readable by their owner only

# Write "user:password" lines, then let mosquitto_passwd hash them in place.
printf 'simulator:%s\napi:%s\n' \
  "$MQTT_SIMULATOR_PASSWORD" "$MQTT_API_PASSWORD" > "$DATA/passwd"
mosquitto_passwd -U "$DATA/passwd"

cp /mosquitto/config/acl "$DATA/acl"
cp "$TLS_CERT_FILE" "$DATA/server.crt"
cp "$TLS_KEY_FILE" "$DATA/server.key"

# The broker drops to the "mosquitto" user, so it must own these files.
chown mosquitto:mosquitto "$DATA/passwd" "$DATA/acl" "$DATA/server.crt" "$DATA/server.key"

exec mosquitto -c /mosquitto/config/mosquitto.conf
