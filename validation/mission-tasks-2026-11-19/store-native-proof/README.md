# Original DOS F37 lvalue instruction oracle

This checkpoint executes the entire original F37 caller, actual F20 immediate
reader and F1532 bank lookup: **3 bodies /351 instructions**. F37 itself has
314 instructions. The proof covers both executable regions, the exact67-byte
selector map and all18 DWORD jump targets. Every target is an independently
proved original instruction boundary. Captured original bytes are separately
disassembled and compared to reassembled source, including label ordinals.

## A real DOS/JJFFE code variant

The uploaded DOS executable's selector62 writes `body+0xff` unconditionally
and then dispatches F48 with `[23,0,body_slot]`. Its original store is at
VA **0x412a18**. Later JJFFE adds a model lookup/physical-spec-null gate which
is absent from the DOS body. The original therefore emits the write/event
for records whose model is149 or an otherwise unrecognized value too.
The typed F36 replacement path remains a separate dependency of selector61.
It is not substituted for this unconditional byte write.

`source_code_variants` records that recovery. The jump-target **symbol order**
is unchanged, but the original later instruction addresses differ; the proof
therefore does not assert that the unmodified JJFFE table bytes are equal.
The stored table bytes and all target addresses are those of the DOS image.

Actual Root bindings include capacity DATA8889 at **Root+0x118**, used cargo
DATA8891 at **Root+0x120**, inventory DATA8896 at+0x134, six-word DATA8908 at
+0x184, and the two six-word arrays at RootTail+0x10e0/+0x10f8. The bank pointer
is RootTail+0x180c and uses the existing logical-bank token1. No mutable alias
is copied into a second persistent owner.

## Reviewed native transport and external calls

The portable context has thirteen fields: the existing Expression ten owners
and cursor fields plus physical task slot, original descriptor resource token,
and an explicit308-byte market buffer. Root/tail form one contiguous native
owner only for actual instruction access; portable storage keeps the proven
16384/6160-byte parts. Player/secondary-body pointer fields are transported
as canonical bank offsets. Static-variable notifications retain the original
resource token; local notifications use **0x60bf50 + slot*36**, not a packed
handle or host address. Only those source-defined pointer sites are normalized.

The market pointer returned by F649 is normalized as0/1. Its pointed bytes
are the persistent `market_buffer` owner and can be changed by F37 and the
following F48 continuation. This is an explicit single-market witness for one
invocation, not a complete world-market catalog. All13 owners are compared.

F31, F22, F34, F36, F48 and F390/F391/F392/F441/F649 remain exact typed
continuations in this standalone caller oracle. Their arguments and complete
before/after contexts are measured; a generic callback does not establish
those callees' whole bodies. F31 may advance its invocation cursor; other
providers cannot change it. Program, module-global selection, task/descriptor
identity and variable-buffer length remain read-only across providers.
Void EAX is explicitly unconsumed and normalized to zero, never interpreted
as an original scalar return. The source's actual comparisons, wrapped cargo
arithmetic, truncation, loops and callback rereads execute unchanged.

The host bridge supplies a low-address stack and reviewed four-byte pointers.
Original arithmetic is not calculated by Python. Immediate context canaries,
read-only program bytes, untouched task/descriptor references and padding
beyond the declared variable allocation are checked after execution.

## Controls and reproducibility

There are **467 normal native controls**, including all256 byte selectors,
all14 active setter routes, default/table-hole no-ops, signed32 and low16/8
boundaries, cargo capacity less than used, signed-addition wrapping, equipment
loop completion/early failure, callback-mutated owners and F649-before-index
ordering. Thirty-five cases use actual DOS argument-target streams and real
module variable/global/descriptor bindings. A five-store sequence carries the
entire13-owner result through four exact continuation edges while retaining
one immutable authored program. No witness program replacement occurs.

All normal packets repeat in three fresh native process cohorts and reversed
order. The native fixture matches the independently translated Godot runtime
for **9651 checks /0 failures**. One original null-static-global write fault is
recorded separately: three fresh executions terminate with SIGSEGV. No complete
source after-state is fabricated for that fault; the portable runtime rejects
it without publishing owner changes.

Default regeneration requires only committed captures and GNU assembler,
linker/objdump and a C compiler:

```sh
python3 tools/rebuild_source_mission_store_native.py
```

A copied proof with all original EXE/ASM/data paths absent reproduced the
fixture and all five generated proof files byte for byte. Independent reproof
against the pinned executable and assembly reproduced the same five files:

```sh
python3 tools/rebuild_source_mission_store_native.py --reprove-original \
  --exe /path/FIRSTENC.EXE --asm /path/ffe.asm --data /path/ffedat.asm
```

This is an offline ELF64 ABI instruction oracle. It is not an unchanged IA32
program, an Android emulator, full F41 execution, Main integration or physical
phone validation. See `rebuild-verification.json` for the sealed cohort and
source hashes.
