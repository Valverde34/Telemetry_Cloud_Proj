FROM python:3.12-slim
ENV PYTHONUNBUFFERED=1
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY simulator.py .
RUN useradd --system --uid 10001 simuser
USER simuser
CMD ["python", "simulator.py"]
