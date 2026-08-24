FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    MC_DATA_DIR=/data/model-converter

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app
COPY tests ./tests
COPY run.py ./

RUN mkdir -p /data/model-converter

EXPOSE 8080

CMD ["python", "run.py"]
