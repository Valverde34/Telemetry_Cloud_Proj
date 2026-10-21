# Our own broker image: the config, ACL and start script are baked in, so the
# same image runs locally (Docker Compose) and in Azure Container Apps.
FROM eclipse-mosquitto:2

COPY mosquitto.conf /mosquitto/config/mosquitto.conf
COPY acl /mosquitto/config/acl
COPY start.sh /mosquitto/start.sh
RUN chmod 0644 /mosquitto/config/mosquitto.conf /mosquitto/config/acl /mosquitto/start.sh

EXPOSE 8883
# The image's entrypoint runs first; start.sh then prepares secrets and
# starts mosquitto, which drops root privileges to the "mosquitto" user.
CMD ["sh", "/mosquitto/start.sh"]
