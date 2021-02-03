import Combine
import Foundation

fileprivate final class ReplayLatestSubscription<Output, Failure: Error>: Subscription {

	var subscriber: AnySubscriber<Output,Failure>? = nil
	var demand: Subscribers.Demand = .none

	let maxCapacity: Int
	var buffer: [Output]
	var completion: Subscribers.Completion<Failure>? = nil

	init<S>(subscriber: S, buffer: [Output], capacity: Int, completion: Subscribers.Completion<Failure>?) where S: Subscriber, Failure == S.Failure, Output == S.Input {
		self.subscriber = AnySubscriber(subscriber)
		self.buffer = buffer
		self.maxCapacity = capacity
		self.completion = completion
	}

	func request(_ demand: Subscribers.Demand) {
		if demand != .none {
			self.demand += demand
		}
		emitIfDataIsAvailable()
	}

	func receive(input: Output) {
		guard subscriber != nil else { return }

		buffer.append(input)
		if buffer.count > maxCapacity {
			buffer.removeFirst()
		}

		emitIfDataIsAvailable()
	}

	func receive(completion: Subscribers.Completion<Failure>) {
		guard let subscriber = subscriber else { return }
		self.subscriber = nil
		self.buffer.removeAll()
		subscriber.receive(completion: completion)
	}

	func cancel() {
		complete(with: .finished)
	}


	private func complete(with completion: Subscribers.Completion<Failure>) {
		guard let subscriber = subscriber else { return }

		self.subscriber = nil
		self.completion = nil
		self.buffer.removeAll()

		subscriber.receive(completion: completion)
	}

	private func emitIfDataIsAvailable() {
		guard let subscriber = subscriber else { return }

		while self.demand > .none && !buffer.isEmpty {
			self.demand -= .max(1)
			let nextDemand = subscriber.receive(buffer.removeFirst())
			if nextDemand != .none {
				self.demand += nextDemand
			}
		}

		if let completion = completion {
			complete(with: completion)
		}
	}
}

public extension Publishers {
	final class ReplayLatest<Upstream: Publisher>: Publisher {

		public typealias Output = Upstream.Output
		public typealias Failure = Upstream.Failure

		private let lock = NSRecursiveLock()
		private let upstream: Upstream
		private let maxCapacity: Int
		private var buffer = [Output]()
		private var subscriptions = [ReplayLatestSubscription<Output, Failure>]()
		private var completion: Subscribers.Completion<Failure>? = nil

		init(upstream: Upstream, capacity: Int) {
			self.upstream = upstream
			self.maxCapacity = capacity
		}

		public func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
			lock.lock()
			defer { lock.unlock() }

			let subscription = ReplayLatestSubscription(subscriber: subscriber,
														 buffer: buffer,
														 capacity: maxCapacity,
														 completion: completion)

			subscriptions.append(subscription)
			subscriber.receive(subscription: subscription)

			guard subscriptions.count == 1
			else { return }

			let sink = AnySubscriber(
				receiveSubscription: { subscription in
					subscription.request(.unlimited)
				},
				receiveValue: { [weak self] (value: Output) -> Subscribers.Demand in
					self?.receive(value)
					return .none
				},
				receiveCompletion: { [weak self] in
					self?.complete($0)
				}
			)

			upstream.subscribe(sink)
		}

		private func receive(_ value: Output) {
			lock.lock()
			defer { lock.unlock() }

			guard completion == nil
			else { return }

			buffer.append(value)
			if buffer.count > maxCapacity {
				buffer.removeFirst()
			}
			subscriptions.forEach {
				$0.receive(input: value)
			}
		}

		private func complete(_ completion: Subscribers.Completion<Failure>) {
			lock.lock()
			defer { lock.unlock() }

			self.completion = completion
			subscriptions.forEach {
				$0.receive(completion: completion)
			}
		}
    }
}

public extension Publisher {
	func replayLatest(capacity: Int = .max) -> Publishers.ReplayLatest<Self> {
		return Publishers.ReplayLatest(upstream: self, capacity: capacity)
	}
}
