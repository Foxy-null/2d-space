# 動く反射台と巻物の1室（Issue #175）

2026-10-26。合意済みの探索設計を引き継ぎ、main `b29bf5b31cff22aa2192c358e9c9d5350958c379` から着手する。着手前のWeekly残量7%、reset1793513849は不変。旧33室・11巻物ID・共有Playerと反射の物理を保ち、新34室だけへ最終Goalを置く。

最初は既存Springから3反射、広い休憩で実Bootを取り、後半3反射へ戻る配置を仮説にする。第3反射だけが幅144pxを3.2秒でゆっくり往復する。動きはGodotの既存AnimationPlayerで設定し、新しい操作や使用履歴のロックは加えない。薄い短いレールで動く範囲を見せる。

第3反射の左上へ任意の巻物 `moving_sky_12` と静止棚を置き、同じ本線の休憩へ戻す。小さな既存巻物印を使い、説明ラベルは増やさない。総数・保存・選択は12個へ更新する。

実装前の仮説であり、通常/実axis0.8・異なる実入力時機と位相・実R/落下/再攻略・有限の資源省略・巻物の取消と確定/自然帰還/別プロセス保存で確認する。成功ルートは原則30秒以内。動く反射の実位置とHintの経路・目標表示が一致し、主人公・反射・巻物・帰還面をHUDと画面外から守る。人の時間目標は実測前に達成扱いしない。

## 最終配置と調整

第34室は3500×2200px、計6反射。入口のSpringから前半3反射へ進み、第3だけx1228〜1372/y860を往復する。左上の巻物は1100,650、静止棚は1100,768。本線の休憩は中心1640,1168・幅640px、幕はx1780/y0〜1040、靴は1840,1020。幕の下を歩き、通常Jumpと実Boot追加Jumpから第4反射1950,720へ戻る。最後は2400,1200→2700,1600の下りから3200,1520のGoalへ進む。最終Goalはこの部屋だけに置く。

当初は第3から第4へ直行でき、さらに独立担当が休憩台の実右端1937.539から28f通常Jump＋純UpDashだけで実Goalへ到達した。靴消費0・位置/速度/資源注入なしの反例である。幕の追加と第4の80px上昇で修正し、同じ28f列はB4接触0・最高center y794.285・Goal未到達の8項目で追認した。これは全入力の不可能証明ではない。

AnimationPlayerをphysics優先度−10で更新し、任意Hintの線と目標を実移動へ追従させる。第3後の線は休憩・幕下・靴・上昇点を通り、危険な直行を案内しない。Rでは位相を継続し、Pauseでは同じAnimationが停止・再開する。33→34転送を開始したframeは早期returnし、旧roomへのBoot参照を防ぐ。

native準備のレビューで休憩床の見た目400pxと実幅640pxの不一致を検出し、描画を±320へ揃えた。巻物棚に立つ間だけ右へ240・縦offset140のcameraを使い、任意Hintをy570へ置く。次の床・主人公・確定済み巻物の実矩形を全て画面内/HUD外として確認する。

## 実操作と保存の確認

最終B4 y720の16jobは全て終了0・成功markerあり・SCRIPT ERROR/予期しないERRORなし。表示幅と棚のcameraの最後の修正は、後述の追加UI/native再確認で検証する。

| 検証 | 成功項目 |
| --- | ---: |
| main | CANYON_MOVING_ROUTE_TEST_OK 33515 checks |
| lifecycle | CANYON_MOVING_SCROLL_TEST_OK 14931 checks |
| reload | CANYON_MOVING_RELOAD_TEST_OK 24 checks |
| phase-branch | CANYON_MOVING_SCROLL_TEST_OK 6285 checks |
| phases | CANYON_MOVING_PHASES_TEST_OK 27282 checks |
| recovery | CANYON_MOVING_RECOVERY_TEST_OK 18963 checks |
| spring | CANYON_MOVING_REQUIRED_TEST_OK case=spring attempts=24 checks=120 |
| boots | CANYON_MOVING_REQUIRED_TEST_OK case=boots attempts=24 checks=216 |
| whole | STAGE_5_TEST_OK (15948 checks) |
| old-apps | CANYON_APPLICATIONS_SCROLL_TEST_OK 44615 checks |
| old-reload | CANYON_APPLICATIONS_RELOAD_TEST_OK (17 checks) |
| exit | STAGE_5_EXIT_TEST_OK (201 checks) |
| old-expansion | CANYON_EXPANSION_ROUTE_TEST_OK (43 checks, branch 5.70s) |
| selection | STAGE_SELECT_TEST_OK (144 checks) |
| clear | STAGE_CLEAR_TEST_OK (71 checks) |
| transfer | SCROLL_ROOM_TRANSFER_TEST_OK (48 checks) |

本線は通常/実axis0.8×16/20/24fの6条件で16.98〜17.48秒、3秒の静止休憩を含む。4分割の実位相8列、別位相の弱い枝、実R/実落下/Pause/旧33→34を確認した。Spring省略24例と実右端1940からのBoot省略24例は各8方向×12/20/28fで実Jumpを必須にし、B1/B4へ到達しなかった。実巻物はpending R/実死/途中帰還で保存せず、安全な棚で確定し、3秒静止・同じ本線帰還・再訪/重複なし・途中選択へ戻る保存を通常/弱で確認した。

新1IDの実保存を別processへ渡し、1 / 12とaccessible名、同じnativeの薄い状態を確認した。続けて旧11IDを加える12 / 12は保存互換fixtureであり、12本を実際に集めた証拠ではない。旧31/33の現物2IDを弱入力で再確認し、Goal移設後の自然な次CP転送、別process保存、旧第13室の枝と実配置12本、全左右出口、選択/クリア/通常転送の巻物も確認した。旧全11枝を独立で全反復した意味ではない。

## 限界

本線・別位相の枝・recoveryの終了時にObjectDB2警告がある。原因未確定で、解消済みと扱わない。nativeのVSync警告も別記する。通常のユーザー保存へ書かず、XDGとPID別の試験保存を使う。初見/実機パッド/人の本編9〜15分・巻物込み15〜24分は未測定のままである。

## 最終表示の追認

表示修正後のHint ON・通常/実axis0.8の2枝は11,985項目で成功。薄い確定済みScrollも、主人公・巻物棚・次Rest全体と同時に画面内/HUD外を確認した。native OFFの本線3,506/枝3,518、ONの本線5,564/枝5,834、実1IDの別process選択/再訪/互換26項目の5jobが全て終了0。21PNGを残す。V-Sync非対応の警告だけで、SCRIPT ERROR/予期しないERROR/ObjectDB警告はなかった。旧Visualで中断したnative-v1は最終証拠へ使わない。

追加direct比較のJump回数assertは、Springで出発する列が通常Jumpを使わないことを区別するよう修正した。最新mainへ統合した後、import・選択144・direct24例168項目が全て終了0・無警告。Spring/Boot/direct計72列504項目で指定反射の省略成功なし。旧y800からの右端28f反例も独立8項目で捕捉済みであり、全入力の不可能証明とは区別する。

棚のpreviewでは確定済み巻物・主人公・次の床を同時に確認している。離れた既存の巻物を常時HUD外へ置くという保証には広げない。最新mainの塔34区間/重力37室/回廊36室と、総数8/8/10/12/12を保持した。
