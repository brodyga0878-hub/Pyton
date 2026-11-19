# Composed native mission runtime proof

The offline composer runs independently proved original DOS instruction kernels
against one persistent set of eighteen logical owners. Each invocation projects
its actual caller or callee cursor and heap binding, executes a native kernel,
closes a typed continuation through another native kernel, and transports the
measured bytes back into the suspended caller. Expected game arithmetic and
copy results are not calculated in Python.

Final verification covers **31 native cases, 106 measured child results and
1,180 independent Godot checks with no failures**. The fixture SHA256 is
`3a2523e896e8d3cbdc3b7e149a9a591fbca2a68485e9ecdfc05cd9d41b6b7421`.
Three fresh cohorts and reversed replay agree exactly. The corpus includes
75 nested dependency calls, sixteen explicit world observations, four full-owner
continuation edges and four cases using the complete original resource graph.
A separate full-arena F52 SIGSEGV is measured in three fresh native processes
and rejected atomically by the portable runtime.

This is a bounded composition proof. F41 statement execution and the remaining
world services are explicit authored observations. Main, the complete mission
VM, the complete world, and an APK are outside this checkpoint.

## Original instruction evidence

The six constituent proofs contain 43 distinct captured procedures and 2,700
original instructions. F1345 contributes ten instructions solely to establish
the exact model-table boundary; the executable constituent set has 42 bodies
and 2,690 original instructions. Shared F20/F1532 captures are counted once.

| Constituent | Captured procedures | Original instructions |
| --- | ---: | ---: |
| Expression | 17 | 1,311 |
| Store | 3 | 351 |
| Guards | 5 | 187 |
| Task lifecycle | 4 | 177 |
| Events and scheduler | 12 | 541 |
| Model replacement and table anchor | 5 | 195 |

Each constituent has its own original-byte and instruction proof. The Store
proof retains the complete inline 67-byte selector map and all eighteen DWORD
jump targets. The composer uses the uploaded DOS variants: F37 selector62 is an
unconditional FF-byte store/event23, F38 has no later state admission guard,
and F47 reads its selected clause without the later declared-count guard.

An independent reproof from FIRSTENC.EXE, ffe.asm and ffedat.asm reproduced all
26 generated constituent capture/proof artifacts byte for byte. It wrote fresh
files in a separate recovery directory and changed none of the frozen proofs.
The resulting per-artifact hashes are recorded in rebuild-verification.json.

## Shared owners and invocation cursors

The persistent context contains Root, Root tail, body bank, event registers,
module globals, immutable program and source base, immutable expression metadata,
temporary event index, scratch words, task arena, event tree root/nodes/next ID,
logical task-variable allocations/next ID, immutable module definitions, and
keyed market records. It has no persistent invocation cursor or return register.

Task slot, packed handle, task resource address and heap identity are different
values. F51 returns a physical slot or FFFFFFFF for NULL. F52 returns the packed
handle, including valid zero after sixteen-bit generation wrap. Static-variable
event3 uses the source descriptor identity; local-variable event4 uses the
physical source task address 60BF50 + slot*36. Arena+20 remains a scalar; pointer
translation is limited to fields proved to contain addresses.

F52 holds separate caller-expression and callee-store cursors. F47 and F53 have
private local cursors. The readonly program bytes and definition graph stay
bound across callbacks. A continuation whose required task-variable allocation
has been freed is rejected before any live owner is changed.

## F55 to F52 to F51 callback transport

Original F55 clears eight scratch DWORDs, pushes four zero arguments, calls F52,
and then calls the scheduler F54. The composition closes that F52 callback using
the real task body, which invokes the real F51 allocator. F51 selects the first
state-zero physical slot, sets state4, increments its generation word, binds the
module descriptor, allocates the descriptor-sized variable buffer, and writes
the packed handle and argument into its first eight bytes. Other allocation
bytes retain the explicitly defined A5 allocator policy.

The new C overlay changes callback transport only. Original Event assembly is
unchanged. Model entry instrumentation records the real native call order in
a previously unused output trailer; its remaining 28-byte A5 canary and readonly
body/resource witnesses are checked before any result is imported. Owner7 imports a child-measured new logical variable allocation;
owner8 imports a child-measured free. The outer process retains the addresses of
its existing native tree nodes, temporary callback snapshots, and variable pool.
Before applying arena byte patches, the overlay converts native descriptor and
variable pointers to their logical tokens, then imports the resulting complete
arena. This prevents partial low-byte differences from corrupting host pointers.

Registry changes are transported as ordered F44/F45/F50 actions. Their actual
original instructions execute inside the suspended outer Event process. The
replay trace is suppressed because the child execution already records those
instructions in the composed call order; native tree and snapshot addresses
remain stable. Arbitrary replacement of an authored node map is not used as a
substitute for these actions.

The native callback heap witness supports consecutive surviving new allocations
and measured frees. Transient allocate/free cycles that leave monotonic identity
gaps are outside this native transport profile. This restriction does not claim
that all valid authored world transitions have native corpus coverage.

## Market bindings, boundaries and result semantics

F649 is the source binding for each mutable 308-byte market owner. A successful
lookup binds the requested system key; later F48 callbacks retain the same
buffer. Sequential assignments to different systems retain both owners. An
expression market snapshot must agree with any existing bound market owner.
Unbound zero transport bytes do not become a fabricated market record.

The remaining world calls carry exact arguments, physical task frame, caller IP,
complete before/after owner contexts, return word, and typed input/output bytes.
F41 remains an explicit statement continuation. Void source EAX values are not
asserted as game results. Original faults have separate records without a
fabricated complete after-state; the portable runtime rejects their domains
atomically.

## Reproduction and final verification

The final fixture, copied-proof replay, constituent original reproof hashes,
independent Godot parity counts, and source pin status are recorded in
rebuild-verification.json. Reproduction uses the new composer and the frozen
constituent proofs; no emulator or original DOS executable is used by the game.

A normal portable regeneration deliberately supplies missing original input paths:

```sh
python3 tools/rebuild_source_mission_runtime_native.py \
  --exe /absent/FIRSTENC.EXE --asm /absent/ffe.asm --data /absent/ffedat.asm \
  --proof-dir /tmp/starfrontier-runtime-proof \
  --output /tmp/starfrontier-runtime-fixture.json
godot --headless --path . --script tests/test_source_mission_runtime.gd
```

The stronger copied-proof check redirected all 34 constituent proof reads to
fresh copies and denied both original DOS input directories. A second complete
composition read all 34 proof inputs from the independently re-proved original
captures. Both reproduced the 515,536-byte fixture and all four generated runtime
artifacts byte for byte. The final Godot report pins 47 current source files.
