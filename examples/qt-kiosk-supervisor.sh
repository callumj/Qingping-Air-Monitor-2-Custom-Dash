#!/bin/sh

DIR=/userdata/qt-kiosk
QML="$DIR/Dashboard.qml"
UPDATER="$DIR/ha-json-updater.sh"
SNOW_APP=/qingping/bin/QingSnow2App
PIDFILE=/tmp/qt-kiosk-supervisor.pid
QML_PIDFILE=/tmp/qt-kiosk-qml.pid
UPDATER_PIDFILE=/tmp/qt-kiosk-updater.pid
SNOW_PIDFILE=/tmp/qingsnow-offscreen.pid
LOG=/tmp/qt-kiosk-supervisor.log

PATH=/bin:/sbin:/usr/bin:/usr/sbin

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"
}

matching_pids() {
  pattern="$1"
  ps -o pid,args | grep "$pattern" | grep -v grep | awk '{print $1}'
}

is_running() {
  pattern="$1"
  matching_pids "$pattern" | grep -q .
}

kill_pidfile() {
  file="$1"
  if [ -f "$file" ]; then
    pid=$(cat "$file" 2>/dev/null || true)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi
    rm -f "$file"
  fi
}

kill_matching() {
  pattern="$1"
  for pid in $(matching_pids "$pattern"); do
    [ "$pid" = "$$" ] && continue
    kill "$pid" 2>/dev/null || true
  done
}

kill_stock_snow_ui() {
  ps -o pid,args | grep QingSnow2App | grep -v grep | while read pid args; do
    [ "$pid" = "$$" ] && continue
    echo "$args" | grep -q -- "-platform offscreen" && continue
    kill "$pid" 2>/dev/null || true
  done
}

wait_no_matching() {
  pattern="$1"
  count=0
  while :; do
    found=0
    for pid in $(matching_pids "$pattern"); do
      [ "$pid" = "$$" ] && continue
      found=1
    done
    [ "$found" -eq 0 ] && return 0
    count=$((count + 1))
    [ "$count" -gt 10 ] && return 1
    sleep 1
  done
}

stop_stock_ui() {
  killall watchdog.sh 2>/dev/null || true
  kill_stock_snow_ui
  killall QLauncher 2>/dev/null || true
  killall weston 2>/dev/null || true
}

suppress_miio_cloud() {
  # miio_client enforces Xiaomi cloud connectivity and can tear down Wi-Fi when
  # WAN is blocked. Snow can still publish local third-party MQTT without it.
  for pattern in "miio_client " "miio_client_helper_nomqtt.sh" "miio_recv_line"; do
    if is_running "$pattern"; then
      log "suppressing $pattern"
      kill_matching "$pattern"
    fi
  done
}

start_snow_offscreen() {
  if ! is_running "QingSnow2App.*offscreen"; then
    log "starting QingSnow2App offscreen for MQTT/sensor reporting"
    cd /qingping/bin || return 1
    QT_QPA_PLATFORM=offscreen \
    nohup "$SNOW_APP" -platform offscreen >> /tmp/qingsnow-offscreen.out 2>&1 </dev/null &
    echo $! > "$SNOW_PIDFILE"
  fi
}

start_updater() {
  if ! is_running "$UPDATER"; then
    log "starting updater"
    nohup /bin/sh "$UPDATER" >> /tmp/qt-kiosk-updater.out 2>&1 </dev/null &
    echo $! > "$UPDATER_PIDFILE"
  fi
}

start_qml() {
  if ! is_running "qmlscene.*$QML"; then
    log "starting qmlscene"
    mkdir -p /tmp/qt-runtime
    chmod 700 /tmp/qt-runtime
    XDG_RUNTIME_DIR=/tmp/qt-runtime \
    QT_QPA_PLATFORM=eglfs \
    QT_QPA_EGLFS_WIDTH=720 \
    QT_QPA_EGLFS_HEIGHT=720 \
    nohup qmlscene -platform eglfs "$QML" >> /tmp/qt-kiosk-qml.out 2>&1 </dev/null &
    echo $! > "$QML_PIDFILE"
  fi
}

start_supervisor() {
  if [ -f "$PIDFILE" ]; then
    old_pid=$(cat "$PIDFILE" 2>/dev/null || true)
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
      echo "qt kiosk supervisor already running as $old_pid"
      exit 0
    fi
  fi

  for old_pid in $(matching_pids "$DIR/qt-kiosk-supervisor.sh start"); do
    [ "$old_pid" = "$$" ] && continue
    if kill -0 "$old_pid" 2>/dev/null; then
      log "replacing stale supervisor $old_pid"
      kill "$old_pid" 2>/dev/null || true
    fi
  done
  wait_no_matching "$DIR/qt-kiosk-supervisor.sh start" || true

  echo $$ > "$PIDFILE"
  trap 'rm -f "$PIDFILE"; exit 0' INT TERM EXIT
  log "supervisor started"

  while :; do
    stop_stock_ui
    start_snow_offscreen
    suppress_miio_cloud
    start_updater
    start_qml
    sleep 5
  done
}

stop_supervisor() {
  kill_pidfile "$PIDFILE"
  kill_matching "$DIR/qt-kiosk-supervisor.sh start"
  wait_no_matching "$DIR/qt-kiosk-supervisor.sh start" || true
  kill_pidfile "$QML_PIDFILE"
  kill_pidfile "$UPDATER_PIDFILE"
  kill_pidfile "$SNOW_PIDFILE"
  kill_matching "qmlscene.*$QML"
  kill_matching "$UPDATER"
  kill_matching "QingSnow2App.*offscreen"
  log "supervisor stopped"
}

case "${1:-run}" in
  start|run)
    start_supervisor
    ;;
  stop)
    stop_supervisor
    ;;
  restart)
    stop_supervisor
    sleep 1
    start_supervisor
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|run}"
    exit 2
    ;;
esac
