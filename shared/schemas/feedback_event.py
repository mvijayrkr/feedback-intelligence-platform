from datetime import datetime
from typing import Any, Dict, Literal, Optional
from pydantic import BaseModel, Field

FeedbackSource = Literal[
    "google", "reddit", "doordash", "ubereats",
    "survey", "qr", "voice", "manager_note",
]

class FeedbackEvent(BaseModel):
    event_id: str
    tenant_id: str
    location_id: str
    source: FeedbackSource
    source_event_id: str
    review_text: str
    rating: Optional[float] = Field(default=None, ge=1, le=5)
    event_ts: datetime
    raw_payload: Dict[str, Any] = Field(default_factory=dict)