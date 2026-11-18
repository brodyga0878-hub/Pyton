# Original mission expression instruction oracle

This checkpoint executes 17 complete original procedures: F20..F31,
F462/F463, F922/F1530 and F1532. The instruction proof contains 1,311 original
code instructions, three inline selector tables and all 110 DWORD targets.
F922/F1530/F1532 are shared previously proved helpers; the expression/list
bodies add 14 distinct procedures. This is not F41 or a complete mission VM.

## Proof and the DOS/JJFFE variant

Code regions are independently assembled as IA32 against actual DOS operand
bindings and compared instruction by instruction. Every source code label is
also bound to its actual original instruction index/address. Inline bytes are
validated separately: all table targets must identify proved original code
boundaries. The portable path separately disassembles the archived original
bytes; assembly text is not treated as its own expected oracle.

F21 and F31's tables match the reference assembly. F22's actual DOS table at
VA `0x4115d1` differs in two slots: selector15 writes Root+`0x124` through
JUMP204, while selector16 proceeds to the event tail without writing. JJFFE
swaps those effective slots. The captured source table is corrected from the
original bytes and both differences are recorded in `source_table_variants`.
The getter/setter asymmetry is retained deliberately.

F31 has 68 table slots. Slots0/1,28/29/30,33 and38..44 do not initialize the
outer result local; some still recurse. The accepted profile rejects these
undefined-result expressions instead of inventing zero or an identity result.
The defined 55 selectors execute under bounded valid operand domains.

## Owners and host adaptation

The ten-field context has Root16384, the contiguous original Root tail6160,
raw bank38986, event registers284, shared module globals40, selected task
variables8..1024, readonly program1..65536, cursor offset, module-global base
and temporary event index. Actual operand bindings independently establish:

- Root base `0x64213c`; player/secondary pointers at+`0xc8`/+`0xcc`.
- The six-DWORD arrays D9093/D9095 at Root+`0x50e0`/+`0x50f8`.
- D9133's bank reference at Root+`0x580c`; its portable token is1.
- Module globals `0x60bde0`, events `0x60be08`, temporary index `0x60bf4c`.

Root+tail occupy one contiguous native owner; their portable byte windows
are disjoint. Body pointers serialize as bank offsets116+338*slot (or NULL).
No host address is persisted. The synthetic current-task view contains only
the source descriptor/global pointer and selected variable pointer consumed
by these procedures. It does not claim to implement task lifecycle or F41.

The bridge expands cdecl stack slots for ELF64, keeps source arithmetic and
four-byte fields, uses a low-address private stack, and resolves inline table
branches through source32 words. Immediate boundary canaries and program
readonly checks run for every packet. A missing provider stops via a host
longjmp before continuing the original caller; it cannot fabricate a result.

External F48/F85/F96/F106/F392/F461/F649/F658/F857/F870/F871/F909/F1476 bodies
remain explicit providers. Root/bank/global/local mutations are exact typed
before/after observations. Program, cursor, module base and local buffer
length remain readonly across a provider. F461 supplies an explicit4096-byte
list witness with a bounded terminator. The actual list helpers F25/F26/F30
and F462/F463 then execute. F649 supplies NULL or an explicit308-byte market
view; F658 supplies2 output bytes. F870 supplies four DWORDs in output-argument
order and the source caller consumes output2. F871's five other output
pointers alias one scratch DWORD; the result is its **fourth output / total
argument5**, host slot RBP+48. Its normalized pair is scratch/result. Unused
void return registers are not asserted as source scalar results.

## Corpus and reproduction

The fixture has 404 measured controls, including24 actual DOS mission clause
entrypoints over the complete57560-byte mission image and original declared
module/local views. Static admission chooses well-formed expressions; all
expected arithmetic, callbacks, cursor and owner bytes come from the executed
instructions. Five separate divide-error controls actually terminate with
SIGFPE (zero divisors and signed INT_MIN/-1 overflow); no complete native
post-state is claimed for those traps. They are excluded from primary cases.

Three fresh whole-process404-packet cohorts and a reverse cohort reproduce
exact outputs. Fresh per-packet reference executions also guard hidden state.
Godot compares all ten owners, values, defined-pointer flags and exact source
call order. Current result: 3,310 checks, zero failures.

```sh
python3 tools/rebuild_source_mission_expression_native.py
```

Default replay uses committed captures only. Original files may be absent.
GNU assembler/linker/objdump, GCC and Python3 are required. Recheck original:

```sh
python3 tools/rebuild_source_mission_expression_native.py --reprove-original \
  --exe /path/FIRSTENC.EXE --asm /path/ffe.asm
```

Copied-proof regeneration with all original paths absent and independent
original reproof reproduce the fixture and five generated proof files byte
for byte. Native tools remain outside Android; this is not an emulator on the
phone. Full world/economy/text services, F37/F41, task lifecycle, Main and
physical-device behavior remain outside this checkpoint.
