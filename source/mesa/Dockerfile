FROM python:3.11-slim

WORKDIR /app

# Instalacja zależności
RUN pip install --no-cache-dir mesa==1.2.1 numpy

# Kopiujemy skrypt
COPY model.py .

# Uruchomienie
ENTRYPOINT ["python", "model.py"]
