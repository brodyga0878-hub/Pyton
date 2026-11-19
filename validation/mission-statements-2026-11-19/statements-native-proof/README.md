# Whole original DOS F41 statement caller

This checkpoint contains the complete uploaded DOS F41 statement dispatcher and
six small original helper bodies: F20, F23, F24, F1333, F1532 and the actual DOS strlen.
There are **7 whole bodies / 1509 instructions**. F41 itself has **1430**
instructions in two executable regions, separated by the exact 61-DWORD DATA5
jump table. The original entry is 0x412c38, table 0x412c68, first target 0x412d5c,
and final ret 0x413d9e. All targets are independently proved instruction boundaries.

Every original code byte is separately disassembled and compared with reassembled
source, including label ordinals and complete operand bindings. The actual F41
opcode/table behavior equals the JJFFE listing here: **no F41 code or table
variant was found**. This differs from the previously recovered F37/F38/F47
variants; no earlier capture was edited. The strlen target is independently
anchored by F41's original call and contains 13 instructions / 25 bytes.

## One context and invocation-local bytes

The eleven-field context owns Root16384, RootTail6160, bank38986, immutable
program/base/cursor, physical task record36/slot, readonly vectors324, and an
explicit text buffer/cursor. DATA9133 is RootTail+0x180c, DATA8558 is the append
pointer at original VA0x60bf44, and DATA1705/6/7 are the vector fields at
0x48f07c/80/84. DATA2244 is a separately captured two-byte empty-string constant
at 0x49aa16, immediately after the archived original string region.

Each F41 invocation supplies an explicit 156-byte seed and a bytewise00/01
initializedness mask. Only 72 caller-observable bytes are exposed:20 formatter
parameter bytes at EBP-156,48 UI record bytes at EBP-136, and4 outlocal bytes at
EBP-4. Source writes mark exactly the bytes they initialize. Reused record words
and masks persist during one invocation. Optional provider writes affect only
the pointer window actually passed to that call. Other84 compiler scalar-spill
bytes remain excluded; their seed/mask transport is never a claim about the
private source stack or a way to mutate inaccessible source locals.

Uninitialized packet bytes retain their explicit seed and mask0. A zero seed is
an authored invocation witness, not proof that the original initializes those
bytes to zero. Controls vary seeds, retain previous record fields, and carry
measured caller-visible bytes/masks through eleven dependent frame transitions.

The ELF64 bridge expands cdecl argument slots from4 to8 bytes while preserving
all literal156 local offsets. Program bytes are not rewritten. Root references,
task resource fields, bank-return pointers and packet pointers are normalized
only at source-defined fields/call sites. Partial owner writes round-trip through
logical pointer tokens. Packed task handles, physical task slots, arbitrary
scalars, resource VAs, bank offsets and ephemeral packet references remain distinct.

## Typed continuations and evidence

Nine-key observations contain kind, arguments, full context before/after, return,
input/output bytes and their definedness masks. F31/F37/F52 alone may change the
invocation cursor. UI records expose48 bytes, F1344 parameters20, and F304/F305
outlocals4. F101 exposes the actual NUL-terminated inline program string. F1344
receives destination owner/offset and format ID, mutates the pointed context
owner, and returns a destination offset; the original F41 performs return-1.

F664 argument2 and F304/F305 argument0 preserve their low8 bits. Actual DOS callee
instructions independently show signed-byte consumption; upper EAX register or
stack-address residues are not portable argument values. The partial callee ABI
sites are retained as evidence and do not claim whole execution of those workers.
Unconsumed void EAX values are normalized to zero, including F41's F39 call even
though the separately proved F39 identity worker has a defined scalar result.

F31, F37, F38, F39/F40, F48/F52 and UI/text/world services remain explicit typed
workers in this standalone oracle. Closing them in a higher-level composer does
not change this proof's boundary contract. Broad F1344 formatting, full world
services, Main integration and Android phone validation are not claimed here.

F1333 is retained and instruction-proved as part of the caller graph. Its bank0
coordinate-add branch requires unowned low pointers with the actual F1532 body;
the admitted normal corpus does not claim execution of that helper branch. The
other five small helpers have native execution witnesses.

## Controls and separate domains

The 362 normal controls execute all256 opcode bytes and all61 dispatch targets,
including unknown-byte no-ops. They include empty/UTF-8 inline strings, nullable
UI/body results, cursor and callback mutations, physical task state changes,
actual descriptor/vector multiplication wrap, body-index aliases, inventory
boundaries, source byte-width residues, local packet reuse and explicit provider
writes. Sixteen controls retain the full immutable original resource image and
actual source prefixes/descriptor identities. Eleven dependent owner transitions
share one immutable program and use preceding native output, with explicit
measured frame transport. There are490 typed boundaries.

All normal controls repeat in three fresh process cohorts and reversed order.
Expected arithmetic comes from original instructions, never Python. Two original
SIGSEGV domains are measured separately in three fresh processes each: a null
bank direct body write and a null descriptor block transition. The first retains
its complete typed pre-fault F31 continuation, so portable rejection occurs at
the unowned-pointer domain rather than at a missing callback. No successful
complete source after-state is fabricated for either fault.

A literal backward relative jump runs until the explicit4096-dispatch host
budget. This is a separate bounded nontermination observation, not an original
termination or successful final state. An unterminated inline literal is rejected
by a bounded owned-program admission check with transport exit97. The actual13
strlen instructions still run for every admitted literal. This transport rejection
is not labelled an original SIGSEGV. Descriptor/vector/program span restrictions
and formatter destination capacities similarly do not assert original clipping.

## Reproduction

```sh
python3 tools/rebuild_source_mission_statements_native.py
python3 tools/rebuild_source_mission_statements_native.py --reprove-original \
  --exe /path/FIRSTENC.EXE --asm /path/ffe.asm --data /path/ffedat.asm
```

The default route uses committed instruction/resource captures. It accepts absent
EXE/ASM/data/mission-ASM paths for frozen-source verification. A copied proof with
all originals absent reproduces the fixture, and independent original reproof
reproduces all five generated captures. See rebuild-verification.json for final
hashes and independent runtime test totals. The native tools are offline research
oracles and are not shipped as Android emulators.
