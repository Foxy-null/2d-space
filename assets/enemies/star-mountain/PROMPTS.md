# 星間山荒・大赤斑の素材

総称は「UMA妖怪エイリアン」、個体名は「星間山荒・大赤斑」。素材8枚はユーザーが描いたもの。`originals/` は添付PNGのバイト列を変更せず保存している。

| 元画像 | 用途 | 使用画像 |
| --- | --- | --- |
| sozai15.png | 立ち | idle.png |
| sozai22.png | 歩行A | walk-a.png |
| sozai3.png | 歩行B | walk-b.png |
| sozai4.png | ジャンプ | jump.png |
| sozai5.png | 下降 | descend.png |
| sozai6.png | やられ | defeated.png（画素変更なし） |
| sozai_a.png | 長針 | originals/sozai_a.png |
| sozai_b.png | 短針 | originals/sozai_b.png |

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
