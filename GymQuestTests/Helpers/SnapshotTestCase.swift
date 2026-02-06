import XCTest
import SwiftUI
import SnapshotTesting
@testable import GymQuest

/// Base class for snapshot tests.
/// Wraps views in UIHostingController with the correct environment objects
/// and snapshots at standard device sizes.
class SnapshotTestCase: XCTestCase {

    /// Set to true in a test method or setUp to record new reference images.
    /// After recording, set back to false and re-run to verify.
    var record = false

    /// Snapshot a SwiftUI view at iPhone 15 and iPhone SE sizes
    func assertSnapshot<V: View>(
        of view: V,
        named name: String? = nil,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        let wrapped = view
            .environmentObject(FeatureFlags.shared)
            .preferredColorScheme(.dark)

        let vc = UIHostingController(rootView: wrapped)
        vc.view.frame = UIScreen.main.bounds

        // iPhone 15 (393x852)
        let iPhone15Config = ViewImageConfig(
            safeArea: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
            size: CGSize(width: 393, height: 852),
            traits: UITraitCollection(traitsFrom: [
                .init(userInterfaceStyle: .dark),
                .init(displayScale: 3)
            ])
        )

        // iPhone SE 3rd gen (375x667)
        let iPhoneSEConfig = ViewImageConfig(
            safeArea: UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0),
            size: CGSize(width: 375, height: 667),
            traits: UITraitCollection(traitsFrom: [
                .init(userInterfaceStyle: .dark),
                .init(displayScale: 2)
            ])
        )

        let snapshotName15 = [name, "iPhone15"].compactMap { $0 }.joined(separator: "-")
        let snapshotNameSE = [name, "iPhoneSE"].compactMap { $0 }.joined(separator: "-")

        SnapshotTesting.assertSnapshot(
            of: vc,
            as: .image(on: iPhone15Config),
            named: snapshotName15,
            record: record,
            file: file,
            testName: testName,
            line: line
        )

        SnapshotTesting.assertSnapshot(
            of: vc,
            as: .image(on: iPhoneSEConfig),
            named: snapshotNameSE,
            record: record,
            file: file,
            testName: testName,
            line: line
        )
    }
}
