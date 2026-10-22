# mac2jb

**send the bundled ns2jb bootstrap to a nintendo switch 2 using a mac as a usb keyboard.**

mac2jb combines a usb hid text sender with pinned copies of `libusbd`, `macos_usb_gadget_poc`, and `ns2jb`. all upstream project source files are included in this repository; no separate source checkouts, submodules, or bootstrap downloads are required. build tools and runtime software are not included.

> **experimental / unverified:** the usb gadget driver was created for a 2021 apple silicon macbook pro on macos 12. there is **no confirmed support yet for the m4 macbook pro or current macos**, and this package has not been verified to type into a physical switch 2. building the sender does not prove the usb connection will work. changing macos security settings for a kernel extension is risky; do not do so on a machine you rely on without understanding the consequences.

## compatibility

| component | requirement or status |
| --- | --- |
| mac hardware | apple silicon (`arm64`); usb device-mode support is unverified on newer models |
| mac used for testing | macbook pro · model identifier `Mac16,1` · model number `MW2U3LL/A` · apple m4 (10 cores: 4 performance + 6 efficiency) · 16 gb ram |
| test mac firmware | system firmware `18000.101.7` · os loader `18000.101.7` |
| test mac results | **testing configuration only; functional usb compatibility not yet confirmed** |
| macos | original driver targets macos 12; newer releases not validated; macos version of test mac not provided |
| developer tools | xcode command line tools, and full xcode to build the driver (not bundled) |
| host runtime | node.js 22 or newer (not bundled) |
| switch 2 | system software `23.0.1` and smilebasic `4.4.9`, as specified by pinned ns2jb |
| storage and network | over 20 mib free in smilebasic; mac and switch 2 on the same reachable local network |
| usb | data-capable cable and a supported usb controller/port and console keyboard input route; unverified |

## step-by-step setup

### 1. get mac2jb

