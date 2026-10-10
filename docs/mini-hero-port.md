# ミニ勇者バトル：4-1.htmlのGodot 4移植記録

今回の正本は、元の開発者と連絡が取れたあとに受領した **4-1.html**。以前の途切れた添付から作った仮の戦闘進行・装備・成長・報酬を置き換え、正本にある処理を移植した。元の数値や条件を独自に調整していない。

作業ブランチは `feat/stage-2-level-design`。今回mainへの切り替え・マージ、コミット、pushは行っていない。既存アクションのプレイヤー、ステージ、ギミック、HUDは変更していない。

## 正本と旧資料

- 正本：[games/mini_hero/source/4-1.html](../games/mini_hero/source/4-1.html)、92,089バイト。添付をバイト単位で保存し、内容を修正していない。
- SHA-256：`a9505da5a7fe8f70cb5438f5ad8c8de8f3790156104742832f68e6faa0f6b467`
- JavaScriptとHTMLの終端まで存在する。全文の構文確認と、Chromiumでの起動・初戦表示を確認した。
- 旧資料 [source/4.html](../games/mini_hero/source/4.html) は受領履歴として残している。ゲームと比較テストの移植元には使用しない。
- 旧資料の切断位置までのコードは正本にも含まれ、正本の続きで僧侶の技、LIMIT、道具、ターン、報酬、経路、クエスト、図鑑、開始処理を確認できた。以前の「未受領」「仮実装」という分類は今回の移植に引き継がない。

## 実装した機能

| 機能 | 正本から移植した内容 |
| --- | --- |
| 開始・進行 | 難易度4種、3人パーティ、生存者の行動順、MP不足時の不消費、行動者の毒、敵ターン、勝敗、再開、階層移動 |
| 戦闘 | 通常攻撃・防御・基本魔法、弱点・耐性、会心、反射、かばう、行動不能、敵強化、敵行動予告とパターン、通常敵10種・ボス4種 |
| 技・LIMIT | 各職業9種、計27技と9LIMIT。使用Lv・MP、LIMIT100の条件、範囲攻撃・補助・回復・蘇生・ゲージ消費、対応するツリー強化 |
| スキルツリー | 45項目。消費SP・前提・習得・能力加算・対応する効果の参照 |
| 装備 | 基本装備31種、接頭効果12種、ランダム装備生成、所持数、装備交換・解除、職業条件、セット効果、能力増減とHP・MPの上限処理 |
| 道具・製作 | 道具10種、素材5種、道具レシピ6種、装備レシピ25種。使用効果・所持数・素材検証と消費 |
| 勝利・成長 | 敵撃破記録、EXP・Lv・SP、職業別成長、戦後回復、素材・装備ドロップ、3階層目の製作支給 |
| 経路・イベント | 10経路、支給品4択、泉・宝箱・祠、経路による敵・報酬補正、ボス直前の経路固定 |
| クエスト・図鑑 | 36クエストの解放条件・進捗・一度だけの受取、固定／重み付きランダム報酬、敵撃破数と図鑑表示 |
| 画面 | 難易度選択、3列のパーティ・敵・ログ、対象選択、HP・MP・LIMIT、2列のコマンドとメニュー、ポップアップ、経路／支給品選択、予告・浮き文字・揺れ・フラッシュ |

初期SP0、初期未装備、追加効果付きの所持装備6個、初期道具・素材の数も正本に合わせた。「開発用補給（仮）」、仮の初期装備、仮の成長・敵攻撃・報酬式は取り除いた。

数値例：薬草HP25、上薬草HP55、魔力水MP18、修練の書SP+1。勝利EXPは `18 + 階層×6`、初期必要EXP35、以後は四捨五入で1.35倍。成長するのは生存者のみで、職業別の成長と最大Lv10も正本どおり。

## 元コードとの対応

