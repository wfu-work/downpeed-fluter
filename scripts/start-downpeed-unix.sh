#!/usr/bin/env bash
set -euo pipefail

bundle_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
address="${DOWNPEED_ADDRESS:-127.0.0.1:17680}"

case "$(uname -s)" in
  Darwin)
    data_dir="${DOWNPEED_DATA_DIR:-${HOME}/Library/Application Support/Downpeed}"
    app_path="${bundle_dir}/Downpeed.app"
    ;;
  Linux)
    data_dir="${DOWNPEED_DATA_DIR:-${XDG_CONFIG_HOME:-${HOME}/.config}/Downpeed}"
    app_path="${bundle_dir}/downpeed"
    ;;
  *)
    echo "Unsupported operating system." >&2
    exit 1
    ;;
esac

engine_path="${bundle_dir}/downpeedd"
if [[ ! -x "${engine_path}" ]]; then
  echo "Missing executable Go engine: ${engine_path}" >&2
  exit 1
fi
if [[ ! -e "${app_path}" ]]; then
  echo "Missing Flutter client: ${app_path}" >&2
  exit 1
fi

mkdir -p "${data_dir}"
"${engine_path}" --address "${address}" --data-dir "${data_dir}" \
  >>"${data_dir}/engine.log" 2>&1 &
engine_pid=$!

cleanup() {
  kill "${engine_pid}" 2>/dev/null || true
  wait "${engine_pid}" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

sleep 1
if ! kill -0 "${engine_pid}" 2>/dev/null; then
  echo "Downpeed engine failed to start. See ${data_dir}/engine.log" >&2
  exit 1
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
  open -W "${app_path}"
else
  "${app_path}"
fi

