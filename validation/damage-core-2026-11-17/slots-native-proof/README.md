# Original raw object slot allocation and release

The native oracle compares every original DOS instruction in F928, F924,
F925, F1533, F1538, F1495 and F1341 before using the documented ELF64 ABI
adapter. Expected record bytes and count changes come from these instructions.
Python constructs inputs, transports measured outputs and hashes raw banks.

There are 974 controls: both descending searches over slots 114..1, all 256
new flag bytes and all 256 released flag bytes, all 149 captured factory
models, counter wrap, exhausted banks, source pointer aliases, physical body
pointers whose record index names another slot, and 24 dependent native
allocation/release/reallocation steps. The complete 38,986-byte bank has a
116-byte header followed by 115 records of 338 bytes. Slot zero is preserved
by allocation. Flags at zero and the extra header byte are deliberate controls.

The 94 F144 observations are explicit event boundaries, including authored
module flags and mutation replies. They do not claim that every original
module has a non-null event-11 handler. Replies can patch the raw bank and
the 168-byte flag/private window, change the raw counter and change the loop
limit. Native F924 then resumes and re-reads future flags and the inclusive
limit. Its saved record index remains authoritative if a reply changes the
body's index byte. All callback preconditions include the entire bank hash,
module window, counter, limit, event index, body identity and reason.

All native cases repeat in three fresh processes and in reverse order. Bank,
source, descriptor, physical resource and module window canaries are checked.
External template bytes and the actual aliased source pointer's post-call
record are reported separately. Every runtime result compares the full bank
hash, counters, callback inputs and raw factory bytes against the oracle.

The standalone counter is the explicit owner of D8834, audited as Root+0x70
(DOS VA 0x6421ac). D7758 is bound to this supplied flags bank; no duplicate
Root or world registry is created. Module limits are bounded to -1..20,
matching the original 21-entry registry. The 168-byte window starts at D8623;
it does not claim to own the full 512-byte module block initialized by F143.

Factory resources currently cover models 0..148. F942's model 155 and its
complete debris behavior are outside this profile; unsupported models reject
without changing caller data. This work does not implement the complete F144
event engine, instantiate game-world objects, change Main or produce an APK.

Portable replay works with an independently copied proof directory and all
three original paths missing:

```sh
python3 tools/rebuild_source_object_slots_native.py --output /tmp/slots.json \
  --exe /absent/FIRSTENC.EXE --asm /absent/ffe.asm --data /absent/ffedat.asm
godot --headless --path . --script res://tests/test_source_object_slots.gd
```
