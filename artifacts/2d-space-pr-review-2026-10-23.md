# 2d-space PRレビュー結果（2026-10-23 UTC）

開いていた30件（#15〜#44）をレビューし、29件をマージしました。未マージで残っているのは、不具合を実入力で再現した [#21](https://github.com/Foxy-null/2d-space/pull/21) だけです。

- 開始時のmain：`e406a41e879fc77652442c9c6a28f8f5499b74cd`
- 完了時のmain：[`baa9bb357c3fa32b5b7be1871eef89f4258a2cae`](https://github.com/Foxy-null/2d-space/commit/baa9bb357c3fa32b5b7be1871eef89f4258a2cae)
- GitHub APIで29件すべての `merged=true` を確認しました。
- Gitの履歴でも29件の元headがmainに含まれ、#21のheadが含まれないことを確認しました。
- この作業コピーも最終mainまで同期しました。

## 未マージ：#21

**P2：スイッチをOFFにしてからクリアすると、柵が閉じたまま残る。**

対象：[scripts/tutorial.gd:297–302](https://github.com/Foxy-null/2d-space/blob/db68812a39b0668f853b9cb86e38adba38042d08/scripts/tutorial.gd#L297-L302)

柵の状態を更新するのが重量スイッチの変更イベントだけになっています。到着台を押してクリア状態へ変わっても柵を更新しないため、「クリア後は柵を開いたままにして往復できる」というPRの仕様を満たしません。

再現手順：

1. 第12室で箱を投げ、重量スイッチをONにして柵を通る。
2. 通過後に箱を取り直し、スイッチをOFFにする。
3. 箱をスイッチの手前側へ退け、到着台を押してクリアする。
4. クリア済みでも柵が閉じている。Rでやり直しても同じ状態になる。

Godot 4.7.2で実入力を送り、部屋選択のfixture以外は座標・速度・課題実績を直接書き換えずに確認しました。

```text
AFTER_CLEAR cleared=true button=false divider_disabled=false
AFTER_RESET cleared=true button=false divider_disabled=false
```

修正の方向は、クリア・再入場・やり直しにも共通する更新処理で、柵を「スイッチONまたはクリア済み」に同期することです。スイッチOFFのままクリアする回帰テストも必要です。今回はこの修正を加えず、PRを開いたまま残しています。

## レビューとマージの一覧

各PRの説明、正確なbase/head差分、関連する呼び出し元とテスト、README・仕様・用語集、代表的な比較画像を確認しました。表のコミットはGitHubでのマージ結果です。

| PR | 内容 | 結果 | マージコミット |
| --- | --- | --- | --- |
| [#15](https://github.com/Foxy-null/2d-space/pull/15) | 次の反射先と出口を形で伝える | マージ済み | `a190f91` |
| [#16](https://github.com/Foxy-null/2d-space/pull/16) | チュートリアルを短い操作キーと矢印で案内する | マージ済み | `20beebf` |
| [#17](https://github.com/Foxy-null/2d-space/pull/17) | 相棒と運搬先を絵で結び操作説明を減らす | マージ済み | `ddbd68c` |
| [#18](https://github.com/Foxy-null/2d-space/pull/18) | 重力ゲートを使って渡るチュートリアル地形に改善 | マージ済み | `848d34f` |
| [#19](https://github.com/Foxy-null/2d-space/pull/19) | 傘の滑空を地形で学べるチュートリアルにする | マージ済み | `9f0540c` |
| [#20](https://github.com/Foxy-null/2d-space/pull/20) | ステージ選択を小さな遊びの絵で案内する | マージ済み | `d85b5e0` |
| [#21](https://github.com/Foxy-null/2d-space/pull/21) | 投げた箱で進路を開くチュートリアルに改善 | 未マージ：P2の不具合 | — |
| [#22](https://github.com/Foxy-null/2d-space/pull/22) | 相棒の追加ジャンプを安全に繰り返せる配置にする | マージ済み | `9c0c485` |
| [#23](https://github.com/Foxy-null/2d-space/pull/23) | 箱の配置で到着台を開ける運搬パズルにする | マージ済み | `6fe1243` |
| [#24](https://github.com/Foxy-null/2d-space/pull/24) | 塔の復帰地点を旗と印で示す | マージ済み | `f4c6e2f` |
| [#25](https://github.com/Foxy-null/2d-space/pull/25) | 向かい風を地上ダッシュで渡るチュートリアルに改善 | マージ済み | `c43a087` |
| [#26](https://github.com/Foxy-null/2d-space/pull/26) | 床ばねで上段へ進むチュートリアルにする | マージ済み | `a3af9d5` |
| [#27](https://github.com/Foxy-null/2d-space/pull/27) | 到着台の案内を小さな絵と状態表示に整理 | マージ済み | `0f498cd` |
| [#28](https://github.com/Foxy-null/2d-space/pull/28) | クリア後もパッド操作で自由練習を続けられるよう修正 | マージ済み | `d5dd4fd` |
| [#29](https://github.com/Foxy-null/2d-space/pull/29) | 丸いバンパーの反射で広い足場へ進む導入部屋に変更 | マージ済み | `28c7222` |
| [#30](https://github.com/Foxy-null/2d-space/pull/30) | チュートリアルの見出しと出口案内を簡潔にする | マージ済み | `355d401` |
| [#31](https://github.com/Foxy-null/2d-space/pull/31) | 追加ジャンプを広い片面足場で試せる導線に改善 | マージ済み | `aac62c5` |
| [#32](https://github.com/Foxy-null/2d-space/pull/32) | チュートリアル終盤を傘と反転滑空で渡る経路にする | マージ済み | `b32274b` |
| [#33](https://github.com/Foxy-null/2d-space/pull/33) | 追加ジャンプ連携の着地点と再試行床を広げる | マージ済み | `82bf870` |
| [#34](https://github.com/Foxy-null/2d-space/pull/34) | ダッシュ導入の着地場と入力の余裕を広げる | マージ済み | `c37a7f0` |
| [#35](https://github.com/Foxy-null/2d-space/pull/35) | 補充ダッシュから出口へ着地しやすい配置にする | マージ済み | `96ee068` |
| [#36](https://github.com/Foxy-null/2d-space/pull/36) | キーバインド設定追加 | マージ済み | `7e3fa4f` |
| [#37](https://github.com/Foxy-null/2d-space/pull/37) | 棘での復帰後に運搬中の相棒が消える問題を修正 | マージ済み | `8e345cc` |
| [#38](https://github.com/Foxy-null/2d-space/pull/38) | チュートリアル2室目の壁キック経路を矢印で案内 | マージ済み | `147ad82` |
| [#39](https://github.com/Foxy-null/2d-space/pull/39) | 到着台の案内が空中の忍者や持ち物を隠さないようにする | マージ済み | `8b01aed` |
| [#40](https://github.com/Foxy-null/2d-space/pull/40) | 操作設定中の入力が背面のポーズを開閉する問題を修正 | マージ済み | `a810570` |
| [#41](https://github.com/Foxy-null/2d-space/pull/41) | 操作設定とステージ選択をパッドで往復できるようにする | マージ済み | `65e4e3e` |
| [#42](https://github.com/Foxy-null/2d-space/pull/42) | ステージ3の経路矢印を常時表示する | マージ済み | `339855d` |
| [#43](https://github.com/Foxy-null/2d-space/pull/43) | 塔の到着台に重なる頂上案内を削除 | マージ済み | `3f8cba8` |
| [#44](https://github.com/Foxy-null/2d-space/pull/44) | ステージ5の最初のバンパーへの飛び込みを図示する | マージ済み | `baa9bb3` |

## 依存関係と競合の処理

- #40・#41をKeybindへ先に取り込み、設定中のポーズ干渉とフォーカス孤立を解消してから#36をmainへマージしました。
- #19→#30、#39→#27、#30→#27、#38→#16、#27→#16の順に子PRを親へ取り込みました。
- 到着台の描画位置、各部屋の課題、案内位置、シーンのリソース数、READMEのテスト一覧、ステージ選択のカードと設定へのフォーカス経路の競合は、双方の変更を保って解消しました。
- #44では、既存の反射先表示と新しい入口案内の回帰確認を両方残しました。
- #28の仕様文書に残っていた旧帰還操作をY／△へ更新し、通知とボタンの説明も画面に合わせました。

## 検証

Godot 4.7.2 official ARM64を使用し、ユーザー設定は実行ごとの専用XDG_DATA_HOMEへ隔離しました。

- #21を除いた統合構成で、自動テスト38本すべて終了コード0。スクリプトエラー・ERROR・失敗結果はありませんでした。
- 最終mainの実行スクリプト、テスト、project.godotが、この統合構成と一致することを確認しました。
- 最終mainでも関連6本を追加確認しました。詳細は下表に記録します。
- 全変更に対する `git diff --check` が成功しました。
- GitHub上のCIワークフロー・チェック・既存レビューは0件でした。上記は今回ローカルで実行した検証です。

| テスト | 実行方法 | 結果 |
| --- | --- | --- |
| tutorial_spring_route_test.gd | headless | 339 checks成功 |
| tutorial_guidance_test.gd | headless | 421 checks成功 |
| stage_5_test.gd | headless | 4297 checks成功 |
| input_settings_navigation_test.gd | Xvfb/OpenGL GUI | 41 checks成功 |
| input_settings_pause_test.gd | Xvfb/OpenGL GUI | 109 checks成功 |
| stage_clear_test.gd | Xvfb/OpenGL GUI | 71 checks成功 |

GUI実行時の音声はDummyドライバを指定しています。

一部の既存テストには終了時のObjectDB警告があり、今回その原因調査は行っていません。全テストの終了コードは0です。

## 未確認の範囲

Windows実機、物理ゲームパッド、人間による初見プレイは確認していません。GUI検証もLinux/Xvfb上で送った入力イベントによるものです。

今回は新しい用語や設計方針を決めていないため、CONTEXT.mdやADRは追加していません。

