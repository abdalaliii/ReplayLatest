import XCTest
import Combine
@testable import ReplayLatest

final class ReplayLatestTests: XCTestCase {

	var subscriptions = Set<AnyCancellable>()

	func test_ReplayLatests() {
		let subject = PassthroughSubject<Int, Never>()
		let publisher = subject.replayLatest(capacity: 2)
		let expectedResult = [0, 1, 2, 1, 2, 3, 3]
		var results = [Int]()

		publisher
		  .sink(receiveValue: { results.append($0) })
		  .store(in: &subscriptions)

		subject.send(0)
		subject.send(1)
		subject.send(2)

		publisher
		  .sink(receiveValue: { results.append($0) })
		  .store(in: &subscriptions)

		subject.send(3)

		XCTAssert(
		  results == expectedResult,
		  "Results expected to be \(expectedResult) but were \(results)"
		)
	}

	static var allTests = [
		("testReplayLatestOperator", test_ReplayLatests),
	]
}
