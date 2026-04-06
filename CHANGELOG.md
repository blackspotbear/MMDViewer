# CHANGELOG

## 0.5.0

このリリースでは、長期間放置されていたプロジェクトを、現在の Apple ツールチェーンで再びビルド、実行、保守できる状態へ大きく立て直しました。

目的:

- 現在の Xcode と iOS Simulator で、再びビルドと実行ができる状態へ戻す
- 数学処理や物理ブリッジの中核を `simd` 寄りに整理し、長期保守のリスクを下げる
- テスト、設計整理、ドキュメントを増やし、今後のリファクタリングを安全に進められる土台を作る

主な変更:

- 現在の Xcode 向けに project 設定、Metal 周辺、`UIScene` 対応を見直し、ビルドと simulator 起動を復旧した
- simulator 上で、モデル表示、VMD モーション再生、Play/Pause、カメラ操作、描画継続性を確認した
- 自前 `MetalView` の substrate を `MTKView` ベースへ移しつつ、既存の render loop 契約は維持した
- vendor している Bullet を 2.89 へ更新し、更新後も物理挙動が破綻していないことを確認した
- GLKit 依存の数学レイヤーを段階的に `simd` へ寄せ、ベクトル、クォータニオン、行列 bridge、物理境界の型変換を近代化した
- `DataReader`、PMX/VMD ロード、補間、行列互換、物理ブリッジ、updater、camera、ViewController の再生状態同期まで回帰テストを拡充した
- `MMDView`、`PMXObject`、renderer/pass 境界を中心に責務整理を進め、frame 準備、animation 更新、geometry 更新、GPU 転送、present の流れを追いやすくした
- ドキュメンテーションコメントと `ROADMAP.md` などの文書を整備し、将来の変更判断をコードと文書の両方から追えるようにした
- `melt` 描画基盤を Xcode 上の論理 group だけでなく、実際の物理ディレクトリ構成として整理した

補足:

- formatter / linter の評価までは完了したが、差分を大きくしすぎないため実適用は意図的に保留している
- 今後の改善候補は `ROADMAP.md` に整理してあり、このリリースは大規模な復旧と近代化の第一段をまとめたものになっている

## 0.4.0.d

Fix errors on Xcode 10.2.1 .

## 0.4.0.c

Support camera control by double tap, pan, pinch and rotation.

## 0.4.0.b

Support stipple transparency.

## 0.4.0.a

Introduce Light Pre-Pass (in progress).

Rewrite in Swift3.

## 0.3.0

Improve performance.

## 0.2.0

Support physics.

## 0.1.0

First release.
