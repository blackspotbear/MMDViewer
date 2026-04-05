# MMDViewer Project Goals and Findings

## 調査の目的

この調査の第一目的は、数年間メンテナンスされていない本プロジェクトを、現在の開発環境で再びビルド・実行可能な状態まで更新することです。あわせて、以下を実施する前提で現状を把握しました。

- 最新の Swift 言語仕様に沿って書き直す
- 利用中のフレームワークを最新のものへ更新する
- Apple がより適した新フレームワークを提供している場合は移行を検討する
- リファクタリングを進める
- ドキュメンテーションコメントを充実させる
- テストコードを整備する

## 現状の要約

このプロジェクトは、MikuMikuDance の PMX モデルと VMD モーションを読み込み、Metal で描画する iOS アプリです。README では「MMD の完全対応は目指さず、シェーダ実装の playground」と明記されています。

- UI は UIKit + Storyboard ベース
- 描画は Metal ベース
- 数学演算と姿勢計算に GLKit を多用
- 物理演算は Objective-C++ ブリッジ経由で Bullet 2.83.7 を同梱
- テストターゲットは存在するが中身は雛形のまま

## リポジトリ構成

- `MMDViewer/`
  - アプリ本体
  - PMX/VMD ローダ、姿勢計算、描画パス、Metal シェーダを含む
- `MMDViewerTests/`
  - 単体テストターゲット。実質未実装
- `MMDViewerUITests/`
  - UI テストターゲット。実質未実装
- `data/`
  - PMX モデル、テクスチャ、VMD モーション
- `third-party/bullet3-2.83.7/`
  - 物理演算ライブラリのベンダリング済みソース
- `MMDViewer.xcodeproj/`
  - Xcode プロジェクト設定

## 実装アーキテクチャの理解

### アプリ起動と UI

- [`AppDelegate.swift`](/Users/kmi/devel/MMDViewer/MMDViewer/AppDelegate.swift) は `@UIApplicationMain` を利用しており、Scene ベースではありません
- [`ViewController.swift`](/Users/kmi/devel/MMDViewer/MMDViewer/ViewController.swift) は storyboard 上の `MMDView` と toolbar を制御しています
- バックグラウンド遷移は独自 `NotificationCenter` 通知文字列で連携しています

### 描画

- [`MMDView.swift`](/Users/kmi/devel/MMDViewer/MMDViewer/MMDView.swift) が描画ループの中心です
- `CADisplayLink` で 30fps 駆動
- `MetalView` を自前実装し、その上で `BasicRenderer` と `Traverser` が scene graph を巡回
- `#if true` により現状は forward rendering 側が有効
- deferred rendering 系コードも残っているが、実験途中の構成に見えます

### アセット読み込み

- [`PMX.swift`](/Users/kmi/devel/MMDViewer/MMDViewer/PMX.swift) が PMX をバイナリ解析
- [`VMD.swift`](/Users/kmi/devel/MMDViewer/MMDViewer/VMD.swift) がモーションを解析
- [`DataReader.swift`](/Users/kmi/devel/MMDViewer/MMDViewer/DataReader.swift) が低レベル読み出しを担当
- モデルとモーションは [`MMDView.swift`](/Users/kmi/devel/MMDViewer/MMDViewer/MMDView.swift) 内で固定パス読み込みされており、差し替え容易性は低いです

### アニメーションと姿勢制御

- [`PMXObject.swift`](/Users/kmi/devel/MMDViewer/MMDViewer/PMXObject.swift) が姿勢、モーフ、GPU バッファ、テクスチャを集約しています
- FK、IK、Grant、物理を 1 フレームごとに順次適用しています
- 骨姿勢は `Posture` クラスに蓄積されます
- 行列・クォータニオン処理はほぼ全面的に GLKit 拡張に依存しています

### 物理演算

- [`PhysicsSolver.mm`](/Users/kmi/devel/MMDViewer/MMDViewer/PhysicsSolver.mm) が Bullet を直接利用する Objective-C++ 実装です
- Swift 側は [`PhysicsSolver.swift`](/Users/kmi/devel/MMDViewer/MMDViewer/PhysicsSolver.swift) と protocol で抽象化されています
- Bridging Header を通じて Swift と接続しています
- Bullet のバージョンは `2.83.7` で、かなり古い部類です

## 確認できた古さと主要な更新ポイント

### 1. ビルド設定が古い

[`MMDViewer.xcodeproj/project.pbxproj`](/Users/kmi/devel/MMDViewer/MMDViewer.xcodeproj/project.pbxproj) から、以下を確認しました。

