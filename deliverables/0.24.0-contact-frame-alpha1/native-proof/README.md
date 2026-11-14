# Original caller sign and F581 query-frame contract

Reproduce from the project root with Python3 and GNU `as`/`ld` on Linux x86_64:

```sh
python validation/contact-frame-2026-11-14/native-proof/rebuild_source_contact_frame_native.py
python validation/contact-frame-2026-11-14/native-proof/validate_source_contact_frame_native.py
```

Build files and host executables stay under `/tmp`. The replay reads archived assemblies and deterministically rewrites only this new fixture/proof bank. No timestamps are emitted. The original DOS executable is not needed for this replay. `reprove_original_caller_instructions.py` optionally refreshes the instruction comparison when the original pinned `/workspace/ffe-original/FIRSTENC.EXE` and upstream `ffe.asm`/`ffedat.asm` are present.

Dependencies are the unchanged footprint48 proof generator/observed assembly, original21 excluded assembly, existing packet/decoder tools and their narrow two-file ground-harness import dependency, plus the original classifier/root/footprint fixtures. The new `caller-source-procedures.s` and its pinned instruction proof are archived here. No full recovered-history tree, binary, external service or GPU is required. The prior README files describe their already checked DOS/resource provenance.

## What actually ran

The fixture has230 frame cases and12 bounded caller cases,242 total. Frame inputs cover all17 supported solid descriptors, signed axes, positiveZ with tiny positive/negative X/Y that either vanish or survive original quantization, near-outer coordinates at multiple F579 scales, four explicit parent-rotation/byte57 controls, and five retained Cobra/Shuttle/history witnesses. There are237 F581 observations and236 actual query frames; the retained child coarse hit intentionally has no query frame. Observed scales include0/2/3/4/5 and the separate raw-history scale18 control. All banks run in three fresh native processes with same-process reverse repeats.

Original full F576/F579/F581/F1876 instructions run for frame cases. New preserving observations capture:

- `O`: the actual scaled first source vertex, before source differences.
- `D`: `O − observer`, before length/rotation work.
- `working_difference`: source scratch after the XY step and before JUMP2504 replaces it with the positive-distance centre.
- `U`: all nine actual final Q31 rotation words; `C`: the actual three query-centre words; `A`: all nine transformed basis words supplied to F1876.
- Source observer, scale, scaled threshold and the two actual rotation-path flags.
- Existing native winning integer leaf triangles and source query/global state through the unchanged footprint prefix.

Three **additional diagnostic** calls execute original F1669 on `(D,U)`, original F1669 on `(-D,U)` and original F1670 on `(C,U)`. Native signed32 NEG creates `-D`. Native signed32 ADD, matching the original F1876 point-translation semantics, observes the actual forward image `C + T_U(-D)`. The legacy centre-difference diagnostic `C - T_U(D)` is separately labelled. Q31 floor multiplication is not odd: these two diagnostics are generally different. Original F581 does not itself make these extra calls, and the transpose product is not claimed to be a mathematically exact inverse.

The caller executable runs original F569/F570/F1532/F1662/F1335. F575 is explicitly replaced by an entry observer that captures the still-signed input vector and returns zero. Byte57 pair frames match; positive body148 and zero DATA9155 suppress frame-transition paths. F572/F573/F1677 are abort traps. This proves the bounded caller sign and argument order, not a full classification/response/world-frame engine.

The new static DOS comparison covers11 complete procedures,1076 instructions and3263 bytes: those five native caller procedures, plus static-only F574/F575/F1333/F1531/F1661/F1677. The archived native caller contains only the five adapted procedures. The original67-procedure frame/math/terrain proof remains unchanged. The validator reruns every new exact record and confirms all158 original footprint48 outputs are unchanged.

## Result: body minus parent; positiveZ degeneracy is original

Actual F570 primary-parent witnesses copy positiveZ4000000000 and negativeZ−4000000000 unchanged into the F575 entry observer. A same-frame positiveZ body with another object at `[10,20,30]` produces `[-10,-20,3999999970]`. Signed64 carry cases are also native outputs. No Python subtraction formula supplies expected vectors.

Source anchors explain this result:

- F570 (`ffe.asm:36010–36020`) directly copies body+0x3E for its primary-parent-relative position. Its same-frame pair path (`36118–36138`) copies body position and invokes F1662 with the other object's position. F1335 (`83499`) performs `op1 − op2`; F1662 (`100411`) applies it componentwise.
- F1677 (`101683`) reconstructs absolute position by recursively adding parent position and local/transformed-local displacement. The mixed-frame F570 path subtracts these absolute results. This mixed path is statically checked, not executed by this bounded caller bank.
- F570 calls F575 directly; F574 is a separate disabled-response height entry that forwards the supplied vector to F575. F575 (`36383–36394`) saves the signed vector before ABS changes caller scratch. F576 receives that saved signed copy.
- F575's kind1 correction (`36598–36667`) forms `inner − previous_altitude` and **adds** its product with the outward signed-relative normal to body position. F579's byte56/57 guard (`37715–37729`) chooses whether the parent transpose is required. A global caller-vector negation would reverse these consistent conventions.

At model120 positiveZ, scale3, native observation is:

```
observer = [0,0,449986560]
D        = [0,0,-449986560]
U        = identity-Q31
C        = [0,0,449986560]
U*D      = [0,0,-449986560]   # separate native diagnostic
T(-D)    = [0,0,449986559]
q(observer) = [0,0,899973119] # actual signed32 C+T(-D)
```

Both source rotation branches are skipped because the working X/Y components are exactly zero. The C assignment then uses positive F1466 distance and does not preserve negative Z. NegativeZ has the matching sign, with ordinary Q31 rounding. Positive rawX1 can quantize to zero and retain the degenerate result, whereas rawX−1 survives arithmetic SAR as a negative component, takes both branches and restores the expected near-axis orientation. This is native original-source behavior, not evidence for reversing every body/parent vector.

The actual forward map of the observer is `C + T_U(observer-O) = C + T_U(-D)`, not `C - T_U(D)`. For model120 negativeZ the actual native forward point is `[0,0,0]` while the legacy difference is `[0,0,1]`; near positiveZ it can be `[0,-1,-1]` while the legacy difference is `[0,1,1]`. The fixture includes both independent native observations. A frame/projection API must expose this literal antiparallel case as unsupported for a claimed physical-observer identity, or otherwise explicitly retain the original virtual query frame. It must not silently flip the caller, fabricate a corrected U/C, or treat ordinary Q31 roundoff as an exact inverse. The data prove original query-frame and native-leaf coordinates; they do not certify global world geometry, repaired original physics, a GPU triangle, live landing or a full engine clone.
