#!/usr/bin/env bash
set -euo pipefail

if ((EUID != 0)); then
  exec sudo -- bash "$0" "$@"
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

for script in backup.sh backup2.sh backup3.sh; do
  echo "===== $script を実行します ====="
  bash "$SCRIPT_DIR/$script" "$@"
done
