# 過酷な惑星の見本：生成記録

内蔵の `image_gen` を使用。ユーザーから「もっと過酷そうに」「溶岩がぐつぐつ煮えたぎってそうな星」「邪悪なオーラの満ちた星」という修正があり、初回の穏やかな荒野に代わる2つの見本を作成した。

画像：[harsh-planets.png](harsh-planets.png)、1254×1254px。上段が煮えたぎる溶岩、下段が邪悪なオーラ。2つは環境の題材案であり、描き込みA・Bの比較ではない。いずれも採用したAの絵柄を基準にする。

参照画像：

1. `environment-examples.png`：同じ構図とギミックの外観の参照。右下の荒野より強く過酷さを出す。
2. `gimmicks-a.png`：採用した絵柄と機能の記号。

生成元：`exec-e00b83b1-6300-46b2-a134-710b851a7685.png`。

画像は環境の見た目を比較する概念図。溶岩や瘴気のダメージ判定・作用領域、実際のステージ構成を決めるものではない。実寸での通常重力・反転時の視認性は未確認。

## 使用プロンプト

```text
Use case: stylized-concept.
Asset type: revised harsh-planet art-direction comparison for the hand-drawn 2D platform game Ninja Buttobi-kun Galaxy.
Input images: Image 1 is the existing environment-board reference. Its bottom-right barren planet was TOO MILD and must be replaced by much more visibly hostile worlds. Image 2 is the APPROVED A game-gimmick drawing style and functional silhouettes.
Primary request: create ONE comparison board with TWO LARGE matched wide side-view gameplay scene mockups, stacked vertically. TOP: a fiercely boiling LAVA planet. BOTTOM: a planet suffused with an unmistakably EVIL AURA. The environments must look profoundly inhospitable at a glance, far more severe than the tame brown wasteland in Image 1. Preserve approved A's simple hand-drawn rendering; severity comes from strong silhouettes, big flat color masses, bubbling lava and oppressive atmosphere, not realistic rendering or extra fine detail.
Exact labels outside the play areas, verbatim: "過酷な惑星：煮えたぎる溶岩" and "過酷な惑星：邪悪なオーラ". No other text, HUD or watermarks. Target 1536 x 1536, white narrow margins and two landscape panels, each with a clear game-screen frame.

Shared composition and invariants:
Use the same basic broad floor with a middle gap, left ceiling ledge and right wall/low ledge as Image 1's bottom-right scene. Strict front-facing 2D side view, no isometric view or diorama. Preserve recognizable gameplay objects in identical relative positions and colors in both scenes: small indigo ninja on left, red flat directional spring paddle with visible gray coil, floating mint double-chevron dash pickup, violet spring-sole boot air-jump pickup, open coral gravity-up arc and open cyan gravity-down arc with their arrow directions, round gold finish pad with two footprints and little checker flag on right. Keep portal centers visibly open. Keep all functional silhouettes and cue symbols, no themed replacements that obscure their roles. Supporting mounts may use the local rock. Leave out the little wind vent so atmosphere is not confused with an active wind gimmick.
Ninja remains the same rounded indigo character with gray gloves/feet, cream face and simple eyes, same small gameplay scale. No equipment or costume redesign. No new characters, monsters or NPCs.

TOP, lava planet:
An enormous visibly CHURNING molten landscape dominates the background and the depths behind the foreground gap. Bright flat orange-red magma with thick yellow-orange scalloped edges, a few LARGE round boiling bubbles rising or bursting, two or three simple droplets and a broad molten surge. Big jagged black/charcoal volcano silhouettes with wide orange eruption mouths, thick dark red-brown smoke clouds occupying much of the sky, a huge cracked fiery planet in the distance. Main foreground platforms are black basalt blocks with readable muted gray-brown contact caps; a small number of wide burnt orange cracks confined to decorative side faces. Strong black and orange masses give extreme heat, instability and total absence of habitation. Lava should occupy a substantial visible area and feel like a huge boiling cauldron, not a tiny decorative orange strip. Keep silhouettes clean and shapes large, no dense sparks, realistic lava texture, cinematic glow, photorealistic lighting or gradients. Foreground playable contact surfaces remain clean and unobstructed by lava.

BOTTOM, evil-aura planet:
Deep plum and near-black sky with a giant ominous black celestial disk encircled by a lopsided violet whirlpool/eclipsed halo. Large curled ribbons of dark purple miasma coil around distant crooked rock spires and across the valley; several strong broad shapes convey an oppressive, cursed landscape. A few violet fissures in distant cliffs, hostile hooked silhouettes, barren black-purple foreground rocks with a simple lighter stone cap so contact surfaces remain readable. The mood must be sinister and suffocating, not a gentle lavender evening. Dense atmosphere expressed with flat layered shapes, no volumetric fog or neon bloom. No monster faces, eyes, skulls, blood, horror creatures, active lasers or magical collectible orbs. The evil aura is environmental scenery, not new equipment or a new enemy mechanic. Leave space and quieter contrast immediately behind important gadgets so their violet, mint, coral and cyan cue colors still read.

Style:
Gently uneven dark hand-drawn outlines, big mostly flat color fields, at most one small secondary tone per material, VERY few cracks or surface marks, original modest handmade game art. Simple readable cartoon shapes can convey genuine menace and heat while staying in the same drawing style as the earlier friendly worlds. Background outlines weaker than foreground, but do NOT mute the world's visual harshness into pastel safety. No glossy 3D, realistic texture, paper grain, painterly shading, heavy gradients, cinematic lighting or clutter. Avoid decoration on collision edges that suggests different playable geometry.
These are atmosphere and art-direction concepts, not implementation of damage rules. Do not add spikes, enemies, moving floors, new gates or new interactable objects. Output a single crisp two-panel comparison board.
```

