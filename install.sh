#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
SERVICE="${LLAMA_SERVICE:-llama-main}"
if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  TARGET_USER="$SUDO_USER"
  HOME_DIR="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
  TARGET_USER="$(id -un)"
  HOME_DIR="$HOME"
fi
INI="${LLAMA_MODELS_INI:-$HOME_DIR/llama-models.ini}"
SERVER="${LLAMA_SERVER:-$HOME_DIR/llama.cpp/build-all/bin/llama-server}"

[ -f "$INI" ] || { echo "Missing $INI"; exit 1; }
[ -x "$SERVER" ] || { echo "Missing executable $SERVER"; exit 1; }

sudo install -m 0755 "$ROOT/bin/llama-modelctl" /usr/local/bin/llama-modelctl
sudo install -m 0755 "$ROOT/bin/llama-hw-select" /usr/local/bin/llama-hw-select
sudo mkdir -p /models-local
sudo chown "$TARGET_USER:$TARGET_USER" /models-local
mkdir -p "$HOME_DIR/.config/llama-modelctl"

if systemctl --user cat "$SERVICE.service" >/dev/null 2>&1; then
  mkdir -p "$HOME_DIR/.config/systemd/user/$SERVICE.service.d"
  cat > "$HOME_DIR/.config/systemd/user/$SERVICE.service.d/10-auto-hardware.conf" <<EOF
[Service]
Environment=LLAMA_HOME=$HOME_DIR
Environment=LLAMA_MODELS_INI=$INI
Environment=LLAMA_SERVER=$SERVER
Environment=LLAMA_MODELCTL_STATE=$HOME_DIR/.config/llama-modelctl/state.json
ExecStartPre=/usr/local/bin/llama-hw-select
EOF
  systemctl --user daemon-reload
  /usr/local/bin/llama-hw-select
  systemctl --user restart "$SERVICE"
  echo "Installed for user service: $SERVICE"
elif systemctl cat "$SERVICE.service" >/dev/null 2>&1; then
  sudo mkdir -p "/etc/systemd/system/$SERVICE.service.d"
  sudo tee "/etc/systemd/system/$SERVICE.service.d/10-auto-hardware.conf" >/dev/null <<EOF
[Service]
Environment=LLAMA_HOME=$HOME_DIR
Environment=LLAMA_MODELS_INI=$INI
Environment=LLAMA_SERVER=$SERVER
Environment=LLAMA_MODELCTL_STATE=$HOME_DIR/.config/llama-modelctl/state.json
ExecStartPre=/usr/local/bin/llama-hw-select
EOF
  sudo systemctl daemon-reload
  /usr/local/bin/llama-hw-select
  sudo systemctl restart "$SERVICE"
  echo "Installed for system service: $SERVICE"
else
  echo "WARNING: $SERVICE.service not found. Tools installed, but systemd hook not installed."
fi

echo
echo "Done. Try:"
echo "  llama-modelctl devices"
echo "  llama-modelctl list"
echo "  llama-modelctl --help"
