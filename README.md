# Cursor Ring & Magnifier (macOS)

macOS 13+向けのメニューバー常駐アプリです。以下を実装しています。

- カーソル追従リング（入力透過、マルチディスプレイ対応）
- リング設定（サイズ/太さ/透明度/8色プリセット+カスタム色）
- リングサイズ`Custom`（スライダー）
- リング内塗りつぶし設定（ON/OFF、塗り色、塗り透明度）
- クリックフィードバック（縮小+色変化、通常クリックと右クリックを区別）
- リング表示ON/OFFショートカット（デフォルト: `Control + M`、変更可）
- 虫眼鏡（デフォルト: `Control`ホールド、変更可）
- 虫眼鏡サイズ選択（Small/Medium/Large/X-Large/XX-Large）
- 虫眼鏡形状選択（Circle/Wide Rectangle）
- 設定の永続化（`UserDefaults`）
- Start at Login切替
- 権限状態表示とガイド（Accessibility / Screen Recording）

## 開発ビルド

```bash
swift build
swift run MouseCircleApp
```

## .app形式の生成

```bash
./scripts/package_app.sh
```

生成先:

- `dist/CursorRingMagnifier.app`

Applicationsへ配置:

```bash
cp -R dist/CursorRingMagnifier.app /Applications/
```

## 実装メモ

- クリックフィードバックとグローバルショートカットはAccessibility権限が必要です。
- 虫眼鏡はScreen Recording権限が必要です。
- 2本指クリックはシステム上右クリック相当イベントとして扱っています。
