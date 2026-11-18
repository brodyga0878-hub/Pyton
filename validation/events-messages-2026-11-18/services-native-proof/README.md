# Native event services composition

This supplemental fixture reuses the independently instruction-proved original player, event and message native adapters. It measures 22 compositions, separate from their standalone cohorts. There are 13 player cases and nine message cases: 11 actual F48 dispatches and seven actual F271 backend executions. The harness makes 38 player, 41 event and 27 message native calls, each in three fresh processes, followed by an exact reverse-order stream.

At each player F48 seam, the source-defined low byte is sign-extended by the actual player instructions. Its raw unsigned32-bit ABI arguments enter actual F48, including F61 indices 128/255 becoming 0xffffff80/0xffffffff. Original F48 executes its real subtree snapshot and callback sequence. Measured Root/bank/event/temp changes are transported back as bounded byte patches, and the original player function resumes. Registry, arena and scratch changes keep their separate shared owners. Python computes byte differences for transport only; it does not compute expected cleanup, event tree, queue, clock or random arithmetic.

Two dependent steps carry an actual preceding native result: Player cleanup into message routing, then one message result into another. Packet witnesses contain all48 explicitly supplied bytes. Equipment binds only offsets 0, 4, 0x18; destruction binds 0, 0x18 and 0xc only when its count argument is defined. Other bytes remain explicit opaque witness data. No unspecified legacy caller stack bytes are invented.

The independent DOS bindings agree on Root at 0x64213c, Root clock +4, screen+0xe8, temporary event index at 0x60bf4c and separate event scratch at 0x60bf24. The player watched byte is 0x4eed84, outside Root; Root+0xef is preserved. Event registers, temporary index, scratch and watched byte each retain one owner.

UI selection, sound, formatter/wrapping, F1104 gameover and mission VM callback bodies remain typed providers. This is a kernel proof and composition test; it does not claim Main or Android integration.

Godot kernel and State validation passed 982 checks with zero failures, including all 22 full-owner hot/cold replays, 11 nested F48 calls, seven F271 executions, all nine packet witnesses and both dependent owner steps.
