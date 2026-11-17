# Original player control composition

The 80-case fixture joins separately DOS-verified native kernels at their exact
raw callback contexts. Expected game arithmetic comes only from those native
executables; Python copies/serializes their raw results and supplies inputs.

- 64 cases: whole F1009/F1008 mode prefix, actual F1044/F1045/F1512 drift, then
  F1009 continuation with the native drift response.
- 8 cases each of F1019 and F1021: the actual F1009 prefix selects the phase;
  actual native F1037/F1039 input output resumes its first input boundary;
  actual native F1033 contact output resumes its contact boundary; the actual
  completed phase output then resumes F1009.

There are 304 native invocations, each repeated in three fresh processes (912
executions). Full 338-byte body and parent, 16,384-byte raw root window, all
16 external fields and supplied clock words are retained. Root C8/CC contain
stable logical object references, never saved host addresses. The original
DWORD mode table and source arithmetic remain unchanged. The derived mode
observer journal grows from 32 to 256 byte writes only to copy complete native
phase responses; this is harness storage, not game logic.

F569 geometry is an explicit supplied observation. Remaining world, frame,
control, event and presentation callbacks retain their exact matched raw
observations. This does not claim their implementation, a full world scheduler,
or routing through Main. F1033's proved arithmetic reads the first 544 root
bytes and external words; the native contact oracle checks its unchanged tail.
The exact returned prefix is copied into the phase's original full root,
preserving that phase's unrelated tail bytes.

GUI samples use an explicit cross-language SHA-256 layout: raw body338,
raw root16384, then nine little-endian uint32 words in this order: frame ticks,
forward key, reverse key, three spin values, transfer state, saved flags, effect
gate. Signed values retain their two's-complement bits. This token serializes
input identity only; it is not an expected-physics implementation.

All original procedure archives, input resources, imported proof/ABI helpers,
and generator sources are pinned in composition-proof.json. The phase fixture
is additionally pinned as validation evidence. Host assembler captures are
saved alongside the report. No private original files are read by this tool:

```sh
python3 tools/rebuild_source_player_cycle_native.py
```

Portable replay accepts --output and --proof-dir for isolated outputs; --exe,
--asm and --data are accepted for command parity but never read. A replay with
all three private paths absent produced identical fixture SHA-256
`c1ed973184be474bcbe6a2ce3dad324aeec3fa4c7cd25fad6dbe53372c171512`.
