# mac2jb

**type a SmileBASIC bootstrap into a Nintendo Switch 2 using an Apple silicon Mac acting as a USB HID keyboard.**

mac2jb combines a USB HID text sender with vendored source from
[libusbd](https://github.com/shinyquagsire23/libusbd),
[macos_usb_gadget_poc](https://github.com/shinyquagsire23/macos_usb_gadget_poc),
and [ns2jb](https://gitlab.com/pepsipu/ns2jb).

**Release layout:** the user-tested inherited-indentation implementation is now
`sender.c` and the default `mac2jb-send` executable. `make` and
`scripts/send.sh` use that same source. Earlier experimental senders are not
shipped in this package. This is experimental hardware-specific software,
not a supported general-purpose macOS USB gadget API.

## confirmed test machine and connection

These are **results from one user's physical hardware testing**, not blanket compatibility claims.

| item | working test configuration |
| --- | --- |
| mac | MacBook Pro with Apple M4, `Mac16,1`, 10-core CPU, 16 GB RAM |
| macOS | `26.4.1` |
| firmware observed | system firmware `18000.101.7`, OS loader `18000.101.7` |
| mac ports available | three USB-C ports: two left, one right |
| mac port used | **upper-left USB-C port** (topmost on the left side) |
| switch 2 connection | **top USB-C port on the Switch 2** |
| switch 2 firmware | 23.0.1 |
| smilebasic version | 4.4.9 |
| switch 2 mode | docked and undocked (both tested successfully) |
| cable | USB 2.0 **data-capable USB-C to USB-C** cable |
| selected gadget controller | **`usb-drd1`** |
| gadget driver | `gay.bowser.usbgadget` / `usbgadget.kext`, version `1.01` observed loaded |
| keyboard smoke test | `hello` appeared inside SmileBASIC |
| capitalization | tested corrected inverse Shift handling for letters |
| indentation | inherited-space test sender worked on real SmileBASIC editor |
| bootstrap | tester reported successful full typing with the inherited-indent sender |
| fast sending | 10 ms and 1 ms were reported to work, but below ~50 ms no noticeable speed improvement; lower settings were less stable |

An **undocked** direct connection also worked at least once, but the tester could not reliably reproduce it. After the initial `hello` success, USB enumeration was intermittent; a fresh test eventually worked again using the docked configuration above. A working connection today does not imply every reconnect will succeed.

The physical ports are **not** universally mapped to `usb-drd0`, `usb-drd1`, and `usb-drd3` on all Apple silicon Macs. `usb-drd1` is the *empirically working choice for the test machine*, not a universal default.

## before you begin

- Use only a console and computer you own or are authorized to test.
- This project depends on a **third-party experimental kernel extension** and a USB device-controller path that Apple does not provide as a supported general-purpose USB gadget API. The original upstream driver targets older Apple silicon/macOS software.
- The test Mac had **Reduced Security** and **System Integrity Protection (SIP) disabled** temporarily to load the experimental driver. That is a **record of the test environment, not a recommendation** to disable them. These changes reduce protections for your Mac. Review Apple's kernel-extension security guidance and restore your normal security policy after research testing.
- A successful `make`, a loaded kext, a charging indicator, or macOS's accessory-approval prompt **does not** prove USB HID enumeration. The real proof is text appearing on the target.
- The sender **types into the focused editor**. It does not run the code. Unexpected input focus can cause accidental typing elsewhere.
- A USB disconnect or interrupted write may leave the receiver believing a key is still down. The tested sender attempts a neutral HID release report on exit, but that is best-effort. If a key repeats indefinitely, **unplug the cable** to reset the connection.

## files and prerequisites

You need an Apple silicon Mac, Xcode Command Line Tools, **full Xcode for building the kext**, and the checked-in vendored source. For later `ns2jb` network-host work, the pinned project's host also needs Node.js 22+ and an appropriate local network. The device/SmileBASIC software versions required for that separate stage must match the vendored upstream `ns2jb` instructions; the original bundled README specified Switch 2 system software `23.0.1` and SmileBASIC `4.4.9`.

From the extracted project folder (containing `Makefile`):

```sh
xcode-select --install  # only if developer tools are not installed
uname -m
sw_vers -productVersion
bash scripts/check.sh
```

Expected architecture: `arm64`. No upstream clone is needed: the source is under `vendor/`, and the bootstrap to type is `assets/bootstrap.bas`.

## build and test — step by step

### 1. verify the kext already installed on your test Mac

```sh
kmutil showloaded | grep -i usbgadget
```

The original developer built the kext using the Xcode project at:

```text
vendor/macos_usb_gadget_poc/usbgadget/usbgadget.xcodeproj
```

A loaded extension is required but is **not sufficient** for successful gadget mode. Do not change security settings further just because enumeration fails.

### 2. build the default sender

From the project root (the folder containing `Makefile`):

```sh
make clean
make
ls -l mac2jb-send
```

`make` builds the verified inherited-indentation `sender.c` into
`mac2jb-send`, signs it ad hoc, and uses a bundled `libusbd.dylib` with an
executable-relative runtime search path. `make clean` removes the sender and
the vendored library binary, so the next `make` recompiles them both.

### 3. test the USB connection before sending code

Use the **upper-left Mac USB-C port** to the **top Switch 2 USB-C port** with
a data-capable USB 2.0 USB-C-to-USB-C cable. mac2jb has been successfully tested with the switch 2 both docked and undocked. the confirmed setup uses `usb-drd1`, the upper-left usb-c port on the macbook pro, and the top usb-c port on the switch 2 with a usb 2.0 data-capable cable.
Open an *empty, focused* SmileBASIC editor.

```sh
bash scripts/test-controllers.sh usb-drd1
```

When prompted, type `SEND` and Enter. Check that `hello` appears on the
Switch 2. The script sends text only; it does not press Run. If enumeration
fails, reconnect the cable and retry the known-good setup before exploring
another controller. Other Macs may use a different controller.

### 4. verify indentation using the included small test

Clear the editor completely. The included `indent-test.bas` contains
`COMMON DEF P$(V#)` followed by nested `VAR`, `FOR`, `NEXT`, `RETURN`, and
`END` statements:

```sh
MAC2JB_CONTROLLER=usb-drd1 ./mac2jb-send indent-test.bas --delay-ms 50
```

Inspect the received indentation. After each Enter, SmileBASIC carries
the previous line's leading spaces into the next line. The sender
compares that *inherited* indentation with the desired leading spaces from
the file, sending only the extra spaces or Backspaces. It does not use
Home or Shift+Home and does not guess indentation from BASIC keywords.

Expected leading indentation counts for the sample's eight lines:
`0, 1, 1, 2, 1, 1, 0, 0` spaces. These are ordinary single spaces.

### 5. dry-run, then send the full bootstrap

Before sending, make sure the receiving editor is empty and the
correct editor window has focus.

```sh
shasum -a 256 -c assets/bootstrap.bas.sha256
MAC2JB_CONTROLLER=usb-drd1 bash scripts/send.sh --dry-run
MAC2JB_CONTROLLER=usb-drd1 bash scripts/send.sh --delay-ms 50
```

Type `SEND` when prompted. `scripts/send.sh` uses the default
**`mac2jb-send`**, so the indent behavior is identical to Step 4.

`assets/bootstrap.bas` is the trimmed copy sent to SmileBASIC; it omits
four introductory comments and the subsequent blank line. Its original
unmodified source remains at `vendor/ns2jb/bootstrap.bas`. The checksum
in `assets/bootstrap.bas.sha256` is for the **trimmed** copy.

Do not interact with the editor while mac2jb is typing. After the sender
reports completion, verify the text is complete and its capitalization,
punctuation, and indentation are correct **before saving or running** the
program. Sending text is not proof of successful execution of the ns2jb
bootstrap or network stage.

### 6. optional ns2jb host stage

The separate ns2jb network host is bundled under `vendor/ns2jb`. Consult
its `README.md` and the pinned upstream requirements before using:

```sh
bash scripts/host.sh --help
```

`--help` is passed to the upstream host; its exact supported CLI options
depend on that vendored version. `bash scripts/check.sh` also checks for
Node.js 22+ on the Mac.

## timing and safety notes

The default inter-key pacing is **50 ms**. Use `--delay-ms N` to change
it (supported range 1–2000 ms). This setting does not control the time
spent inside USB write calls; in testing, settings below around 50 ms
offered little apparent improvement and shorter values sometimes became
unstable.

The sender transmits a press and release for each key, and attempts a
neutral HID report during normal exit or interruption. If the connection
fails after a key press, a release might never reach the Switch and the
key may repeat. **Unplug and reconnect the USB cable** if that happens.
The sender prints elapsed time, cumulative USB write time, pacing time,
and retry counts; this is diagnostic, not proof the target received all
characters.

## troubleshooting

| symptom | what happened during development / what to check |
| --- | --- |
| `dyld: Library not loaded: libusbd.dylib` | the sender lacked an appropriate executable-relative rpath; confirm `-Wl,-rpath,@executable_path/vendor/libusbd` in the Makefile and rebuild |
| `Bad code signature` when loading the kext | macOS refused the experimental kernel extension under the initial security configuration; do not interpret sender compilation as kext approval |
| `Failed to find gay_bowser_usbgadget` | upstream `libusbd` selected only hardcoded `usb-drd2`, which was **absent** from the M4 test Mac; discovered services were `usb-drd0`, `usb-drd1`, `usb-drd3` |
| `Error matching IOUSBDeviceInterface (0)` | appeared transiently even during runs that later found the interface; the zero status alone did not establish a fatal failure |
| `Waiting for USB host enumeration...` | the gadget path was found but the target had not successfully enumerated the HID device; for this test Mac, `usb-drd1` eventually worked |
| charging works, keyboard doesn't | USB power role is not proof of USB data-role configuration |
| wrong letter case | SmileBASIC mapped unshifted letters to uppercase and shifted letters to lowercase during this test; the sender inverted Shift for letters |
| text typed, but indentation grows incorrectly | the default `sender.c` now implements inherited-space correction; rebuild with `make clean && make` if using an earlier snapshot |
| no indentation | an earlier keyword-based algorithm overcorrected; it was abandoned |
| line breaks disappear | an earlier Shift+Home/Backspace reset deleted newlines; **do not use `--indent-reset`** |
| compiler error at `auto_indent=0;\\n` | this occurred only in an abandoned experimental sender; use the current default `sender.c` and rebuild |
| stuck repeating character after cancellation | key-down was delivered but key-up was missed; stop sender and disconnect/reconnect the cable |
| `mac2jb-send: no such file or directory` | run `make` from the folder containing `Makefile`, then run `./mac2jb-send` |

## development log: how we got here

This is a **chronological troubleshooting history**, not a Git commit history or independently timestamped lab journal. All observations below come from the tests and logs shared during the project; dates for individual experiments were not consistently recorded.

1. **Bundled the source and bootstrap.** Created the mac2jb integration from pinned `libusbd`, `macos_usb_gadget_poc`, and `ns2jb`, with offline source builds and USB text-sending scripts.
2. **First build/runtime problem: dylib search path.** `mac2jb-send` originally couldn't launch because `libusbd.dylib` wasn't found by the dynamic loader. Added an executable-relative rpath to the Makefile and rebuilt.
3. **Loaded the experimental driver.** After code-signing/security investigation, `kmutil` confirmed `gay.bowser.usbgadget (1.01)` was loaded on the M4 test Mac. SIP was temporarily disabled in that research environment.
4. **Discovered the wrong hardcoded controller.** The first `hello` test failed with `Failed to find gay_bowser_usbgadget`. `ioreg` showed `usb-drd0`, `usb-drd1`, and `usb-drd3` services — **no `usb-drd2`** — while vendored `libusbd` searched for `usb-drd2` in **two places**. docked and undocked compatibility confirmed. usb hid keyboard emulation successfully transmitted text to the switch 2 in both docked and undocked configurations using the top usb-c port. usb-drd1 was the working controller on the m4 macbook pro.
5. **Confirmed service discovery after editing both references.** Replacing the hardcoded controller enabled `libusbd` to connect to `gay_bowser_usbgadget` and its generated `IOUSBDeviceInterface`. Enumeration still initially timed out.
6. **Corrected an HID descriptor inconsistency.** The embedded keyboard report descriptor was **65 bytes**, but the HID descriptor advertised **93 bytes (`0x5D`)**. The updated test build used the actual report length.
7. **Added controller selection.** Instead of editing the C source for every test, introduced `MAC2JB_CONTROLLER` and a controller test script for `usb-drd0`, `usb-drd1`, and `usb-drd3`.
8. **First successful physical USB HID transmission.** With **`usb-drd1`**, the Mac's **upper-left USB-C port**, the Switch 2's **top USB-C port**, a **USB 2.0 data-capable USB-C cable**, and the Switch **docked**, `hello` appeared in SmileBASIC. An undocked attempt reportedly worked once too, but it could not be reproduced consistently.
9. **Latest firmware compatibility confirmed.** mac2jb was successfully tested on nintendo switch 2 running the latest system firmware available on october 22, 2026 (23.0.1), with smilebasic version 4.4.9. usb hid keyboard emulation and bootstrap text transmission worked in both docked and undocked configurations.
10. **Worked around intermittent enumeration.** Several docked/undocked tests and Mac ports failed after the first success. Returning to the known port/controller setup eventually restored successful typing. Root cause of the intermittent behavior was **not fully identified**.
11. **Found inverted letter capitalization.** SmileBASIC produced uppercase letters without Shift, and lowercase with Shift on the tested editor. Reversed letter Shift handling in the sender. Symbol and punctuation correctness still requires inspection of the received code.
12. **Transferred bootstrap text.** After dry-run validation and typing tests, the tester confirmed the bootstrap reached the editor. First transfers exposed performance and whitespace problems.
13. **Measured delay behavior.** Lowered pacing from 100 ms to 20, 10, 5, and 1 ms. The tester reported 10 and 1 ms worked, but little perceptible speed increase below about 50 ms; very short delays were less reliable.
14. **Discovered a stuck-key failure mode.** Interrupting a transfer between key-down and key-up could leave a repeating character on the Switch. Added best-effort neutral-report cleanup, bounded retries, and transfer timing statistics.
15. **Removed nonexecutable bootstrap header text.** Removed the first four comment lines and one blank line in the sendable copy, trimming it from **8,108 to 7,804 bytes**, while retaining the untouched upstream copy under `vendor/ns2jb`.
16. **First indentation attempt: literal spaces.** The sender typed every source indent again after SmileBASIC had already carried the previous line's indent. Nested blocks accumulated too many spaces.
17. **Second attempt: keyword-aware “smart” indentation.** Tried guessing new indent levels from `COMMON DEF`, `FOR`, etc. This removed required indentation, because the editor actually inherits whitespace rather than indenting by syntax.
18. **Third attempt: Shift+Home/Backspace reset.** Attempted to clear each new line's indent wholesale. On the console, this also removed line breaks. The method was abandoned.
19. **Determined the editor's real rule.** The tester established that **Enter carries the previous line's manually entered leading spaces**, and extra spaces or Backspace are needed only when the desired indentation changes.
20. **Built a separate inherited-indent sender.** The tested `sender-indent-test.c` tracked the carried-forward indent and applied a per-line difference. A real `COMMON DEF P$(V#)` / `FOR` / `NEXT` / `RETURN` / `END` test typed with correct spaces and newlines. The tester reported that the full bootstrap also worked flawlessly with this approach.
21. **Consolidated the working sender for a manual GitHub push.** The tested `sender-indent-test.c` was promoted to `sender.c`, the default `make` target and scripts were aligned, and the trimmed bootstrap checksum was updated. Previously, the GitHub connector could read `cpypwn/mac2jb` but returned `403 Resource not accessible by integration` for branch creation despite reporting push permission. The maintainer chose to push from the Mac. **This README records the tested snapshot; it does not imply any commit or push has occurred.**

### lessons from the debugging log

A driver **loading** is not the same as a device **enumerating**, and an enumerated keyboard isn't the same as correctly **typing the full program**. Correct HID report lengths, controller selection, key-release safety, case mapping, and editor whitespace behavior all mattered. Keep the smallest working test (a single line, then an indentation sample) before retrying a large transfer.

## repository layout

```text
Makefile                             builds mac2jb-send from tested sender.c
sender.c                             tested inherited-indentation HID sender
indent-test.bas                      short indentation test input
assets/bootstrap.bas                 trimmed sendable bootstrap
assets/bootstrap.bas.sha256          checksum of trimmed sendable bootstrap
vendor/ns2jb/bootstrap.bas           original upstream bootstrap
assets/hello.txt                     simple keyboard smoke-test input
scripts/test-controllers.sh          test selectable USB controllers
scripts/test-usb.sh                  send hello using default sender
scripts/send.sh                      send assets/bootstrap.bas using default sender
scripts/check.sh                     prerequisite and checksum verification
scripts/host.sh                      pinned ns2jb host launcher
vendor/libusbd/                      pinned USB device-mode library
vendor/macos_usb_gadget_poc/         pinned research kext source
vendor/ns2jb/                        pinned ns2jb project
upstream.lock                        pinned upstream revision identifiers
```

Use `make-release-zip.command` on macOS to generate a release archive
without compiled binaries or local build artifacts. The vendor source
is included; **the prebuilt, locally approved kernel extension is not**.

## credits and licensing

- [shinyquagsire23](https://github.com/shinyquagsire23) — [libusbd](https://github.com/shinyquagsire23/libusbd) and [macos_usb_gadget_poc](https://github.com/shinyquagsire23/macos_usb_gadget_poc).
- [pepsipu / sammy hajhamid](https://gitlab.com/pepsipu/ns2jb) — original `ns2jb`, SmileBASIC bootstrap, and network host.
- [cpypwn](https://github.com/cpypwn) — mac2jb integration and testing.

This project is independent and not affiliated with Nintendo or SmileBASIC. Respect the licenses and redistribution terms of the vendored upstream projects; an integration-level license does not override third-party rights.
