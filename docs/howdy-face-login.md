# Howdy Face Login

Face recognition for SDDM via [Howdy](https://github.com/boltgolt/howdy).
Module config: [modules/howdy.nix](../modules/howdy.nix). PAM wiring:
[modules/display-manager.nix](../modules/display-manager.nix).

## First-Time Setup

### 1. Calibrate the IR emitter

The IR LED is a separate USB device that needs a UVC control packet to turn
on. `linux-enable-ir-emitter` is enabled at
[modules/howdy.nix:34](../modules/howdy.nix#L34) and replays the saved
packet on each boot. The packet is found interactively, once:

```sh
sudo -E linux-enable-ir-emitter configure -m
```

The tool cycles through candidate packets and asks whether the LED lit up
during each test. The IR LED is invisible to the naked eye but shows as a
violet glow through a phone camera. Point a phone at the laptop's camera
bezel during each test and answer `y` for the packet that lit it.

### 2. Enroll a face

```sh
sudo howdy -U bjoern add
```

Sit at typical laptop distance under normal lighting. Re-run for additional
models (different lighting, glasses on/off); matching checks against all
enrolled encodings.

### 3. Test

Lock the session with `loginctl lock-session` and click the face icon at
the SDDM prompt without typing anything. The session unlocks within ~1s
under good lighting.
