# スタート画面

ユーザーがQ1〜Q4のおすすめをすべて採用し、制作を依頼した。

## 確定した仕様

- ゲームを起動すると、最初にスタート画面を表示する。
- 中央に手描き風のロゴを置き、日本語の「忍者ぶっとびくん」の下に「Galaxy」を表示する。
- 背景は既存の宇宙基地の星空を使い、選択画面と絵柄を揃える。
- ロゴの下にSTARTを表示し、クリック、Enter／テンキーEnter／Space、ゲームパッドA／×で既存のステージ選択画面へ進む。
- 起動時とタイトルへ戻ったときはSTARTにフォーカスを置く。
- ステージ選択からは「タイトルに戻る」、Esc、ゲームパッドBack／Selectでスタート画面へ戻る。戻るボタンは方向キーでも選べる。
- プレイ中とクリア後の戻り先はステージ選択画面とする。
- 基準の画面サイズは1280×720。ロゴの縦横比を保つ。

![スタート画面](screenshots/start-screen.png)

## 画面遷移

```mermaid
flowchart LR
    A[起動] --> B[スタート画面]
    B -->|START| C[ステージ選択画面]
    C -->|タイトルに戻る / Esc / Back| B
    C -->|ステージを選ぶ| D[プレイ]
    D -->|戻る / クリア後の決定| C
```

## ファイルと確認

- `scenes/start_screen.tscn` / `scripts/start_screen.gd`：ロゴ、START、初期フォーカスと選択画面への遷移。
- `assets/ui/title-logo.png`：透過ロゴ。生成方法とプロンプトは [素材の記録](../assets/ui/PROMPTS.md) を参照。
- `assets/ui/menu-theme.tres`：スタート画面と選択画面で共有する既存のボタン装飾。
- `scenes/stage_select.tscn` / `scripts/stage_select.gd`：スタート画面へ戻る操作。
- `tests/stage_select_test.gd`：起動先、各入力での画面の往復、フォーカス復帰と既存ステージ選択の動作。

```sh
godot --headless --fixed-fps 60 --path . --script res://tests/stage_select_test.gd
```

描画ありで同じテストに `-- --screenshots` を付けると、スタート画面とステージ選択の画像を `docs/screenshots/` に保存する。

Godot 4.7.2で、画面の往復と既存ステージ選択を含む63項目がヘッドレス・描画ありの双方で成功した。共通クリア画面の32項目もヘッドレスで成功した。実画面でロゴの文字・透過と配置、STARTのフォーカス表示、戻るボタンの配置を確認した。ゲームパッドは入力イベントで検証し、実機では未確認。

変更しにくい設計上の選択はないため、ADRは作成しない。
