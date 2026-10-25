# 重力の回復Dashを使う第16〜21室

[Issue #141](https://github.com/Foxy-null/2d-space/issues/141)。旧15室の地形・位置・既存4個の巻物IDと共有Playerの移動性能を保ち、後ろへ独立したnative sceneを6室追加する。第21室だけを最終到着とする。既存のDash回復Crystal、重力ゲート、風、壁とトゲを使い、操作履歴では出口をロックしない。

着手時点の構成案は次の通り。座標と穴の幅は通常入力・実横入力0.8・踏切時機の実測で詰め、完成後に結果を追記する。旧2室を丸ごと横へつないだ第10〜15室と異なり、新6室は一つの空間に上下や方向の違う短い課題を組む。

| 室 | 主な課題 | 旧配置との違い・休憩 |
| --- | --- | --- |
| 16：天井の回復リレー | Up反転後、天井の広い穴を横Dash→空中Crystal→再Dashで渡り、Downで床へ戻る | 靴の追加JumpではなくDash自体を空中回復する。反転した天井で3秒休み、渡りに再出発する |
| 17：深い下降をつなぐ | 反転した安全な下面からJumpと下Dash、途中の回復Crystal、もう一度の下Dashで深いDownゲートへ届く | 下向きの距離を一度のDashで代用できない配置。下層の床から右へ戻る短い帰路を持つ |
| 18：逆風の左折り返し | 右から入り、風に逆らって左へ回復Dashをつなぐ。着地する天井は入口側より高い | 第16室の同じ高さの穴と異なる上向きの着地と風の制動を使う。到着後は開いた床から右へ帰る。反転した休憩から任意の巻物へ下り、同じ場所へ戻れる |
| 19：壁の上から角を回る | 交互の張り出しを壁キックで上がり、Up反転して休む。下Dashから回復を挟み、吊り壁のトゲ下面を斜めに回ってDownへ | 高い壁を登る課題と、Dash方向を変える短い下回りを一つの部屋でつなぐ。天井の下面に休憩を置く |
| 20：左へ上昇して戻る | 右から入り、上Dash→回復Crystal→再上Dashで高いUpゲートへ進む。天井で休み、左のDownへ下Dashして到着台へ | 主進行を左へ広げ、水平の回復渡りではなく垂直の回復を使う。到着後の右帰路と、休憩から元へ戻る二つ目の任意巻物を残す |
| 21：上下の回復連鎖 | 通常重力の上Dash回復からUpに入り、天井で休む。風を横切る下Dash回復でDownへ戻り、最後の到着台へ | 同じ部屋で上昇と下降の回復を対にする。二つのCrystalを使う途中に3秒静止できる天井を置く |

巻物は第18・20室へ各1個、計6個とする。入口には既存の小さな巻物印だけを置き、通常の主経路では拾わない。到着前後のどちらでも、寄り道への接触、安全確定、主経路への帰還を実入力で通す。確定前のR・実死亡・途中帰還は未獲得へ戻り、確定後は同じ操作と保存再読込・ステージ選択の6/6とアクセシブル名で保持を確認する。

全室は原則10〜20秒、3秒の休憩と左向き室の右帰路も含めて30秒以内を目指す。通常入力と`Input.action_press`へ直接渡す0.8を`Input.get_axis`で確認し、離陸位置・16〜24フレームの幅も試す。回復Crystalを省く比較と、8方向Dash・屋根・下面・休憩から次の課題を飛ばす代表例を残す。有限の比較であり任意の入力列の不可能証明とはしない。

旧15室の連続攻略、旧4枝、15↔16の実往復、新左向き室の帰路と再訪、R・実死亡・Goal21・保存と表示を確認する。描画では通常の成功経路と枝を通し、同じ負例を描画で繰り返さない。本編9〜15分の全体目標を達成したかは別途実測し、未達ならそのまま記録する。

旧第15室のコースそのものは変更せず、旧最終境界`RightBoundary`のCollisionだけを非最終室では無効にする。第15↔16室を左右に歩いて通れるようにし、新最終21室の境界は維持する。

第19室では、実到着まで通った三つの代用を地形で防いだ。操作の履歴には条件を足していない。

- 張り出しへ通常Jumpと上Dashで着地して補充すると、壁キック0回・Dash5回で完走できた。張り出し上面3箇所を見えるトゲにした。
- 吊り壁の左面を掴んで下り、壁キックして8f後に右下Dashすると、空中Crystalを使わずDash1回でDownとGoalへ届いた。吊り壁の左面にトゲを加え、正規の真下→回復→斜めDashはその下を通す。
- 高い左壁の天面でDashを補充してからJump＋右上Dashすると、Up反転・空中Crystalを使わず壁キック3回・Dash2回で完走できた。8/16fで実Goalまで再現した。左壁の36pxの天面をトゲにして、その補充地点をなくした。正規の最後の壁キックは天面より下で使う。

同じ入力列の回帰に加え、任意の入力列を保証しない有限の省略比較を残す。回復Crystalを省く比較では、その1個だけの接触を止め、実入口から休憩とJumpを通し、実際の次の足場や反転への到達を調べる。出口を直接ロックしたり、操作回数を成功条件に加えたりしない。

第16室では、反転中に一度下へJumpし、天井端へ掴み直して壁キックすると、16/24f後の横Dash1回で空中Crystalを省き実Goalまで通れた。天井端の縦面40pxを見えるトゲにする。通常の下面への静止と、端の手前から下へ離れる正規Jumpは保つ。同型の第18室も同じ端面にガードを置く。単純に歩いて掴む初期の試験では壁に接触できていなかったため、Jumpして掴み直す入力と、実際の端面トゲの`player_hit`を観測する回帰へ置き換えた。

新第19室の左壁は下100pxを入口の通路として残す。第18室から来て、未到着の第19室からすぐ前室へ戻る際に、壁で閉じ込めないためである。その通路を利用して壁の外側を登る代用は、外面の見えるトゲで防ぐ。正規の内側の壁キックと、床での左右歩行には当てない。

## 実測

Godot 4.7.2、60fps。新6室を通常/実横入力0.8、Jump後16/24fのDashで攻略した456項目は成功。入力は`Input.action_press`のstrengthを直接指定し、`Input.get_axis`の実値も検査する。値には3秒静止と、第18・20室の右出口への帰路を含む。

| 室 | 通常入力 | 実横入力0.8 |
| --- | --- | --- |
| 16 | 10.15秒 | 11.23秒 |
| 17 | 11.00〜11.13秒 | 12.42〜12.55秒 |
| 18 | 16.37秒 | 18.98秒 |
| 19 | 12.52〜12.65秒 | 13.77〜13.90秒 |
| 20 | 18.92〜19.18秒 | 21.75〜22.02秒 |
| 21 | 12.82〜13.08秒 | 14.23〜14.50秒 |

第20室の0.8は目安の20秒を超えるが、上限30秒には収まる。新6室の通常経路は合計約82秒。全体9〜15分の主経路目標を達成したという記録にはしない。

新巻物の寄り道は、3秒休憩を含め到着前5.08〜5.25秒、到着後4.92〜8.73秒。通常経路では2本とも未取得で進める。旧4IDは`wall_loft_01`、`inverted_return_02`、`upper_current_03`、`left_depth_04`を保ち、新IDは`wind_return_05`、`upper_return_06`。6/6表示の合算fixtureだけ旧4IDを登録し、旧4本の実取得経路は既存の専用suiteで別に確認する。

## 再実行

すべてプロセスID付きの専用保存先を使い、通常の保存ファイルへ触れない。Godot実行は共有2枠のwrapper経由で一つずつ投入する。

```sh
rtk proxy python3 /tmp/celeste-godot-slot.py /tmp/codex-stage-select-tools/Godot_v4.7.2-stable_linux.arm64 --headless --path . --fixed-fps 60 --script res://tests/gravity_third_route_test.gd --quit-after 90000
```

- `-- --routes-only`：新6室の通常/0.8の攻略だけ。
- `-- --timing`：新6室の16/24f・通常/0.8。各室に3秒静止を含む。
- `-- --negative-only`：回復7箇所×8方向×16/24f、張り出しの踏み台と吊り壁下り。`--room=19`などを併用すると対象室だけに絞る。
- `-- --roof-only`：入口からの8方向、天井端の壁キック、左壁の上面で補充して屋根へ上がる再現入力。
- `-- --guards-only`：端面の掴み直しと左壁の屋根補充の実再現だけを短く確認する。
- `-- --recovery-only`：実回復直後のR、実トゲ死からの再攻略、獲得した到着と帰路の保持。
- `-- --seams-only`：旧15↔新16と左向き18/20の次室との物理往復。
- `-- --scroll-only --keep-fixture`：新2巻物の確定前後、保存・選択。出力された`GRAVITY_THIRD_SAVED_PATH`を次の別プロセスへ渡す。
- `res://tests/gravity_third_reload_test.gd -- --save=user://gravity_third_<PID>.cfg`：上の保存を別プロセスで読む。六つの実巻物の薄表示と表示/アクセシブル名6/6を確認し、fixtureを削除する。
- `-- --capture-only --screenshots`：描画できる環境で成功経路と枝だけを撮影する。負例は反復しない。
- `-- --entry-captures --screenshots --room=17`：指定室の実入口から最初の静止面までを短く撮り直す。

全21室の連続攻略は`tests/stage_3_test.gd`、旧巻物は`gravity_scroll_route_test.gd`、`gravity_expansion_route_test.gd -- --scroll-only --positive-only`、`gravity_more_route_test.gd -- --scroll-only`と`-- --post-arrival-only`で確認する。

## 確認記録

- `stage_3_test.gd`：743項目。ステージ選択から旧15＋新6を実入力で連続攻略し、実到着、21室だけの完了、部屋移動の制御停止とカメラ、R・前室へ戻る・再選択を確認した。新Goalも既存の本編と同じ`mission_required = false`で、未入室でも操作課題の吹出しや解除音を出さない。
- `gravity_third_route_test.gd -- --timing`：456項目。最終地形で6室×通常/0.8×16/24fの24攻略。必要な実Crystal回収・Dash消費・反転・第19室の壁キック4回、主経路の巻物未取得と3秒静止・帰路を確認した。
- `--scroll-only --keep-fixture`：290項目。2本×通常/0.8、確定前のR・実トゲ死・途中帰還、到着前後の取得と往復、確定後のR・実死・途中帰還、保存再読込・薄表示・選択の表示/アクセシブル名6/6を確認した。
- 別プロセスの`gravity_third_reload_test.gd`：12項目。直前の専用保存を読み、実巻物6本の薄表示と記録、選択6/6を確認した。
- `--negative-only`：119負例・541項目。回復7箇所の8方向×16/24f、張り出しの踏み台3例、吊り壁の下り4例。後で見つけた端面の掴み直しと屋根補充は次の専用回帰へ追加した。入口下を開いた最終第19室も`--negative-only --room=19`の23負例・109項目で再確認した。
- `--guards-only`：12負例・52項目。実到着した端面の掴み直しと左壁の屋根補充を、実際の見えるガードへの`player_hit`で遮断する。単に実到着しないことだけに頼らない。
- `--recovery-only`：109項目。実Crystalの回収直後にRで早期復元し、実トゲ死から各室を再攻略して帰る。実到着した部屋と橋だけをR後も保つ。
- `--seams-only`：59項目。旧15↔16、左へ進む18↔19と20↔21の実往復、19室の入口下の通常/0.8歩行と、外面へ跳んだ実接触死・復帰を確認した。
- 旧4本の寄り道：第1室11項目、第7室12項目、第10・14室169項目。旧IDを実入力で取り、選択の1/6・4/6へ反映する。旧第7・14室は到着後の枝と帰還も63項目で確認した。旧15室の地形と4IDは変えていない。
- 描画の成功経路：159項目・24枚。新6室の入口・静止面、壁下の方向変更、左向き室の右帰路、到着前後の2巻物と主経路復帰、最終クリアを実描画して目視した。描画の中で省略負例は繰り返していない。

比較は列挙した有限の入力と踏切位置を対象とする。任意の複数操作の代用が不可能だとする証明ではない。操作数のアサートはテストが正規の連携を実行した観測であり、本体の解錠条件には使わない。

復帰suiteと、独立再実行した中間20fの通常/0.8攻略228項目の終了時には`ObjectDB instances` 2件の警告が残ることがある。終了コード0で109項目は成功し、ゲーム中の実行時エラーは出ていない。原因と本編への影響は未確定で、共有Playerなどの変更へ範囲を広げていない。最終の新第19室通常/0.8のverbose確認56項目、描画159項目、別プロセス保存12項目にはこの終了警告は出ていない。

撮影では第16・17室のUpゲート矢印と、反転後に使うDownゲート矢印の一部がHUD帯や画面下に重なるのを確認し、既存の方向矢印だけをゲート内の読める位置へ移した。ゲートの接触範囲は変えていない。常時の新しい説明ラベルや経路矢印は加えていない。

描画は`xvfb-run`とOpenGL互換レンダラーで行う。`--disable-render-loop`を使う場合も、各撮影点では`RenderingServer.force_draw()`で実際に描画してPNGを保存する。これは[Godotのコマンドライン](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)と[RenderingServer](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html)の標準機能で、物理の60fpsと実入力の経路は変えない。

## 描画

| 室 | 入口と静止面 | 連携と帰路 |
| --- | --- | --- |
| 16 | [入口](screenshots/gravity-third/room_16_entrance.png)・[天井の静止](screenshots/gravity-third/room_16_rest.png) | 端面のトゲ、空中Crystalと反対側の天井が見える |
| 17 | [入口](screenshots/gravity-third/room_17_entrance.png)・[下降前](screenshots/gravity-third/room_17_rest.png) | 下のCrystalへ向かい、深いDownをつなぐ |
| 18 | [右入口](screenshots/gravity-third/room_18_entrance.png)・[左へ渡る前](screenshots/gravity-third/room_18_rest.png) | [到着後の右帰路](screenshots/gravity-third/room_18_right_return.png) |
| 19 | [壁の入口](screenshots/gravity-third/room_19_entrance.png)・[壁の上の静止](screenshots/gravity-third/room_19_rest.png) | [回復後に吊り壁の下で方向を変える](screenshots/gravity-third/room_19_corner.png) |
| 20 | [右入口](screenshots/gravity-third/room_20_entrance.png)・[上昇後](screenshots/gravity-third/room_20_rest.png) | [到着後の右帰路](screenshots/gravity-third/room_20_right_return.png) |
| 21 | [入口](screenshots/gravity-third/room_21_entrance.png)・[下降前](screenshots/gravity-third/room_21_rest.png) | [最後の実到着](screenshots/gravity-third/room_21_arrival.png) |

| 枝 | 到着前の取得・復帰 | 到着後の取得・復帰 |
| --- | --- | --- |
| 18 | [取得中](screenshots/gravity-third/room_18_scroll_before.png)・[同じ天井へ](screenshots/gravity-third/room_18_scroll_return_before.png) | [床から取得](screenshots/gravity-third/room_18_scroll_after.png)・[床へ帰還](screenshots/gravity-third/room_18_scroll_return_after.png) |
| 20 | [回復して取得](screenshots/gravity-third/room_20_scroll_before.png)・[同じ天井へ](screenshots/gravity-third/room_20_scroll_return_before.png) | [片面足場から取得](screenshots/gravity-third/room_20_scroll_after.png)・[棚から床へ](screenshots/gravity-third/room_20_scroll_return_after.png) |
