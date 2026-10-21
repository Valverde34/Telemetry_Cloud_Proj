import json
import os
import time
from contextlib import asynccontextmanager

import paho.mqtt.client as mqtt
import psycopg
from fastapi import FastAPI, Response

DB_URL = os.environ["DATABASE_URL"]
MQTT_HOST = os.getenv("MQTT_HOST", "mosquitto")
MQTT_USERNAME = os.environ["MQTT_USERNAME"]
MQTT_PASSWORD = os.environ["MQTT_PASSWORD"]
# CA certificate used to verify the broker; when set, the connection uses TLS.
MQTT_CA_FILE = os.getenv("MQTT_CA_FILE")
MQTT_PORT = int(os.getenv("MQTT_PORT", "8883" if MQTT_CA_FILE else "1883"))
TOPIC = "sensors/#"


def init_db() -> None:
    for _ in range(30):
        try:
            with psycopg.connect(DB_URL) as conn:
                conn.execute(
                    """CREATE TABLE IF NOT EXISTS readings (
                        id SERIAL PRIMARY KEY,
                        topic TEXT NOT NULL,
                        value DOUBLE PRECISION NOT NULL,
                        ts TIMESTAMPTZ NOT NULL DEFAULT now()
                    )"""
                )
            return
        except psycopg.OperationalError:
            time.sleep(1)
    raise RuntimeError("database not reachable")


def on_connect(client, userdata, flags, reason_code, properties):
    if reason_code.is_failure:
        print(f"MQTT connection refused: {reason_code}", flush=True)
        return
    client.subscribe(TOPIC)


def on_message(client, userdata, msg):
    try:
        value = float(json.loads(msg.payload)["value"])
    except (ValueError, KeyError, TypeError):
        return  # ignore malformed payloads
    with psycopg.connect(DB_URL) as conn:
        conn.execute(
            "INSERT INTO readings (topic, value) VALUES (%s, %s)", (msg.topic, value)
        )


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)
    if MQTT_CA_FILE:
        client.tls_set(ca_certs=MQTT_CA_FILE)  # also verifies the broker's hostname
    client.on_connect = on_connect
    client.on_message = on_message
    client.connect_async(MQTT_HOST, MQTT_PORT)
    client.loop_start()
    yield
    client.loop_stop()


app = FastAPI(title="Telemetry API", lifespan=lifespan)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/health/data")
def health_data(response: Response):
    """End-to-end check: are readings still arriving? 503 if the newest one is
    older than 2 minutes, i.e. something in simulator -> broker -> API -> DB broke.
    Used by the Azure availability test, not by the liveness probe."""
    with psycopg.connect(DB_URL) as conn:
        (age,) = conn.execute(
            "SELECT EXTRACT(EPOCH FROM now() - max(ts)) FROM readings"
        ).fetchone()
    fresh = age is not None and age < 120
    if not fresh:
        response.status_code = 503
    return {
        "status": "ok" if fresh else "stale",
        "last_reading_age_seconds": None if age is None else round(float(age), 1),
    }


@app.get("/readings")
def readings(limit: int = 20):
    limit = max(1, min(limit, 200))
    with psycopg.connect(DB_URL) as conn:
        rows = conn.execute(
            "SELECT topic, value, ts FROM readings ORDER BY id DESC LIMIT %s", (limit,)
        ).fetchall()
    return [{"topic": t, "value": v, "ts": ts.isoformat()} for t, v, ts in rows]
