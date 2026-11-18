# Original mission guard and event-word kernel

The oracle independently reassembles every original IA32 instruction in
F32/F33/F34/F35 and the shared F20 literal reader before adapting the host ABI:
five whole procedures / 187 instructions. The four guard/event procedures
contain 162 instructions; F20 is a shared helper, not a newly invented parser.
The actual 68-row / 1088-byte metadata table is bound by DOS operands at
0x48ec3c. Its SHA256 is
`fa9ea4bbb6b062b426e0c56299b0aa1a646341a7355bb51aa5cad574cc8670b0`.

F32 evaluates registration keys, calls the selected F44/F45 provider, restores
the saved operand cursor, then walks children recursively. These are distinct
source steps. F33 starts a local cursor for each guard and rereads task+8 and
the signed guard count after callbacks. Its public caller cursor remains
unchanged because the source function has no caller-IP argument. F34 writes
the selected event word before requesting F48(2,0,index); F35 returns that word.

The seven-field context contains event_registers284, program, program_base_u32,
ip_u32, task_record36, task_slot_u32 and metadata1088. Programs and metadata are
readonly resources. Task and event bytes can change through exact matched
observations. F31 expression evaluation and registry F44/F45/F48 are explicit
providers in this standalone kernel; the service composition connects actual
expression/event kernels separately. This proof does not execute F47 or F41.

Task pointers normalize to their original DOS physical-address tokens
0x60bf50+slot*36; packed generation handles are not substituted. The original
F47 callback word remains 0x413ff4. Descriptor key words remain original
resource tokens. Only metadata key-kind2 identifies a pointer: an arbitrary
F31 scalar is never reinterpreted because its numeric value resembles a host
pointer. Task+8 relocation is tracked by provenance, preserving unused opaque
words. No host address is a persisted owner.

Reviewed ELF64 changes expand cdecl stack argument slots, widen F32's two-pop
local frame from8 to16 host bytes, and relocate F33's loaded readonly program
reference in a register while preserving flags and the source resource bytes.
Native canaries protect every owner and both readonly resources are checked
after each execution. Semantically undefined void EAX returns are excluded.

The fixture contains113 native controls: all68 metadata selectors, signed
zero/negative clause counts, multiple clauses, F33 block-pointer rereads,
recursive child descriptor rereads, callback cursor override/rewind, every
event-word boundary and12 dependent event-owner transitions. There are80
authored provider observations (25F31/20F44/12F45/23F48). All cases run three
fresh times and in reverse order in one process. Godot passes1588 checks with
zero failures, comparing every context byte and the full source call order.
Invalid spans, out-of-table selectors, recursion limits and malformed providers
are rejected as bounded profile cases; they are not fabricated DOS results.

Normal portable reproduction:

```sh
python3 tools/rebuild_source_mission_guards_native.py
```

No original files are read in that mode. A copied proof with all original
arguments pointing to absent files reproduced the fixture and five generated
proof files exactly. Independent `--reprove-original` against the pinned DOS
executable and assembly reproduced the same bytes. Python authors inputs and
provider answers; it does not calculate expected guard order, keys or state.
