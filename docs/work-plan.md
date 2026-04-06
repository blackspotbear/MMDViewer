# MMDViewer Work Plan

## 進め方の方針

この作業は、一度に大きく作り替えるのではなく、小さなイテレーションで段階的に進めます。各イテレーションでは、変更範囲を意図的に狭く保ち、ビルド・起動・基本操作への影響を早い段階で確認します。

また、各節目であなたに iPhone シミュレータ上の動作確認をお願いする前提で進めます。これにより、内部実装の改善中に描画、モーション再生、カメラ操作、アプリ起動といったユーザー視点の動作が破壊されていないことを継続的に確認できます。

## 実施ルール

- 1 回の変更では 1 つの主題だけを扱う
- 変更後はまずビルド確認を行う
- ビルドが通ったら、必要に応じて単体テストまたは UI テストを追加・更新する
- その後、あなたに iPhone シミュレータでの確認を依頼する
- シミュレータ確認で問題がなければ次のイテレーションへ進む
- 問題があれば、その場で原因を限定してから修正する
- 数学 API の置換と、GPU に渡すバッファ配置や生バイト列の変更は同じイテレーションで混ぜない
- 描画バッファ、uniform、matrix palette、render pass を触った変更は、単体テストだけで完了扱いにせずシミュレータ確認を必須にする
- `melt` は MMDViewer 専用の描画基盤レイヤー名として維持し、renderer / pass / drawer / updater / view など描画側の整理単位として扱う
- `melt` を物理ディレクトリへ移す場合は、ロジック変更と混ぜず `ファイル移動と参照更新だけ` の専用イテレーションに分ける

## 想定する確認項目

各イテレーションの完了時に、必要に応じて次の観点を確認します。

- アプリが起動する
- モデルが表示される
- モーションが再生される
- 再生 / 一時停止が機能する
- ダブルタップ、パン、ピンチ、回転の操作が効く
- 背景遷移後に挙動が大きく壊れない
- 見た目や動きに明らかな回帰がない

## 作業フェーズ

### フェーズ 0: 開発環境の正常化

目的は、まず機械的なビルド確認ができる状態を取り戻すことです。

- `xcodebuild` のプラグイン不整合を解消する
- `xcodebuild -list` と最小ビルドが通る状態を確認する
- 現在の Xcode / Swift / iOS Simulator の前提を固定する

### フェーズ 1: 現行コードをできるだけ保ったままビルド復旧

目的は、設計刷新より前に、現行機能を保ったまま現代ツールチェーンで動かすことです。

- Swift 6 系でのコンパイルエラー解消
- iOS Deployment Target とビルド設定の更新
- Storyboard、Info.plist、署名設定の見直し
- Bullet 連携と Bridging Header の成立確認
- 利用中の Bullet の更新可否と更新コストを調査する

### フェーズ 2: テスト基盤の整備

目的は、後続のリファクタリングを安全に進めるための回帰検知を先に作ることです。

- `DataReader` の単体テスト
- PMX/VMD パーサの基本テスト
- 補間や行列計算の数値テスト
- UI 起動確認テストの最小セット

### フェーズ 3: GLKit 依存の段階的削減

目的は、もっとも古い依存である GLKit を安全に置き換えることです。

- ベクトル型を `simd` へ移行
- クォータニオン型を `simd_quatf` へ移行
- 行列型を `simd_float4x4` へ移行
- まず数学 API と相互変換を置き換え、その後に描画バッファ経路の変更可否を別イテレーションで判断する
- Objective-C++ 側の変換コードを更新
- 旧実装との数値差分をテストで監視

### フェーズ 4: レンダリング基盤の整理

目的は、描画基盤を現代的で保守しやすい形に整えることです。

- 自前 `MetalView` を `MTKView` ベースへ移行
- render pass / drawer / updater の責務整理
- forward / deferred の設定方法を整理
- テクスチャ読込やバッファ管理の見直し

### フェーズ 5: UI とアプリライフサイクルの現代化

目的は、アプリ外周の構成を今後も保守しやすい形にすることです。

- UIKit 維持か SwiftUI 移行かを判断
- App lifecycle と Scene 対応を整理
- 通知文字列や画面責務を見直す

### フェーズ 6: 品質向上

目的は、長期保守できるコードベースに仕上げることです。