- `IPHONEOS_DEPLOYMENT_TARGET = 12.2`
- `SWIFT_VERSION = 5.0`
- Storyboard ベース
- Bridging Header 利用

現行ツールチェーンは `Apple Swift version 6.2.4` ですが、プロジェクト設定はそれに追従していません。

### 2. GLKit 依存が強い

`GLKMatrix4`、`GLKQuaternion`、`GLKVector*` がモデル読み込み、姿勢制御、カメラ、物理連携まで広範囲に使われています。Metal を使っているにもかかわらず、数学レイヤは GLKit のままです。

Apple の公開資料では、OpenGL ES は iOS 12 で deprecated とされ、GLKit はその文脈の古い技術群に属します。今後の保守性を考えると、`simd` ベースへ統一するのが最優先です。

### 3. UIKit の起動構成が旧式

`@UIApplicationMain` と AppDelegate 主体の構成で、Scene lifecycle や SwiftUI の app 構成は採用されていません。現時点でも UIKit 継続は可能ですが、長期的には SwiftUI の app lifecycle を採り、描画部分だけを UIKit/MetalKit ブリッジする形が自然です。

### 4. MetalView を自前実装している

[`MetalView.swift`](/Users/kmi/devel/MMDViewer/MMDViewer/MetalView.swift) は `CAMetalLayer` を直接扱う独自 UIView です。これは当時は妥当ですが、現在は `MTKView` に寄せた方が保守性、drawable 管理、リサイズ処理、周辺 API 連携の面で有利です。

### 5. テストが未整備

- [`MMDViewerTests.swift`](/Users/kmi/devel/MMDViewer/MMDViewerTests/MMDViewerTests.swift) は雛形のみ
- [`MMDViewerUITests.swift`](/Users/kmi/devel/MMDViewer/MMDViewerUITests/MMDViewerUITests.swift) も雛形のみ

ローダ、補間、IK、行列変換、モーフ適用、物理ブリッジ境界など、テストしやすい領域は多い一方で、現状は検証資産がほぼありません。

## 現在のビルド確認結果

当初、この環境では `xcodebuild` 実行時に Xcode プラグインのロード失敗が発生し、プロジェクト一覧取得の段階で停止していました。エラーメッセージは要約すると以下です。

- `A required plugin failed to load`
- `xcodebuild -runFirstLaunch` を促すメッセージ

その後、以下を実施してビルドと実行の復旧を確認しました。

- `xcodebuild -runFirstLaunch` による Xcode 初期化
- iOS Simulator runtime の導入
- Metal Toolchain の導入
- `IPHONEOS_DEPLOYMENT_TARGET` を `13.0` へ更新
- iOS Simulator では `x86_64` を除外し、`arm64` Simulator 前提へ調整
- `CAMetalLayer` と drawable size 更新まわりの現行 SDK 対応
- depth/stencil texture の `storageMode` を現行 Metal validator に合わせて修正
- fragment buffer offset 制約に対応するため、一部 material 受け渡しを `setFragmentBytes` に変更

2026-04-06 時点で、現在の Xcode 26.4 環境において以下を確認済みです。

- `xcodebuild` による simulator 向けビルド成功
- iPhone Simulator 上でのアプリ起動成功
- PMX モデル表示成功
- VMD モーション再生成功

したがって、現時点では「ビルド不能な過去プロジェクト」ではなく、「現代環境で再び起動できるが、段階的な近代化と警告解消が必要なプロジェクト」という状態まで回復しています。

## 2026-04-06 時点の残課題

ビルドと基本動作は復旧しましたが、まだ以下は残っています。

- Bullet 2.83.7 由来の大量 warning
- テスト未整備
- `GLKit` / 自前 MetalView 依存の近代化は継続中

一方で、第1段階の後片付けとして以下は解消済みです。

- `UIScene` lifecycle 未対応の警告
- toolbar の Auto Layout 警告
- `GLKit` 拡張の retroactive conformance 警告
- `statusBarOrientation` の deprecated 警告

また、第2段階の着手として以下を実施済みです。

- `DataReader` に対する基本的な単体テストを追加
- テストターゲットの `PRODUCT_NAME` が誤って `MMDViewer` になっていた設定を修正
- `xcodebuild test -only-testing:MMDViewerTests` で 6 件の単体テスト成功を確認

第3段階では、Swift 側の `float3` / `float4` を `SIMD3<Float>` / `SIMD4<Float>` へ置き換えたうえで、`GLKQuaternion` の積・回転・補間経路も `simd` ベースの実装へ寄せました。現時点では API 境界に `GLKQuaternion` を残しつつ内部実装を差し替える形にしており、既存呼び出し側への影響を抑えながら段階的な移行を進めています。

