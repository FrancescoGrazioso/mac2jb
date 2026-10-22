# mac2jb

**USB keyboard-based bootstrap entry for Switch 2, with a bundled ns2jb host.**

A macOS USB HID keyboard sender for entering `bootstrap.bas` into **SmileBASIC on Nintendo Switch 2**, plus a wrapper for the local-network `ns2jb` host. The project aims for **committed, frozen upstream source**: no Git submodules, no `git pull` during a user build, no downloading `bootstrap.bas` at runtime.

> **Release status:** Frozen source bundle. The supplied ZIP includes the three vendor source trees, the bootstrap asset, and local integration scripts. This has **not** been built or tested on a compatible Mac/Switch 2, and the experimental USB device-mode driver may not work on modern macOS. External Apple development tools and Node.js are still required.

## Files

```text
sender.c                      USB keyboard HID source
Makefile                      offline build against local vendor/libusbd
scripts/check.sh              local preflight (never downloads anything)
scripts/send.sh               types bundled assets/bootstrap.bas
scripts/host.sh               runs the bundled ns2jb host
scripts/freeze-upstream.sh    MAINTAINER ONLY: one-time Git snapshots
vendor/                       upstream snapshots when filled and committed
assets/                       frozen bootstrap when filled and committed
UPSTREAM.lock                 upstream commit hashes when snapshots exist
```

## Get started (no upstream downloads)

