#!/usr/bin/env bash
#
# diagnostic.sh - containerized system diagnostic tool.
# Usage: diagnostic.sh <command> [args]
#   system          show Linux system information
#   network <host>  resolve a host and check connectivity
#   disk            show filesystem disk usage
#   help            show usage
# Exit: 0 success, 1 operational failure, 2 invalid command or input.

set -u

LOG_DIR="logs"
SCRIPT_NAME="diagnostic.sh"

log() {
    local msg="$1"
    local ts
    ts="$(date '+%Y-%m-%dT%H:%M:%S%z')"
    mkdir -p "$LOG_DIR"
    printf '%s [%s] %s\n' "$ts" "$SCRIPT_NAME" "$msg" >> "$LOG_DIR/diagnostic.log"
}

usage() {
    cat <<'USAGE'
diagnostic.sh - containerized system diagnostic tool

Usage:
  diagnostic.sh <command> [args]

Commands:
  system            Show Linux system information
  network <host>    Resolve <host> and check connectivity
  disk              Show filesystem disk usage
  help              Show this help text

Exit codes:
  0  success
  1  operational failure (e.g. host unreachable)
  2  invalid command or missing required argument
USAGE
}

system() {
    local host user now os kernel up cpu mem cwd
    host="$(hostname 2>/dev/null || cat /proc/sys/kernel/hostname 2>/dev/null || uname -n)"
    user="$(whoami 2>/dev/null || id -un 2>/dev/null || printf '%s' "${USER:-unknown}")"
    now="$(date)"
    os="$( . /etc/os-release 2>/dev/null && printf '%s' "$PRETTY_NAME" || uname -s )"
    kernel="$(uname -s -r)"
    if uptime >/dev/null 2>&1; then
        up="$(uptime)"
    elif [[ -r /proc/uptime ]]; then
        local secs; secs="$(cut -d. -f1 /proc/uptime)"
        up="$(( secs / 86400 ))d $(( (secs % 86400) / 3600 ))h $(( (secs % 3600) / 60 ))m"
    else
        up="unavailable"
    fi
    if [[ -r /proc/cpuinfo ]]; then
        local model count
        model="$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')"
        count="$(grep -c '^processor' /proc/cpuinfo)"
        cpu="${model:-unknown} (${count} cores)"
    elif command -v nproc >/dev/null 2>&1; then
        cpu="$(nproc) cores"
    else
        cpu="unavailable"
    fi
    if command -v free >/dev/null 2>&1; then
        mem="$(free -h | awk 'NR==2 {print $3 " used / " $2 " total"}')"
    elif [[ -r /proc/meminfo ]]; then
        mem="$(awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {printf "%.1f GiB available / %.1f GiB total", a/1048576, t/1048576}' /proc/meminfo)"
    else
        mem="unavailable"
    fi
    cwd="$(pwd)"

    printf 'Hostname: %s\n' "$host"
    printf 'Current User: %s\n' "$user"
    printf 'Date/Time: %s\n' "$now"
    printf 'Operating System: %s\n' "$os"
    printf 'Kernel Version: %s\n' "$kernel"
    printf 'Uptime: %s\n' "$up"
    printf 'CPU: %s\n' "$cpu"
    printf 'Memory: %s\n' "$mem"
    printf 'Working Directory: %s\n' "$cwd"

    log "reported system information"
    exit 0
}

network() {
    local host="$1"
    local addr reachable

    addr="$(getent hosts "$host" 2>/dev/null | awk '{print $1; exit}')"
    [[ -z "$addr" ]] && addr="$(host "$host" 2>/dev/null | awk '/has address/{print $NF; exit}')"
    [[ -z "$addr" ]] && addr="$(python3 -c 'import socket,sys; print(socket.gethostbyname(sys.argv[1]))' "$host" 2>/dev/null)"
    [[ -z "$addr" ]] && addr="$(ping -c 1 "$host" 2>/dev/null | sed -n 's/.*(\([0-9.]*\)).*/\1/p' | head -n1)"

    printf 'Host: %s\n' "$host"
    printf 'Resolved address: %s\n' "${addr:-unresolved}"

    reachable=1
    if command -v ping >/dev/null 2>&1 && ping -c 1 -W 1 "$host" >/dev/null 2>&1; then
        reachable=0
    else
        local probe_port
        for probe_port in 80 443 22; do
            if timeout 2 bash -c ">/dev/tcp/$host/$probe_port" 2>/dev/null; then
                reachable=0
                break
            fi
        done
    fi
    printf 'Connectivity: %s\n' "$([[ $reachable -eq 0 ]] && echo reachable || echo unreachable)"

    log "host=$host addr=${addr:-unresolved} reachable=$reachable"
    exit "$reachable"
}

disk() {
    echo "Filesystem disk usage:"
    df -P -h
    log "reported disk usage"
    exit 0
}

cmd="${1:-help}"

case "$cmd" in
    system)
        system
        ;;
    network)
        host="${2:-}"
        if [[ -z "$host" ]]; then
            echo "Error: 'network' requires a host argument" >&2
            usage >&2
            log "network called without host"
            exit 2
        fi
        network "$host"
        ;;
    disk)
        disk
        ;;
    help|-h|--help)
        usage
        exit 0
        ;;
    *)
        echo "Error: unknown command '$cmd'" >&2
        usage >&2
        log "unknown command: '$cmd'"
        exit 2
        ;;
esac