加えて、`GLKMatrix4` と `simd_float4x4` の相互変換を導入し、shader uniforms と matrix palette を GPU へ送る経路は `simd` ベースへ寄せました。こちらも API 境界は `GLKMatrix4` のまま保ち、まずは描画系のデータ受け渡しから近代化しています。

また、クォータニオン変換・合成・ベクトル回転の回帰テストに加えて、`GLKMatrix4` <-> `simd_float4x4` の round-trip テスト、および実データの PMX / VMD fixture を読み込むローダ確認テストを追加し、`xcodebuild test -only-testing:MMDViewerTests` で 11 件の単体テスト成功を確認済みです。

## Bullet 更新可否の調査結果

ローカル実装の確認では、Bullet は prebuilt library ではなく、[`third-party/bullet3-2.83.7/`](/Users/kmi/devel/MMDViewer/third-party/bullet3-2.83.7) に同梱したソースを Xcode ターゲットへ直接追加して使っています。フォルダ名は `2.83.7` ですが、同梱された [`VERSION`](/Users/kmi/devel/MMDViewer/third-party/bullet3-2.83.7/VERSION) には `2.84` と記載されています。

現在 Swift / Objective-C++ 側で実際に使っている Bullet API はかなり限定的です。

- dynamics world: `btDiscreteDynamicsWorld`
- broadphase / dispatcher / solver: `btDbvtBroadphase`, `btCollisionDispatcher`, `btSequentialImpulseConstraintSolver`
- shape: `btSphereShape`, `btBoxShape`, `btCapsuleShape`
- transform / motion: `btTransform`, `btDefaultMotionState`, `btRigidBody`
- constraint: `btGeneric6DofSpringConstraint`

つまり、このアプリは Bullet の巨大な機能集合のうち、剛体、基本 shape、6DoF spring constraint だけを使っています。依存範囲が狭いため、「理論上は更新可能」である可能性が高いです。

一方で、[`MMDViewer.xcodeproj/project.pbxproj`](/Users/kmi/devel/MMDViewer/MMDViewer.xcodeproj/project.pbxproj) を確認すると、Xcode target に追加されている Bullet ソースは実使用 API よりかなり広く、合計 143 本の `.cpp` / `.c` をコンパイルしています。内訳は次の通りです。

- `BulletCollision/BroadphaseCollision`: 10
- `BulletCollision/CollisionDispatch`: 26
- `BulletCollision/CollisionShapes`: 36
- `BulletCollision/Gimpact`: 11
- `BulletCollision/NarrowPhaseCollision`: 12
- `BulletDynamics/Character`: 1
- `BulletDynamics/ConstraintSolver`: 16
- `BulletDynamics/Dynamics`: 3
- `BulletDynamics/Featherstone`: 7
- `BulletDynamics/MLCPSolvers`: 3
- `BulletDynamics/Vehicle`: 2
- `BulletSoftBody`: 8
- `LinearMath`: 8

つまり、アプリが本当に必要としている剛体 + 基本 shape + 6DoF spring constraint まわりよりも、target 設定側は「Bullet 2 系のかなり広い範囲を丸ごと抱えている」状態です。vendor 更新時の差分や warning の量は、この広さの影響を強く受けます。

また、[`PhysicsSolver.mm`](/Users/kmi/devel/MMDViewer/MMDViewer/PhysicsSolver.mm) はもともと umbrella header の `btBulletDynamicsCommon.h` を読み込んでいましたが、現時点では明示的な個別 header 群へ差し替えても simulator build は通ります。つまり、コード側の include 依存は先に狭められる見込みがあり、target 側の縮小前準備として有効です。

さらに、版付き vendor パス `third-party/bullet3-2.83.7` への直接依存を確認すると、Xcode project 側では主に次の 6 箇所に集中していました。

- group path: `BulletCollision`
- group path: `BulletDynamics`
- group path: `BulletSoftBody`
- group path: `LinearMath`
- `HEADER_SEARCH_PATHS` 2 箇所

このため、vendor 差し替え作業そのものは「版付きディレクトリ名に引きずられて project 全体を大改造する」ほど重くはなく、少なくともパス更新の観点では比較的機械的に進められる見込みです。

一方で、更新には次のリスクがあります。

