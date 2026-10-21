import json
import os
import random
import time

import paho.mqtt.client as mqtt

HOST = os.getenv("MQTT_HOST", "mosquitto")
USERNAME = os.environ["MQTT_USERNAME"]
PASSWORD = os.environ["MQTT_PASSWORD"]
# CA certificate used to verify the broker; when set, the connection uses TLS.
CA_FILE = os.getenv("MQTT_CA_FILE")
PORT = int(os.getenv("MQTT_PORT", "8883" if CA_FILE else "1883"))


def on_connect(client, userdata, flags, reason_code, properties):
    if reason_code.is_failure:
        print(f"MQTT connection refused: {reason_code}", flush=True)
    else:
        print("Connected to MQTT broker", flush=True)


client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
client.username_pw_set(USERNAME, PASSWORD)
if CA_FILE:
    client.tls_set(ca_certs=CA_FILE)  # also verifies the broker's hostname
client.on_connect = on_connect
while True:
    try:
        client.connect(HOST, PORT)
        break
    except OSError as exc:  # broker not up yet (or TLS handshake failed)
        print(f"MQTT connect failed: {exc}", flush=True)
        time.sleep(2)
client.loop_start()

while True:
    client.publish("sensors/weather/temperature",
                   json.dumps({"value": round(random.uniform(10, 30), 1)}))
    client.publish("sensors/radar/speed",
                   json.dumps({"value": round(random.uniform(20, 120), 1)}))
    time.sleep(1)
