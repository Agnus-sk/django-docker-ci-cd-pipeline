FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .

COPY wheels /wheels
RUN pip install --no-index --find-links=/wheels -r requirements.txt


COPY . .

RUN useradd -m appuser \
 && chown -R appuser:appuser /app

USER appuser

EXPOSE 8000

CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]

