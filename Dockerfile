FROM python:3.13-slim AS builder

# Install build deps for llama.cpp
RUN apt-get update && apt-get install -y --no-install-recommends \
    git cmake build-essential curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Build llama.cpp (CPU only, no CUDA needed)
RUN git clone --depth 1 https://github.com/ggerganov/llama.cpp /llama.cpp && \
    cd /llama.cpp && mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DLLAMA_CURL=OFF && \
    cmake --build . --config Release -j$(nproc) --target llama-server

# Download Granite 4 Micro GGUF (~1.8GB Q4_K_M)
RUN curl -L -o /model.gguf \
    "https://huggingface.co/lmstudio-community/granite-4.0-micro-GGUF/resolve/main/granite-4.0-micro-Q4_K_M.gguf"

# Runtime stage
FROM python:3.13-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates && rm -rf /var/lib/apt/lists/*

# Copy llama-server binary and model
COPY --from=builder /llama.cpp/build/bin/llama-server /usr/local/bin/llama-server
COPY --from=builder /model.gguf /model.gguf

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /app

# Copy deps first for caching
COPY pyproject.toml uv.lock ./
RUN uv sync --no-dev --frozen 2>/dev/null || uv sync --no-dev

# Copy app
COPY . .

# Entrypoint: start llama-server in background, then chainlit
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000
CMD ["/entrypoint.sh"]
