# 相棒の回廊の連携6室

[Issue #134](https://github.com/Foxy-null/2d-space/issues/134)。既存9室の後に6室を加え、全15室・巻物3個へ広げる。共有Player・相棒・靴・反転ゲート・Spring・風の物理は変えない。各室の入口で復帰し、相棒を保持して出口へ運ぶ条件を維持する。第11室の出口は片面足場とし、反転したまま下面へ着地して進めない。右境界の下端も場外復帰より下へ延ばす。操作履歴による出口ロックや常設説明は追加しない。

| 部屋 | 配置 | 休憩と枝 |
| --- | --- | --- |
| 10：相棒と空中の靴 | 入口Y1700から相棒と空中の靴をつなぎ、560px上の台へ。左上Y850、右上Y550へ折り返す | 幅460pxの最初の台と各上層。左の巻物`combo_left_02`へ寄り、元のY850の台へ戻る |
| 11：反転して運ぶ | 相棒を保持してUpゲートから天井側の休憩面へ上がる。左のDownゲートからY920へ戻り、右・左・右へ台を渡る | 反転した面と床の台で静止できる。天井の面と次の足場の間隔を226pxとし、頭上を塞がない |
| 12：バネから相棒へ | 入口Y1900のSpringで上がり、相棒のJumpとDashをつないで650px上の台へ。左上Y930、右上Y650へ進む | 最初の台は幅330px。Springの公開設定を1250px/sにし、通常の相棒JumpとDashだけでは最初の台へ届かない |
| 13：風と空中の継ぎ足し | 高い横風から右の島へ。空中の靴と相棒で560px上の左の台へ折り返し、右上へ進む | 左の台は幅580px。巻物`wind_left_03`へ寄り、同じY1200の主経路へ戻る |
| 14：壁の先で持ち直す | Y2200の入口から1500px高い対向壁を保持した壁キックで登り、左へ寄って右下の台を渡る | 壁の頂上と下りの各台で静止できる。旧第8室と同じ上投げ・手ぶら登り・再取得の比較を行う |
| 15：運搬の長い折り返し | Y2000から5台を右・左・右・左・右へ渡り、最後の横風から到着台へ | 各台で相棒とDashを回復。最終到着台はこの部屋だけに置く |

各室の高さは1800・1600・2000・2000・2300・2100px。縦カメラと場外復帰は部屋の高さを使う。Springの第12室はカメラを300px上寄りにし、HUDをY100へ置く。入口のSpringと最初の到着台を同時に見せ、HUDで隠さない。第13室はHUDを右下へ置き、最初に使う上の風を見せる。第10室の靴は入口の上、第13室の靴は右の島の上にあり、第13室の最初の風渡りでは取らず、その次の上昇中に取る。最初の台の側面は薄い片面足場とし、側面登りで高低差を置き換えない。対向壁以外の左境界には見えるトゲを置く。

新しい巻物の入口には小さな巻物の印を置く。空中で触れた巻物を安全な棚へ持ち帰ると保存し、相棒の保持枠を使わない。任意棚から同じ主経路へ帰って次室へ進める。第10・13室には到着台や完成後の橋を置かない。既存回廊と同じく、次の部屋への移動後は前室へ逆戻りしない。

アイテムは部屋の`Items`に置き、復帰で靴とゲートを元へ戻す。Springは専用の復帰メソッドを持たないため部屋直下へ置き、Rで接触を離れた後に再び作動することを実入力で検査する。最終Goal参照・HUD総数は実際の部屋一覧から取得する。新しい巻物を含め選択画面とアクセシブル名の総数を3個にする。

## 検証

Godot 4.7.2 / Linux、物理更新60Hz・固定描画60fps。通常入力と横入力0.85で、新6室を連続して攻略した。各室の最初の休憩で3秒静止し、相棒の保持と資源の回復を確認してから通常操作で再出発する。反転室は天井でも3秒静止する。横入力は`Input.action_press`へ直接渡す合成入力で、0.85は`Input.get_axis`でも0.85になる。JoypadMotionは使わず、実機パッドのdeadzoneや校正結果とは区別する。

| 部屋 | 通常入力 | 横入力0.85 |
| --- | --- | --- |
| 10 | 13.40秒 | 12.92秒 |
| 11 | 19.52秒 | 18.75秒 |
| 12 | 11.92秒 | 11.95秒 |
| 13 | 14.40秒 | 14.40秒 |
| 14 | 22.35秒 | 24.83秒 |
| 15 | 15.93秒 | 15.95秒 |

成功経路10〜20秒を目安にし、対向壁の第14室は22〜25秒を許容した。全て30秒以内で、休憩を含めて再試行する量を抑える。これらは自動操作の所要時間で、初見プレイヤーの時間ではない。全体が本編9〜15分になったとは扱わない。

`tests/corridor_more_test.gd`は新6室、旧巻物と新2巻物の実往復、確定前後のR・実トゲ接触死・途中帰還、保存の読込、選択の`3 / 3`とアクセシブル名を扱う。新枝の往復は通常12.23／13.28秒、横0.85で11.90／13.72秒。3秒の静止を含め、元の主経路の休憩台まで死亡せず戻った。保存先はPID付きの専用ファイルで、`--keep-fixture`と`tests/corridor_more_reload_test.gd -- --fixture=user://corridor_more_<PID>.cfg`を使い、別のGodotプロセスで3個の保存・表示・薄い再訪表示も確認する。

`--timing-only`は第10・13室のJump→相棒Jump→靴Jump→Dashの3間隔を独立に16・20・24フレームへ変える。通常と横0.85の108組で270項目が成功した。

`tests/corridor_more_required_test.gd`では、靴・相棒の追加Jump・重力反転・Spring・壁キックをそれぞれ省く384入力を比較し、1104項目が成功した。通常Jumpと8方向Dash、異なる踏切位置と12・20・28フレームのDashを含む。Springは比較の踏切を始める前に無効にし、実際のSpring発動が0回であることも確認する。準備段階で使った相棒Jumpは比較区間の記録から分ける。

`--rest-only`では実入口から休憩台へ着地した後、第10・12・13・15室で次の高台を省く96入力を試し、216項目が成功した。`tests/corridor_throw_climb_test.gd -- --new-shaft`は、第14室で相棒の背からの踏切を含む上投げ・左右の手ぶら登り・再取得の12例、37項目が成功した。全12例で実際の手ぶら上登りが成立し、相棒を再取得して高台へ進む経路は再現しなかった。Springへ通常Jumpで上から落ち、相棒Jumpなしで上Dashを24・32・36・40・44・48フレームに変える追加6例も未達。発動位置Y1873.34からの最高中心Y1233.79で、最初の台に必要な中心Y1224へ届かなかった。`--spring-step-only`では相棒の背へ実際に立ち、Grabと通常Jumpで持ち上げてからSpringへ落ちる8例も比較し、32項目が成功した。上Dashは24〜52フレームの8通りで、相棒Jumpなしの到達は再現しない。最高中心Y1234.37で、必要なY1224へ届かなかった。予防だけの速度変更は加えていない。有限の代表入力であり、任意の入力列に対する不可能証明ではない。

第11室では、反転した休憩面から右端へ歩き、反転Jump→20フレーム→相棒Jump→20フレーム→右下Dashで、Downゲートを通らず出口の下面へ着地して次室へ進める経路を実再現した。出口の片面化と境界の下端延長後は、12・20・28・36・44フレームと下・右下・右・上Dashの20組、80項目で通過しない。共有Playerの物理や履歴条件は変更していない。

上記の通常8方向・休憩からの省略・相棒の踏み台・Spring・Downゲートの比較は、一括554経路・1562項目でも成功した。省略用にネイティブAreaを無効化する比較と、その後の実経路は別のステージ個体に分ける。

全15室の本編入力・運搬条件・天井・復帰・クリア画面は`tests/stage_4_test.gd`、旧3室と巻物は`tests/corridor_expansion_test.gd`、旧第7〜9室の必須操作は422項目と旧対向壁の73項目でも確認した。第1〜6室の長い全省略入力は今回は再実行せず、既存fixtureを維持した。描画は`tests/corridor_more_capture_test.gd`で1室ずつ実入力を実行し、6室と2枝を完走した。一括描画の終了143は未完として記録し、分割fixtureで補完した。PNG20枚を目視し、Springの到着台・最初の風・相棒の配送画像をHUDや画面端で隠さない位置へ調整した。

最終状態の回帰結果は次の通り。全て終了コード0。踏切108組と新対向壁12例は、検査後に対象の地形や共有物理を変更していない。

| テスト | 結果 |
| --- | --- |
| `corridor_more_required_test` | 554経路・1562項目 |
| 同 `--spring-step-only` | 8経路・32項目 |
| `corridor_more_test` | 通常・横0.85、巻物の往復と中断・保存の257項目 |
| 同 `--timing-only` | 108組・270項目 |
| `corridor_more_reload_test` | 別プロセスで5項目 |
| `stage_4_test` | 全15室・792項目 |
| `corridor_expansion_test` | 旧第7〜9室と巻物・422項目 |
| `corridor_throw_climb_test` | 旧対向壁24経路・73項目 |
| 同 `--new-shaft` | 新対向壁12経路・37項目 |
| `stage_clear_test` | 71項目 |
| `arrival_retry_test` | 32項目 |
| `scroll_room_transfer_test` | 48項目 |
| `stage_select_test` | 144項目 |

初見試遊と実機パッドは未確認。


| 部屋 | 描画 |
| --- | --- |
| 10 | [入口](screenshots/corridor-more/room10_entrance.png)・[休憩](screenshots/corridor-more/room10_rest.png) |
| 11 | [入口](screenshots/corridor-more/room11_entrance.png)・[反転休憩](screenshots/corridor-more/room11_inverted_rest.png)・[床の休憩](screenshots/corridor-more/room11_rest.png) |
| 12 | [Springと到着台](screenshots/corridor-more/room12_entrance.png)・[上層の見通し](screenshots/corridor-more/room12_rest.png) |
| 13 | [入口の風](screenshots/corridor-more/room13_entrance.png)・[島の休憩](screenshots/corridor-more/room13_rest.png) |
| 14 | [対向壁](screenshots/corridor-more/room14_entrance.png)・[壁上の休憩](screenshots/corridor-more/room14_rest.png) |
| 15 | [入口](screenshots/corridor-more/room15_entrance.png)・[折り返し](screenshots/corridor-more/room15_rest.png)・[最終到着台](screenshots/corridor-more/room15_goal.png) |
| 10の巻物 | [空中で接触](screenshots/corridor-more/room10_scroll.png)・[安全な棚](screenshots/corridor-more/room10_scroll_rest.png)・[主経路へ戻る](screenshots/corridor-more/room10_scroll_return.png) |
| 13の巻物 | [空中で接触](screenshots/corridor-more/room13_scroll.png)・[安全な棚](screenshots/corridor-more/room13_scroll_rest.png)・[主経路へ戻る](screenshots/corridor-more/room13_scroll_return.png) |
