import json
import os
from pathlib import Path
from confluent_kafka import Producer
from shared.schemas.feedback_event import FeedbackEvent

TOPIC = os.getenv("KAFKA_TOPIC", "feedback.raw.events")
BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
INPUT_FILE = Path(os.getenv("INPUT_FILE", "data/dummy/out/feedback_events.jsonl"))

def main() -> None:
    print(f"producer_bootstrap={BOOTSTRAP}")
    producer = Producer({"bootstrap.servers": BOOTSTRAP, "enable.idempotence": True, "acks": "all"})
    count = 0
    with INPUT_FILE.open(encoding="utf-8") as f:
        for line in f:
            event = FeedbackEvent(**json.loads(line))
            producer.produce(TOPIC, key=event.event_id, value=event.model_dump_json())
            producer.poll(0)
            count += 1
    producer.flush()
    print(f"✅ published={count}")

if __name__ == "__main__":
    main()