FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV CONFIG_FILE_PATH=src/config.ini

RUN mkdir -p /app/src && \
    cat > /app/src/config.ini << 'EOF'
[database]
DB_SCHEME=mysql+aiomysql
DB_USER=app_user
DB_PASSWORD=app_password_123
DB_NAME=software_labs
DB_HOST=db
DB_PORT=3306

[service]
HOST=0.0.0.0
PORT=8000
EOF

EXPOSE 8000

CMD ["python", "run.py"]
