FROM python:3.13-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    git cmake build-essential curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Build llama.cpp
RUN git clone --depth 1 https://github.com/ggerganov/llama.cpp /llama.cpp && \
    cd /llama.cpp && mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DLLAMA_CURL=OFF && \
    cmake --build . --config Release -j$(nproc) --target llama-server

# Runtime
FROM python:3.13-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates && rm -rf /var/lib/apt/lists/*

COPY --from=builder /llama.cpp/build/bin/llama-server /usr/local/bin/llama-server
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync --no-dev --frozen 2>/dev/null || uv sync --no-dev
COPY . .

# Model downloaded at runtime to /data volume (persists across deploys)
ENV MODEL_PATH=/data/granite-4.0-micro-Q4_K_M.gguf
ENV MODEL_URL=https://huggingface.co/lmstudio-community/granite-4.0-micro-GGUF/resolve/main/granite-4.0-micro-Q4_K_M.gguf

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000
CMD ["/entrypoint.sh"]
