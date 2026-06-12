# Используем стабильный slim-образ
FROM python:3.11-slim

# Выставляем переменные окружения, чтобы Python не буферизировал логи
# и не плодил мусорные .pyc файлы
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=5000

WORKDIR /app

# Устанавливаем системные зависимости, которые могут понадобиться для curl_cffi
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Копируем и устанавливаем зависимости Python
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Копируем остальной код приложения
COPY . .

# Открываем порт наружу
EXPOSE ${PORT}

# Запускаем через Production-ready сервер Gunicorn с Uvicorn-воркерами
CMD gunicorn main:app --workers 4 --worker-class uvicorn.workers.UvicornWorker --bind 0.0.0.0:${PORT}
