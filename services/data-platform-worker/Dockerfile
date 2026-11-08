FROM python:3.12-slim
WORKDIR /app
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app
COPY services/data-platform-worker/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt
COPY shared /app/shared
COPY services /app/services
COPY data/dummy/out /app/data/dummy/out
CMD ["python", "services/data-platform-worker/worker.py"]
