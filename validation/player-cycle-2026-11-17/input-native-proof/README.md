Original DOS player input
=========================

This proof covers complete F1037/F1038/F1039/F1040/F1121:220 original
instructions, checked against FIRSTENC.EXE SHA256
`d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72`.
F1038 is restored from that executable. JJFFE added CalcKeyInput, keyboard
rotation and saturating arithmetic; those later changes are excluded here.
Original mouse accumulation retains16-bit wrapping before applying the camera
limits. F1121 retains the original low32-bit products and five-doubling edges.

The generator statically reassembles every archived32-bit procedure and checks
all normalized instructions and original code-byte hashes. A reviewed native64
cdecl stack adapter executes the same integer instructions with low-address raw
data and stack. The only special frame change is F1038 scratch8→16 bytes for
its two host-width pops. No emulator or private executable is required for the
default rebuild. `--refresh-original-proof` additionally repeats the independent
comparison against the pinned original executable and JJFFE source.

The774 controls include all five procedures,3 fresh processes, reversed case
order and64 consecutive original inputs. Every338-byte body and complete16KiB
root is compared; untouched root bytes are pinned by a full output hash. Four
raw body/root guard regions remain unchanged. Root+EA, E9, DC and1B8 have one
backing store rather than duplicate global values. Python prepares input packets
and decodes outputs; it does not calculate expected game arithmetic.

GUI F1445 is a typed supplied u32 accumulator response. F931 records the original
signed mode and exact338-byte body pointer request; its event effects are outside
this closure. No Android touch collection, live Main integration or complete
player/world scheduling is claimed.

Verified commands:

```
python3 tools/rebuild_source_player_input_native.py
python3 tools/rebuild_source_player_input_native.py --exe /tmp/unavailable-firstenc.exe --asm /tmp/unavailable-ffe.asm --data /tmp/unavailable-ffedat.asm --output /tmp/source-player-input-portable.json
godot --headless --path . --script tests/test_source_player_input.gd
```

The portable rebuild and a separate original-EXE refresh reproduced the fixture
byte for byte. Runtime checks:7,171 passed,0 failed.