- `PMXObject` など責務集中箇所の分割
- クラス、構造体、主要関数へのドキュメンテーションコメント追加
- テストコードにも意図と前提条件が分かるコメントを追加
- DocC 導入の検討
- テスト拡充
- lint / formatting / 命名の見直し

### フェーズ 7: 最終棚卸しと追加改善案の検討

目的は、主要な近代化作業が一巡した後に、取りこぼしや次の改善余地を整理することです。

- さらに近代化できる箇所が残っていないかを点検する
- 追加で自動テスト化できる領域がないかを見直す
- パフォーマンス改善の余地がある箇所と計測方法を検討する
- `SwiftLint`、`swift-format`、必要なら formatter 運用の導入余地を検討する
- 導入コストに対して効果の高い開発支援を整理する
- 次の保守サイクルに向けた改善候補を文書化する

## TODO

### 直近

- [x] Xcode 環境の不整合を解消し、`xcodebuild` が動く状態にする
- [x] ターゲット一覧、利用 SDK、シミュレータ起動条件を確認する
- [x] 現行コードを変更せずに発生するビルドエラーを収集する
- [x] 最初のビルド復旧イテレーションの対象を最小単位で切り出す

### ビルド復旧

- [x] Swift 6 系で問題になる構文、API、警告を洗い出す
- [x] `IPHONEOS_DEPLOYMENT_TARGET` を見直す
- [x] signing や project setting の古い値を更新する
- [x] アプリがシミュレータで起動する状態まで戻す
- [x] あなたに iPhone シミュレータで初回動作確認を依頼する
- [x] モデル表示とモーション再生が復旧したことを確認する
- [x] `UIScene` lifecycle 警告を解消する
- [x] toolbar の Auto Layout 警告を解消する
- [x] `statusBarOrientation` の deprecated 依存を解消する
- [x] `GLKit` 拡張の retroactive conformance 警告を解消する

### テスト

- [x] 単体テスト対象をロジック層から切り出す
- [x] `DataReader` のテストを書く
- [x] PMX/VMD ローダの基礎テストを書く
- [x] 数学処理の回帰テストを書く
- [x] 最小限の UI 起動テストを書く

### GLKit 置換

- [x] 置換対象の型と拡張メソッド一覧を作る
- [x] `GLKVector*` の置換を小さな単位で始める
- [x] `GLKQuaternion` の主要演算を `simd` ベースへ移行する
- [x] `GLKMatrix4` と `simd_float4x4` の相互変換を導入する
- [x] `GLKMatrix4` の factory / helper を安全な単位で `simd` ベースへ寄せる
- [x] `GLKMatrix4` の互換性境界を回帰テストとコメントで明文化する
- [ ] `GLKMatrix4` の matrix-matrix 演算置換方針を確定する
- [ ] 物理ブリッジの型変換を更新する
- [x] 物理ブリッジの差し替え点を helper とコメントで局所化する
- [x] 各段階であなたにシミュレータ確認を依頼する

### レンダリング基盤

- [x] `MetalView` の drawable / layer 管理責務を整理する
- [x] `MMDView` の frame 駆動を値オブジェクトと helper に分離する
- [x] render pass / renderer / traverser の begin-end 境界を helper に整理する
- [x] `PMXObject` の render buffer 更新責務を helper と文脈型へ分離する
- [ ] `melt` 論理 group を物理ディレクトリへ移すか判断する
- [ ] 物理ディレクトリ化する場合の配置案を確定する
- [ ] ファイル移動と project 参照更新だけの専用イテレーションを実施する
- [ ] `MTKView` 移行の差分設計を書く
- [ ] 最小移行を実装する
- [ ] 描画結果の回帰確認を行う
- [ ] あなたにシミュレータで見た目確認を依頼する

### UI / 品質

- [ ] UIKit 維持か SwiftUI 移行かを判断するための比較メモを作る
- [x] ライフサイクル通知の整理方針を決める
- [x] ドキュメンテーションコメント追加対象を洗い出す
- [x] renderer / pass / drawer / updater / view 基盤へのコメント追加を進める
- [x] `PMXObject` / `PMXUpdater` / physics bridge へのコメント追加を進める
- [x] テストコードに意図、前提、期待結果が分かるコメントを書く
- [x] 責務分離の優先順位を決める
- [x] `PMXObject` の初期化と毎フレーム更新を段階的に分離する
- [x] `MMDView` の scene 準備と frame 実行を段階的に分離する
- [ ] 最終的なテスト不足領域を埋める
- [x] Bullet 2 系の公式 release を基準に、vendor を丸ごと更新できるか調査する
- [x] Bullet 2.89 を第一候補として、API 差分と移行コストを確認する
- [ ] 丸ごと更新が重すぎる場合に備えて、target 依存面積の縮小を第 2 案として整理する
- [x] Bullet 2.89 更新後の描画、モーション、物理挙動をシミュレータで確認する

