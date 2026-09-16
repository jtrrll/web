#!/usr/bin/env bash
set -euo pipefail

DEPLOYMENTS='@deployments@'
NAME="${1:-}"

if [[ -z $NAME ]]; then
  NAMES=$(echo "$DEPLOYMENTS" | jq -r 'keys[]')
  NAME=$(echo "$NAMES" | gum choose --header="Select a deployment")
  if [[ -z $NAME ]]; then
    exit 0
  fi
fi

if ! echo "$DEPLOYMENTS" | jq -e --arg name "$NAME" '.[$name]' >/dev/null 2>&1; then
  AVAILABLE=$(echo "$DEPLOYMENTS" | jq -r 'keys | join(", ")')
  echo "unknown deployment '$NAME', available: $AVAILABLE" >&2
  exit 1
fi

TARGETS=$(echo "$DEPLOYMENTS" | jq -c --arg name "$NAME" '.[$name][]')

while IFS= read -r target; do
  HOSTNAME=$(echo "$target" | jq -r '.hostname')
  HOST=$(echo "$target" | jq -r '.host')
  SSH_PORT=$(echo "$target" | jq -r '.ssh_port')

  echo "Adding $HOST:$SSH_PORT to known hosts..."
  ssh-keyscan -p "$SSH_PORT" "$HOST" >>~/.ssh/known_hosts 2>/dev/null

  STYLED_NAME=$(gum style --bold --foreground=212 "$NAME")
  echo "Deploying $STYLED_NAME/$HOSTNAME to $HOST:$SSH_PORT..."
  NIX_SSHOPTS="-p $SSH_PORT" nixos-rebuild switch \
    --flake ".#$HOSTNAME" \
    --target-host "admin@$HOST" \
    --use-remote-sudo
  echo "Deployed $STYLED_NAME/$HOSTNAME successfully!"
done <<<"$TARGETS"
