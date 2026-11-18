# Next lvalue and mission-task lifecycle block — read-only audit, 2026-11-18

This memo changes no0.30 project source, resources, fixtures or proofs. It is a next-block dependency plan, not a claim that F36/F37/F38/F47/F52/F53 or full F41 already execute.

## 1. Close lvalue writes and lifecycle before the full statement interpreter

A coherent next checkpoint is the complete bodies F36/F37/F38/F47/F52/F53, composed with the existing F20..35 expressions/guard registration and Events F44/F45/F48/F51/F54. F41 remains an exact, typed statement continuation until its own whole body and effects are carried over. This supplies assignment, cancellation, argument binding, initialization/guard scheduling and callback execution without claiming full original missions or connecting a partial cycle to Main.

F37 directly reaches F20/F22/F31/F34/F36/F48 plus F390/F391/F392/F441/F649 and the F1532/F1538 indirect slots. Reuse actual bodies where available, and retain strict before/after owner observations for the remaining equipment/world services. F37 is not just a generic variable store: its equipment loop, cargo limits, object model replacement and emitted events have different source order and rereads.

## 2. Reuse rich original model resources; do not reuse the whole factory as F36

F36 needs the full68-byte descriptor: scale words+14/+18, flags byte+24, radius words+2C/+30, collision-program pointer+34 and physical-spec pointer+38. It dereferences the collision first byte and optional24-byte physical specification through+14, plus the15-entry DATA7210 drive mass table. Equipment's projected physical specification alone cannot supply that graph.

However, these rich inputs already exist for0..148 in data/ffe_object_factory.json: descriptor68, collision-present/first-byte, physical24 or explicit null, drive15. data/ffe_effect_factory.json adds153/155 with explicit149-null. They can be reused after provenance/alias validation. F36 itself must be ported separately: F1533 initializes additional fields, has different copy/model0 behavior and must not be called as a substitute. When the new physical specification is null, F36 preserves existing physical body fields rather than clearing them.

Prove actual F1495 plus F1341 arithmetic in the F36 closure: radius exponent is the wrapped16-bit sum of descriptor scale words plus7, followed by signed high-word handling and original64-bit shifts. Verify the338-byte record byte-for-byte, including unchanged bytes and word/byte truncation.

F1538 reads DATA4681 at originalVA0x4D0CFC. The reviewed JJFFE table has466 slots,465 nonnull and149 null, but that alone is not a proved DOS table extent. Exploratory DOS reads find all466 candidate nonnull descriptors mapped; the next words continue into an adjacent ship-string table. Bind DATA4682 independently from an original code operand and verify the exact boundary before claiming the complete model catalog. Extend actual DOS descriptor/pointer-target captures for any additional admitted model indices; do not invent a maximum from the existing149-model runtime profile.

## 3. Preserve the single owners and two independent program cursors

Reuse the current Root16384 plus RootTail6160 and single bank38986. Current expression proof already binds DATA8861 toVA0x642204 (Root+C8), DATA8896 to0x642270 (Root+134), DATA8908 to0x6422C0 (Root+184), DATA9093 to0x64721C (RootTail+10E0), DATA9095 to0x647234 (RootTail+10F8), and DATA9133 to0x647948 (RootTail+180C). The six-word9093/9095 arrays must stay in that existing tail, not acquire duplicate mutable owners. F37's DATA8889/8891 cargo-capacity words require fresh operand proof; do not infer their offsets from late BSS label order.

Keep the separate40-byte module-global owner,71 event-register words, scratch32, temporary removal index,150x36 arena, logical variable heap and immutable mission image. Actual descriptors use shared static words; F37 static writes emit event3 with descriptor resource identity, and local writes emit event4 with the physical task identity. Index values are signed/wrapped words in the original calls.

F52 requires a caller expression cursor/task and a different callee lvalue cursor/new task. They may share one immutable57560-byte resource image but must advance separate offsets and select the correct variable buffer. Its module argument target stream is descriptor+0; arguments are evaluated in the caller, stored by F37 in the callee. The descriptor+4 default-expression pointer should be preserved as resource data even where this particular body does not consume it. All pointer transport must use resource offsets/task slots/logical allocation IDs, not host addresses.

## 4. Follow the literal lifecycle, including the non-obvious rescan

F38 takes the packed handle, checks its slot/generation word and signed state1..4, unregisters the active block with actual F33/F45, then clears task+8 and sets task+C=-1. A module with cleanup sets state5 without this generation increment; otherwise it increments the16-bit generation and sets state6. Reject slot>=150 before host access. Stale/inactive handles are source no-ops, not new errors.

F47 takes a physical task pointer and clause index. It runs only in state1 and below the current clause count. A true F31 condition leaves its cursor immediately at statements; set state2, execute F41 at that advanced cursor, and restore1 only if state is still2. Negative clause indices are outside the safe source profile, not silently clamped. The current guards proof binds the real F47 callback word to **0x413FF4 (4276212)**; do not use0x414FF4.

F52 returns the packed handle, including a valid zero handle after generation wrap. It receives a physical slot pointer from F51, binds arguments, sets task+10 to block0 and task+14=0, then returns task+4. The full-arena F51 NULL result is dereferenced by the original F52; classify that fault domain explicitly rather than returning a fabricated successful zero handle.

F53 sets state3, unregisters prior guards, executes current block+0 initialization through F41, then evaluates clauses while state stays3. **After a true clause, the source does xor esi,esi followed by the common inc esi; rescan therefore resumes at clause1, not clause0.** It reloads the current block from task+10 during the loop. Preserve callback-mutated block/state/variables and bound genuine nontermination. On completion it assigns task+8=current block and task+C=current block index, registers actual F33/F44 dependencies, and finally writes state1 in the original order.

## 5. Prove inline tables, data aliases and all continuation state

F37 contains a67-byte selector lookup DATA3 and18 original DWORD jump targets DATA4. Compare both raw tables, all actual targets and every code region; a helper that strips SECTION.data cannot establish this whole body. Test all byte selectors, including table holes/default no-ops. F36 binds both original dispatch slots F1538/F1495 and their pointed data, not just rewritten host labels. F38/F47/F52/F53 need whole instruction equality and exact four-byte arena/resource/variable pointers before the reviewed host ABI adapter.

Native controls should cover aliasing writes, event callback mutations, physical-slot versus packed-handle distinction, argument cursor advancement, module-shared static/local separation, task cancellation with/without cleanup, generation wrap, F53 rescan/reentrancy, invalid source pointer/fault profiles and cold replay. F36 repeated model changes must compare the complete body and preservation of fields when resources are null. Void EAX values must remain explicitly unconsumed; only F52's defined handle is a scalar result.

## 6. Follow with whole F41 and its explicit world-effect matrix

Once lvalue/lifecycle bodies are closed, port all61 F41 statement selectors and its244-byte original jump table. Reuse the already captured105 modules and original DOS bytecode, not the differing JJFFE program bytes. Per-selector effects must identify real equipment, object, economy, text/UI and world bodies; generic successful callbacks do not establish original mission behavior. F39/F40 and string output cursor/buffer ownership remain part of that subsequent closure. Main integration follows the matching complete world cycle, not an isolated VM success flag.
