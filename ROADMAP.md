# ROADMAP

## 現在の到達点

このプロジェクトは、長期間放置されていた状態から、現在の Xcode と iOS Simulator で再びビルド、テスト、実行できる状態まで復旧しました。

あわせて、描画基盤、物理、数学レイヤー、テスト、ドキュメントの近代化を段階的に進めています。現時点では「現代環境で保守可能な状態」にはかなり近づいていますが、Apple の最新流儀へ全面移行済みという段階ではありません。

## 近代化状況

| 領域 | 現在の状態 | 判定 |
| --- | --- | --- |
| ビルド環境 | 現在の Xcode / iOS Simulator で build, run, test 済み | 近代化済み |
| Metal 基盤 | `MTKView` ベースへ移行済み | かなり近代化済み |
| 物理 | Bullet 2.89 へ更新済み | 近代化済み |
| テスト | ローダ、数値、物理境界、updater、UI の回帰テスト追加済み | かなり改善済み |
| ドキュメント | プロジェクト文書とコードコメントを大幅拡充済み | 改善済み |
| 数学レイヤ | `simd` へかなり移行済みだが、`GLKit` はまだ一部残存 | 部分的 |
| Swift 言語仕様 | 現在の Xcode で通るが、project 設定はまだ `Swift 5.0` 表記 | 部分的 |
| UI フレームワーク | まだ `UIKit + Storyboard` | 未移行 |
| App lifecycle | `UIScene` 対応は済み、SwiftUI App ではない | 部分的 |
| 最新 Apple 作法への全面追従 | 一部反映済みだが全面刷新ではない | 未完了 |

## 残りステップ

1. `SWIFT_VERSION` や周辺設定を、実際に安全な範囲で引き上げる
2. 残っている `GLKit` 依存をさらに減らすか撤去する
3. `UIKit + Storyboard` を維持するのか、SwiftUI を部分導入するのか決める
4. SwiftUI を使うなら、まず設定画面や補助 UI のような描画外 UI から入る
5. 最後に formatter のような差分の大きい変更を段階適用する

## 将来の目標: レンダリング方式の切り替え UI

README にある 2 種類の見た目は、forward rendering と deferred rendering に対応している可能性が高い。現時点のコードでは [`/Users/kmi/devel/MMDViewer/MMDViewer/melt/view/MMDView.swift`](/Users/kmi/devel/MMDViewer/MMDViewer/melt/view/MMDView.swift) に `#if true // forward rendering` と `#else // deferred rendering` が残っており、切り替えはコンパイル時分岐になっている。

将来的には、現在の Play / Pause ボタンの並びに「rendering mode 切り替え」ボタンを追加し、実行時に見た目を切り替えられるようにしたい。

### 実現性の判断

- 技術的には実現可能
- ただし、今のままでは単純な boolean 1 個ではなく、`MMDView` 側で scene graph を再構築できるようにする必要がある
- forward / deferred の両方とも最終的には `Node` 木と `Traverser` を使うため、renderer 全体を別実装に分ける必要はない

### 必要になる変更

1. `MMDView` に `RenderMode` のような enum を導入する
2. `#if true` / `#else` をやめて、render mode を引数に scene graph を構築する
3. mode 変更時に root node, pass, drawer, updater をまとめて再生成する `rebuildSceneGraph` を用意する
4. 必要なら pass が保持する texture / attachment cache を切り替え時に解放する
5. `ViewController` に切り替えボタンを追加し、`MMDView` へ mode 変更を通知する
6. simulator 上で forward / deferred の両方について、表示、モーション、Play / Pause、操作、描画継続を確認する

### 注意点

- deferred 側は forward 側ほど継続的に実行確認されていないため、掘り起こし時に不具合が出る可能性がある
- drawable, depth texture, G-buffer の寿命管理は runtime 依存が強く、単体テストより simulator 目視確認が重要
- したがって、この機能追加は「UI を足す作業」ではなく、「scene graph の実行時再構築を安全に導入する作業」として扱うべき

## まだやっていない理由

- `SwiftUI` への全面移行は、描画 loop、gesture、toolbar、lifecycle の再配線を同時に招きやすく、今回の「小さいイテレーションで壊さず進める」方針と相性が悪かった
- `GLKit` の完全撤去は、相互変換や互換 helper の整理までは進めたが、matrix multiply など一部に GLKit 実装を残した方が安全だと判断した
- formatter / linter の実適用は、コードベース全体に大きな差分を発生させやすく、最終段まで保留する方針にした

## 将来の再開時に最初に確認すること

1. `xcodebuild -project MMDViewer.xcodeproj -scheme MMDViewer -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
2. `xcodebuild -project MMDViewer.xcodeproj -scheme MMDViewer -destination 'platform=iOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO test -only-testing:MMDViewerTests`
3. iPhone シミュレータでモデル表示、モーション再生、Play/Pause、カメラ操作を確認する
4. `CHANGELOG.md` の `0.5.0` とこの `ROADMAP.md` を読み直し、どこまで近代化済みかを再確認する

## コード上の重要な参照先

- [`/Users/kmi/devel/MMDViewer/MMDViewer/melt/view/MMDView.swift`](/Users/kmi/devel/MMDViewer/MMDViewer/melt/view/MMDView.swift)
  - frame loop、scene 準備、present までの流れ
- [`/Users/kmi/devel/MMDViewer/MMDViewer/melt/object/PMXObject.swift`](/Users/kmi/devel/MMDViewer/MMDViewer/melt/object/PMXObject.swift)
  - animation、morph、geometry、GPU 転送の中心
- [`/Users/kmi/devel/MMDViewer/MMDViewer/GLKMatrix4+MMD.swift`](/Users/kmi/devel/MMDViewer/MMDViewer/GLKMatrix4+MMD.swift)
  - `GLKit` と `simd` の互換境界、残している理由
- [`/Users/kmi/devel/MMDViewer/MMDViewer/PhysicsSolving.swift`](/Users/kmi/devel/MMDViewer/MMDViewer/PhysicsSolving.swift)
  - 物理ブリッジの公開境界
- [`/Users/kmi/devel/MMDViewer/MMDViewer/PhysicsSolver.mm`](/Users/kmi/devel/MMDViewer/MMDViewer/PhysicsSolver.mm)
  - Bullet との実結線

## 補足

- `melt` は MMDViewer 専用の描画基盤レイヤー名として維持する
- `melt` はすでに物理ディレクトリ化されており、Xcode 上の group 構造と実ファイル配置は一致している
- formatter / linter は評価済みだが、差分を大きくしすぎないため実適用は保留している
