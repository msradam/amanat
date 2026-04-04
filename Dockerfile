FROM python:3.13-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates unzip && rm -rf /var/lib/apt/lists/*

# Pre-built llama-server
RUN curl -L -o /tmp/llama.zip \
    "https://github.com/ggerganov/llama.cpp/releases/download/b5170/llama-b5170-bin-ubuntu-x64.zip" && \
    cd /tmp && unzip -q llama.zip && \
    find /tmp -name "llama-server" -exec cp {} /usr/local/bin/llama-server \; && \
    chmod +x /usr/local/bin/llama-server && \
    rm -rf /tmp/*

WORKDIR /app

# Install deps with pip (faster than uv for CI)
COPY requirements-railway.txt ./
RUN pip install --no-cache-dir -r requirements-railway.txt

COPY . .

ENV MODEL_PATH=/data/granite-4.0-micro-Q4_K_M.gguf
ENV MODEL_URL=https://huggingface.co/lmstudio-community/granite-4.0-micro-GGUF/resolve/main/granite-4.0-micro-Q4_K_M.gguf

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000
CMD ["/entrypoint.sh"]