Extract this archive and upload its contents to [github.com/cpypwn/mac2jb](https://github.com/cpypwn/mac2jb) (create that repository first if it does not exist). **Upload the contents of the `mac2jb` folder, not the enclosing folder.** All three vendored source trees and `assets/bootstrap.bas` are already included; you do not have to run a dependency snapshot command.

To make another release ZIP on macOS, double-click `MAKE-RELEASE-ZIP.command`. This script packages local files only; it never downloads or updates dependencies.

**Copyright note:** Review permission to redistribute the third-party code before making the repository public. Upstream licenses are not automatically granted by this project's MIT license.

## Advanced maintainers: update vendored dependencies intentionally

1. Review the upstream licenses and redistribution permissions **before publishing**. `libusbd` uses MIT, but do **not** assume `ns2jb` or `macos_usb_gadget_poc` may be redistributed without consent. Their copyright notices must be preserved.
2. On a machine with Git and internet, run:

   ```bash
   chmod +x scripts/*.sh
   ./scripts/freeze-upstream.sh --I-am-the-maintainer
   ```

3. Inspect `UPSTREAM.lock`, the bundled `bootstrap.bas`, and the entire vendor tree. The tool makes regular **source snapshots**, removes nested `.git`, and copies `bootstrap.bas` to `assets/`. It does **not** automatically update them on later builds. No submodules or runtime package-manager downloads are used.
4. If redistribution is allowed, commit all applicable source and metadata:

   ```bash
   git add Makefile README.md LICENSE sender.c .gitignore scripts vendor assets UPSTREAM.lock
   git commit -m "Freeze USB gadget, libusbd and ns2jb dependencies"
   git push
   ```

5. Changes upstream will **not** change this project. Update snapshots only after intentional review and testing. `freeze-upstream.sh` refuses to overwrite existing directories. For a fresh snapshot, first archive/remove your previous vendor copies and compare upstream changes before replacing them.

## User: prerequisites (no upstream repository downloads)

- **Apple Silicon (arm64) MacBook**. Device-mode proof of concept targets macOS 12, and its USB controller example is hardcoded for a right-side port on a 2021 MacBook Pro. Other machines/versions may not work.
- Mac with macOS developer tools (Xcode command-line tools), full Xcode for the historical kernel extension, and **Node.js 22+** for the network host. These operating-system tools/runtimes are **not** embedded or bundled; users may need to install them separately.
- Switch 2 with **system software 23.0.1**, **SmileBASIC 4.4.9**, and over **20 MiB free** in SmileBASIC save space per original ns2jb documentation. A compatible USB data cable and local network shared with the Mac.
- **Working `usbgadget.kext`** installed and approved by the owner. The historical kext requires reduced macOS security (including SIP changes in the original proof of concept), which is risky. Bundling a kext does **not** bypass macOS security approvals, code signing, hardware constraints, or compatibility. Do not modify security settings on an important production laptop just for this demo.

## Step 1: Check Mac and frozen files

Clone **the [cpypwn/mac2jb](https://github.com/cpypwn/mac2jb) repository**, not any upstream repository, or download its ZIP. In Terminal from the project folder:

```bash
uname -m
sw_vers -productVersion
csrutil status
./scripts/check.sh
```

`check.sh` checks that snapshots are present and the frozen bootstrap hash matches. It does not access the internet. If it reports missing `vendor/` or `assets/`, the repository owner did not complete the offline snapshot step.

## Step 2: Build from the included source

```bash
make
```

Builds `vendor/libusbd/libusbd.dylib` and `mac2jb-send` using locally installed Apple compiler tools. No `git clone`, `curl`, `brew` or network access is performed. Compilation succeeding does not mean your Mac supports USB gadget mode.

## Step 3: Install/enable the historical USB device driver

Read `vendor/macos_usb_gadget_poc/README.md` and inspect the included `usbgadget/usbgadget.xcodeproj`. On a compatible historical macOS setup, open the Xcode project and build the extension:

```bash
open vendor/macos_usb_gadget_poc/usbgadget/usbgadget.xcodeproj
```

Follow Apple's [kernel-extension approval guidance](https://support.apple.com/guide/security/kernel-extensions-sec8e454101b/web), and the bundled developer documentation. Do **not** automate SIP disabling or load unsigned kernel code blindly. The driver was built as an experimental 2021 MacBook Pro / macOS 12 proof of concept, not a modern production driver. Verify an approved, loaded driver with:

```bash
kmutil showloaded | grep -i usbgadget
```

If unsupported or unloaded, stop: standard Mac USB host mode cannot send HID keyboard reports to the Switch 2. Consider a dedicated USB-HID microcontroller instead.

## Step 4: Check the text without USB activity

```bash
./scripts/send.sh --dry-run
```

Requires the sender to be compiled. Validates the **frozen** `assets/bootstrap.bas` for a US-ASCII keyboard and reports its length. The sender does **not** execute BASIC or automatically type RUN.

## Step 5: Type the source into SmileBASIC

1. On the Switch 2, open SmileBASIC → **Make a Program** → program **slot 0**, using a clean empty editor. Set the editor's keyboard layout to match **US English** if applicable.
2. Connect the appropriate data-capable USB cable to the Mac's supported device-mode port and the Switch 2's supported USB keyboard input path. This hardware combination is **unverified**.
3. On the Mac run:

   ```bash
   ./scripts/send.sh --delay-ms 100
   ```

4. Focus the Switch 2 editor, then type `SEND` into the **Mac Terminal** when prompted. It waits for keyboard enumeration and sends key press/release reports. Use **Control+C** to interrupt if input is going to the wrong place.
5. Inspect the text for missed characters; HID success cannot prove editor accuracy. Retry with `--delay-ms 200` after clearing the editor if necessary. Save the editor program as `NS2` in slot 0.

## Step 6: Complete the upstream ns2jb FS demo

**This phase uses local networking, not the USB keyboard link.** Follow the pinned `vendor/ns2jb/README.md` for the exact version in your GitHub release. The upstream steps inspected on **2026-10-22** were:

1. Connect the Switch 2 and the Mac to the same reachable local network. The demo host uses TCP port **39380**. Keep the Mac awake.
2. Restart the **Switch 2**, open SmileBASIC and enter **Direct mode**.
3. On the Mac, from the project root, run:

   ```bash
   ./scripts/host.sh
   ```

   If multiple network interfaces exist, select the Mac IPv4 address reachable from the Switch 2. Or specify one directly: `./scripts/host.sh 192.168.1.10` (use your **actual** Mac address).
4. In SmileBASIC **Direct mode**, enter these commands **one at a time**:

   ```basic
   LOAD "TXT:NS2"
   RUN
   REMOVE NSR,&H60000000,&H3FFFFFFF
   ```

   Confirm the load. The upstream documentation says the `Out of memory` error following `REMOVE` is expected. **Do not repeat REMOVE in the same SmileBASIC application process.**
5. The host prints a unique `V=START(...)` line containing your host IP and pairing data. **Type exactly the line printed on your own Mac**, not an example from another computer.
6. Leave SmileBASIC open and your Mac awake until the host reports **`FS execution verified`** and restoration/cleanup. The host places results under `vendor/ns2jb/runs/` (ignored by Git). If unsuccessful, keep logs, restart the **console** and retry on a fresh process. Upstream reports a timing-sensitive process.
7. **Restart the console afterward.** This demo does not install persistent custom firmware, as described by the ns2jb authors.

**Risks:** This is a privileged-process memory manipulation demo. It may crash applications or consoles or fail on other firmware. Review the original code and documentation before running. This project doesn't imply that the ns2jb demo is a general-purpose jailbreak or installs custom firmware.

## Troubleshooting

| Symptom | Check |
|---|---|
| `Missing offline component` | Maintainer must commit all snapshots; users should not fetch moving upstream code. |
| `clang` / `xcrun` missing | Install compatible Apple developer tools. |
| `libusbd_init` fails | Experimental device driver must load on supported Mac hardware/OS. |
| Host never enumerates keyboard | Supported USB controller/port, driver, cable and console HID support. |
| Wrong punctuation | US keyboard layout and editor focus. |
| Truncated BASIC | Clear editor and resend slower; review typed source. |
| `node` missing | Install Node.js 22+; it is a runtime, not a vendored JS dependency. |
| Connection fails | Check LAN reachability and TCP port 39380, then logs. |
| Bootstrap failures | Match exact upstream-supported firmware/software and restart as its documentation requests. |

## Publishing on GitHub

1. Create an empty repository named **`mac2jb`** under your GitHub account **`cpypwn`**: <https://github.com/new>.
2. Open <https://github.com/cpypwn/mac2jb>, select **Add file → Upload files**, and drag **all files and folders inside** the extracted `mac2jb` directory into GitHub (including the `vendor` and `assets` directories). Commit the upload in the GitHub interface.
3. Verify the web repository displays `README.md`, `sender.c`, `vendor/libusbd`, `vendor/macos_usb_gadget_poc`, `vendor/ns2jb`, `assets/bootstrap.bas`, and `UPSTREAM.lock`.

This bundle uses normal files rather than Git submodules; upstream changes cannot silently alter your stored source. Publishing does not remove the need for macOS tools, Node.js, a compatible Mac, or macOS driver approval. Verify redistribution rights before public upload.

## Credits and licenses

- [shinyquagsire23](https://github.com/shinyquagsire23) — [`libusbd`](https://github.com/shinyquagsire23/libusbd) (MIT) and the experimental [`macos_usb_gadget_poc`](https://github.com/shinyquagsire23/macos_usb_gadget_poc).
- [Sammy Hajhamid / pepsipu](https://gitlab.com/pepsipu/ns2jb) — original `ns2jb`, SmileBASIC `bootstrap.bas`, network host and native-demo engine.
- This repository's integration scripts and USB text sender are MIT-licensed under `LICENSE`; **that license does not automatically cover vendored third-party code**. Preserve upstream licenses/copyright and obtain permission where required.
- Unaffiliated with Nintendo or SmileBASIC.
