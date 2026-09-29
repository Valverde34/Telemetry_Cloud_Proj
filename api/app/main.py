import json
import os
import time
from contextlib import asynccontextmanager

import paho.mqtt.client as mqtt
import psycopg
from fastapi import FastAPI

DB_URL = os.environ["DATABASE_URL"]
MQTT_HOST = os.getenv("MQTT_HOST", "mosquitto")
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
    client.on_connect = on_connect
    client.on_message = on_message
    client.connect_async(MQTT_HOST, 1883)
    client.loop_start()
    yield
    client.loop_stop()


app = FastAPI(title="Telemetry API", lifespan=lifespan)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/readings")
def readings(limit: int = 20):
    limit = max(1, min(limit, 200))
    with psycopg.connect(DB_URL) as conn:
        rows = conn.execute(
            "SELECT topic, value, ts FROM readings ORDER BY id DESC LIMIT %s", (limit,)
        ).fetchall()
    return [{"topic": t, "value": v, "ts": ts.isoformat()} for t, v, ts in rows]
