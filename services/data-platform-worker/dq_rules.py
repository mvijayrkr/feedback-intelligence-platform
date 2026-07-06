from datetime import datetime

REQUIRED_FIELDS = ["event_id","tenant_id","location_id","source","source_event_id","review_text","event_ts"]

def validate_event(payload):
    errors = []
    for field in REQUIRED_FIELDS:
        if field not in payload or payload[field] in (None, ""):
            errors.append(f"missing_required_field:{field}")
    rating = payload.get("rating")
    if rating is not None:
        try:
            rating_f = float(rating)
            if rating_f < 1 or rating_f > 5:
                errors.append("rating_out_of_range")
        except Exception:
            errors.append("rating_not_numeric")
    try:
        datetime.fromisoformat(str(payload.get("event_ts")).replace("Z","+00:00"))
    except Exception:
        errors.append("invalid_event_ts")
    return len(errors) == 0, errors