| ファイル | 担当 |
| --- | --- |
| [data.json](../games/mini_hero/data.json) | 正本から抽出した難易度、職業、敵、技、LIMIT、装備、接頭効果、素材、レシピ、ツリー、クエストの条件・報酬 |
| [battle.gd](../games/mini_hero/battle.gd) | 画面に依存しない状態と処理。`restart`→`start`、`turn`→`perform`、`useSkill`→`use_skill`、`useLimit`→`use_limit`、`executeIntent`→`execute_intent`、`win`→`win`、`nextBattle`→`next_wave`、`claimQuest`→`claim_quest` |
| [game.gd](../games/mini_hero/game.gd) / [game.tscn](../games/mini_hero/game.tscn) | DOM・CSSの画面をGodotのControl、Container、Button、ProgressBar、Tweenに置き換え、操作を戦闘処理へ渡す |
| [game_select.gd](../scripts/game_select.gd) | 既存アクションとRPGへの入口。今回の変更はRPGの説明から旧「開発版」表記を除いたことのみ |
| [fonts](../games/mini_hero/fonts) | 正本の絵文字を描くNoto Color EmojiとOFLライセンス |

実行時にHTMLやJavaScriptを埋め込まず、Godotの処理として動作する。Node.jsとPythonは比較値を再生成するときだけ必要。ゲームの起動には不要。

## 移植時の変更と既知の差

- ゲーム選択への戻る操作とEscは、2つのゲームを選ぶための統合用操作として残した。
- DOM・CSSをネイティブの画面へ置き換えた。黒背景・白枠・丸いカード／ボタン・3列配置・2列メニューと元の文字を使用する。1280×720の既存プロジェクトで、下まで収まらない画面は正本のブラウザ画面と同様に縦スクロールする。スマートフォン用の1列への切替は移植していない。
- 絵文字を図形に置き換えていた旧実装は削除した。🛡️・🧙・✨、🟦・🦇・🔥・🪨・💎・🍄・🐺・🎁・🧛・🐉、ボスと💀、予告やクエストの絵文字は正本の文字をそのまま使う。ブラウザの絵文字字体はOSで変わるため、任意のOSの見た目とピクセル単位で同じとは保証しない。
- JavaScriptの待機時間はGodotのタイマーで再現する。浮き文字・揺れ・フラッシュ・警告はTweenで描く。CSSの発光や全キーフレームをピクセル単位で一致させる検証はしていない。
- 装備インスタンスの不透明なIDは日時＋乱数から連番＋乱数に置き換えた。装備の能力、追加効果、所持・装備判定、乱数の消費回数は保持する。比較時は両方のIDを定義順に正規化する。
- **二連撃の安全処理を1か所追加した。** 正本では最後の生存者が1撃目で倒れると、2撃目の対象が`undefined`となり`hit()`で例外が発生することをJavaScriptで再現した。Godot版は生存者がいなければ2撃目を省略し、敗北へ進む。生存者がいる場合の対象・式は正本どおり。

### 正本にある未接続・未提供の機能

以下は不足を推測した項目ではなく、受領した正本全文に基づく。

- セーブ／ロード処理はない。ゲーム選択へ戻る・終了する・最初から始めると状態を失う。
- 最終エンディングや終了階層はない。20階のボス以降も階層進行が続く。
- 装備の`breathResist`は定義されているが、正本の戦闘処理から参照されないため独自に適用していない。
- 難易度の`reward`値も正本の勝利報酬では参照されない。経路の`reward`による補正は実際に参照されるため移植した。
- ミミックの`trap`は敵の特殊処理に対応する分岐がなく、正本の通常攻撃へのフォールバックを保っている。

これらを今後変更する場合は、正本の仕様を移植した修正と、新たな仕様の追加を区別して記録する。

## 絵文字フォント

