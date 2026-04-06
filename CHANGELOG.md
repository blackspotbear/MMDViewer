# CHANGELOG

## 0.5.0

This release is a large-scale modernization and recovery of the project so it can be built, tested, and maintained again on a current Apple toolchain.

Intent:

- Restore the app to a buildable and runnable state on current Xcode and iOS Simulator
- Reduce long-term maintenance risk by moving core math and bridge boundaries toward `simd`
- Improve confidence for future refactoring by adding tests, clarifying architecture, and documenting decisions

Highlights:

- Restored successful build and simulator launch on current Xcode, including fixes for modern Metal validation, `UIScene` adoption, and old project settings
- Verified model display, VMD motion playback, Play/Pause, camera gestures, and post-update rendering behavior on the simulator
- Replaced the old custom Metal view substrate with an `MTKView`-based implementation while preserving the existing render loop contract
- Updated the vendored Bullet integration to 2.89 and verified physics behavior remained usable after the upgrade
- Migrated major GLKit-dependent math layers toward `simd`, including vectors, quaternions, matrix bridging, and physics bridge boundary types
- Added regression coverage for `DataReader`, PMX/VMD loading, interpolation, matrix compatibility, physics bridge flow, updater behavior, camera math, and view controller playback synchronization
- Refactored `MMDView`, `PMXObject`, renderer/pass boundaries, and related helpers so frame preparation, animation update, geometry update, GPU transfer, and presentation steps are easier to follow
- Expanded documentation comments and project documentation so future work can continue from explicit architectural decisions instead of implicit behavior
- Reorganized the `melt` rendering foundation from an Xcode-only logical group into real directories that match the rendering-layer structure

Notes:

- Formatter and linter evaluation were completed, but broad formatting changes are intentionally deferred to avoid creating a large final diff
- Additional future work remains documented in `docs/`, but this release captures the major recovery and modernization pass

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
