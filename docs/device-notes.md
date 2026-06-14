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
- Background reporting: `/qingping/bin/miio/miio_client`

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
- QML reads local JSON with `XMLHttpRequest` using a `file://` URL.
- QML displays local images using `Image`.
- The supervisor restarts the updater and QML if either exits.

Avoid:

- Direct QML HTTPS calls to Home Assistant.
- Starting `qmlscene` in a shell that exits immediately without `nohup` or a
  supervisor.
- Killing `miio_client` if you still rely on the device's sensor reporting.

## Useful Debug Commands

```sh
ps -o pid,ppid,stat,comm,args | grep -E "qt-kiosk|qmlscene|ha-json|QingSnow|watchdog|miio" | grep -v grep
tail -50 /tmp/qt-kiosk-init.log
tail -50 /tmp/qt-kiosk-supervisor.log
tail -50 /tmp/ha-json-updater.log
cat /tmp/qt-localdata.out
jq . /userdata/qt-kiosk/state.json
```

