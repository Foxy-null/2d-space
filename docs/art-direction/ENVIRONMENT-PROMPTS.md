# 環境別のデザイン見本：生成記録

内蔵の `image_gen` を使用。Aのギミック見本と前作の忍者を参照し、同じ構図・機能の記号で4つの環境を比較する見本を生成した。初回の岩肌と遠景の描き込みを減らす編集を行い、編集後の画像を採用した。

採用画像：[environment-examples.png](environment-examples.png)。画像は描き方を確認する概念図であり、既存の部屋の配置図やゲームへ置くスプライトではない。実際の忍者には既存のスプライトを使う。

その後、ユーザーから過酷な惑星をより過酷そうにする指示を受け、右下の穏やかな荒野に代わる [溶岩・邪悪なオーラの見本](harsh-planets.png) を作成した。この記録は初回の4環境比較の生成過程として残す。修正後のプロンプトは [過酷な惑星の生成記録](HARSH-PLANETS-PROMPT.md) を参照する。

## 初回生成

参照画像：

1. `docs/art-direction/gimmicks-a.png`：採用した形・機能の記号・描き込みの基準。
2. `docs/sprites/legacy-character-poses.png`：前作の忍者と絵柄。

生成元：`exec-ecc69408-9c67-43c7-b688-d5e9e0796f9d.png`。

```text
Use case: stylized-concept.
Asset type: final environmental art-direction comparison for the Japanese 2D platform game Ninja Buttobi-kun Galaxy.
Input images: Image 1 is the APPROVED game-gimmick shape and flat-rendering reference, "A｜前作寄り", containing sixteen numbered objects. Image 2 is the original ninja pose/style reference. These are visual references, not sheets to reproduce. All sixteen items are not required in each scene; use a small representative shared set.
Primary request: create ONE landscape comparison board containing FOUR matched side-view gameplay scene mockups in a clean 2 by 2 arrangement. These demonstrate environmental progression while keeping the same recognizable gimmicks and original modest hand-drawn art style. Exact panel labels, placed outside the play areas: "宇宙基地", "生活圏のある惑星", "未開発の惑星", "過酷な惑星：荒野の例". No other explanatory text, numbers, HUD, logos or watermark. Target 2048 x 1536 landscape, spacious distinct panels. This is a concept comparison, not a redesign of the approved objects.
Shared scene composition: strict front-facing 2D side-scrolling platformer camera, broad ground with one moderate gap, a low ledge and one vertical wall/hanging ceiling ledge for gravity play, a small authentic indigo ninja near the ground on the left, an open gravity-up portal near the middle and gravity-down portal toward the right, a compact spring pad, a floating mint double-chevron dash charge and a violet spring-sole boot jump charge, a round gold footprint finish pad on the right. Keep the same basic layout and object silhouettes, functional markings and colors in ALL FOUR panels so the differences can be judged. No isometric terrain or camera, no diorama, no deep perspective, no painterly landscape.
APPROVED SHAPES MUST MATCH IMAGE 1:
- Gravity portals: two disconnected coral or cyan arc emitters with a visibly empty pass-through center and the appropriate vertical up/down arrow. They are NOT solid panels or closed doors. Do not join them with opaque colored fill.
- Dash pickup: small floating mint capsule/comet with two forward chevrons, no pedestal, NOT a diamond.
- Air-jump pickup: a violet boot with springy sole, no pedestal, NOT an octagonal badge.
- Directional spring: a flat contact paddle mounted on a visible coil spring with one clear launch-direction mark, NOT a bare freestanding arrow.
- Finish pad: low round cream/gold plate with two footprints and a small checker pennant, plate can sink into the base. NOT the old red rectangular switch, no spring under it.
Keep these cue colors and physical silhouettes shared across environments. Change only the nonfunctional mounting/base materials, the terrain and distant scenery. A gold finish pad may be mounted to metal decking, a maintained stone plinth, a rough rock support or a weathered support, but stays the SAME recognizable footprint pad.

Four environmental examples:
TOP LEFT, "宇宙基地": orderly cream and gray metal decking and pillars, few simple seams and large bolts, sparse antenna silhouettes and simple space-base structures in the low-contrast distance. Muted navy-purple space beyond, a few sparse stars and a simple flat moon. Friendly and maintained. Clear walkable/ceiling surfaces.
TOP RIGHT, "生活圏のある惑星": maintained stone-and-earth platforms with some grass on decorative edges, a few simple rounded space houses, a bridge and cultivated garden plots in the FAR BACKGROUND only, communicating everyday habitation without adding NPC characters. Quiet muted blue-violet sky and a simple distant planet/moon. The shared gadget mounting bases look maintained and sit naturally on the terrain. No Japanese castles, shrines, torii or traditional architecture.
BOTTOM LEFT, "未開発の惑星": irregular natural rock masses on the SIDE FACES, a few odd-shaped alien plants in the distant background and sparse vegetation, no houses or cultivated fields. Muted dusty lavender/ochre terrain palette. The approved gadgets remain intact, supported on simple rock-set mounts. Natural cliff forms feel wilder, but all playable tops and kickable vertical contact faces stay clear and relatively straight.
BOTTOM RIGHT, "過酷な惑星：荒野の例": barren weathered rock, larger angular crags and deeper-looking gaps in the scenery, almost no vegetation or habitation, a sparse wind stream marked by a small vent with visible flow lines, drawing on the existing wind gimmick. Desaturated rust/gray and muted plum sky, slightly more severe terrain silhouettes yet still friendly and slightly odd. Weathered mounts can have a few simple chips on decorative sides, never unreadable function markings. This is only a representative harsh environment, not a fixed assignment to an actual stage.

Style throughout: match the original ninja and approved A. Gently uneven black/dark outlines, broad mostly flat color regions, very few surface marks, only tiny secondary tones for necessary separation. Keep distant background detail/outline contrast lower than active terrain and interactive objects. Do not add paper texture, realistic materials, complex sci-fi paneling, high gloss, dramatic cinematic light, gradients on objects, bloom, neon, 3D rendering, volumetric effects or dense decorative clutter. The original ninja's round head, short limbs, indigo clothes, gray hands and feet, cream face and simple eyes must remain faithful and unredesigned across panels. Character size approximately 7 percent of each viewport height, at gameplay scale, not a giant mascot.

No new mechanics: do not add enemies, spikes, damaging lava, lasers, keys, moving platforms or breakable floors. Danger here is conveyed by the environment and existing gaps/wind, not by invented hazards. Do not add new character equipment. Avoid decoration on contact edges which suggests a different collision shape. All four scenes should look as though one original hand-drawing artist drew them in one game. Output a single clear cohesive comparison board.
```

