FROM python:3.13-slim AS llama-builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    git cmake build-essential && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/ggerganov/llama.cpp /llama.cpp && \
    cd /llama.cpp && mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DLLAMA_CURL=OFF -DBUILD_SHARED_LIBS=OFF && \
    cmake --build . --config Release -j$(nproc) --target llama-server

FROM python:3.13-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates libgomp1 && rm -rf /var/lib/apt/lists/*

COPY --from=llama-builder /llama.cpp/build/bin/llama-server /usr/local/bin/llama-server

WORKDIR /app
COPY requirements-railway.txt ./
RUN pip install --no-cache-dir -r requirements-railway.txt
COPY . .

ENV MODEL_PATH=/data/granite-4.0-micro-Q4_K_M.gguf
ENV MODEL_URL=https://huggingface.co/lmstudio-community/granite-4.0-micro-GGUF/resolve/main/granite-4.0-micro-Q4_K_M.gguf

CMD ["python", "start.py"]
