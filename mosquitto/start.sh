#!/bin/sh
# Builds the broker's password file from environment variables at startup,
# so no passwords (or password hashes) are ever stored in git.
set -eu

DATA=/mosquitto/data
umask 077   # files created below are readable by their owner only

# Write "user:password" lines, then let mosquitto_passwd hash them in place.
printf 'simulator:%s\napi:%s\n' \
  "$MQTT_SIMULATOR_PASSWORD" "$MQTT_API_PASSWORD" > "$DATA/passwd"
mosquitto_passwd -U "$DATA/passwd"

cp /mosquitto/config/acl "$DATA/acl"

# The broker drops to the "mosquitto" user, so it must own these files.
chown mosquitto:mosquitto "$DATA/passwd" "$DATA/acl"

exec mosquitto -c /mosquitto/config/mosquitto.conf
