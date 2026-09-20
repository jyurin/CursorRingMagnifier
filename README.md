# Cursor Ring & Magnifier (macOS)

[最新版アプリをダウンロード（GitHub Releases）](https://github.com/jyurin/CursorRingMagnifier/releases/latest)

配布ZIPはApple Silicon搭載Mac向けです。Releasesの **Assets** にある `CursorRingMagnifier-macOS.zip` をお選びください。

macOS 13+向けのメニューバー常駐アプリです。以下を実装しています。

- カーソル追従リング（入力透過、マルチディスプレイ対応）
- リング設定（サイズ/太さ/透明度/8色プリセット+カスタム色）
- リングサイズ`Custom`（スライダー）
- 線の太さ`Custom`（スライダー）
- リング内塗りつぶし設定（ON/OFF、塗り色、塗り透明度）
- クリックフィードバック（押している間は縮小+色変化を維持し、離すと復帰。通常クリックと右クリックを区別）
- リング表示ON/OFFショートカット（デフォルト: `Control + M`、変更可）
- 虫眼鏡（デフォルト: `Control`ホールド、変更可）
- 虫眼鏡サイズ選択（Small/Medium/Large/X-Large/XX-Large）
- 虫眼鏡形状選択（Circle/Wide Rectangle）
- 設定の永続化（`UserDefaults`）
- Start at Login切替
- 権限状態表示とガイド（Accessibility / Screen Recording）

## v0.2.0: 画面共有時の軽量化

機能と設定を維持し、描画・入力監視・画面取り込みの内部構造を更新しました。

- 全画面の120Hz再描画を廃止。リング周辺だけの小さなウィンドウを、マウス移動時に最大60Hzで移動します。
- 拡大鏡はScreenCaptureKitで必要な領域だけを最大30fpsで取り込み、画面全体の画像化・CPUでの切り抜きを行いません。
- 拡大鏡のキーを離す、リングをOFFにする、スリープに入ると取り込みを停止します。
- リングと拡大鏡はデスクトップ共有の対象にし、拡大鏡自身の取り込みからだけ除外して合わせ鏡を防ぎます。
- 設定スライダーの保存はまとめて行い、自動起動の登録はその設定を変更した時だけ行います。

設計と検証範囲は [PERFORMANCE.md](PERFORMANCE.md) を参照してください。

## 開発ビルド

```bash
swift build --build-system native
swift run --build-system native MouseCircleApp
```

## .app形式の生成

```bash
./scripts/package_app.sh
```

生成先:

- `dist/CursorRingMagnifier.app`
- `dist/CursorRingMagnifier-macOS.zip`
- `dist/CursorRingMagnifier-macOS.zip.sha256`

生成済みの旧版は `dist/previous/` に退避されます。ビルド済みファイル・バックアップはGitの管理対象外です。

Applicationsへ配置する前に、起動中の旧版を終了してください。

```bash
cp -R dist/CursorRingMagnifier.app /Applications/
```

既存の設定は同じ保存先から読み込みます。設定を初期化・削除する必要はありません。
更新によりmacOSが権限の再確認を求める場合は、「設定 > 操作」のアクセシビリティと「設定 > 拡大鏡」の画面収録を確認してください。

パッケージは既定でアドホック署名されます。AppleのDeveloper ID署名・公証済みという意味ではありません。一般配布向けの署名・公証は別途必要です。

## テスト

Swift Testingを使用します。対応する開発ツールをインストールしたMacで実行してください。

```bash
./scripts/test.sh
```

Xcodeとは別にインストール済みのCommand Line Toolsを使用する場合:

```bash
DEVELOPER_DIR=/Library/Developer/CommandLineTools ./scripts/test.sh
DEVELOPER_DIR=/Library/Developer/CommandLineTools ./scripts/package_app.sh
```

この指定はシステム全体の開発ツール設定を変更しません。Xcodeのライセンス同意を自動で行うこともありません。

## 実装メモ

- クリックフィードバックとグローバルショートカットはAccessibility権限が必要です。
- 虫眼鏡はScreen Recording権限が必要です。
- 2本指クリックはシステム上右クリック相当イベントとして扱っています。
- Zoomなどでは「デスクトップ全体」を共有してください。特定アプリのウィンドウ共有では別ウィンドウのオーバーレイが含まれない場合があります。
- 標準スクリーンショットのショートカット検出で表示を一時停止します。外部の撮影ツールやmacOSの撮影タイミングによっては映り込むため、確実に除外したい撮影前は `Control + M` でOFFにしてください。
