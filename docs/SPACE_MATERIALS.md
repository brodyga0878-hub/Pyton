# Existing ship and station material upgrade

The texture update reuses the existing hulls, landing gear, orbital station,
solar wings and optional graphics-preview rocks. No mesh positions, triangle
construction, collision bounds, flight parameters or docking targets change.
The Cobra high-detail hull remains 7,534 triangles.

The shared original texture library supplies albedo, OpenGL normal and linear
ORM maps. Hull armour uses painted alloy; frame, edge trim, gold and copper
use brushed metal; landing-gear tyres use rubber; cockpit glazing uses glass.
The original colour palette remains the tint. Linear albedo mean normalization
preserves its brightness after sRGB texture decoding. Emissive navigation lamps
retain their clean solid colours.

Hull textures use object-space triplanar sampling because the old mesh has no
tangents and some edge UVs collapse. Normal-map perturbations are projected onto
the existing surface normal and transformed with the model-view normal matrix.
Texture coordinates use object metres, so origin shifts and ship movement do
not cause texture crawling. The optional rock shader restores instance scale
before sampling, without incorporating world translation.

Mipmapped anisotropic filtering and derivative fading limit distant normal
shimmer. Economy quality skips normal sampling; medium quality reduces its
strength. Material cache keys include quality so an economy ship cannot change
a high-quality ship's shading. Standard station and glazing materials use the
engine's triplanar normal and ORM path. Solar-cell grid edges and colour
variation are filtered before they become subpixel.

Validation: `tests/test_space_material_bindings.gd` checks map bindings, palette,
quality isolation and economy fallback. Existing `test_ship_graphics.gd` and
`test_graphics_space_environment.gd` cover geometry, landing gear, engine effects,
docking clearance and deterministic preview placement. Actual GPU screenshots
are needed in addition to these resource contracts; this update does not claim
that textures alone reproduce the reference game's authored models or lighting.
