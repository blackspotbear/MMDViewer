import XCTest
import UIKit
import Metal
@testable import MMDViewer

/// Storyboard 上の controller と lifecycle 通知の橋渡しを監視する。
/// ここが崩れると描画本体が無事でも再生/停止 UI だけ壊れるため、fixture つきで固定する。
final class ViewControllerTests: XCTestCase {

    func testLifecycleNotificationsSyncPlaybackStateAndButtonTitle() {
        let sut = makeStoryboardViewController()
        let updater = makeFixturePMXUpdater()
        sut.mmdView.pmxUpdater = updater

        sut.viewDidEnterBackground(nil)
        XCTAssertFalse(updater.playing)
        XCTAssertEqual(sut.playPauseButton.title, "Play")

        sut.viewWillEnterForeground(nil)
        XCTAssertTrue(updater.playing)
        XCTAssertEqual(sut.playPauseButton.title, "Pause")
    }

    func testPlayButtonTogglesFixtureUpdaterState() {
        let sut = makeStoryboardViewController()
        let updater = makeFixturePMXUpdater()
        sut.mmdView.pmxUpdater = updater

        sut.onPlayButtonPushed(self)
        XCTAssertFalse(updater.playing)
        XCTAssertEqual(sut.playPauseButton.title, "Play")

        sut.onPlayButtonPushed(self)
        XCTAssertTrue(updater.playing)
        XCTAssertEqual(sut.playPauseButton.title, "Pause")
    }

    private func makeStoryboardViewController(file: StaticString = #filePath, line: UInt = #line) -> ViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle(for: ViewController.self))
        guard let controller = storyboard.instantiateInitialViewController() as? ViewController else {
            XCTFail("Missing initial ViewController", file: file, line: line)
            fatalError("Missing initial ViewController")
        }
        controller.loadViewIfNeeded()
        return controller
    }

    private func makeFixturePMXUpdater(file: StaticString = #filePath, line: UInt = #line) -> PMXUpdater {
        guard let device = MTLCreateSystemDefaultDevice() else {
            XCTFail("Missing Metal device", file: file, line: line)
            fatalError("Missing Metal device")
        }
        guard let pmxData = fixtureData(at: "data/mmd/Alicia_solid.pmx") else {
            XCTFail("Missing PMX fixture", file: file, line: line)
            fatalError("Missing PMX fixture")
        }
        guard let vmdData = fixtureData(at: "data/vmd/2分ループステップ1.vmd") else {
            XCTFail("Missing VMD fixture", file: file, line: line)
            fatalError("Missing VMD fixture")
        }

        let pmx = PMX(data: pmxData)
        let vmd = VMD(data: vmdData)
        return PMXUpdater(pmxObj: PMXObject(device: device, pmx: pmx, vmd: vmd))
    }

    private func fixtureData(at relativePath: String) -> Data? {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = projectRoot.appendingPathComponent(relativePath)
        return try? Data(contentsOf: url)
    }
}
