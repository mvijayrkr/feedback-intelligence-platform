import re
from functools import lru_cache

from transformers import pipeline

EMAIL_RE = re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b")
PHONE_RE = re.compile(r"\b(?:\+?1[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b")

CATEGORIES = {
    "delivery": ["late","delay","driver","delivery"],
    "food_quality": ["cold","stale","fresh","taste","spicy","burnt"],
    "order_accuracy": ["missing","wrong","incorrect","item"],
    "service": ["rude","staff","service","manager"],
    "pricing": ["price","expensive","cost","value"],
    "packaging": ["leak","spill","package","container"],
}

ROBERTA_MODEL_NAME = "cardiffnlp/twitter-roberta-base-sentiment-latest"

@lru_cache(maxsize=1)
def get_sentiment_model():
    return pipeline(
        "sentiment-analysis",
        model=ROBERTA_MODEL_NAME,
        tokenizer=ROBERTA_MODEL_NAME,
    )

def normalize_text(text):
    text = EMAIL_RE.sub("[EMAIL_MASKED]", text or "")
    text = PHONE_RE.sub("[PHONE_MASKED]", text)
    return re.sub(r"\s+"," ",text).strip()

def category(text):
    lower = text.lower()
    for c, words in CATEGORIES.items():
        if any(w in lower for w in words):
            return c
    return "general"

def sentiment_from_text(text):
    if not text or len(text.strip()) < 3:
        return {
            "sentiment": "unknown",
            "sentiment_score": 0.0,
            "sentiment_model": ROBERTA_MODEL_NAME,
        }

    result = get_sentiment_model()(text[:512])[0]

    return {
        "sentiment": str(result["label"]).lower(),
        "sentiment_score": float(result["score"]),
        "sentiment_model": ROBERTA_MODEL_NAME,
    }

def enrich_gold(payload, quality_errors):
    clean = normalize_text(payload.get("review_text",""))
    cat = category(clean)
    sentiment_result = sentiment_from_text(clean)
    sent = sentiment_result["sentiment"]
    return {
        **payload,
        "clean_review_text": clean,
        "quality_errors": quality_errors,
        "sentiment": sent,
        "sentiment_score": sentiment_result["sentiment_score"],
        "sentiment_model": sentiment_result["sentiment_model"],
        "category": cat,
        "severity": "high" if sent == "negative" else "low",
        "intent": "complaint" if sent == "negative" else "praise_or_feedback",
        "embedding_text": f"{cat}. {sent}. {clean}",
        "processing_stage": "gold",
    }
