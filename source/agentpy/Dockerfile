FROM python:3.11-slim

WORKDIR /app

# Instalacja zależności
RUN pip install --no-cache-dir agentpy numpy

# Kopiujemy skrypt
COPY model.py .

# Uruchomienie
CMD ["python", "model.py"]