download the repository from [github.com/cpypwn/mac2jb](https://github.com/cpypwn/mac2jb) using **code → download zip**, extract it, and open **terminal** in the extracted project folder. no other source repository downloads are needed.

### 2. check prerequisites

install apple's command line developer tools if needed:

```sh
xcode-select --install
```

install full xcode for the usb driver build and node.js 22+ for the network host if they are not already installed. then check your system and bundled sources:

```sh
uname -m
sw_vers -productVersion
csrutil status
bash scripts/check.sh
```

`arm64` is expected. `check.sh` checks the local vendor tree, the bundled file checksum, developer tools, and node.js; it does not download anything.

### 3. build the usb sender

```sh
make
```

this builds `vendor/libusbd/libusbd.dylib` and `mac2jb-send` using the included source. no source dependencies are downloaded. if it fails, review the compiler errors before moving on.

### 4. check usb device-mode driver support

mac2jb needs a working macos usb *device* driver, not ordinary usb-host access. the bundled upstream proof of concept includes an xcode project:

```sh
open vendor/macos_usb_gadget_poc/usbgadget/usbgadget.xcodeproj
```

read [`vendor/macos_usb_gadget_poc/README.md`](vendor/macos_usb_gadget_poc/README.md) and apple's [kernel extension approval information](https://support.apple.com/guide/security/kernel-extensions-sec8e454101b/web) before attempting to build or approve its `usbgadget.kext`. the original approach involves reduced system security and sip changes. **this guide does not recommend changing those protections on a daily-use mac.** modern m4 hardware support is unverified, and there is no known universal install command for it.

once an approved extension is installed, you can inspect whether it loaded:

```sh
kmutil showloaded | grep -i usbgadget
```

if no suitable driver loads, **stop here**: sending text over the cable will not work merely because `make` succeeds. a dedicated usb hid-capable microcontroller is a safer alternative.

### 5. validate the bundled bootstrap

```sh
bash scripts/send.sh --dry-run
```

this checks whether `assets/bootstrap.bas` can be represented using the sender's supported us keyboard reports. it **does not** communicate with the switch 2.

### 6. type bootstrap.bas into smilebasic

1. on the switch 2, open **smilebasic → make a program → slot 0**, with an empty editor.
2. connect a data-capable usb cable using a port that has been confirmed to support usb device mode on your mac and keyboard input on the console. this combination has not been tested for the m4 model.
3. in terminal on the mac, run:

   ```sh
   bash scripts/send.sh --delay-ms 100
   ```

4. focus the smilebasic editor. when the sender prompts, enter `SEND` in the **mac terminal** to start transmitting. the prompt word must be uppercase because the program checks it exactly.
5. check the entered program for errors or missing characters. if necessary, clear the editor and retry using `--delay-ms 200`.
6. save the program as `NS2` in slot 0. the filename and program commands below are case-sensitive where required by the upstream workflow.

**do not run the sender without the expected input field focused.** press control+c in terminal to interrupt.

### 7. start the ns2jb host

this stage uses the local network rather than usb. restart the switch 2, reopen smilebasic, and switch to **direct mode**. keep both devices on the same reachable lan.

on the mac, run:

```sh
bash scripts/host.sh
```

if prompted, choose the mac's lan ip address accessible from the switch. alternatively, specify it explicitly:

```sh
bash scripts/host.sh 192.168.1.10
```

replace the example address with your mac's real ip. the upstream host uses tcp port `39380`.

### 8. complete the ns2jb sequence in smilebasic

enter these commands **one at a time** in direct mode:

```basic
LOAD "TXT:NS2"
RUN
REMOVE NSR,&H60000000,&H3FFFFFFF
```

confirm the load when prompted. according to the pinned ns2jb instructions, the `Out of memory` message after `REMOVE` is expected. **run `REMOVE` only once per smilebasic application process.**

now enter the exact **`V=START(...)`** command printed in your own mac terminal. it includes session-specific connection details, so do not copy one from someone else's setup.

keep smilebasic open and the mac awake until the host reports `FS execution verified` and completes its cleanup. logs are written under `vendor/ns2jb/runs/`. restart the console after finishing. the upstream demo is timing-sensitive, may require a fresh attempt, and does **not** install persistent custom firmware.

see the bundled [`vendor/ns2jb/README.md`](vendor/ns2jb/README.md) for the full upstream description and limitations. manipulating privileged processes can crash the application or console; proceed only if you understand the risks.

## troubleshooting

| problem | what to check |
| --- | --- |
| file or checksum missing | use the complete release; confirm `vendor/` and `assets/bootstrap.bas` exist |
| compiler or sdk error | verify xcode command line tools and matching architecture |
| `libusbd_init` failure | check whether the experimental driver actually supports your hardware and macos version |
| no usb keyboard enumeration | check gadget driver, port selection, cable, and switch 2 keyboard support |
| wrong symbols or incomplete lines | confirm us keyboard layout and editor focus; retry with a longer delay |
| missing `node` or old version | install node.js 22 or newer |
| host can't connect | check both devices' lan ip addresses, firewalls, and port 39380 |
| ns2jb fails | confirm the exact supported firmware/software, retain `runs/` logs, and retry after a fresh console restart |

## source layout

```text
assets/bootstrap.bas                frozen smilebasic program
sender.c                            usb keyboard text sender
scripts/check.sh                    offline prerequisites and checksum check
scripts/send.sh                     local text transmission helper
scripts/host.sh                     bundled ns2jb network host launcher
vendor/libusbd/                     pinned usb library source
vendor/macos_usb_gadget_poc/        pinned experimental driver source
vendor/ns2jb/                       pinned ns2jb source and host
upstream.lock                       frozen upstream commit identifiers
make-release-zip.command            local packaging utility
```

source revisions are pinned in [`upstream.lock`](upstream.lock). normal builds do not pull code from upstream. the original third-party source trees retain their upstream filenames, because changing case-sensitive identifiers or build paths could break them.

## credits and licensing

- [shinyquagsire23](https://github.com/shinyquagsire23) — [`libusbd`](https://github.com/shinyquagsire23/libusbd) and [`macos_usb_gadget_poc`](https://github.com/shinyquagsire23/macos_usb_gadget_poc).
- [pepsipu / sammy hajhamid](https://gitlab.com/pepsipu/ns2jb) — original `ns2jb` project, `bootstrap.bas`, and network host/engine.
- [cpypwn](https://github.com/cpypwn) — mac2jb project integration.

integration source is covered by [`LICENSE`](LICENSE). vendored third-party sources keep their original rights and licenses; the integration license does not override those rights. verify redistribution permissions before publishing third-party sources. this is an independent project, not affiliated with nintendo or smilebasic.
