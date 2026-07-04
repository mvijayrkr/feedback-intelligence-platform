FROM python:3.12-slim
WORKDIR /app
ENV PYTHONUNBUFFERED=1
ENV DBT_PROFILES_DIR=/app/analytics/dbt/fip_analytics
COPY analytics/dbt/fip_analytics/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt
COPY analytics /app/analytics
WORKDIR /app/analytics/dbt/fip_analytics
CMD ["dbt", "run"]
