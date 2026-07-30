#!/bin/bash

set -euo pipefail

MODEL_DIR=/app/models
HF_REPO=Serveurperso/ACE-Step-1.5-GGUF

mkdir -p "$MODEL_DIR"

echo "Checking IPv6 availability..."

if [ -f /proc/net/if_inet6 ]; then
    echo "IPv6 support detected"
else
    echo "WARNING: IPv6 support not detected"
fi

echo "Starting temporary IPv6 health server on port 8080..."

python3 - <<'PY' &
import http.server
import socketserver
import socket

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"ACE-Step loading models\n")

    def log_message(self, format, *args):
        pass

class IPv6Server(socketserver.TCPServer):
    address_family = socket.AF_INET6

try:
    with IPv6Server(("::", 8080), Handler) as httpd:
        print("Health server listening on [::]:8080", flush=True)
        httpd.serve_forever()
except Exception as e:
    print(f"Health server failed: {e}", flush=True)
    raise
PY

HEALTH_PID=$!

cleanup() {
    echo "Cleaning up health server..."

    if kill -0 "$HEALTH_PID" 2>/dev/null; then
        kill "$HEALTH_PID" 2>/dev/null || true
        wait "$HEALTH_PID" 2>/dev/null || true
    fi
}

trap cleanup EXIT TERM INT

sleep 2

if kill -0 "$HEALTH_PID" 2>/dev/null; then
    echo "Health server running PID=$HEALTH_PID"
else
    echo "WARNING: health server failed to start"
fi


download_model() {
    FILE=$1
    URL="https://huggingface.co/$HF_REPO/resolve/main/$FILE?download=true"

    if [ -f "$MODEL_DIR/$FILE" ]; then
        echo "$FILE already exists"
        return
    fi

    echo "Downloading $FILE..."

    wget \
        --continue \
        --progress=dot:giga \
        --tries=5 \
        --waitretry=10 \
        -O "$MODEL_DIR/$FILE.tmp" \
        "$URL"

    mv "$MODEL_DIR/$FILE.tmp" "$MODEL_DIR/$FILE"

    echo "Finished downloading $FILE"
}


download_model "Qwen3-Embedding-0.6B-Q8_0.gguf"
download_model "acestep-5Hz-lm-4B-Q5_K_M.gguf"
download_model "acestep-v15-sft-Q4_K_M.gguf"
download_model "vae-BF16.gguf"


echo "Models:"
ls -lh "$MODEL_DIR"


echo "Stopping temporary health server..."

cleanup


echo "Starting ACE-Step server..."

exec /app/ace-server \
    --models "$MODEL_DIR" \
    --host :: \
    --port 8080
