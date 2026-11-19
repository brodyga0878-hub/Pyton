# Original F36 model replacement

The proof compares all original instructions of F36, F1538, F1495 and F1341:
**four whole procedures /185 instructions**. A separate ten-instruction F1345
body independently anchors DATA4682, the adjacent ship-string pointer table.
F1538 binds DATA4681 at0x4d0cfc; F1345 binds DATA4682 at0x4d1444. Their exact
1864-byte separation establishes466 model-table slots. This is not a count
inferred only from the later JJFFE resource listing.

The native fixture has **566 normal controls**: all465 non-null actual DOS
models, five lookup-only controls including the original NULL slot149,
wrapped radius exponents, signed physical values, all15 default-drive entries,
explicit null collision/physical witnesses and32 dependent replacements.
Every338-byte output record is compared with Godot. The suite passes
**4872 checks /0 failures**. Inputs, the unused source-record witness, all
descriptor/physical bytes and immediate boundary canaries remain untouched.
Three fresh process streams and reverse order reproduce exact native output.

The actual F36 dereference of NULL model149 produces SIGSEGV in a separate
native process. That fault is not included in566 normal cases; no fabricated
after-record is asserted. F1538's defined NULL pointer result is distinct from
its valid non-null model0 pointer. Out-of-table indices and negative physical
default-drive indices outside15 captured words are explicitly rejected safe
profiles; the original lookup itself does not supply a range check.

Expected arithmetic comes from the complete original procedures through the
reviewed ELF64 ABI adapter, not a second Python formula. F1495's host frame
reserves16 rather than8 bytes for its two64-bit epilogue pops; source32-bit
local fields and arithmetic remain unchanged. F1538's observed entry counter
preserves flags. The low-address pointer table and resource pointer fields are
relocated for the host only, then restored before readonly comparisons. The
executable and adapter are offline proof tools, never Android assets.

F36 writes the model word, two64-bit radius fields and replacement flags. It
copies physical statistics only when the new physical pointer is non-null;
otherwise existing physical fields remain. It does not copy another body,
allocate an object, assign type87, clear factory-only fields or advance time.
There is no special model0 skip. F1533 is not used as a replacement substitute.
The source F36 scalar EAX is void/unconsumed and excluded from portable results.

Default replay uses only the copied proof and committed resource JSON:

```sh
python3 tools/rebuild_source_model_replace_native.py --output /tmp/models.json
```

It accepts --proof-dir and --exe/--asm/--data/--mission-asm; all four original
paths can be absent unless --reprove-original is supplied. The arithmetic
proof itself consumes EXE/ffe.asm/ffedat.asm; mission assembly is a catalog
source-identity input to the separate extractor. Copied-proof regeneration
and independent original reproof reproduced the fixture and all four generated
proof files byte for byte. See rebuild-verification.json.

This proves raw model replacement and lookup. Complete geometry, rendering,
all world services, Main integration, a complete mission VM and physical-device
performance are outside this checkpoint.