### 最終棚卸し

- [ ] 追加で近代化できる箇所が残っていないかを確認する
- [ ] 追加でテスト化できる領域を洗い出す
- [ ] パフォーマンス改善候補と計測方針を整理する
- [ ] `SwiftLint` や `swift-format` の導入メリットとコストを評価する
- [ ] formatter / lint の導入方針を決める
- [ ] 次の改善候補を短いメモとして残す

## 直近の達成事項

- Xcode 26.4 環境で `xcodebuild` が利用可能になった
- iOS Simulator runtime と Metal Toolchain を導入した
- simulator 向けビルドが成功する状態まで復旧した
- iPhone Simulator 上でアプリ起動を確認した
- PMX モデル表示と VMD モーション再生を確認した
- 現行 Metal validator に合わせて depth/stencil texture と fragment buffer の扱いを修正した
- `UIScene` 対応と toolbar ボタン構成の見直しを行い、外周の警告を一段整理した
- `DataReader` の単体テストを追加し、古い test target 設定が現代 Xcode で失敗する問題を修正した
- Swift 側の `float3` / `float4` を `SIMD3<Float>` / `SIMD4<Float>` に置き換え、`simd` 移行の最初の warning 整理を行った
- `GLKQuaternion` の積・回転・補間経路を `simd` 実装へ寄せ、クォータニオン回帰テストを追加した
- `GLKMatrix4` と `simd_float4x4` の相互変換を追加し、uniform / matrix palette の GPU 転送経路を `simd` ベースへ寄せた
- `GLKMatrix4` <-> `simd_float4x4` の round-trip テストを追加し、単体テストは 10 件になった
- 実データの PMX / VMD fixture を使ったローダ確認テストを追加し、単体テストは 11 件になった
- VMD 補間の数値回帰テストを追加し、単体テストは 13 件になった
- Play / Pause ボタンを使った最小 UI 起動テストを追加し、UI テストで起動とトグル操作を自動確認できるようにした
- Bullet vendor 調査を進め、実使用 API は限定的だが Xcode target は 143 本の Bullet ソースを広くコンパイルしていることを確認した
- `PhysicsSolver.mm` の Bullet include を umbrella header から明示的な個別 header 群へ絞っても simulator build が通ることを確認した
- Bullet 更新方針を見直し、「先に縮小」より「まず丸ごと更新を試し、難しければ縮小へ切り替える」方針に改めた
- Bullet の版付きパス依存は Xcode project 内で主に group path 4 箇所と `HEADER_SEARCH_PATHS` 2 箇所に集中しており、vendor 差し替え自体は比較的機械的に進められそうだと分かった
- Bullet 2.89 への vendor 丸ごと更新を試し、`btMultiSapBroadphase` の参照削除と `btSdfCollisionShape` / `btMiniSDF` の追加で simulator build と単体テスト成功まで確認した
- Bullet 2.89 更新後も、シミュレータ上でモデル表示、モーション再生、Pause / Play、カメラ操作に問題がないことを確認した
- `GLKVector3` / `GLKVector4` の基本 helper の内部実装を `simd` ベースへ寄せ、既存 GLK 演算との差分を回帰テストで監視できるようにした
- 数学互換レイヤーとその回帰テストにドキュメンテーションコメントを追加し、`GLKit` 置換の意図と制約を追いやすくした
- `GLKVector2` と VMD の Bezier 補間計算も `simd` ベースの内部実装へ寄せ、補間ロジックを描画非依存のまま近代化した
- `BasicRenderer` の model matrix stack 参照バグを修正し、あわせて `GLKMathDegreesToRadians` 依存を外した
- 無効化されたまま残っていた lint 用 build phase を削除し、毎回出ていた `Run Script` 警告を解消した
- `Traverser` の update / draw 順序を固定する単体テストを追加し、renderer 周辺のリファクタリングに備えた足場を増やした
- `BasicRenderer` の投影行列更新と model matrix stack 先頭アクセスの重複を helper にまとめ、renderer 状態管理を追いやすくした
- `Traverser` の node 進入/退出処理を helper にまとめ、pass と model matrix stack の対応を追いやすくした
- `Renderer` / `RenderPass` / `Node` / `Updater` / `Drawer` に `melt` 基盤としての役割コメントを追加し、描画層の整理単位を明文化した
- `GLKMatrix4` の `simd_mul` をそのまま使うと GLKit のベクトル適用規約とずれることをテストで確認し、factory / transpose と演算 helper を分けて移行する方針を固めた
- `GLKMatrix4` の axis rotation factory と instance helper (`scale` / `translate` / `rotateAroundX`) を simd-backed factory 経由へ寄せた
- `Renderer` に render command encoder の push / pop helper を追加し、forward / deferred / shadow / wireframe pass の begin / end 境界を renderer 側責務としてそろえた
- `GBufferPass` の begin context と frame index 更新を helper に分離し、deferred path の開始条件とフレーム進行を追いやすくした
- `WireframePass` の begin context、render pass descriptor 更新、pipeline state 更新を helper に分離し、補助描画 pass の段取りを他の pass と揃えた
- `ForwardRenderPass` / `ShadowPass` の begin context と end encoding を helper に分離し、`MMDView` の forward scene graph 構築も node factory へ寄せた
- `MMDView` の frame 完了処理と current frame 実行を helper に分離し、display link から renderer commit までの責務を追いやすくした
- `PMXObject` initializer の vertex/buffer/texture 準備を `PMXObjectResources` にまとめ、resource 初期化のまとまりを 1 箇所に寄せた
- `AppDelegate` の scene configuration 生成と `SceneDelegate` の foreground/background 通知発火を helper に分け、lifecycle 外周の責務を揃えた
- `ViewController` の playback UI 初期化と play/pause toggle を helper に寄せ、UI 外周の状態同期入口を読みやすくした
- `GLKMatrix4` の off-center orthographic factory を `GLKMatrix4+MMD` へ移し、shadow 行列生成から残っていた `GLKMatrix4Make*` 依存を削った
- `GLKMatrix4.multiplyVector4` は `simd` 実装へ寄せられた一方、matrix-matrix multiply は規約差が大きく、当面は GLKit 実装を維持する方針を回帰テストで確認した
- Physics と Bullet の境界で使う GLKit 型変換と rigid body offset 計算を helper に集約し、将来の `simd` 置換ポイントを見通しやすくした
- `Traverser`、`BasicRenderer`、回帰テストに、renderer 規約やテスト意図が分かるドキュメンテーションコメントを追加し始めた
- `PMXObject` に、アニメーション更新、物理連携、morph、uniform / palette / material 転送の役割が追えるドキュメンテーションコメントを追加し始めた
- `PMXObject` の GPU 転送まわりで、shadow 行列計算と palette / material 書き込みを helper へ切り出し、責務分離の最初の足がかりを作った
- `PMXObject` の GPU 転送 helper を private encoder に集約し、描画用データ準備の責務境界を読み取りやすくした
- `PMXObject` の毎フレーム GPU buffer 更新を 1 セットの戻り値にまとめ、draw 前の更新フローを追いやすくした
- `PMXObject` の FK / IK / Grant / world matrix 更新を 1 つの helper にまとめ、物理前の姿勢更新フローを追いやすくした
- `PMXObject` の morph 適用で左右キーフレーム処理の重複を helper に寄せ、毎フレーム更新の段取りを追いやすくした
- `PMXObject` のベース頂点コピーと morph 適用を 1 つの helper にまとめ、CPU morph 更新の差し替え点を明確にした
- `PMXObject` の render buffer 更新代入を helper にまとめ、`calc` を段取り中心で読める形に寄せた
- `PMXObject` の物理ステップも helper にまとめ、`calc` を姿勢更新 / 物理 / 頂点 / 描画バッファの 4 段で読める形にした
- `PhysicsSolver.mm` で Swift 側 rigid body と Bullet body の対応付け、transform 読み書きの重複を helper に集約した
- `PhysicsSolving` 境界と Swift 側の physics update ループにコメントを追加し、今後の `simd` 化の差し替え点を明示した
- `ForwardRenderPass` の drawable / depth attachment 更新責務と `MetalView` の layer 管理責務をコメントと helper で整理し、`melt` の pass-view 境界を追いやすくした
- `GLKMatrix4.multiplyVector4` を `simd` 実装へ寄せ、`PMXObject` 側も helper 経由に統一して matrix-vector 適用の互換性を回帰テストで固定した
- `GBufferPass` と `ShadowPass` の役割コメントを補強し、deferred / shadow の pass 境界をコード上で追いやすくした
- `MMDView` の resource 読み込み、display link 開始、drawable サイズ更新を helper に分離し、`melt` view 層の frame 駆動を段取り中心で追いやすくした
- matrix / traversal / 補間まわりの回帰テストに意図コメントを追加し、どの挙動を守っているかをテストコード上で追いやすくした
- `BasicRenderer` と `CameraUpdater` に renderer 状態管理と camera 更新の規約コメントを追加し、`melt` の view-renderer 境界を読み取りやすくした
- `PMXUpdater` と `PhysicsSolving` に、アニメーション更新順序と物理ブリッジ境界のコメントを追加し、PMX 更新フローを追いやすくした
- `PMXDrawer` / `PMXShadowDrawer` に描画責務コメントを追加し、shadow 側の未使用変数も除いて drawer 層を読みやすくした
- `MetalView` の drawable 取得を helper に分離し、view 層の失敗点と責務をさらに追いやすくした
- `ViewController` の再生状態同期と `AppDelegate` の scene 構成にコメント/ helper を追加し、UI 外周の責務を読みやすくした
- `SceneDelegate` と `ViewController` のライフサイクル通知名を `Notification.Name` で共通化し、UI 外周の境界を型安全に揃えた
- `ViewController` の lifecycle observer を `viewDidLoad` + `deinit` 管理へ寄せ、再表示時の重複登録リスクを減らした
- `SceneDelegate` の通知発火と `MMDView` の window 初期化入口を helper に集約し、UI / view 外周の lifecycle 境界をさらに追いやすくした
- `PMXObject` の morph 補間重み計算と render buffer 保存を helper に分け、毎フレーム更新の段取りをより局所的に読める形へ寄せた
- `PMXObject` の初期化を curve tie / posture / buffer provider / texture 読込の helper へ分離し、責務集中していた constructor を追いやすくした
- `MMDView` の main loop で timestamp 更新と draw 前提条件判定を helper に分離し、frame 駆動の流れをさらに段取り中心で追いやすくした
- `PMXObject` の morph 更新で keyframe 取得と morph 解決を helper 境界へ寄せ、VMD / PMX 依存点を局所化した
- `MetalView` の system default device 作成と layer 初期設定を helper に分離し、`melt` view 入口の差し替え点を明確にした
- `ForwardRenderPass` の begin 条件を helper にまとめ、drawable / command buffer / view の前提条件を 1 箇所で追えるようにした
- `PMXDrawer` の material ごとの texture / pipeline / fragment material 設定を helper に集約し、forward draw loop の段取りを追いやすくした
- `BasicRenderer` の command buffer 生成と end handler 呼び出しを helper に分離し、renderer の frame begin / end 境界を読みやすくした
- `ShadowPass` の encoder 生成と encoder 設定を helper に分離し、shadow pass の begin 境界を読みやすくした
- `PMXObject` の uniform / palette / material buffer 取得を helper に寄せ、GPU 転送前の取得点をそろえた
- `GBufferPass` の color / depth / stencil attachment 更新を helper に分離し、deferred pass の attachment 更新責務を追いやすくした
- `GBufferPass` の texture resource 設定、encoder 生成、composition 段取りを helper に分離し、deferred path の begin/end 境界を読みやすくした
- `PMXObject` の render buffer 保存 helper 名を明示化し、更新段取りの意図を追いやすくした
- `Traverser` の 1 frame begin / draw / end を helper に集約し、traversal と frame 境界を分けて追いやすくした
- `PMXObject` の current vertex buffer 取得とベース頂点コピーを helper に分離し、CPU morph 前段の差し替え点を明確にした
- `Renderer.setEndHandler` の責務コメントを補強し、`MMDView` と renderer の frame 完了境界を読み取りやすくした
- `PMXObject` の index buffer / physics solver 生成と 1 frame 更新入口を helper 化し、初期化と毎フレーム更新の段取りをそろえた
- `PMXObject` の curve tie / posture / counter / solver 初期化を `PMXObjectAnimationState` にまとめ、`PMXUpdater` でも角速度減衰と frame 進行を helper に分離して更新入口の段取りをそろえた
- `MMDView` の window 参加時処理で display scale 設定と scene 準備を helper に分け、UIKit lifecycle 入口の段取りをさらに読みやすくした
- `ViewController` の再生状態参照を computed property に集約し、通知/toolbar の両経路で同じ playback 状態判定を使うようにした
- `SceneDelegate` の lifecycle notification 発火を 1 つの helper にまとめ、`MMDView` でも PMX updater 生成を helper 化して scene graph 構築時の段取りをそろえた
- `ViewController` の lifecycle notification 登録と playback button 文言決定を helper に寄せ、UI 外周の重複を減らした
- `MMDView` の gesture recognizer 登録を helper に分離し、view 初期化時の入力セットアップを追いやすくした
- `PMXObject` の 1 frame 更新を animation state / geometry state / render buffer の段に分け、`AppDelegate` でも Main.storyboard 生成を helper 化して UI 外周の入口をそろえた
- `MMDView` の scene resource 読み込みを PMX / VMD / PMXObject 生成 helper に分け、scene 準備時の差し替え点を明確にした
- `PMXObject` の morph 適用と render buffer 取得で optional 分岐と `BufferProvider` 利用を helper に寄せ、毎フレーム更新の段取りをさらにそろえた
- `MetalView` の drawable 取得、layer 初期化、frame 追従を helper 境界へそろえ、`melt` view 入口の責務をさらに明確にした
- `MMDView` の forward / deferred scene graph 構築を node factory 群へ分離し、描画構成の段取りを大きめの単位で追いやすくした
- `MMDView` では drawable サイズ更新フラグだけを管理し、layer frame 追従は `MetalView` 側責務へ戻して view 境界の重複を減らした
- `PMXObject` の morph 更新で、VMD/PMX 名解決と CPU 頂点 buffer 反映を別段に分け、将来の GPU morph 化やテスト追加の差し替え点を明確にした
- `MMDView` の scene resource 読み込みを `MMDSceneResources` へまとめ、読込結果の生成と view への保持を別段に分けた
- `PMXObject` が個別に抱えていた 4 種類の `BufferProvider` を `PMXBufferProviders` に束ね、描画バッファ所有境界を 1 つのまとまりとして扱えるようにした
- `MMDView` の scene graph 構築を `MMDSceneGraphConfiguration` と適用処理に分け、構成値と root node 反映を別段にした
- `SceneDelegate` と `ViewController` の lifecycle / playback 状態を enum で持ち上げ、通知名や再生状態の分岐を外周専用の型へ寄せた
- `MMDView` の display link 入口を `prepareCurrentFrame` と描画実行に分け、frame 準備と draw 実行の境界を明確にした
- `PMXObject` の毎フレーム更新で `PMXAnimationTick` を導入し、現在フレーム番号と IK 反復回数の参照を 1 つの値として渡すようにした
- `MMDView` の scene 準備を `MMDPreparedScene` で表し、resource 読み込みと root/layer 反映を準備段と適用段に分離した
- `MMDView` の scene graph 構成は保持済みプロパティ `miku` に暗黙依存させず、準備済み `PMXObject` を明示的に受け渡す形へ直した
- `PMXObject` の 1 フレーム更新で `PMXFrameContext` を導入し、renderer と animation tick をまとめた文脈を各更新段へ渡すようにした
- `MMDView` の frame 完了処理で drawable 取得と command buffer 完了を helper に分け、present / commit の最終段を追いやすくした
- `PMXObject` の constructor では `PMXObjectSetup` に resource/animation state 生成を束ね、初期化段取りを 1 つの setup 値として読める形にした
- `MMDView` の window 参加時セットアップを `MMDWindowConfiguration` にまとめ、display scale と prepared scene 適用を同じ構成値から扱えるようにした
- `PMXObject` の morph 更新で keyframe と補間重みを `PMXMorphFrameContext` にまとめ、morph 適用前の frame 依存値を 1 つの値へ寄せた
- `MMDView` の current frame 準備結果を `MMDPreparedFrame` にまとめ、display link 入口での準備と draw 実行を値オブジェクト経由で二段に分けた
- `MetalView` の layer/device 初期化を `MetalViewLayerConfiguration` にまとめ、UIView 側で持つべき Metal 構成値を 1 箇所で読める形にした
- `PMXObject` の 1 フレーム文脈を `PMXAnimationTick` と `PMXRenderContext` に分け、毎フレーム更新の中でも描画依存の境界をさらに局所化した
- `MMDView` の frame 完了処理でも `MMDFrameCompletion` を導入し、drawable と command buffer の締め処理を 1 つの値として扱えるようにした
- `PMXObject` の geometry 更新段で `PMXGeometryContext` を導入し、CPU morph 前段が必要とする vertex buffer と animation tick を 1 つの文脈にまとめた
- `MMDView` の resize/reshape 更新で `MMDDrawableLayout` を導入し、drawable size と renderer の reshape 入力を同じレイアウト値から扱えるようにした
- `PMXObject` の uniform / palette / material 更新でも `PMXRenderContext` を共通入口にし、描画依存の受け渡しを `Renderer` 生参照より一段局所化した
- `MMDView` の prepared scene 適用でも `MMDSceneApplication` を介す形にし、resource 保持と scene graph / layer 反映を同じ適用値として読めるようにした
- `MMDView` の display link 起動設定を `MMDDisplayLinkConfiguration` に分け、window 構成から frame 駆動設定だけを切り出せるようにした
- `PMXObject` の render buffer 保存でも `PMXStoredRenderBuffers` を介す形にし、draw 前に保持する GPU バッファ集合を 1 つの値として扱えるようにした
- `PMXObject` の morph 解決結果を `PMXMorphUpdates` として左右別の更新集合にまとめ、keyframe 解決と頂点更新適用の境界をさらに明確にした
- `MMDView` の display link 起動では生成と設定を分け、window 構成から frame 駆動へ流れる段取りをより追いやすくした
- `MMDPreparedFrame` が drawable layout も持つようにし、frame 準備結果を時間情報だけでなく描画前提込みの値として扱えるようにした
- `PMXRenderContext` に model matrix も含め、uniform 更新段が `PMXObject` のプロパティへ暗黙依存しすぎない形に寄せた
- `PMXRenderContext` では model / normal matrix を `PMXModelTransforms` に束ね、uniform 更新段の入力をモデル変換単位で扱えるようにした
- `MMDView` の draw 可否判定も `MMDDrawableLayout` を入力にして、frame 準備結果と drawable 前提条件を同じ値で追えるようにした
- `MMDPreparedFrame` の時間情報も `MMDFrameTiming` に分け、display link の経過時間計算結果を frame 準備値の一部として追えるようにした
- `PMXObject` の render buffer 生成結果も `PMXFrameRenderBufferAssembly` を介す形にし、draw 前の GPU バッファ組み立て段を専用の値として扱えるようにした
- `PMXMorphFrameContext` では左右 keyframe 群を `frames` として扱う形にそろえ、morph 文脈値の役割を読み取りやすくした
- `MMDView` の frame 完了値でも present 用の組を `MMDFramePresentation` として分離し、drawable 提示と command buffer commit の責務を明確にした
- `MMDView` の draw 実行段でも `MMDFrameExecution` を介し、frame 準備値から実行時に参照する時間情報を別段で扱えるようにした
- `PMXFrameContext` では animation 入力を `PMXAnimationContext` に分け、毎フレーム更新の中でアニメーション依存の値を render 文脈と分離した
- `MMDView` の resize / reshape 更新でも `MMDLayoutUpdate` を介し、drawable layout の反映段を専用の更新値として扱えるようにした
- `PMXObject` の morph 適用入口でも `PMXMorphApplicationContext` を介し、morph 文脈の取得と適用段をさらに分けた
- `MMDView` の display link 設定も window 構成値から与える形にして、window 参加時の初期設定を 1 か所で読めるようにした

## 次のイテレーション候補

- `GLKMatrix4` の演算 API 置換
- Bullet 2.89 更新後のシミュレータ実動作確認
- Bullet と bridge 境界の型変換整理

## イテレーションの完了条件

各イテレーションは、少なくとも次を満たしたときに完了とします。

- 変更の目的が 1 つに絞られている
- ローカルでビルド結果を確認している
- 必要なテストを追加または更新している
- あなたに依頼すべきシミュレータ確認項目が整理されている
- 回帰がなければ次のステップへ進める状態になっている

## 進捗共有のしかた

進捗共有では、毎回次の形を維持します。

- 今回のイテレーションで何を変えたか
- 何を確認できたか
- まだ残っているリスクは何か
- あなたに iPhone シミュレータで確認してほしい項目は何か
- 次のイテレーションで着手する範囲はどこか
