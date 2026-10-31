#!/bin/sh
# "ssh" (default) runs the SSH server; "webhook" runs the webhook test server.
set -e
case "${1:-ssh}" in
  ssh)
    ssh-keygen -A
    exec /usr/sbin/sshd -D -e ;;
  webhook)
    exec pwsh -NoProfile -File /opt/course/webhook.ps1 -LogPath /srv/webhook/received.jsonl ;;
  *)
    exec "$@" ;;
esac
