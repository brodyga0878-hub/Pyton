# Shared native mission services composition

This supplement reuses the separately proved original DOS expression, guard
and event-registry kernels. It does not add a new collection of original
procedures or calculate expected expression/guard/registry arithmetic in Python.
Every result and owner mutation comes from measured native calls. The host ABI
adaptations are retained as six assembly/C captures plus composition-proof.json.

There are26 cases. Six real Guard F31 requests execute the actual expression
kernel. Seventeen registry requests execute actual Events bodies: nine F44,
two F45 and six F48. Other cases exercise direct expression/global/local/event
reads, source global setters, the original shared RNG, and signed F33 counts.
Three cases retain the complete57560-byte original mission image and all105
definitions: module26 uses four local words/global offset20, and module32 uses
the actual DOS fifteen local words/no shared-global pointer. Their evaluated
leaf expressions are reachable within actual guard expressions. This does not
assert that the complete original mission or F41 statement VM executes.

The Core has20 fields. Root, Root tail, raw bank, event registers, module globals,
program, arena, registry, task-variable heap and counters have a single owner.
Selected task records and variable bytes are temporary kernel views. Program
cursor, physical task reference, packed handle and descriptor token remain
different values. Expected results compare every final Core field.

Five operations share one immutable160-byte authored program:

1. Actual F33/F32 registers an event-word guard through real F44; caller IP16
   remains unchanged because the guard cursor is local to F33.
2. Actual F34 stores word70 and real F48 invokes the explicit F47 provider.
   The provider authors Root and selected-local mutations; F47's body is not
   replaced with a claim of full execution.
3. Actual F31 reads the modified local through the same variable owner and
   advances the caller IP16→21.
4. Actual F33/F32 removes the original registration through real F45,
   preserving IP21.
5. Actual F34/F48 dispatches after removal and finds no handler.

All four continuation edges use the exact preceding native Core20 state.
No program replacement, caller-IP rebinding or freshly configured owner occurs
between these steps. The test suite separately checks live and cold-owned
continuation. Other short authored programs are explicit independent witnesses;
they are not labelled as the complete original mission image.

The oracle executes each packet three times in fresh processes, then repeats
every packet in reverse order in a shared process per kernel. Observed counts
including those repeats are80 expression,140 guard and72 event executions.
These repetitions are proof checks, not additional unique gameplay controls.

Portable reproduction needs only the committed tool/proofs/resources:

```sh
python3 tools/rebuild_source_mission_services_native.py
```

Copied-proof reproduction with original EXE/ASM/data paths absent produced the
exact fixture and all seven generated captures. The full image's105 descriptors
and module26/module32 owner projections are checked by the runtime separately.
F47 and F41 bodies, world-effect services, Main integration and physical Android
remain outside this composition's claim.
