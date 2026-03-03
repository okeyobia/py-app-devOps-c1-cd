#!/usr/bin/env bash
set -euo pipefail

HOST=${FASTAPI_HOST:-fastapi.local}
SERVICE_NS=${INGRESS_NAMESPACE:-ingress-nginx}
SERVICE_NAME=${INGRESS_SERVICE:-ingress-nginx-controller}
STATE_DIR=.devinfra
PID_FILE="$STATE_DIR/minikube-tunnel.pid"
LOG_FILE="$STATE_DIR/minikube-tunnel.log"
HOST_TAG="# fastapi-dev-ingress"

usage() {
  cat <<EOF
Usage: $0 <start|stop|status>

start   Patch the ingress controller Service to LoadBalancer (if needed),
        launch minikube tunnel, and ensure /etc/hosts maps $HOST to the
        LoadBalancer IP.
stop    Remove the hosts entry and stop the tunnel background process.
status  Show the current service type, tunnel state, and hosts mapping.

Environment overrides:
  FASTAPI_HOST          Hostname to map (default: fastapi.local)
  INGRESS_NAMESPACE     Namespace containing ingress-nginx (default: ingress-nginx)
  INGRESS_SERVICE       Service name for the controller (default: ingress-nginx-controller)
EOF
}

log() {
  printf '[dev-ingress] %s\n' "$*"
}

die() {
  log "Error: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

ensure_state_dir() {
  mkdir -p "$STATE_DIR"
}

run_kubectl() {
  kubectl -n "$SERVICE_NS" "$@"
}

get_service_type() {
  run_kubectl get svc "$SERVICE_NAME" -o jsonpath='{.spec.type}' 2>/dev/null || true
}

ensure_service_exists() {
  if ! run_kubectl get svc "$SERVICE_NAME" >/dev/null 2>&1; then
    die "Service $SERVICE_NAME not found in namespace $SERVICE_NS"
  fi
}

ensure_load_balancer_type() {
  local type
  type=$(get_service_type)
  if [[ "$type" != "LoadBalancer" ]]; then
    log "Switching $SERVICE_NAME to LoadBalancer"
    run_kubectl patch svc "$SERVICE_NAME" -p '{"spec":{"type":"LoadBalancer"}}' >/dev/null
  fi
}

get_lb_ip() {
  run_kubectl get svc "$SERVICE_NAME" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true
}

tunnel_running() {
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid=$(cat "$PID_FILE")
    if ps -p "$pid" >/dev/null 2>&1; then
      return 0
    fi
  fi
  return 1
}

start_tunnel() {
  if tunnel_running; then
    log "minikube tunnel already running"
    return
  fi
  log "Starting minikube tunnel (sudo password may be required)"
  ensure_state_dir
  sudo nohup minikube tunnel >"$LOG_FILE" 2>&1 &
  echo $! >"$PID_FILE"
  sleep 2
}

stop_tunnel() {
  if tunnel_running; then
    local pid
    pid=$(cat "$PID_FILE")
    log "Stopping minikube tunnel (pid $pid)"
    sudo kill "$pid" >/dev/null 2>&1 || true
    rm -f "$PID_FILE"
  else
    log "No tunnel PID tracked"
  fi
}

wait_for_lb_ip() {
  local ip=""
  for _ in {1..30}; do
    ip=$(get_lb_ip)
    if [[ -n "$ip" ]]; then
      echo "$ip"
      return
    fi
    sleep 2
  done
  die "Timed out waiting for LoadBalancer IP; check minikube tunnel output in $LOG_FILE"
}

remove_hosts_entry() {
  if grep -q "$HOST_TAG" /etc/hosts 2>/dev/null; then
    sudo sed -i '' "/$HOST_TAG$/d" /etc/hosts
  fi
}

update_hosts_entry() {
  local ip="$1"
  remove_hosts_entry
  printf '%s %s %s\n' "$ip" "$HOST" "$HOST_TAG" | sudo tee -a /etc/hosts >/dev/null
}

show_status() {
  require_cmd kubectl
  local type ip hosts_line="(absent)"
  type=$(get_service_type)
  ip=$(get_lb_ip)
  if grep -q "$HOST_TAG" /etc/hosts 2>/dev/null; then
    hosts_line=$(grep "$HOST_TAG" /etc/hosts)
  fi
  log "Service type: ${type:-unknown}"
  log "LoadBalancer IP: ${ip:-pending}" 
  if tunnel_running; then
    log "Tunnel: running (pid $(cat "$PID_FILE"))"
  else
    log "Tunnel: stopped"
  fi
  log "Hosts entry: $hosts_line"
}

start_flow() {
  ensure_state_dir
  ensure_service_exists
  ensure_load_balancer_type
  start_tunnel
  local ip
  ip=$(wait_for_lb_ip)
  update_hosts_entry "$ip"
  log "fastapi ingress reachable via http://$HOST/"
}

stop_flow() {
  remove_hosts_entry
  stop_tunnel
}

main() {
  if [[ $# -ne 1 ]]; then
    usage
    exit 1
  fi

  case "$1" in
    start)
      require_cmd kubectl
      require_cmd minikube
      start_flow
      ;;
    stop)
      require_cmd kubectl
      require_cmd minikube
      stop_flow
      ;;
    status)
      show_status
      ;;
    -h|--help)
      usage
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
