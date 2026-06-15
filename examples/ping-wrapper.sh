#!/bin/sh
#
# Optional local-only helper for Qingping Air Monitor 2 devices.
#
# QingSnow2App may run one-shot public ping checks as part of its Wi-Fi
# verification path. On a WAN-blocked device, failed checks can make the stock
# app decide Wi-Fi is unhealthy even though LAN, SSH, and local MQTT are fine.
#
# Install only after saving the original ping binary, for example:
#
#   cp -p /bin/ping /bin/ping.real
#   cp ping-wrapper.sh /bin/ping
#   chmod 755 /bin/ping
#
# LAN/private targets still use the original ping. Non-LAN checks that look
# like Snow's verifier pattern are answered locally with success.

REAL_PING=/bin/ping.real
ORIGINAL_ARGS="$*"

if [ ! -x "$REAL_PING" ]; then
  echo "ping-wrapper: missing $REAL_PING" >&2
  exit 127
fi

target=""
count=""
wait=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    -c)
      shift
      count="$1"
      ;;
    -W)
      shift
      wait="$1"
      ;;
    -*)
      ;;
    *)
      target="$1"
      ;;
  esac
  shift
done

case "$target" in
  127.*|10.*|192.168.*|localhost)
    # shellcheck disable=SC2086
    exec "$REAL_PING" $ORIGINAL_ARGS
    ;;
  172.16.*|172.17.*|172.18.*|172.19.*|172.20.*|172.21.*|172.22.*|172.23.*|172.24.*|172.25.*|172.26.*|172.27.*|172.28.*|172.29.*|172.30.*|172.31.*)
    # shellcheck disable=SC2086
    exec "$REAL_PING" $ORIGINAL_ARGS
    ;;
esac

if [ "$count" = "1" ] && [ "$wait" = "2" ] && [ -n "$target" ]; then
  echo "PING $target ($target): 56 data bytes"
  echo "64 bytes from $target: seq=0 ttl=64 time=1.0 ms"
  echo
  echo "--- $target ping statistics ---"
  echo "1 packets transmitted, 1 packets received, 0% packet loss"
  echo "round-trip min/avg/max = 1.0/1.0/1.0 ms"
  exit 0
fi

# shellcheck disable=SC2086
exec "$REAL_PING" $ORIGINAL_ARGS
