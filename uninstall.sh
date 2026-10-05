#!/usr/bin/env bash
set -euo pipefail
SERVICE="${LLAMA_SERVICE:-llama-main}"
sudo rm -f /usr/local/bin/llama-modelctl /usr/local/bin/llama-hw-select
rm -f "$HOME/.config/systemd/user/$SERVICE.service.d/10-auto-hardware.conf" 2>/dev/null || true
sudo rm -f "/etc/systemd/system/$SERVICE.service.d/10-auto-hardware.conf" 2>/dev/null || true
systemctl --user daemon-reload 2>/dev/null || true
sudo systemctl daemon-reload 2>/dev/null || true
echo "Tools removed. Models, llama.cpp and llama-models.ini were left untouched."
