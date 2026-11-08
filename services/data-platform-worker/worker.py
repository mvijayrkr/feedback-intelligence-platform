import json, os
from pathlib import Path
import boto3, psycopg2
from psycopg2.extras import Json, execute_values
from dq_rules import validate_event
from nlp_enrichment import enrich_gold

AWS_ENDPOINT_URL=os.getenv("AWS_ENDPOINT_URL","http://localhost:4566")
RAW_BUCKET=os.getenv("RAW_BUCKET","fip-local-raw")
PROCESSED_BUCKET=os.getenv("PROCESSED_BUCKET","fip-local-processed")
LOCAL_INPUT=os.getenv("LOCAL_INPUT","data/dummy/out/feedback_events.jsonl")
MAX_RECORDS=int(os.getenv("MAX_RECORDS","25000"))
RDS_HOST=os.getenv("RDS_HOST","localhost")
RDS_PORT=os.getenv("RDS_PORT","5432")
RDS_DB_NAME=os.getenv("RDS_DB_NAME","fip")
RDS_USERNAME=os.getenv("RDS_USERNAME","fip_user")
RDS_PASSWORD=os.getenv("RDS_PASSWORD","fip_password")

def s3_client():
    return boto3.client("s3", endpoint_url=AWS_ENDPOINT_URL, aws_access_key_id="test", aws_secret_access_key="test", region_name="us-west-2")

def db_conn():
    return psycopg2.connect(host=RDS_HOST, port=RDS_PORT, dbname=RDS_DB_NAME, user=RDS_USERNAME, password=RDS_PASSWORD)

def init_db():
    sql = '''
    create schema if not exists silver;
    create schema if not exists gold;
    create schema if not exists analytics;
    create table if not exists silver.feedback_events (
      event_id text primary key, tenant_id text, location_id text, source text,
      source_event_id text, review_text text, clean_review_text text, rating numeric,
      event_ts timestamptz, quality_errors jsonb, raw_payload jsonb, loaded_at timestamptz default now()
    );
    create table if not exists gold.feedback_events_enriched (
      event_id text primary key, tenant_id text, location_id text, source text,
      source_event_id text, review_text text, clean_review_text text, rating numeric,
      event_ts timestamptz, sentiment text, sentiment_score numeric, sentiment_model text,
      category text, severity text, intent text, embedding_text text,
      raw_payload jsonb, loaded_at timestamptz default now()
    );
    '''
    with db_conn() as conn:
        with conn.cursor() as cur: cur.execute(sql)

def read_events():
    p=Path(LOCAL_INPUT)
    if p.exists():
        return [json.loads(l) for l in p.read_text().splitlines() if l.strip()]
    client=s3_client()
    response=client.list_objects_v2(Bucket=RAW_BUCKET)
    events=[]
    for obj in response.get("Contents", []):
        if obj["Key"].endswith(".json"):
            body=client.get_object(Bucket=RAW_BUCKET, Key=obj["Key"])["Body"].read()
            events.append(json.loads(body))
    return events

def write_s3(prefix, event):
    key=f"{prefix}/tenant={event.get('tenant_id','unknown')}/source={event.get('source','unknown')}/event_id={event.get('event_id','missing')}.json"
    s3_client().put_object(Bucket=PROCESSED_BUCKET, Key=key, Body=json.dumps(event, default=str).encode())

def load_rds(silver_rows, gold_rows):
    with db_conn() as conn:
        with conn.cursor() as cur:
            execute_values(cur, '''
            insert into silver.feedback_events
            (event_id,tenant_id,location_id,source,source_event_id,review_text,clean_review_text,rating,event_ts,quality_errors,raw_payload)
            values %s on conflict (event_id) do nothing
            ''', [(r.get("event_id"),r.get("tenant_id"),r.get("location_id"),r.get("source"),r.get("source_event_id"),r.get("review_text"),r.get("clean_review_text"),r.get("rating"),r.get("event_ts"),Json(r.get("quality_errors",[])),Json(r.get("raw_payload",{}))) for r in silver_rows])
            execute_values(cur, '''
            insert into gold.feedback_events_enriched
            (event_id,tenant_id,location_id,source,source_event_id,review_text,clean_review_text,rating,event_ts,sentiment,sentiment_score,sentiment_model,category,severity,intent,embedding_text,raw_payload)
            values %s on conflict (event_id) do nothing
            ''', [(r.get("event_id"),r.get("tenant_id"),r.get("location_id"),r.get("source"),r.get("source_event_id"),r.get("review_text"),r.get("clean_review_text"),r.get("rating"),r.get("event_ts"),r.get("sentiment"),r.get("sentiment_score"),r.get("sentiment_model"),r.get("category"),r.get("severity"),r.get("intent"),r.get("embedding_text"),Json(r.get("raw_payload",{}))) for r in gold_rows])

def main():
    print(f"RDS={RDS_HOST}:{RDS_PORT}/{RDS_DB_NAME}")
    init_db()
    silver, gold, quarantine = [], [], []
    for event in read_events()[:MAX_RECORDS]:
        ok, errors = validate_event(event)
        enriched = enrich_gold(event, errors)
        if ok:
            silver.append(enriched); gold.append(enriched); write_s3("silver", enriched); write_s3("gold", enriched)
        else:
            quarantine.append({**event,"quality_errors":errors}); write_s3("quarantine", quarantine[-1])
    load_rds(silver, gold)
    print(f"✅ phase2_complete silver={len(silver)} gold={len(gold)} quarantine={len(quarantine)}")

if __name__=="__main__":
    main()
