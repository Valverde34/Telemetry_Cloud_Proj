FROM python:3.12-slim
ENV PYTHONUNBUFFERED=1
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY simulator.py .
# Code is owned by root and read-only for everyone else, whatever the
# file permissions were on the build machine.
RUN chmod -R a+rX,go-w /app
RUN useradd --system --uid 10001 simuser
USER simuser
CMD ["python", "simulator.py"]
