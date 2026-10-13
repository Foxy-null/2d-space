# 絵柄の比較サンプルの生成プロンプト

組み込みのimagegenで作成した方針検討用の画像。ゲームへ組み込む素材ではない。

`sample-a.png` は前作と同程度の描き込みを目指した新しい宇宙基地の案。現作の部屋を構図の参照にし、前作の忍者・城・木の壁・足場を描き方の参照にした。

`sample-b.png` はAを編集し、輪郭・配置・色を揃えながら、地形と到着台などに控えめな陰影と細部を加えた案。どちらも1536×1024px。画像生成による比較案であり、原画やゲーム画面そのものではない。

## A

参照画像の順序：現作 `docs/screenshots/stage-2/room_1.png`、前作の忍者の復元画像 `docs/sprites/legacy-character-poses.png`、添付ZIPから抽出した前作素材の参照一覧。

```text
Use case: style-transfer.
Asset type: game art direction sample A for the Japanese 2D platformer "Ninja Buttobi-kun Galaxy", a controlled comparison of two rendering densities.
Input images: Image 1 is the current gameplay screenshot and EDIT TARGET / layout reference. Image 2 is the ORIGINAL CHARACTER STYLE REFERENCE, a sheet of the authentic ninja poses. Image 3 is the ORIGINAL ENVIRONMENT STYLE REFERENCE containing the hand-drawn ninja, castle and wooden platforms. Do not reproduce the reference sheet or its labels; do not import a castle or Japanese architecture.
Primary request: make a clean landscape art-direction board for option A, faithful to the original game's modest hand-drawn black outlines and mostly flat coloring. Upper roughly two thirds: the same room from Image 1 reskinned as an early-game space base. Lower roughly one third: two large isolated detail views on a plain pale warm-gray background, the platform/wall surface on the left and the red arrival switch on the right. One small label "A" at the upper left. No other words, text, HUD, marketing graphics, logos or watermark.
Scene: friendly, slightly odd outer space, muted navy-purple sky, sparse simple dots for stars, one small pale moon and one small muted ringed planet, low contrast. Treat them as simple drawn shapes, no realistic astronomy textures. The main gameplay background remains mostly open.
Preserve the room's large-scale obstacle layout, horizontal floor, hanging wall from the ceiling near the left third, upright central wall, the small standing ninja at bottom left, the upward red and downward cyan pass-through gravity gates, lime spring pad, and the arrival switch at bottom right. View must be strict front-facing side-scrolling 2D, no perspective camera, no diorama, no depth of field. Convert the blue solid rectangles into broad cream-gray space-base panels with a few short seam lines and one or two large bolts. Keep horizontal walkable surfaces and vertical kickable surfaces visually exact and uninterrupted. Outline both floor and ceiling contact edges. Decorative dents and seams must remain inside surfaces and not become holes.
Character: use the authentic Image 2 standing ninja without redesign, extra armor, lighting, visor, scarf or new costume. Same round head, short limbs, indigo outfit, gray hands and feet, cream face, simple black eyes and the same pose. It is a comparison anchor and must remain drawn in the source style. No additional characters. Do not include or redesign the green creature or red umbrella.
Arrival switch: preserve the actual mechanic: a low broad gray or cream rectangular pedestal with a recessed socket, and a chunky flat-topped red pressable cap that sinks into it. Flat front view, minimal subtle top plane, a simple cream star emblem on the front. No launch rocket, no staircase, no chest. Show the same switch enlarged in the lower right detail view. Mostly flat red cap and gray base, small black outline and two simple bolts; no glossy white highlight streak, chrome reflection or glow.
Option A rendering: keep the original game's slightly irregular dark outlines, simple unevenly spaced seams and broad plain color regions. Sparse surface marks, restrained colors. Only tiny flat secondary tone where needed to distinguish a lip or rim, as in the original wood and castle; NOT a cel-shaded upgrade. Lines should have gentle hand-drawn wobble, without becoming furry or sketchy. Do not copy compression artifacts from the source extraction. Match the ninja's level of finish. No paper grain, no watercolor, no painted texture, no polished vector icon aesthetic, no shiny mobile-game aesthetic, no complex metal plating, no grunge, no volumetric lighting, no nebula, no bloom.
Output: one crisp 1536 by 1024 landscape board, opaque background. The board must be useful at normal gameplay scale and in the two enlarged object details. The enlarged details must depict precisely the same objects and same drawing density used in the main scene.
```

## B

編集対象：生成した `sample-a.png`。

```text
Use case: style-transfer.
Asset type: game art direction sample B, the controlled slightly richer variant of the provided sample A.
Input image: Image 1 is the EDIT TARGET, sample A. It is a landscape comparison board with a side-view space-base game room above and two enlarged object details below.
Primary request: preserve this board essentially exactly, changing ONLY the rendering density of the environment and arrival switch from mostly flat to modestly more detailed hand-drawn game art. Change the little upper-left letter "A" to "B". This is a deliberately small upgrade, not a different art style.
STRICT INVARIANTS: same 1536 by 1024 canvas, same board structure and framing, same floor height, wall shapes, platform contact edges, every object silhouette, scale and position, identical sparse star positions, same moon and ringed planet and backdrop colors. Keep the original ninja in the bottom-left of the scene completely unchanged in appearance, pose, colors, location and flat drawing style. Keep the gravity arrows and green spring shape and colors unchanged. Do not insert any additional objects, rocks, props, characters, labels or HUD. Do not redesign anything. Keep the slightly uneven black hand-drawn linework and muted palette. The room above and enlarged details below must show the same rendering treatment.
Allowed changes are a few small flat-color planes and a few simple surface marks:
1. Cream-gray floor and walls: a narrow lighter rim at exposed panel edges, a narrow slightly darker flat shade on a lower or right interior edge, a handful of short panel-joint marks or restrained tiny screw details. Broad main areas remain plain. Contact boundaries and silhouettes remain fixed.
2. Arrival switch: red cap gets a small dark-red lower/right shade plane and one restrained dull coral highlight plane; gray base gets a short darker lip/socket shade and a tiny lighter edge. Any highlights are flat color strokes, not reflections. Keep the cream star emblem exactly. No white gloss streak, shine or metallic lighting.
3. The background planets may get at most one small flat secondary tone and a few simple surface marks, without changing their outline, location, color family or contrast. Keep the sky and star distribution unchanged.
Draw it as if the very same person who drew the original ninja added just a little depth to the surroundings. The added shading should remain in small areas and not dominate the flat color regions. It should stay comfortable beside the unchanged ninja.
Avoid: gradients added to objects, painterly lighting, 3D render, photorealistic textures, bloom or glow, ambient occlusion, cast shadows extending out into the scene, chrome, complex panel grids, heavy weathering, paper grain, watercolor, smooth vector illustration, a polished mobile-game/chibi redesign. The expected difference is visible but restrained.
```
