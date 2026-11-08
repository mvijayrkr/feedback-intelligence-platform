from datetime import datetime, timezone, timedelta
from faker import Faker
from pathlib import Path
import random
import uuid

from shared.schemas.feedback_event import FeedbackEvent

fake = Faker()
TENANT = "curry_bowl_express"
LOCATIONS = ["mission", "castro", "soma", "oakland", "berkeley", "sunnyvale", "fremont", "san_jose", "palo_alto", "mountain_view", "dublin", "pleasanton"]
SOURCES = ["google", "reddit", "doordash", "ubereats", "survey", "qr", "voice", "manager_note"]
SCENARIOS = ["cold food", "missing item", "late delivery", "rude staff", "great biryani", "portion size", "price concern", "spicy level mismatch", "packaging leak", "long wait time", "excellent service", "wrong order", "freshness concern"]

def make_event(i: int) -> FeedbackEvent:
    scenario = random.choice(SCENARIOS)
    location = random.choice(LOCATIONS)
    source = random.choice(SOURCES)
    return FeedbackEvent(
        event_id=str(uuid.uuid4()),
        tenant_id=TENANT,
        location_id=location,
        source=source,
        source_event_id=f"{source}-{i}",
        review_text=f"{fake.sentence()} Main topic: {scenario}. Location: {location}.",
        rating=round(random.uniform(1, 5), 1),
        event_ts=datetime.now(timezone.utc) - timedelta(minutes=random.randint(1, 50000)),
        raw_payload={"scenario": scenario, "source": source, "generated": True},
    )

def main() -> None:
    out = Path("data/dummy/out/feedback_events.jsonl")
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="utf-8") as f:
        for i in range(25000):
            f.write(make_event(i).model_dump_json() + "\n")
    print(f"✅ wrote {out}")
    print("✅ records=25000")

if __name__ == "__main__":
    main()