import json
import os
import boto3
from confluent_kafka import Consumer
from shared.schemas.feedback_event import FeedbackEvent

TOPIC = os.getenv("KAFKA_TOPIC", "feedback.raw.events")
BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
RAW_BUCKET = os.getenv("RAW_BUCKET", "fip-local-raw")
AWS_ENDPOINT_URL = os.getenv("AWS_ENDPOINT_URL", "http://localhost:4566")
MAX_MESSAGES = int(os.getenv("MAX_MESSAGES", "10"))

def s3_client():
    return boto3.client("s3", endpoint_url=AWS_ENDPOINT_URL, aws_access_key_id="test", aws_secret_access_key="test", region_name="us-west-2")

def main() -> None:
    print(f"consumer_bootstrap={BOOTSTRAP}")
    consumer = Consumer({"bootstrap.servers": BOOTSTRAP, "group.id": "fip-ingestion-worker", "auto.offset.reset": "earliest", "enable.auto.commit": False})
    consumer.subscribe([TOPIC])
    consumed = 0
    try:
        while consumed < MAX_MESSAGES:
            msg = consumer.poll(10.0)
            if msg is None:
                break
            if msg.error():
                print(msg.error())
                continue
            event = FeedbackEvent(**json.loads(msg.value()))
            key = f"tenant={event.tenant_id}/source={event.source}/event_id={event.event_id}.json"
            s3_client().put_object(Bucket=RAW_BUCKET, Key=key, Body=event.model_dump_json().encode("utf-8"))
            print(f"s3_write_ok s3://{RAW_BUCKET}/{key}")
            consumer.commit(msg)
            consumed += 1
    finally:
        consumer.close()
    print(f"✅ consumed={consumed}")

if __name__ == "__main__":
    main()