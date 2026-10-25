# 星間山荒・大赤斑の素材

総称は「UMA妖怪エイリアン」、個体名は「星間山荒・大赤斑」。原画19枚はユーザーが描いたもの。`originals/` は添付PNGのバイト列を変更せず保存している。

| 元画像 | 用途 | 使用画像 |
| --- | --- | --- |
| sozai15.png | 立ち | idle.png |
| sozai22.png | 歩行A | walk-a.png |
| sozai3.png | 歩行B | walk-b.png |
| sozai4.png | ジャンプ・壁登りの交互表示 | jump.png |
| sozai5.png | 下降 | descend.png |
| sozai6.png | やられ | defeated.png（画素変更なし） |
| sozai_a.png | 長針 | originals/sozai_a.png |
| sozai_b.png | 短針 | originals/sozai_b.png |
| sozai156.png | 左向きの立ち | idle-left.png |
| sozai7.png / sozai8.png | 運搬歩行A/B | carry-a.png / carry-b.png |
| sozai9.png | ダッシュ | dash.png |
| sozai10_-_.png | スーパーダッシュ | superdash.png |
| sozai11.png | 壁掴み・壁登り | wall-climb.png |
| sozai12.png | 投擲・捕獲後の投げ返し | throwback.png |
| sozai_c1.png / sozai_c2.png | 同じ追尾トゲの待機・飛行 | homing-neutral.png / homing-flight.png |
| sozai_e.png | 固まった灰の雨 | ash-rain.png |
| sozaif.png | 灰の雲のデザイン原本 | ash-cloud.png（許可された生成による清書） |

落下はジャンプ画像を左へ傾ける。やられ画像を落下には使わない。白い顔・骨・爪・衣装は意図した配色として保つ。

## 補正方法と判断

組み込みの `image_gen` で各姿勢の透明背景の補正候補を作ったが、線の太さ・形・塗りまで変わったため、6候補とも不採用とした。CLI/APIへの切り替えや外部依存の追加はしていない。

最終素材は原画を基にGodotのImage処理で局所補正した。透明な1画素の上下左右が同じ茶色系または赤紫系で塗られている場合のみ、その周囲の平均色で埋める。輪郭から完全に離れた1画素の色の点も調べたが、除去する箇所はなかった。白い画素と描線はすべて維持した。

該当箇所はジャンプの元画像 `sozai4.png` の座標 `(56, 224)` にある透明穴1画素のみ。他の5姿勢と針2枚は画素を変更していない。座標は `repairs.json`、原画保持の自動検証は `tests/stage_6_needles_test.gd` に記録した。比較画像は `deliverables/enemy-comparison.png`。

大きい白い隙間や輪郭につながる細い色の線は、模様・毛の描線・意図した余白との区別がつかないため、そのまま保つ。これらの塗り直しは、修正箇所の指定がある場合に行う。

## 使用プロンプト

以下の `{file}` と `{pose}` を、上表のファイル名と `idle / walk-a / walk-b / jump / descend / defeated` に置き換え、元画像1枚を編集対象として渡した。

```text
Edit target: the attached existing hand-drawn game sprite ({file}, {pose}). Perform conservative paint repair only, with a genuinely transparent background. Preserve this exact character, pose, facing, composition, proportions, black sketch outlines, individual hair strands, all anatomical details, original brown/white/magenta palette, and all intentional white face, bones, claws and costume areas. Only fill unmistakable tiny unpainted pinholes inside otherwise solid brown or magenta painted regions using the immediately neighboring color, and remove unmistakable colored overspill outside its enclosing black contour. Do not broadly fill white areas or transparent spaces between limbs/hair. Preserve the rough hand-drawn visual identity: do not smooth, redesign, simplify, add shading, add features or redraw it as a polished illustration. If a white/transparent area is ambiguous, leave it unchanged. Keep the full sprite and a small transparent margin, without any text, guide, floor, drop shadow or background. The result must remain unmistakably the very same original drawing with minimal local repairs.
```

ゲームではGodotのAtlasTextureで透明な余白を除き、縦横比を保って表示する。元PNGの上書きや、姿勢の描き足しは行っていない。

## 追加素材と灰の雲

追加したキャラクター・トゲ・雨のPNGは原本と同一のバイト列。白い体色や描線を塗り直していない。c1/c2は1600×1200の原本を残し、ゲームではトゲ本体の矩形だけをAtlasTextureで表示して離れた下描き線を外す。

灰の雲は前回承認された生成結果 `deliverables/ash-cloud-review/ash-cloud-base.png` を採用し、`ash-cloud.png` にコピーした。`ash-swirl.gdshader` が4つの渦と黄色い流れを4秒で循環させる。原本のsozaif.pngはそのまま保存。生成時のプロンプトは次のとおり。

Use case: style-transfer.
Asset type: transparent 2D game effect sprite, a single base cloud for a smoothly animated ash-cloud attack.
Input image 1 is the EDIT TARGET and design reference: the user's sozaif.png ash-cloud sketch. Edit ONLY this cloud. Preserve its broad horizontal shape, warm dark ash-gray body, and sulfur-yellow / gold swirling streams.
Primary request: turn the sketched cloud into a clean, convincing, readable, swirling ash cloud suitable for a hand-drawn 2D platform game. One long irregular cloud, approximately 3:1 aspect ratio. Dense rolling gray ash, rounded billowing folds, a few feathered wisps, and three or four distinct eddies along its width. The eddies should be curls in the ash itself, with thin yellow wind ribbons following the curls. Keep yellow secondary to the gray cloud. Flat hand-painted game art with 3–4 gray shading tones and subtle hand-drawn contours, not photorealistic smoke and not a polished sci-fi nebula.
Composition: entire single cloud centered in the canvas, horizontal, fully contained with clear transparent margins on every side. Do not clip any end. No grid or sprite sheet in this image; this is the clean base sprite that will be animated afterward.
Palette: warm charcoal and ash gray, with yellow-ochre and vivid sulfur-yellow accents as in the user's drawing. No blue, red, purple or white glow.
Constraints: genuinely transparent background, no white backdrop, no checkerboard painted into the image. No characters, no enemy, no rain spikes, no text, no labels, no lightning bolts, no ground, no scenery, no borders or watermark. Preserve the identity of the user's gray-and-yellow cloud while improving the cloud folds and spiral readability.


`poses.json` は原本のファイル名、足元・胴体の基準点、軌跡を除く換算身長を記録する。表示の基準は128px。描画上の倍率は同じ身体の大きさになるよう調整し、横長のやられ姿勢を無理に縦へ引き伸ばさない。
