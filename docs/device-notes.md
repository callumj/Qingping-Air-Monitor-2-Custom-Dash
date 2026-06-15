# Device Notes

## Confirmed On Tested Device

- OS: Buildroot Linux
- Init: BusyBox init
- Display: Qt/EGLFS
- QML runner: `/usr/bin/qmlscene`
- Root filesystem: writable ext4
- User data: `/userdata`
- Vendor UI process: `QingSnow2App`
- Vendor watchdog: `/qingping/bin/watchdog.sh`
- Miio client: `/qingping/bin/miio/miio_client`
- Sensor data publishing: `QingSnow2App`

## Init Flow

BusyBox init runs `/etc/init.d/rcS`, which executes scripts matching
`/etc/init.d/S??*` in lexical order.

On the tested device:

- `/etc/init.d/S50launcher` runs the vendor startup path.
- The vendor startup path initializes hardware, Wi-Fi, watchdog, and Miio.
- A late script such as `/etc/init.d/S99qt-kiosk` can take over the display
  after the stock startup path has done useful setup work.

## Why Not Browser Kiosk?

Browser options were explored, including WPE/Cog and Chromium/Xwayland. The
device can get close, but the overhead and display stack complexity are not a
good fit.

Qt/QML with EGLFS is already present and stable. A local QML dashboard plus a
shell JSON updater is simpler and more reliable.

## Stable Runtime Pattern

The most reliable pattern found:

- `ha-json-updater.sh` fetches remote state and writes local JSON atomically.
- `QingSnow2App -platform offscreen` keeps the sensor data publishing path alive
  without owning the display. Killing Snow entirely stops data publishing,
  including Qingping's own data flow and the MQTT payloads consumed by Home
  Assistant. `miio_client` alone is not enough.
- For local-only/WAN-blocked operation, suppress `miio_client`,
  `miio_client_helper_nomqtt.sh`, and `miio_recv_line` after boot. On the tested
  unit, `miio_client` logged `sta will close in ...` when Xiaomi/Mijia cloud was
  unreachable and eventually tore down Wi-Fi. Snow offscreen continued
  publishing third-party MQTT without `miio_client`.
- For WAN-blocked operation, Snow may still run its own connectivity verifier.
  The tested binary contained hardcoded public ping/DNS targets and issued
  commands shaped like `ping -c 1 TARGET -W 2`. Failed verifier checks can still
  destabilize Wi-Fi even when local MQTT is healthy.
- QML reads local JSON with `XMLHttpRequest` using a `file://` URL.
- QML displays local images using `Image`.
- The supervisor restarts the updater and QML if either exits.

Avoid:

- Direct QML HTTPS calls to Home Assistant.
- Starting `qmlscene` in a shell that exits immediately without `nohup` or a
  supervisor.
- Killing `miio_client` if you still rely on Miio/Xiaomi cloud support.
- Killing every `QingSnow2App` process if you still rely on sensor data being
  published anywhere.

## MQTT Reporting

`miio_client` is not the whole reporting path. On the tested device,
`QingSnow2App` is critical for sensor data publishing. If you kill
`QingSnow2App` entirely, data publishing stops, including Qingping's own data
flow and the third-party MQTT payloads consumed by Home Assistant, even if
`miio_client` is still running.

The useful compromise is to stop the visible stock UI but keep Snow running
headlessly:

```sh
QT_QPA_PLATFORM=offscreen /qingping/bin/QingSnow2App -platform offscreen
```

This allows a custom `qmlscene -platform eglfs` dashboard to own the display
while Snow continues publishing sensor data in the background.

### Local-Only MQTT And Network Verification

On the tested device, `/data/etc/setting.ini` had both a `[third]` MQTT section
and a vendor `[host]` MQTT section. For a LAN-only setup, both were pointed at
the local MQTT broker. With only WAN egress blocked, leaving the vendor host
pointing at the cloud caused repeated failed cloud connection attempts.

Snow also performed Wi-Fi verification by running pings against public targets,
including hardcoded IPs and DNS-derived targets. Allowing ICMP can help, but it
is not necessarily sufficient because the set of targets can vary. The tested
stable experiment used:

- `QingSnow2App -platform offscreen` for sensor publishing.
- Local MQTT broker settings for both `[host]` and `[third]`.
- Suppression of `miio_client`, `miio_client_helper_nomqtt.sh`, and
  `miio_recv_line`.
- A targeted `/bin/ping` wrapper that passes LAN pings through to
  `/bin/ping.real` but reports success for Snow's non-LAN one-shot verifier
  pattern.

The wrapper example is in `examples/ping-wrapper.sh`. Treat it as experimental:
it replaces a system binary, so keep the original as `/bin/ping.real` and verify
that LAN pings still use the real binary.

### MQTT Report Request

For MQTT integrations, Snow subscribes to the down topic configured in
`/data/etc/setting.ini`, usually:

```text
qingping/DEVICE_MAC/down
```

Running Snow offscreen keeps the data publisher available, but the tested device
also needed an external request to start or refresh MQTT reporting after reboot.
It resumed reporting when this payload was published to the down topic:

```json
{"type":"12","up_itvl":"15","duration":"21600"}
```

It then published current sensor data to:

```text
qingping/DEVICE_MAC/up
```

If Home Assistant shows the Qingping integration as unavailable after a device
reboot, confirm MQTT by subscribing to `qingping/#`, then publish the request to
the down topic. If that works, add a Home Assistant automation like
`examples/home-assistant/qingping-mqtt-poll.yaml` to send the request on HA
start and periodically.

## SSH And Dropbear

The tested device runs Dropbear for SSH. Modern OpenSSH clients may need legacy
RSA compatibility flags, depending on the firmware and host key:

```sh
ssh -o PubkeyAcceptedAlgorithms=+ssh-rsa \
  -o HostkeyAlgorithms=+ssh-rsa \
  root@DEVICE_IP
```

For a device that will stay on your network, public-key-only root SSH is a
reasonable hardening step:

```sh
mkdir -p /root/.ssh
chmod 700 /root /root/.ssh
cat >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
cat >/etc/default/dropbear <<'EOF'
DROPBEAR_ARGS="-s -T 3"
EOF
```

Meaning of the tested flags:

- `-s`: disable password logins.
- `-T 3`: allow at most three authentication attempts.
- `-R`: generated by the existing init path to create host keys as needed.

Always verify public-key login before enabling `-s`.

## Useful Debug Commands

```sh
ps -o pid,ppid,stat,comm,args | grep -E "qt-kiosk|qmlscene|ha-json|QingSnow|watchdog|miio" | grep -v grep
tail -50 /tmp/qt-kiosk-init.log
tail -50 /tmp/qt-kiosk-supervisor.log
tail -50 /tmp/ha-json-updater.log
cat /tmp/qt-localdata.out
jq . /userdata/qt-kiosk/state.json
```
