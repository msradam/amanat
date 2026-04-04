#!/bin/bash
# Start llama-server in background
llama-server \
    --model /model.gguf \
    --port 8080 \
    --host 0.0.0.0 \
    --ctx-size 4096 \
    --parallel 1 &

# Wait for llama-server to be ready
echo "Waiting for llama-server..."
for i in $(seq 1 60); do
    if curl -s http://localhost:8080/health > /dev/null 2>&1; then
        echo "llama-server ready"
        break
    fi
    sleep 2
done

# Set env for the app
export OPENAI_API_BASE=http://localhost:8080/v1
export OPENAI_API_KEY=llama

# Start Chainlit
exec uv run chainlit run app.py --host 0.0.0.0 --port ${PORT:-8000}
