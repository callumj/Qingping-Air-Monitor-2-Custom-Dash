#!/bin/sh
set -eu

CONFIG=${CONFIG:-/userdata/qt-kiosk/ha-config.json}
OUT=${OUT:-/userdata/qt-kiosk/state.json}
TMP="${OUT}.tmp"
LOG=${LOG:-/tmp/ha-json-updater.log}
INTERVAL=${INTERVAL:-10}
SNAPSHOT_IMAGE=${SNAPSHOT_IMAGE:-/userdata/qt-kiosk/garden-latest.jpg}
SNAPSHOT_TMP="${SNAPSHOT_IMAGE}.tmp"

json_string() {
  printf '%s' "$1" | jq -Rs .
}

valid_state() {
  case "$1" in
    ""|"unknown"|"unavailable"|"null") return 1 ;;
    *) return 0 ;;
  esac
}

state_from_all() {
  entity="$1"
  printf '%s' "$states_json" | jq -r --arg entity "$entity" '.[] | select(.entity_id == $entity) | .state' 2>/dev/null | head -1
}

config_entity() {
  key="$1"
  jq -r --arg key "$key" '.entities[$key] // empty' "$CONFIG"
}

number_or_previous() {
  value="$1"
  key="$2"
  fallback="$3"
  if valid_state "$value"; then
    printf '%s' "$value" | awk '{ printf "%.0f", $1 }'
  else
    jq -r --arg key "$key" --arg fallback "$fallback" '.[$key] // $fallback' "$OUT" 2>/dev/null || printf '%s' "$fallback"
  fi
}

text_or_previous() {
  value="$1"
  key="$2"
  fallback="$3"
  if valid_state "$value"; then
    printf '%s' "$value"
  else
    jq -r --arg key "$key" --arg fallback "$fallback" '.[$key] // $fallback' "$OUT" 2>/dev/null || printf '%s' "$fallback"
  fi
}

local_time_label() {
  iso="$1"
  cleaned=$(printf '%s' "$iso" | cut -d . -f 1 | sed 's/T/ /')
  if [ -n "$cleaned" ]; then
    epoch=$(date -u -d "$cleaned" +%s 2>/dev/null || true)
    if [ -n "$epoch" ]; then
      date -d "@$epoch" '+%b %d %I:%M %p'
      return 0
    fi
  fi
  printf '%s' "$iso"
}

ha_get_states() {
  curl -sS -m 8 \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    "$BASE/api/states"
}

ha_get_forecast() {
  weather_entity="$1"
  [ -z "$weather_entity" ] && return 0
  curl -sS -m 12 -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    "$BASE/api/services/weather/get_forecasts?return_response" \
    -d "{\"entity_id\":\"$weather_entity\",\"type\":\"hourly\"}"
}

forecast_value() {
  weather_entity="$1"
  datetime="$2"
  field="$3"
  printf '%s' "$forecast_json" | jq -r --arg entity "$weather_entity" --arg datetime "$datetime" --arg field "$field" '.service_response[$entity].forecast[] | select(.datetime == $datetime) | .[$field]' 2>/dev/null | head -1
}

next_slot() {
  label="$1"
  local_time="$2"
  now_epoch=$(date +%s)
  slot_epoch=$(date -d "today $local_time" +%s)
  if [ "$slot_epoch" -le "$now_epoch" ]; then
    slot_epoch=$(date -d "tomorrow $local_time" +%s)
  fi
  slot_utc=$(date -u -d "@$slot_epoch" '+%Y-%m-%dT%H:00:00+00:00')
  printf '%s|%s|%s\n' "$slot_epoch" "$label" "$slot_utc"
}

fetch_snapshot() {
  enabled=$(jq -r '.garden.enabled // false' "$CONFIG")
  [ "$enabled" = "true" ] || return 1

  api=$(jq -r '.garden.api // empty' "$CONFIG")
  base=$(jq -r '.garden.baseUrl // empty' "$CONFIG")
  [ -n "$api" ] && [ -n "$base" ] || return 1

  snapshot_json=$(curl -sS -m 12 "$api" || true)
  image_path=$(printf '%s' "$snapshot_json" | jq -r 'max_by(.capturedAt) | .imagePath // empty' 2>/dev/null || true)
  captured_at=$(printf '%s' "$snapshot_json" | jq -r 'max_by(.capturedAt) | .capturedAt // empty' 2>/dev/null || true)

  if valid_state "$image_path" && curl -sS -L -m 20 -o "$SNAPSHOT_TMP" "$base$image_path"; then
    if [ -s "$SNAPSHOT_TMP" ]; then
      mv "$SNAPSHOT_TMP" "$SNAPSHOT_IMAGE"
      chmod 644 "$SNAPSHOT_IMAGE" 2>/dev/null || true
      printf '%s\n' "$captured_at" > /tmp/qt-kiosk-snapshot-captured.txt
      return 0
    fi
  fi

  rm -f "$SNAPSHOT_TMP"
  return 1
}

BASE=$(jq -r '.baseUrl' "$CONFIG")
TOKEN=$(jq -r '.token' "$CONFIG")

if [ -z "$BASE" ] || [ -z "$TOKEN" ] || [ "$BASE" = "null" ] || [ "$TOKEN" = "null" ]; then
  echo "Missing Home Assistant baseUrl or token in $CONFIG" >> "$LOG"
  exit 1
fi

