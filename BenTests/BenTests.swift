import Testing
@testable import Ben

struct BenTests {
    @Test func scaffoldSane() {
        #expect(BillStatus.upcoming.label == "Upcoming")
    }
}
