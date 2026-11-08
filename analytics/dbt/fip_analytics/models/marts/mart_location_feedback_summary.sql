select tenant_id, location_id, count(*) total_feedback_count, avg(rating) avg_rating, max(event_ts) latest_feedback_ts
from {{ ref('gold_feedback_events') }}
group by tenant_id, location_id