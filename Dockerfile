FROM python:3.13-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates && rm -rf /var/lib/apt/lists/*

# Install pre-built llama-server from releases
RUN curl -L -o /tmp/llama.tar.gz \
    "https://github.com/ggerganov/llama.cpp/releases/download/b5170/llama-b5170-bin-ubuntu-x64.zip" && \
    apt-get update && apt-get install -y unzip && \
    cd /tmp && unzip llama.tar.gz && \
    cp /tmp/build/bin/llama-server /usr/local/bin/llama-server 2>/dev/null || \
    find /tmp -name "llama-server" -exec cp {} /usr/local/bin/llama-server \; && \
    chmod +x /usr/local/bin/llama-server && \
    rm -rf /tmp/llama* && \
    apt-get remove -y unzip && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync --no-dev --frozen 2>/dev/null || uv sync --no-dev
COPY . .

ENV MODEL_PATH=/data/granite-4.0-micro-Q4_K_M.gguf
ENV MODEL_URL=https://huggingface.co/lmstudio-community/granite-4.0-micro-GGUF/resolve/main/granite-4.0-micro-Q4_K_M.gguf

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000
CMD ["/entrypoint.sh"]
