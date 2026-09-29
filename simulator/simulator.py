import json
import os
import random
import time

import paho.mqtt.client as mqtt

HOST = os.getenv("MQTT_HOST", "mosquitto")

client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
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
