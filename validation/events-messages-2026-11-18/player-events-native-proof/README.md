# Original player module handlers

This proof executes all 104 original DOS instructions of F1103, F1102, F1101 and F61. The typed boundaries are F262, F991, F1097, F1116, F48 and F1104. Console rendering, the mission event VM and full gameover remain outside this kernel.

The uploaded original DOS binary binds DATA_008877 to initialized byte 0x4eed84, outside Root. It is the separate watched_index_u8 owner. Root+0xef is preserved. The other exact bindings are player DWORD Root+0xc0, mode byte Root+0xea, blink DWORD Root+0x10e and target byte Root+0x112. F1101 separately reads literal Root+0xe8, +0xec and +0xed. DATA_008560 is 0x60bf4c, separate from Root and outside the 71-word event register window at 0x60be08: it is temporary_event_index_s32, reset after F61's F48 callback even when the callback writes it.

The defined dispatcher payload is a DWORD code, DWORD body pointer and low index byte. Uninitialized trailing bytes are not part of the portable contract. The native harness poisons and checks them. The F61 nonzero-code path leaves an opaque payload pointer in EAX, unused by its module caller; this portable result explicitly marks return_defined=false and normalizes its return to zero.

The fixture contains 333 cases, all 256 index bytes and 109 explicitly authored typed callbacks. Each case was checked in three fresh native runs and a reverse-order stream. Full Root, bank, event registers, temporary index and watched byte are compared with Godot: 2,880 checks, zero failures. Callback mutations test source rereads and the temporary reset. Inputs and owner aliases remain read-only.

Copied-proof regeneration with absent original paths reproduced the fixture and all five generated proof files byte for byte. Independent reproof against the original executable and assembly reproduced the same outputs. Default regeneration needs only this portable proof, GNU assembler/linker and a C compiler.