[Google公式Noto Emoji](https://github.com/googlefonts/noto-emoji)の[CBDT版NotoColorEmoji.ttf](https://github.com/googlefonts/noto-emoji/blob/main/2D/fonts/NotoColorEmoji.ttf)を使用。Copyright 2013 Google LLC、[SIL Open Font License 1.1](../games/mini_hero/fonts/OFL.txt)。

Godotが対応するCBDT/CBLC形式を使い、正本が使用する文字と必要な合字を残してサブセット化した。原フォントが持つ、正本で使われる44文字のマッピングが残ること、⭐を含むこと、CBDT/CBLCが残ることを確認した。字体データは82,768バイト。フォントの種類については[Godot公式の絵文字フォント説明](https://docs.godotengine.org/en/stable/tutorials/ui/gui_using_fonts.html#using-emoji)を参照。

サブセット生成時だけFontToolsを作業環境の一時領域で使用した。ゲームへのライブラリ依存は増やしていない。今後正本以外の新しい絵文字を追加する場合は、フォントにも対応する文字を追加する必要がある。

## 検証

Godot 4.7.2 Stable / Linux ARM64。描画付き試験はXvfb、OpenGL Compatibility、Mesa llvmpipe。Windows／macOS、Web・ネイティブの書き出しと実機ゲームパッドによる新RPGの操作は未確認。既存チュートリアル試験は終了コード0だが、終了時にObjectDB 4件の解放警告が出た。今回はその既存コードを変更していない。

| 検証 | 結果・範囲 |
| --- | --- |
| 正本のJavaScript | 全文の構文確認、Chromiumで開始・初戦表示を確認 |
| `mini_hero_test.gd` | 942,173項目成功。正本との621ケース比較と二連撃の安全処理。全27技・9LIMIT、基本行動、全10道具、敵／ボス、全45ツリー、全レシピ、クエスト報酬、経路、開始・勝敗・成長・次階層・ターンを検証 |
| `game_select_test.gd` | 描画付き・ヘッドレスとも101項目成功。画面操作を検証。実際の初戦勝利、装備、修練の書、習得、技、敵ターン、支給品、クエスト、図鑑、製作、経路、再開、全9LIMITの選択表示と各職業での発動、両ゲーム往復、戦闘演出中の退出 |
| `stage_select_test.gd` | 41項目成功。既存のステージ選択、起動と戻る操作 |
| `stage_2_test.gd` | 325項目成功。既存ステージ2の全6部屋の実入力攻略とギミック |
| `tutorial_rooms_test.gd` | 48項目成功。既存チュートリアルの操作、攻略と復帰 |

[mini_hero_reference.py](../tests/mini_hero_reference.py)は正本の関数を変更せずにNode.jsのVMで実行し、[mini_hero_reference.json](../tests/mini_hero_reference.json)を生成する。DOM描画・演出はテスト用に差し替え、`update()`による対象／行動者の補正は保持する。待機だけ即時化する。乱数を0.05・0.5・0.95に固定し、基本状態と全ツリー・装備・反射がある状態を比較する。

比較するのはパーティ・敵の全状態、装備定義と所持数、道具、素材、クエスト、統計、図鑑、階層、行動者・対象、進行フラグ、経路、イベント、ログ、乱数の呼出回数。日付由来のIDと一時的なDOMアニメーション属性は正規化する。この比較は全ての乱数列・全組合せ・CSSの見た目の完全一致を証明するものではない。画面操作と描画は別のGodotテストで確認する。

Godotの実行ファイルを`godot`とした再実行例：

```sh
godot --headless --editor --path . --import
godot --headless --path . --script res://tests/mini_hero_test.gd
godot --headless --fixed-fps 60 --path . --script res://tests/game_select_test.gd
godot --headless --fixed-fps 60 --path . --script res://tests/stage_select_test.gd
godot --headless --fixed-fps 60 --path . --script res://tests/stage_2_test.gd
godot --headless --fixed-fps 60 --path . --script res://tests/tutorial_rooms_test.gd
```

描画付きの画面記録：

```sh
xvfb-run -a godot --audio-driver Dummy --rendering-method gl_compatibility --fixed-fps 60 --path . --script res://tests/game_select_test.gd -- --screenshots
```

比較値の再生成時のみPython 3とNode.jsを使用する：

```sh
python3 tests/mini_hero_reference.py
```

画面記録：[元HTMLの初戦](screenshots/mini-hero/source-battle.png)、[Godotの戦闘](screenshots/mini-hero/battle.png)、[装備](screenshots/mini-hero/equipment.png)、[スキルツリー](screenshots/mini-hero/talents.png)、[ゲーム選択](screenshots/mini-hero/game-selection.png)。両戦闘画像は同じターンや乱数の画像ではない。

配布ZIPには`project.godot`、既存アクションとRPGのソース・素材、正本、移植記録・テスト、RPGの画面記録を含む。Godotに`project.godot`をインポートしてF5で起動する。Godot本体と書き出し済み実行ファイルは含まない。既存アクションの参考スクリーンショットは作業コピーに残し、ZIPには含めていない。
