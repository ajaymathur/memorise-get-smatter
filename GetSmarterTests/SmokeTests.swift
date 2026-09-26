import Foundation
import Testing

@testable import GetSmarter

struct SmokeTests {
    @Test func bundleHasPrivacyManifest() {
        #expect(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy") != nil)
    }
}
