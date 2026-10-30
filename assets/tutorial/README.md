# 第1面の素材

`castle.png` は、ユーザー提供の `ButtobiKun3.0.2(完成！).zip` 内にある前作「忍者ぶっとびくん」の実行ビルドから抽出した城の原画です。

- 元ファイル：`ButtobiKun3.0.2(完成！)/ButtobiKun_Data/sharedassets2.assets`
- Texture2D：`shiro`、pathID 4。対応Sprite：`shiro`、pathID 6。
- 1000×1000px、RGBA。`docs/tutorial-stage-1/castle-source.png` と同一ファイルで、描き直しや切り抜きはしていません。

`bridge-board.png`（96×32）と `rocket.png`（200×320）は、後でユーザーが描き替えるための仮素材です。Python/Pillowで図形として作成しました。生成画像サービスや外部から取得した画像は使用していません。

`bridge-board.png` は厚さ12pxの静止片面足場にも再利用しています。追加の参考画像は保存・素材化せず、薄い木板の特徴だけを差し替えガイドへ記録しています。

`assets/ui/stage_1_clear/` の背景・ロケット・文字も同じ目的の仮素材です。3枚とも1280×720pxで、文字はMeiryoを使って描画しています。手順と実際の配置は [画像差し替えガイド](../../docs/tutorial-stage-1/asset-replacement-guide.md)を参照してください。