room_temp_entity=$(config_entity roomTemp)
humidity_entity=$(config_entity humidity)
co2_entity=$(config_entity co2)
outdoor_temp_entity=$(config_entity outdoorTemp)
outdoor_humidity_entity=$(config_entity outdoorHumidity)
water_temp_entity=$(config_entity waterTemp)
weather_entity=$(config_entity weather)
light_entity=$(config_entity light)

echo "starting updater at $(date)" >> "$LOG"
loop_count=0

while :; do
  loop_count=$((loop_count + 1))

  states_json=$(ha_get_states || true)
  forecast_json=$(ha_get_forecast "$weather_entity" || true)

  room_temp=$(number_or_previous "$(state_from_all "$room_temp_entity" || true)" roomTemp "--")
  humidity=$(number_or_previous "$(state_from_all "$humidity_entity" || true)" humidity "--")
  co2=$(number_or_previous "$(state_from_all "$co2_entity" || true)" co2 "--")
  outdoor_temp=$(number_or_previous "$(state_from_all "$outdoor_temp_entity" || true)" outdoorTemp "--")
  outdoor_humidity=$(number_or_previous "$(state_from_all "$outdoor_humidity_entity" || true)" outdoorHumidity "--")
  water_temp=$(number_or_previous "$(state_from_all "$water_temp_entity" || true)" waterTemp "--")
  weather=$(text_or_previous "$(state_from_all "$weather_entity" || true)" weather "unknown")
  light=$(text_or_previous "$(state_from_all "$light_entity" || true)" lightState "unknown")

  slots=$(printf '%s\n%s\n%s\n' \
    "$(next_slot Morning 08:00)" \
    "$(next_slot Midday 12:00)" \
    "$(next_slot Evening 18:00)" | sort -n | head -3)

  slot1=$(printf '%s\n' "$slots" | sed -n '1p')
  slot2=$(printf '%s\n' "$slots" | sed -n '2p')
  slot3=$(printf '%s\n' "$slots" | sed -n '3p')

  forecast1_label=$(printf '%s' "$slot1" | cut -d '|' -f 2)
  forecast2_label=$(printf '%s' "$slot2" | cut -d '|' -f 2)
  forecast3_label=$(printf '%s' "$slot3" | cut -d '|' -f 2)
  forecast1_dt=$(printf '%s' "$slot1" | cut -d '|' -f 3)
  forecast2_dt=$(printf '%s' "$slot2" | cut -d '|' -f 3)
  forecast3_dt=$(printf '%s' "$slot3" | cut -d '|' -f 3)

  forecast1_temp=$(number_or_previous "$(forecast_value "$weather_entity" "$forecast1_dt" temperature || true)" forecast1Temp "--")
  forecast2_temp=$(number_or_previous "$(forecast_value "$weather_entity" "$forecast2_dt" temperature || true)" forecast2Temp "--")
  forecast3_temp=$(number_or_previous "$(forecast_value "$weather_entity" "$forecast3_dt" temperature || true)" forecast3Temp "--")
  forecast1_condition=$(text_or_previous "$(forecast_value "$weather_entity" "$forecast1_dt" condition || true)" forecast1Condition "$weather")
  forecast2_condition=$(text_or_previous "$(forecast_value "$weather_entity" "$forecast2_dt" condition || true)" forecast2Condition "$weather")
  forecast3_condition=$(text_or_previous "$(forecast_value "$weather_entity" "$forecast3_dt" condition || true)" forecast3Condition "$weather")

  if [ ! -s "$SNAPSHOT_IMAGE" ] || [ $((loop_count % 6)) -eq 1 ]; then
    fetch_snapshot || true
  fi
  snapshot_captured=$(cat /tmp/qt-kiosk-snapshot-captured.txt 2>/dev/null || true)
  snapshot_captured_local=$(local_time_label "$snapshot_captured")
  snapshot_available=false
  [ -s "$SNAPSHOT_IMAGE" ] && snapshot_available=true

  cat > "$TMP" <<EOF_JSON
{
  "roomTemp": $(json_string "$room_temp"),
  "humidity": $(json_string "$humidity"),
  "co2": $(json_string "$co2"),
  "outdoorTemp": $(json_string "$outdoor_temp"),
  "outdoorHumidity": $(json_string "$outdoor_humidity"),
  "waterTemp": $(json_string "$water_temp"),
  "weather": $(json_string "$weather"),
  "lightState": $(json_string "$light"),
  "forecast1Label": $(json_string "$forecast1_label"),
  "forecast1Temp": $(json_string "$forecast1_temp"),
  "forecast1Condition": $(json_string "$forecast1_condition"),
  "forecast2Label": $(json_string "$forecast2_label"),
  "forecast2Temp": $(json_string "$forecast2_temp"),
  "forecast2Condition": $(json_string "$forecast2_condition"),
  "forecast3Label": $(json_string "$forecast3_label"),
  "forecast3Temp": $(json_string "$forecast3_temp"),
  "forecast3Condition": $(json_string "$forecast3_condition"),
  "snapshotAvailable": $snapshot_available,
  "snapshotCapturedAt": $(json_string "$snapshot_captured"),
  "snapshotCapturedLocal": $(json_string "$snapshot_captured_local"),
  "updatedAt": $(json_string "$(date '+%Y-%m-%d %H:%M:%S')")
}
EOF_JSON

  mv "$TMP" "$OUT"
  sleep "$INTERVAL"
done

