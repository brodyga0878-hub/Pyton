# Original event registry and scheduler instruction oracle

This oracle executes twelve complete original DOS procedures: F42/F43
comparators, F44/F45 registration and removal, F46 snapshot traversal,
F48 dispatch, F49/F50 clearing, F51 task allocation, F54 scheduling and
F55/F56 initialization/cleanup. Their 541 IA32 instructions are independently
reassembled and compared with the original executable before the reviewed
ELF64 ABI adaptation. Expected tree topology, callback order, task state and
owner bytes are measured from those instructions, not calculated in Python.

## Reproduce

The normal command requires Python 3, GNU as/ld/objdump and GCC:

```sh
python3 tools/rebuild_source_events_native.py
```

It uses the committed source captures and resources only. The private DOS
executable and JJFFE source paths are not opened by this path. To compare
the original again:

```sh
python3 tools/rebuild_source_events_native.py --reprove-original \
  --exe /path/FIRSTENC.EXE --asm /path/ffe.asm --data /path/ffedat.asm
```

The host C bridge supplies a low-address stack and reviewed allocators.
Original source arithmetic and four-byte memory fields remain intact.
The only F48 control-transfer substitution resolves an opaque callback word
through an explicit provider. That same word is preserved in comparator
keys and captured callback records; it is never replaced by a host address
for sorting or serialized as a host address.

## Memory ownership and logical pointers

The context has twelve fields: Root, raw bank, 71 event-register words,
150 task records, a temporary event index, a separate 32-byte scratch region,
the logical registry root/nodes/counter, logical variable buffers/counter
and readonly normalized program definitions.

F55 writes scratch variables D8550..D8557 at original addresses
`0x60bf24..0x60bf40`. They start **after** the 284-byte event-register window
at `0x60be08`; they are not event registers 2..9. The complete IA32 proof
checks those actual operands. Native initialization controls verify that F55 itself
clears scratch while preserving every event-register byte; explicitly
provided VM writes remain separate callback effects. Root, bank,
registers, arena and scratch have immediate boundary canaries. Normalized
definition records and cleanup words are checked readonly after execution.

Thirty-two-byte registry nodes and variable buffers receive separate
monotonically increasing logical identities, with generation 1 and a
bounded lifetime of 512 allocations in each class. Freed IDs are not reused
under this reviewed allocator policy. Sixteen-byte callback-list nodes live
in a separate temporary pool; they do not advance the saved registry ID
counter and cannot be mutated by the typed external provider.

The arena's original 16-bit generations are separate and execute unchanged.
F51 can successfully allocate physical slot 0 after generation `ffff→0000`
and produce packed handle 0. The fixture distinguishes that success from
a NULL allocation pointer. Full arenas return NULL before reading even an
unloaded definition. Fresh task-variable bytes use the bridge's explicit
`a5` allocation policy; only the first eight bytes are initialized by F51.
The remaining bytes are allocator input, not an asserted original zeroing.

## Corpus

There are 169 cases. Each final packet runs in three fresh processes and
again in reversed order. Forty-two dependent transitions carry actual
preceding native state, including a 24-step insertion sequence and a
20-step task-slot reuse sequence.

The cases cover wrapped first-difference comparisons, all six F42 key
positions in source order, duplicates inserted to the right, all deletion
shapes including immediate and deep left predecessors, subtree-only
in-order snapshots and callback-driven removal/insertion/clearing.
One explicitly authored wrapped-key graph demonstrates why filtering the
entire registry is not equivalent to the original found-subtree traversal.
It is a raw graph probe, not a claim about ordinary initialization.

Source F54 chooses the greatest signed state and the lowest physical slot
on ties. Cases cover states 4/5/6, cleanup before release, inactive signed
states, physical slot 149, complete arena admission failure and generation
wrap. The bounded host/runtime profile stops unsupported nontermination
after 1024 scheduler iterations; it does not claim to emulate an infinite
original loop or out-of-memory/null-allocation faults.

There are 46 explicit external observations: 31 `event_callback`, seven
F53, four F41 and four F52. A missing answer stops with the exact typed
pending context. Provider registry actions invoke the actual original
F44/F45/F50 workers; the result must match the observed tree. Callback
snapshots stay independent when a provider removes a later registration
or inserts a new one. Scalar returns of source void procedures are excluded.

## Composition API

`verify(proof_dir)` returns `(metadata, source, kernel_assembly, host_c)`.
`compile_native(kernel, host_c, directory)` builds the executable, using
the same reviewed commands as the generator. `packet(row, scripts=None)`
encodes one length-prefixed input; packets can be concatenated in a process.
`decode(output, row)` returns actual state, ordered observations and the
optional next request. Output size is the DWORD at header offset 4.

`raw_row(fixture, row)` and `hydrate_context` restore SHA-checked pooled
owner buffers. Callback function words and arguments are opaque unsigned
source values. Actual task pointers are normalized to physical slots;
variable pointers and registry links become logical IDs. Definitions are
typed normalized inputs for the original pointer loads; this does not
execute original VM program resources.

F47 handler bodies, F53/F41/F52 VM work, the full F41 interpreter, live Main
and Android execution remain outside this proof. These kernels alone do
not establish an integrated game release.
