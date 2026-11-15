# pipeline-api (SPECS_v2 §11.3). Interno: sin puerto público.
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY calendario.py servicio.py ./
# pipeline/raw/ (descargas de NASA POWER) va en un volumen: se reutiliza entre reinicios.
CMD ["uvicorn", "servicio:app", "--host", "0.0.0.0", "--port", "8000"]
