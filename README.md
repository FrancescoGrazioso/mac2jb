# mac2jb

An experimental, minimal **USB HID keyboard text sender** for entering the upstream [`ns2jb/bootstrap.bas`](https://gitlab.com/pepsipu/ns2jb/-/blob/main/bootstrap.bas) file into the **SmileBASIC editor on a Nintendo Switch 2** using a USB cable and an Apple Silicon Mac.

It sends key reports, **not a `.bas` file over USB storage**, and does **not** automatically execute the typed program or complete the `ns2jb` demo. Its main purpose is to avoid manually transcribing the long BASIC source.

> [!WARNING]
> **Unverified on Switch 2 and modern macOS.** `libusbd` depends on an experimental macOS USB gadget kernel extension developed for macOS 12. Simply plugging two USB-C devices together does not guarantee that the Mac's controller can act as a keyboard, or that Switch 2/SmileBASIC accepts the emulated keyboard. Use a spare Mac if you plan to experiment with reduced macOS security. Do not disable SIP merely to test this project's compilation.

## Requirements

- Apple Silicon Mac (the cited `libusbd` macOS build targets `arm64`); **support on your specific hardware/macOS version must be confirmed**.
- Xcode command-line tools, full Xcode for compiling the optional old USB gadget kernel extension, Git, Make and Clang.
- [`shinyquagsire23/libusbd`](https://github.com/shinyquagsire23/libusbd), automatically cloned when `setup.sh` is run.
- A **successfully built and loaded** [`shinyquagsire23/macos_usb_gadget_poc`](https://github.com/shinyquagsire23/macos_usb_gadget_poc) `usbgadget.kext` driver; this is a separate, experimental prerequisite, *not bundled*.
- A data-capable USB cable and a target device that recognizes this USB HID keyboard implementation.
- Nintendo Switch 2 running the upstream demo's specified **SmileBASIC 4.4.9 / system software 23.0.1**, if you intend to use the upstream demo. Verify versions with the upstream guide before proceeding.

## 1. Check the Mac

Open Terminal:

```sh
uname -m
sw_vers -productVersion
csrutil status
xcode-select --install
```

`uname -m` should be `arm64`. The Xcode install command may report that tools are already installed. No current macOS compatibility guarantee is claimed here.

## 2. Get this project

On the project GitHub page, select **Code → Download ZIP**, extract the ZIP, and open Terminal in that folder. Or clone your own fork:

```sh
git clone https://github.com/cpypwn/switch2-usb-typer.git
cd switch2-usb-typer
```

For a downloaded ZIP, `cd` into the extracted folder instead.

## 3. Build the sender and `libusbd`

```sh
chmod +x setup.sh fetch-bootstrap.sh
./setup.sh
```

This clones libusbd under `vendor/libusbd`, builds `libusbd.dylib`, and compiles `usb-text-sender`. To rebuild later, use `make clean && make`.

**Build success is not proof that USB device mode works.** It requires the separate driver below.

## 4. Set up the experimental USB gadget driver

See the **original instructions and risks** in [macos_usb_gadget_poc](https://github.com/shinyquagsire23/macos_usb_gadget_poc). You can download its source with:

```sh
cd ..
git clone https://github.com/shinyquagsire23/macos_usb_gadget_poc.git
cd macos_usb_gadget_poc
open usbgadget/usbgadget.xcodeproj
```

Build the `usbgadget` Xcode scheme in Xcode. The original driver was written for macOS 12 and may fail to build or load on newer macOS releases. Kernel-extension installation may require Reduced Security, approval and changes to System Integrity Protection (SIP) using macOS Recovery. These changes materially weaken system security; consult [Apple's security documentation](https://support.apple.com/guide/security/kernel-extensions-sec8e454101b/web) and the driver's own README first. Do **not** blindly install unknown `.kext` binaries, and do not assume disabling SIP will make an incompatible driver work.

Once the extension has been loaded using the instructions appropriate to the specific macOS version, verify:

```sh
kmutil showloaded | grep -i usbgadget
```

If the kernel extension is not listed or USB keyboard enumeration fails, **stop here**: the sender cannot deliver USB keystrokes without a working device-mode driver. A USB HID-capable microcontroller is a more reliable alternative.

## 5. Download the original bootstrap

Return to the project folder and run:

```sh
./fetch-bootstrap.sh
```

The script downloads the current upstream `bootstrap.bas` and prints its SHA-256 hash. The file is excluded from Git, because it belongs to the original authors and can change. Inspect it before using it:

```sh
head -20 bootstrap.bas
shasum -a 256 bootstrap.bas
```

This project **does not execute** the contents of `bootstrap.bas` on your Mac.

## 6. Validate the text first (no USB activity)

```sh
./usb-text-sender bootstrap.bas --dry-run
```

The sender checks each byte against a **US-English USB HID keyboard layout**. It supports standard 7-bit ASCII letters, digits, SmileBASIC punctuation, spaces, tabs, and newlines. It rejects unsupported bytes rather than silently changing them. CRLF files are accepted. If this fails, inspect the source encoding and keyboard layout before proceeding.

## 7. Send text to the Switch 2

1. On the Switch 2, start SmileBASIC, enter **Make a Program**, choose **program slot 0**, and open a **new, empty source editor**. Do **not** enter Direct mode for the bulk program text.
2. Connect the Mac and Switch 2 with a **USB data cable**, using the Switch 2 port/accessories suitable for USB keyboard input. This has **not been hardware-validated** for this Mac HID implementation.
3. In the project directory on the Mac, run:

   ```sh
   DYLD_LIBRARY_PATH="$PWD/vendor/libusbd" ./usb-text-sender bootstrap.bas --delay-ms 80
   ```

4. At the `SEND` confirmation, ensure the Switch 2 editor is the intended destination, then type `SEND` and press Enter in Terminal. The program waits for USB HID enumeration and sends each key as a **press + release**, with an 80 ms inter-character delay.
5. **Watch the Switch 2 screen.** If it types into the wrong place or fails, press **Control+C** on the Mac. The target may contain partial text; clear the editor before retrying.
6. When the transfer finishes, carefully **verify all lines and punctuation**, then save the program as `NS2` in SmileBASIC. Do not assume successful USB writes prove that SmileBASIC received every character. If the console misses characters, retry with `--delay-ms 150` or a larger value (maximum 2000).

The sender intentionally does **not** press a RUN key or issue the upstream `REMOVE`/`START` commands. These are separate operations with additional risks and prerequisites.

## 8. If you intend to use the upstream `ns2jb` demo

Follow [the original `ns2jb` README](https://gitlab.com/pepsipu/ns2jb/-/blob/main/README.md), not a substituted set of steps from this project. Its documentation also requires **Node.js 22+**, the upstream `run.cjs` computer-side host package, compatible Switch 2 firmware and SmileBASIC versions, **over 20 MiB free** in the SmileBASIC save, and a shared reachable network. Its host server uses port **39380**. USB text entry is only the **one-time transcription step**, not the actual demo execution. The upstream demo manipulates privileged processes and is risky; review the code yourself.

## Troubleshooting

| Problem | What to check |
| --- | --- |
| `xcrun` or `clang` not found | Install Xcode command-line tools. |
| `vendor/libusbd` missing | Run `./setup.sh` with internet access. |
| `libusbd.dylib` cannot be loaded | Run with the documented `DYLD_LIBRARY_PATH` environment variable. |
| `libusbd_init` or interface setup fails | Verify the experimental `usbgadget.kext` is supported and actually loaded. |
| `USB host did not enumerate a keyboard` | Check the driver, Mac USB device-mode support, cable, port and whether Switch 2 recognizes the emulated HID device. |
| Text has incorrect punctuation | Set the target keyboard to a US layout; HID maps physical keys, not Unicode characters. |
| Text is truncated or wrong | Stop, clear the editor, try a longer `--delay-ms`, and verify after typing. |
| Unsupported byte error | The downloaded source contains a character outside supported ASCII; do not silently transliterate exploit source. |

## Publish this on GitHub

1. Create a **new empty GitHub repository** named `switch2-usb-typer`, without initializing it with a README.
2. From this folder:

   ```sh
   git init
   git add README.md Makefile sender.c setup.sh fetch-bootstrap.sh .gitignore
   git commit -m "Add experimental macOS USB HID text sender"
   git branch -M main
   git remote add origin https://github.com/YOUR-USERNAME/switch2-usb-typer.git
   git push -u origin main
   ```

3. Replace `YOUR-USERNAME` with your own GitHub username. GitHub may ask you to authenticate.

## Credits and license notes

- **[shinyquagsire23](https://github.com/shinyquagsire23)** — original [`libusbd`](https://github.com/shinyquagsire23/libusbd) library and [USB gadget proof of concept](https://github.com/shinyquagsire23/macos_usb_gadget_poc). The USB descriptor and initialization layout here are adapted from their [`examples/keyboard/main.c`](https://github.com/shinyquagsire23/libusbd/blob/main/examples/keyboard/main.c). `libusbd` is MIT-licensed; see its original [LICENSE](https://github.com/shinyquagsire23/libusbd/blob/main/LICENSE).
- **[pepsipu / Sammy Hajhamid](https://gitlab.com/pepsipu/ns2jb)** — upstream `ns2jb` demo and `bootstrap.bas`. The bootstrap and exploit remain upstream; they are fetched at user request, and no license is asserted for them here.
- **Nintendo / SmileBASIC** — owners of their respective names, software and trademarks; this project is unaffiliated.

This project's original text-input loop, ASCII-to-HID key mapping, and shell scripts are provided under the MIT license in `LICENSE`. The license **does not relicense upstream files**.

## Limitations

- Not tested here on Mac hardware, Switch 2, or real USB links.
- Assumes a **US keyboard layout** and focus in a plain source editor.
- No retry/resume based on confirmed text reception: HID keyboard does not acknowledge application-level text entry.
- No keyboard modifiers beyond left Shift; no clipboard, Unicode, macros, or automatic execution.
- No warranty; run only on devices you control.
