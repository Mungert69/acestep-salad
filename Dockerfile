# =========================
# Build stage
# =========================
FROM nvidia/cuda:11.8.0-devel-ubuntu22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    git \
    wget \
    cmake \
    ninja-build \
    build-essential \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

ENV CUDA_HOME=/usr/local/cuda-11.8
ENV CUDAToolkit_ROOT=/usr/local/cuda-11.8

RUN ln -sf \
    /usr/local/cuda-11.8/targets/x86_64-linux/lib/stubs/libcuda.so \
    /usr/local/cuda-11.8/targets/x86_64-linux/lib/stubs/libcuda.so.1

ENV LIBRARY_PATH=/usr/local/cuda-11.8/targets/x86_64-linux/lib/stubs
ENV LD_LIBRARY_PATH=/usr/local/cuda-11.8/targets/x86_64-linux/lib/stubs:/usr/local/cuda-11.8/lib64

WORKDIR /build

RUN git clone --recursive https://github.com/ServeurpersoCom/acestep.cpp.git

WORKDIR /build/acestep.cpp

RUN cmake -B build \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCUDAToolkit_ROOT=/usr/local/cuda-11.8 \
    -DGGML_CUDA=ON \
    -DCMAKE_CUDA_ARCHITECTURES="61;75"

RUN cmake --build build


# =========================
# Runtime stage
# =========================
FROM nvidia/cuda:11.8.0-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    python3 \
    wget \
    curl \
    ca-certificates \
    libgomp1 \
    iproute2 \
 && rm -rf /var/lib/apt/lists/*

ENV CUDA_HOME=/usr/local/cuda-11.8
ENV LD_LIBRARY_PATH=/app:/usr/local/cuda-11.8/lib64

WORKDIR /app

COPY --from=builder /build/acestep.cpp/build/ /app/

COPY start.sh /app/start.sh

RUN chmod +x /app/start.sh

RUN mkdir -p /app/models

EXPOSE 8080

CMD ["/app/start.sh"]
