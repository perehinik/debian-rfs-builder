#!/usr/bin/env bash
set -e

show_help() {
    echo "Usage: $(basename "$0") -i <image> -s <script> [-c <directory>] [-k <kernel>]"
    echo
    echo "Options:"
    echo "  -i <image>       Root filesystem image."
    echo "  -s <script>      Script to execute inside the target image."
    echo "  -c <directory>   Directory to copy into the target image (optional)."
    echo "  -k <kernel>      Kernel image (default: Image.gz)."
    echo "  -d               Run inside Docker."
    echo "  -h               Show this help message."
}

THIS_SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
THIS_SCRIPT_DIR="$(dirname "$THIS_SCRIPT_PATH")"

IMAGE_NAME=""
SCRIPT_PATH=""
COPY_DIR=""
KERNEL_IMAGE="${THIS_SCRIPT_DIR}/kernel/Image.gz"
QEMU_LOG="./build/qemu.log"
USE_DOCKER=0
DOCKER_IMAGE="perehiniak/linux-build-tools:1.0.0"

while getopts "i:s:c:k:dh" opt; do
    case "$opt" in
        i) IMAGE_NAME="$OPTARG" ;;
        s) SCRIPT_PATH="$OPTARG" ;;
        c) COPY_DIR="$OPTARG" ;;
        k) KERNEL_IMAGE="$OPTARG" ;;
        d) USE_DOCKER=1 ;;
        h)
            show_help
            exit 0
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            show_help
            exit 1
            ;;
        \?)
            show_help
            exit 1
            ;;
    esac
done

if [ "$USE_DOCKER" = "1" ] && [ -z "${INSIDE_DOCKER:-}" ]; then
    exec docker run -it \
        --rm \
        --privileged \
        --network host \
        -e INSIDE_DOCKER=1 \
        -v "$PWD:/root" \
        -v "$HOME/.ssh:/root/.ssh:ro" \
        -w /root \
        -u root \
        --entrypoint "$0" \
        "$DOCKER_IMAGE" \
        "$@"
fi

[ -n "$IMAGE_NAME" ] || { echo "ERROR: -i is required."; exit 1; }
[ -n "$SCRIPT_PATH" ] || { echo "ERROR: -s is required."; exit 1; }

[ -f "$IMAGE_NAME" ] || { echo "ERROR: Image not found: $IMAGE_NAME"; exit 1; }
[ -f "$SCRIPT_PATH" ] || { echo "ERROR: Script not found: $SCRIPT_PATH"; exit 1; }

if [ -n "$COPY_DIR" ] && [ ! -d "$COPY_DIR" ]; then
    echo "ERROR: Directory not found: $COPY_DIR"
    exit 1
fi

SSH_PORT=2222
SSH_USER=qemu
SSH_HOST=localhost

REMOTE_DIR=/tmp/qemu_env
REMOTE_SCRIPT="$(basename "$SCRIPT_PATH")"

SSH_OPTS=(
    -p "$SSH_PORT"
    -o StrictHostKeyChecking=no
    -o UserKnownHostsFile=/dev/null
)

SCP_OPTS=(
    -P "$SSH_PORT"
    -o StrictHostKeyChecking=no
    -o UserKnownHostsFile=/dev/null
)

ssh_exec() {
    local SSH_COMMAND="$1"
    ssh "${SSH_OPTS[@]}" "${SSH_USER}@${SSH_HOST}" "${SSH_COMMAND}"
}

scp_copy() {
    local SCP_SRC="$1"
    if [ -d "${SCP_SRC}" ]; then
        echo "Copy $SCP_SRC/* to ${SSH_USER}@${SSH_HOST}:${REMOTE_DIR}"
        scp -r "${SCP_OPTS[@]}" "${SCP_SRC}/*" "${SSH_USER}@${SSH_HOST}:${REMOTE_DIR}"
    elif [ -f "${SCP_SRC}" ]; then
        echo "Copy ${SCP_SRC} to ${SSH_USER}@${SSH_HOST}:${REMOTE_DIR}"
        scp "${SCP_OPTS[@]}" "${SCP_SRC}" "${SSH_USER}@${SSH_HOST}:${REMOTE_DIR}"
    else
        echo "Does not exist (or is another type)"
    fi
}

cleanup() {
    if kill -0 "$QEMU_PID" 2>/dev/null; then
        kill "$QEMU_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

echo "Start Qemu"

apt update && apt install -y openssh-client


qemu-system-aarch64 \
    -machine virt \
    -cpu cortex-a57 \
    -m 4G \
    -smp 4 \
    -nographic \
    -kernel "$KERNEL_IMAGE" \
    -drive if=none,file="$IMAGE_NAME",format=raw,id=mydisk \
    -device virtio-blk-device,drive=mydisk \
    -append "rootwait root=/dev/vda rw net.ifnames=0" \
    -device virtio-net-device,netdev=usernet \
    -netdev user,id=usernet,hostfwd=tcp::${SSH_PORT}-:22 \
    > "$QEMU_LOG" 2>&1 &
QEMU_PID=$!

until ssh_exec true; do
    echo "Waiting for SSH..."
    sleep 2
done

ssh_exec "mkdir -p '$REMOTE_DIR'"
ssh_exec "rm -rf '$REMOTE_DIR'/*"

scp_copy "$SCRIPT_PATH"

if [ -n "$COPY_DIR" ]; then
    scp_copy "$COPY_DIR"/*
fi

ssh_exec "cd ${REMOTE_DIR} && ./$REMOTE_SCRIPT"
ssh_exec "rm -rf '$REMOTE_DIR'/*"
ssh_exec "sync"

ssh_exec "sudo poweroff"

wait "$QEMU_PID"
trap - EXIT
