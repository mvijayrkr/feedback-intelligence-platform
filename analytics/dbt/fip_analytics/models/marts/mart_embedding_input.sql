select event_id, tenant_id, location_id, source, category, sentiment, sentiment_score, sentiment_model, severity, embedding_text, event_ts
from {{ ref('gold_feedback_events') }}
where embedding_text is not null