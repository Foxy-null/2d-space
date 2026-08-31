# 2D Space

宇宙を舞台に、重力反転で床と天井を切り替えて進む2Dアクションのベースシステムです。

## 必要環境

- Godot 4.7.2 Stable（Standard版）
- Git

## 起動

1. Godotの「インポート」から、このフォルダーの `project.godot` を選ぶ
2. 右上の「プロジェクトを実行」または `F6` ではなく `F5` を押す

## 操作

| 操作 | キーボード | ゲームパッド |
| --- | --- | --- |
| 移動 | `A` / `D` または `←` / `→` | 左スティックまたは十字キー |
| ジャンプ | `Space` / `W` / `↑` | A / × |
| 壁を掴む | `Shift`（長押し） | ZR（長押し） |
| 壁を昇降 | 掴みながら `W` / `S` または `↑` / `↓` | 掴みながら左スティック／十字キー上下 |
| やり直し | `R` | Start |

水色の矢印ゲートを通ると重力が反転します。壁は滑る、ジャンプする、掴んで登る、上端へ乗り越える操作を試せます。

## Sceneの担当分け

- `scenes/player.tscn`: 移動、ジャンプ、コヨーテタイム、壁アクション
- `scenes/stage.tscn`: 足場と当たり判定
- `scenes/gravity_gate.tscn`: 重力反転ギミック
- `scenes/hud.tscn`: 操作説明と現在の重力表示
- `scenes/main.tscn`: 上記Sceneを組み合わせるだけ

同じSceneを複数人で同時編集しないでください。担当Sceneごとにブランチを分けます。

## 確認

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/base_system_test.gd
```

`BASE_SYSTEM_TEST_OK` と表示されれば、入力・移動・ジャンプ・壁アクション・重力反転の土台は正常です。

## 今回は未実装

仕様が未決定のステージ選択／パスワード再開、完成版の画像・音・ステージ群は含めていません。
