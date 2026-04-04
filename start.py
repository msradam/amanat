"""Railway entrypoint: start llama-server + Chainlit."""
import os
import subprocess
import time
import sys

MODEL_PATH = os.environ.get("MODEL_PATH", "/data/granite-4.0-micro-Q4_K_M.gguf")
MODEL_URL = os.environ.get("MODEL_URL", "https://huggingface.co/lmstudio-community/granite-4.0-micro-GGUF/resolve/main/granite-4.0-micro-Q4_K_M.gguf")
PORT = os.environ.get("PORT", "8000")

# Download model if needed
if not os.path.exists(MODEL_PATH):
    os.makedirs(os.path.dirname(MODEL_PATH), exist_ok=True)
    print(f"Downloading model to {MODEL_PATH}...")
    subprocess.run(["curl", "-L", "-o", MODEL_PATH, MODEL_URL], check=True)
    print("Download complete.")

# Start llama-server
os.environ["OPENAI_API_BASE"] = "http://localhost:8080/v1"
os.environ["OPENAI_API_KEY"] = "llama"

llama = subprocess.Popen([
    "llama-server",
    "--model", MODEL_PATH,
    "--port", "8080",
    "--host", "0.0.0.0",
    "--ctx-size", "4096",
    "--parallel", "1",
])

# Wait for health
print("Waiting for llama-server...")
for _ in range(120):
    try:
        import urllib.request
        urllib.request.urlopen("http://localhost:8080/health", timeout=2)
        print("llama-server ready")
        break
    except Exception:
        time.sleep(2)

# Start Chainlit
os.execvp("chainlit", ["chainlit", "run", "app.py", "--host", "0.0.0.0", "--port", PORT])