## 描き込みを減らす編集

参照画像：

1. 初回の環境比較画像：編集対象。
2. Aのギミック見本：絵柄と形の基準。
3. 前作の忍者のポーズ一覧：キャラクターの参照。

採用した生成元：`exec-0ce91745-fbcf-42e0-815d-074817cdd5d6.png`。

```text
Use case: style-transfer.
Asset type: environmental comparison board for Ninja Buttobi-kun Galaxy.
Input images: Image 1 is the edit target, a four-panel environment board. Image 2 is the APPROVED A game-gimmick drawing style and silhouettes. Image 3 is the original ninja identity and modest drawing style.
Primary request: simplify the rendering of Image 1 to match the restrained flat hand-drawing of approved A and the original game. Preserve the four-panel composition, Japanese labels verbatim, foreground layout, scene subjects, all gadget shapes, cue colors, arrow directions and finish footprints. Preserve the environmental progression and terrain collision outlines.
Make terrain side faces large flat color regions with only a FEW broad lines or marks for stone, earth, or metal; remove dense cracks, small pebble dots, many shaded facets, decorative mottling and smooth gradients. Use one flat base tone and at most one small secondary tone for separation. Simplify distant scenery into a few muted silhouettes with weak outlines, rather than numerous detailed layered crags, buildings or plants. Reduce background bridges directly aligned with the foreground gap: remove those narrow bridge spans so no bridge looks like a playable route across the gap; retain other distant buildings as habitation cues. Keep the actual foreground gaps open and readable. Keep simple unusual alien plants.
The four ninja figures must preserve the original reference's rounded indigo head and clothes, gray gloves and feet, cream face and simple eyes; tiny same size and existing positions, no new costume or equipment. Do not make them chibi mascots.
The rock-and-earth supports of the goal and spring should stay simple and integrated with their environment; gadget functional bodies and marks retain their same recognizable A appearance across all four.
Keep exact labels: 宇宙基地; 生活圏のある惑星; 未開発の惑星; 過酷な惑星：荒野の例.
Avoid: realistic texture, paper grain, painterly gradients, new gimmicks, hazards, characters, redesigns, extra text or HUD. Output one cohesive simple four-panel comparison board.
```

