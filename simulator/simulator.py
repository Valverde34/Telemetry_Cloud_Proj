import json
import os
import random
import time

import paho.mqtt.client as mqtt

HOST = os.getenv("MQTT_HOST", "mosquitto")
USERNAME = os.environ["MQTT_USERNAME"]
PASSWORD = os.environ["MQTT_PASSWORD"]


def on_connect(client, userdata, flags, reason_code, properties):
    if reason_code.is_failure:
        print(f"MQTT connection refused: {reason_code}", flush=True)
    else:
        print("Connected to MQTT broker", flush=True)


client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
client.username_pw_set(USERNAME, PASSWORD)
client.on_connect = on_connect
while True:
    try:
        client.connect(HOST, 1883)
        break
    except OSError:
        time.sleep(1)
client.loop_start()

while True:
    client.publish("sensors/weather/temperature",
                   json.dumps({"value": round(random.uniform(10, 30), 1)}))
    client.publish("sensors/radar/speed",
                   json.dumps({"value": round(random.uniform(20, 120), 1)}))
    time.sleep(1)
