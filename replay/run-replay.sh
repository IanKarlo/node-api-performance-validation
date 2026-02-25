#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPLAY_DIR="$ROOT_DIR/replay"
COMPOSE_FILE="$REPLAY_DIR/docker-compose.yml"

ACTION="${1:-up}"
EXPORT_PATH_INPUT="${2:-}"

resolve_export_path() {
  if [[ -n "$EXPORT_PATH_INPUT" ]]; then
    echo "$EXPORT_PATH_INPUT"
    return 0
  fi

  local latest
  latest="$(ls -1d "$ROOT_DIR"/exports/prometheus/* 2>/dev/null | sort | tail -n 1 || true)"
  if [[ -z "$latest" ]]; then
    echo "No export found under $ROOT_DIR/exports/prometheus" >&2
    echo "Run with an explicit path: ./replay/run-replay.sh up /absolute/path/to/tsdb-data" >&2
    return 1
  fi

  echo "$latest/tsdb-data"
}

run_compose() {
  local export_dir="$1"
  PROM_EXPORT_DIR="$export_dir" docker compose -f "$COMPOSE_FILE" "$2"
}

case "$ACTION" in
  up)
    export_dir="$(resolve_export_path)"
    if [[ ! -d "$export_dir" ]]; then
      echo "Export directory not found: $export_dir" >&2
      exit 1
    fi

    echo "Using export: $export_dir"
    PROM_EXPORT_DIR="$export_dir" docker compose -f "$COMPOSE_FILE" up -d
    echo "Prometheus replay: http://localhost:9092"
    echo "Grafana replay: http://localhost:3002 (admin/admin)"
    ;;

  down)
    PROM_EXPORT_DIR="${PROM_EXPORT_DIR:-/tmp/placeholder}" docker compose -f "$COMPOSE_FILE" down
    ;;

  restart)
    export_dir="$(resolve_export_path)"
    if [[ ! -d "$export_dir" ]]; then
      echo "Export directory not found: $export_dir" >&2
      exit 1
    fi

    PROM_EXPORT_DIR="$export_dir" docker compose -f "$COMPOSE_FILE" down
    PROM_EXPORT_DIR="$export_dir" docker compose -f "$COMPOSE_FILE" up -d
    echo "Using export: $export_dir"
    echo "Prometheus replay: http://localhost:9092"
    echo "Grafana replay: http://localhost:3002 (admin/admin)"
    ;;

  status)
    PROM_EXPORT_DIR="${PROM_EXPORT_DIR:-/tmp/placeholder}" docker compose -f "$COMPOSE_FILE" ps
    ;;

  logs)
    PROM_EXPORT_DIR="${PROM_EXPORT_DIR:-/tmp/placeholder}" docker compose -f "$COMPOSE_FILE" logs -f
    ;;

  *)
    echo "Usage: ./replay/run-replay.sh [up|down|restart|status|logs] [path-to-tsdb-data]"
    echo "Examples:"
    echo "  ./replay/run-replay.sh up"
    echo "  ./replay/run-replay.sh up $ROOT_DIR/exports/prometheus/<timestamp>/tsdb-data"
    exit 1
    ;;
esac