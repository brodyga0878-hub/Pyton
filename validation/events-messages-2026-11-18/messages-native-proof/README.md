# Original message routing and ten-slot history backend

This proof executes whole original DOS F349, F350, F351, F352 and F271.
All **278 instructions in five complete procedures** were independently
assembled as IA32 and compared with the original executable before the
documented ELF64 adaptation. The two register-only XCHG EDI/ESI swaps admit
symmetric encodings and are normalized as the same register exchange.
Original callback pointer words are captured and checked separately.

The runtime suite passes **1846 checks, 0 failures**, covering **151 native
cases**. Cases include mode4 menu bypass, mode44 suppression, signed flag
styles, sound/callback rereads, actor/fallback names, direct and immediate
submission, null versus a non-null empty CString, maximum1023-byte text,
signed abs overflow, and sixteen dependent sticky/dismiss/history steps.

## Replay

```sh
python3 tools/rebuild_source_messages_native.py
```

Default replay uses only archived source/proof files, GNU assembler/linker,
GCC and Python3. A copied proof with original EXE/ASM/data paths absent
reproduced the exact fixture and all five captured proof/host files. A
separate complete original reproof reproduced those same bytes:

```sh
python3 tools/rebuild_source_messages_native.py --refresh-original-proof \
  --exe /path/FIRSTENC.EXE --asm /path/ffe.asm --data /path/ffedat.asm
```

The generator repeats original programs in fresh processes and reverse order.
A separate full151-packet cohort was also run in one process, repeated in
three fresh processes and reversed; all outputs were byte-identical. These
portability repeats are separate from the unique runtime check count.

## Exact owners

The public context has exactly six byte buffers:

- `root`:16384 bytes. Actual DOS D8870 is0x642224, precisely Root+0xe8;
  Root tick/day remain the sole timestamp owners at0/+4.
- `bank`:38986 bytes, used for typed actor name references.
- `packet`:48 fully specified caller bytes.
- `queue_records`:10380 bytes, the actual ten records of1038 bytes.
- `queue_control`:36 bytes, nine source words in the order
  D5092/D5093/D5094/D5096/D5097/D5098/D5099/D8677/D8799.
- `fallback_name`:612 bytes, the original D9148 window.

The control words and fallback buffer are outside Root in the actual DOS
bindings; no copies of Root mode or clock are persisted separately. The
three ring indices are bounded to0..9 by the supported runtime profile.

A record is day DWORD+0, tick DWORD+4, style BYTE+8, text1025 bytes+9,
flags DWORD+1034. F271 copies the original unwrapped input text, including
its NUL, without clearing the remaining tail. It counts only CR bytes in a
separate F1398-wrapped scratch copy. Both input and wrapped CStrings are
bounded to1023 characters plus NUL, matching the actual1024-byte scratch.
Only the low style byte is defined; unused high EBX bits are not fabricated.

F350 passes sticky flag1 only when its second argument is zero. F351 uses
argument1, while F352 copies the packet, sets its local packet flags to-1,
and calls F350 with argument0. Packet negative flags select style0x11 and
sound suppression; they do not themselves mean sticky. Nonnegative styles
are0x5f. A null F271 input dismisses the current sticky slot; a non-null
empty CString still executes enqueue, timestamps and index/height updates.

## Pointer and caller-packet policy

Packet+0x1c uses a canonical bank body offset (116+slot*338), or zero for
the D9148 fallback. Native execution temporarily rebinds actual pointers
and normalizes snapshots back. The formatter receives five exact source
words plus a type tag for its last parameter:0 opaque raw word,1 bank-name
offset,2 fallback offset0. Unused opaque actor words remain unchanged.

The standalone kernel requires all48 packet bytes explicitly supplied.
This does **not** claim unspecified stack words in legacy callers were
initialized. Equipment F944 defines only00/04/18; bounty F942 defines
00/0c/18 and rank defines00/18. Those callers need a reviewed complete
packet witness or verified formatter argument dependency before composing
this kernel; zero-filled unknown fields are not source initialization.

EAX from these void message entrypoints is not a portable return contract
and can otherwise contain a host pointer. Results explicitly mark the
return register ignored, and use a neutral bridge value0 without claiming
it is the original register value. All semantic outputs are owned bytes,
call order and typed submissions.

## External bodies and public API

The backend is actual F271 ring/history logic, not a fabricated queue.
F217 menu selection, F1906 audio, F1344 formatting and F1398 wrapping bodies
remain explicit providers. The native C bridge transports authored text and
owner patches; it calculates no expected message routing or queue arithmetic.
F1344 output scratch is never read before the provider supplies it.

`SourceMessages.execute(context, operation, observations, display_mode_s32,
submitted_text)` supports F349/F350/F351/F352 and direct F271. For F271,
`submitted_text=null` is a null pointer; `PackedByteArray([0])` is an empty
CString. For other entrypoints, submitted text comes from the formatter.

An observation has exactly `{kind,args,before,after,return_u32,
input_text_hex,output_text_hex}`. Before/after are direct contexts.
F217 has no arguments; F1906 has sample22. F1344 has code, five source
words and the parameter4 type tag; input text is empty because output
scratch is undefined. Its output is a bounded CString. F1398 has width120,
the copied CString as input, and the explicitly wrapped CString as output.
Other providers require empty text fields. Public JSON codecs preserve all
owner/text bytes. Missing or mismatched providers reject without publishing.

`verify(proof)` returns metadata/source; `build(metadata,source,directory)`
returns binary/assembly. `packet`, `decode`, `run`, `fill_scripts` and
`raw_row(row,buffers)` provide the lossless native composition interface.

This checkpoint does not execute original formatter/wrapper/menu/audio bodies,
draw text, complete all event modules, connect a Main game loop, produce an
APK or establish physical Android/FPS results.
