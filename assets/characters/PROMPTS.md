# キャラクター画像の出典と生成プロンプト

前作の `tachi`、`aruki`、`aruki2`、`jamp`、`kouka`、`rakka` は添付Unityビルドから抽出した。切り出しと共通キャンバスの位置は `legacy-source.json` に記録している。

補完画像には組み込みの `image_gen` を使用した。CLI/APIの別経路は使っていない。生成時の透明度を保持し、シートをコマ単位に切り出してGodotへ取り込んだ。

| 生成シート | ゲームで使う画像 |
| --- | --- |
| `ninja-supplement.png` | `wall-a.png`、`wall-b.png`、`carry-a.png`、`carry-b.png` |
| `jump-creature.png` | `jump-creature-rest.png`、`jump-creature-active.png` |
| `red-umbrella.png` | `red-umbrella-rest.png`、`red-umbrella-active.png` |

衣装の色は画像を再生成せず `outfit.gdshader` で切り替える。通常時は元の藍色をそのまま表示し、Dash使用済みのときだけシアンにする。元の6姿勢の布の形・顔・手足を保つ。

## 忍者の壁登り・運搬

入力参照：`docs/sprites/legacy-character-poses.png`。`transparent_background = true`。

```text
Use case: identity-preserve. Asset type: transparent 2D game character sprite sheet, exactly FOUR key poses in a regular 2 by 2 grid. Reference image is the original ninja identity and drawing style, NOT an edit target background. Create the missing wall climbing and overhead carrying poses for exactly the same small hand-drawn ninja. Preserve the original indigo/navy fabric color, grey mittens and boots, pale skin, simple determined black eyes, headband, proportions, broad head, and imperfect thin dark pencil outlines with flat fills; do not modernize, shade, add equipment or render in 3D. Canvas 1024x1024, four equal 512x512 cells. Every pose has the SAME scale: about 350 pixels body height, feet at y=425 within its cell, body center at x=256. No labels, borders, background, objects or contact shadows; actual transparent background. Top left: wall grip A, facing RIGHT, both grey hands forward gripping an imaginary vertical wall just in front of the body, one knee bent. Top right: wall climbing B, same right-facing hands and torso, alternate knee raised for a clear 2-frame climbing loop. Bottom left: carrying walk A, both hands raised symmetrically above the head as if supporting a large object from underneath, feet in walking contact A. Bottom right: carrying walk B, identical raised arms/head with opposite feet in walking contact B. The invisible carried object is NOT drawn. Use key poses, not in-betweens. Keep each whole ninja within its own cell with at least 50 pixels of transparent margin and do not crop any limbs. Only the four missing poses; do not redraw the existing reference poses.
```

## 緑の生物

入力参照：`docs/sprites/legacy-character-poses.png`。`transparent_background = true`。

```text
Use case: illustration-story. Asset type: transparent 2D game creature sprite sheet, exactly TWO key poses side by side in two equal square cells. The reference is only for the game's hand-drawn style: thin imperfect dark pencil outline, plain flat muted fill, simple black oval eyes, no gradients. Create a small friendly GREEN ear-tipped creature, recognizably a squat rounded square body with two small triangular ears, short feet and a simple face. Do not add a ninja costume or human proportions. It is an item the ninja carries over its head, and grants an extra jump. Canvas 1024x512; each 512x512 cell has the creature centered at x=256 with feet at y=425. Both frames have same width approximately 350px and same shape identity. Left: resting key pose, square-ish squat body, alert open eyes and feet together. Right: extra-jump reaction key pose, same width, a slight squash in the torso and bent short feet, eyes bright and ears lifted; keep motion small enough for a 2-frame loop to look natural. Draw just one creature per cell, completely isolated. Actual transparent background; no labels, no scenery, no shadow, no glow, no arrows, no extra characters, no sheet borders. Preserve green as its ability-identifying color.
```

生成後、反応コマの外側に現れた浮遊線を取り除いた。画像の身体部分を保つ編集で、最終シートには浮遊線を含めない。

```text
Use case: precise-object-edit. Edit this transparent TWO-frame green creature sprite sheet. Remove only the four floating black excitement/motion lines outside the ears of the RIGHT frame. Keep every pixel of both creature bodies, ears, eyes, feet, style and poses unchanged. Do not shrink, enlarge, redraw, move or add any character. Keep the two equal cells and the same transparent background. Only remove the detached marks outside the creature so both frames contain only the creature silhouette and work as a consistent-width two-keyframe game animation. No new symbols, labels, shadows or background.
```

## 赤い和傘

入力参照：`docs/sprites/legacy-character-poses.png` とユーザー添付の唐傘お化け画像。`transparent_background = true`。

```text
Use case: illustration-story. Asset type: transparent 2D game red Japanese umbrella-creature sprite sheet, exactly TWO key poses side by side. Image 1 is the mandatory drawing STYLE: the original ninja game's thin rough black pencil contours and simple flat fills. Image 2 is the SUBJECT reference: a RED Japanese karakasa umbrella yokai, one big pale oval eye with a black pupil, a long pale tongue, red traditional paper canopy with subtle wooden ribs, a little brown handle/one leg. Adapt the reference subject to Image 1's 2D hand-drawn style; no 3D, no painted texture, no glossy rendering. This is the parachute item held above the ninja, and must be noticeably broad when opened. Canvas 1024x512, two equal 512x512 cells, subject centered on x=256 with lowest handle point at y=425 in each. Left key pose: relaxed half-open but already broad conical RED paper umbrella with one large eye and small dangling pale tongue, a short central handle/leg below; max canopy width about 350px, total height no greater than 390px. Right key pose: wind-catching fully opened RED Japanese paper umbrella, canopy about the SAME 350px width, slightly flatter and lifted ribs, same eye/tongue/handle identity, handle bottom at the SAME anchor. Small clear key pose difference, not a redesign. Keep umbrella area wide enough to visibly shield the ninja below, unlike a skinny cone. Transparent margins between the frames, no overlap across cells, no cropped parts. Actual transparent background; no ninja, background, labels, shadows, decorative sparkles, watermarks or grid. Do not add other characters.
```

シートの実出力サイズは指定した目安と異なるため、実画像の2×2／2×1の区切りから取り込んでいる。透過余白の切り出しと拡大率は表示時に処理し、傘の開閉でも表示幅90pxと持ち手の接点を保つ。
