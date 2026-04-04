#!/bin/bash
set -e

# Download model if not already cached in volume
if [ ! -f "$MODEL_PATH" ]; then
    echo "Downloading Granite 4 Micro GGUF..."
    mkdir -p /data
    curl -L -o "$MODEL_PATH" "$MODEL_URL"
    echo "Download complete."
fi

# Start llama-server
llama-server \
    --model "$MODEL_PATH" \
    --port 8080 \
    --host 0.0.0.0 \
    --ctx-size 4096 \
    --parallel 1 &

echo "Waiting for llama-server..."
for i in $(seq 1 120); do
    if curl -s http://localhost:8080/health > /dev/null 2>&1; then
        echo "llama-server ready"
        break
    fi
    sleep 2
done

export OPENAI_API_BASE=http://localhost:8080/v1
export OPENAI_API_KEY=llama

exec uv run chainlit run app.py --host 0.0.0.0 --port ${PORT:-8000}
