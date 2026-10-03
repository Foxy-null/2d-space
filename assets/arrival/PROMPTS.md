# 到着台の画像

ユーザーの添付図（深く沈む赤いボタンと灰色の台座、透明ケースと黄色い南京錠）を参照し、組み込みのimagegenで生成したRGBA画像です。

`arrival-switch-atlas.png` は1536 × 1024px。上段は台座・ボタン・ガラス、下段は閉じた南京錠・開いた南京錠です。
`scripts/arrival_switch.gd` が各領域を切り出して描画します。押し込みではボタン下部を隠し、ケースと鍵は解錠時に消えます。

## 生成プロンプト

```text
Use case: stylized-concept.
Asset type: one production-ready transparent 2D game sprite atlas for a side-view tutorial arrival switch.
Input images: Image 1 is the user's mechanical reference (red thick button pushed deep into gray base); Image 2 is the user's locked glass-case and yellow padlock reference. They are design references, not edit targets. Preserve their recognizable geometry and colors.
Primary request: turn these rough sketches into charming polished chibi/cartoon game art. Chunky rounded shapes, thick smooth dark navy outlines, simple clean cel shading, bright highlights, readable at a tiny game scale. Front orthographic side-platformer elevation, straight horizontal top edges for a player to stand on. Mild dimensional depth from shading only; no perspective skew or isometric view.
Scene/backdrop: genuinely transparent RGBA background. Exactly one 1536x1024 atlas, three equal 512px columns and two equal 512px rows. Keep every part completely inside its own cell, centered, with generous transparent padding and NO overlap.
Composition, cell contents:
TOP LEFT (cell 0,0): only a broad gray-blue metal pedestal/base, approximately 380px wide and 98px tall. Rounded thick navy outline, two simple inset bolts near bottom corners, a dark narrow horizontal socket along the top where the red cap slides down. NO red button, no glass, no lock.
TOP CENTER (cell 1,0): only a tall red chunky rectangular button cap, approximately 320px wide and 166px tall. Very rounded corners but a broad flat horizontal standing surface; bright coral-red rounded narrow top face, deep red vertical front, one bold creamy curved highlight near upper right, subtle side shading. No base, no glass, no lock, no symbols or writing. This cap will move down into the base.
TOP RIGHT (cell 2,0): only a transparent glass safety cover, approximately 360px wide and 220px tall. A squat rectangular dome/box matching the second sketch, gently rounded corners, thin chunky pale blue edge frame, a few broad diagonal milky-white reflection strokes at the sides. The broad center must remain mostly transparent so the red button can show through when composited in game. Empty inside. No button, no base, no padlock. Do not fill the cover with opaque white.
BOTTOM LEFT (cell 0,1): only one big cute yellow/golden CLOSED padlock, approximately 190px wide and 240px tall. Thick curved closed shackle, rounded square gold body, large simple dark navy keyhole, bold white/gold highlights. No key, no glass, no stand.
BOTTOM CENTER (cell 1,1): the same padlock design, same body proportions/colors/view, but UNLOCKED with shackle lifted and swung open to the right. Clearly visible open gap; suitable to swap during a cheerful unlock animation. Approximately 190px wide and 240px tall.
BOTTOM RIGHT (cell 2,1): completely empty transparent cell.
Constraints: exactly the five separate requested sprites. Matching illustration style and outline weight across all five. No cast shadows outside sprites. No characters, arrows, instructional text, labels, checkerboard pattern, decorative background or extra objects. Preserve actual alpha transparency, including the translucent glass. Crisp export-ready art.
```

## 透明度を調整したプロンプト

```text
Use case: precise-object-edit. Edit this generated 1536x1024 game sprite atlas. Preserve every part's exact shape, location, size, colors, cel shading, heavy navy contour, and the three-column/two-row arrangement. Change ONLY transparency:
1. Completely remove ALL blurry glow/halos/shadows surrounding the five sprites. The space outside each hard-edged navy contour must be true alpha=0. No fuzzy colored haze. Opaque sprite interiors for pedestal, red button and two locks.
2. The glass cover in the top-right cell is currently too opaque. Keep its blue edge frame and broad white reflection strokes crisp, but change the large flat blue interior pane to very faint pale blue with alpha around 0.12 to 0.18; a red button placed behind it must be clearly visible. It is an empty transparent safety cover.
3. Keep the empty lower-right cell and all atlas padding fully transparent. No checkerboard, no text, no new sprites. The two padlocks' shackle holes must be transparent.
Output genuine RGBA transparency for production game use.
```