- Xcode プロジェクトへ手で追加している Bullet ソース一覧の更新が必要
- `btGeneric6DofSpringConstraint` まわりの挙動差分確認が必要
- iOS Simulator / 実機での挙動確認を必須にする必要がある
- warning 解消と API 差分吸収を同時にやると切り分けが難しい

2026-04-06 時点で確認できた公式情報では、GitHub 上の最新 release は [bulletphysics/bullet3 Releases](https://github.com/bulletphysics/bullet3/releases) にある `PyBullet 3.2.5` / tag `3.25`（2022-04-24）です。一方でリポジトリ本体は [bulletphysics/bullet3](https://github.com/bulletphysics/bullet3) として 2025 年にも更新が続いており、release と repository head に時間差があります。

このため、更新方針としては次の順が妥当です。

1. まず Bullet 2 系の公式 release を基準に、vendor ディレクトリを丸ごと更新する方針を第一候補として見積もる
2. 更新対象は、現行コードとの距離を考えて `PyBullet 3.2.5` よりも [`Bullet 2.89`](https://github.com/bulletphysics/bullet3/releases/tag/2.89) を先に試す
3. `PhysicsSolver.mm` が依存する API に大きな差分がなければ、小さいイテレーションで差し替える
4. 置換後はビルド、単体テスト、シミュレータ表示、物理付きモーションの実動作確認を行う
5. もし warning や差分の切り分けが重すぎると分かったら、その時点で target 依存面積の縮小を第 2 案として実施する

現時点の結論は、「Bullet 更新は検討価値が高く、まずは丸ごと更新を第一候補として試すべき」です。target 依存面積の縮小は有効な改善ですが、更新前の必須条件ではなく、更新が重すぎる場合の第 2 案として扱うのが合理的です。

## Apple の新しいフレームワークへの移行判断

### 採用有力

- `simd`
  - GLKit 数学 API の代替として最優先
- `MetalKit`
  - `MTKView` と `MTKTextureLoader` の利用価値が高い
- `Swift Testing`
  - 新規テストは XCTest よりこちらを第一候補にできる
- `SwiftUI`
  - UI 層の刷新先として有力

### 慎重判断

- `RealityKit`
  - Apple は現在も積極的に拡張していますが、AR/空間体験向けの性格が強いです
  - このプロジェクトは PMX/VMD の独自フォーマット読込、独自シェーダ、独自レンダリング検証が主目的なので、全面移行先としては適合度が高くありません
  - もし将来 visionOS や AR 表示を狙うなら再検討余地はあります

結論として、現段階では「RealityKit へ移行」よりも「Metal を維持しつつ、数学・ビュー・UI・テスト基盤を現代化」が妥当です。

## テスト観点

優先順位は次の通りです。

1. PMX/VMD/DataReader のパーサテスト
2. 補間計算、姿勢更新、IK/FK の純ロジックテスト
3. モーフ適用のスナップショット的検証
4. 物理ブリッジの境界テスト
5. UI 起動と最低限の再生操作の UI テスト

特に、GLKit -> simd 置換では数値回帰テストが重要です。旧実装と新実装で骨行列、補間結果、カメラ行列が一致することを確認できるようにするべきです。

## リファクタリング上の注目点

- `PMXObject` に責務が集中している
- ローダが巨大関数群ベースで、失敗表現も弱い
- 文字列通知、固定パス、強制アンラップが多い
- クラス中心で値型化できる領域が多い
- public/internal/private の境界が整理されていない
- DocC やソースコメントの整備余地が大きい

## 参考にした外部資料

- Apple Developer Documentation: [Swift Testing](https://developer.apple.com/documentation/testing)
- Apple Developer: [MetalKit](https://developer.apple.com/documentation/metalkit)
- Apple Developer: [MTKView](https://developer.apple.com/documentation/MetalKit/MTKView)
- Apple Developer: [SwiftUI](https://developer.apple.com/swiftui/)
- Apple Developer: [RealityKit Overview](https://developer.apple.com/augmented-reality/realitykit/)
- Apple Archive: [Drawing with OpenGL ES and GLKit](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/OpenGLES_ProgrammingGuide/DrawingWithOpenGLES/DrawingWithOpenGLES.html)
- Swift.org: [Documentation](https://www.swift.org/documentation/)
- Swift.org Blog: [Swift 6.2 Released](https://www.swift.org/blog/swift-6.2-released)

## 補足

この文書は 2026-04-06 時点のリポジトリ内容とローカル環境をもとに更新しました。初回調査時点では Xcode セットアップ不整合の影響を受けていましたが、現在はビルド・起動・モデル表示・アニメーション再生まで確認済みです。
