# タイトル素材

## title-logo.png

現在のロゴはユーザー提供の `image.png`（添付ID `1562228566396239914`）。1789×1304pxの透過PNGを、画素やアルファを変更せずそのまま配置した。赤い円、黒い筆文字、白い縁、金色の手裏剣を含む。画面上では縦横比を保って表示する。

周囲のパーティクルは画像に合わせた金色の手裏剣型とし、ワープの光は暖かい白金色に揃えた。これらはGodotの描画処理で作っており、ロゴ画像には焼き込んでいない。

## 以前のロゴの生成記録

以下は置き換え前のロゴを組み込みの `image_gen` で生成した際のプロンプト。現在の `title-logo.png` には使用していない。

```text
Use case: logo-brand.
Asset type: finished transparent PNG title logo for the 1280×720 start screen of a Japanese 2D space platform game.
Primary request: create a polished, friendly, slightly quirky, hand-drawn game logo. The full official title is 忍者ぶっとびくん Galaxy.
Text (verbatim): first row "忍者ぶっとびくん"; second row "Galaxy". Render every Japanese character correctly, in that exact order; capital G followed by lowercase alaxy. No other words.
Composition: landscape logo, centered, tightly framed with a small safe transparent margin, Japanese row above a slightly smaller Galaxy row. Readable when displayed around 860 pixels wide and 320 pixels tall. The logo itself should be wide, approximately 2.6:1. Make both rows feel like a single cohesive title.
Style/medium: lively hand-lettered rounded Japanese lettering with slightly irregular bold dark ink outlines, big simple color fills, only restrained flat shading, playful old hand-drawn platformer aesthetic. The Japanese lettering is warm cream to soft golden yellow, Galaxy is pale aqua with cream accents. One simple hand-drawn orbital swoosh and a few small four-point stars may integrate with the lettering, without obscuring any characters.
Scene/backdrop: genuinely transparent alpha, intended to sit over a muted indigo and lavender illustrated moon-base starfield.
Constraints: logo artwork only, no background rectangle, no scene, no UI, no START button, no mockup, no watermark, no ninja or other characters. Avoid chrome, glossy 3D bevels, photorealism, strong glow, dense tiny details, and electric neon. Preserve clean alpha at all edges.
```
