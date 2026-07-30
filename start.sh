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
        --show-progress \
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

echo "All models downloaded."

echo "Starting ACE-Step server..."

exec /app/ace-server \
    --models "$MODEL_DIR" \
    --host :: \
    --port 8080

