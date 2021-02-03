# ReplayLatest

The ReplayLatest makes it simple for subscribers to share and receive the most recent values immediately upon subscription.

# Usage

Ensure to import ReplayLatest in each file you wish to have access to the utility.

The operators can then be used as part of your usual publisher chain declaration:

```swift
let subject = PassthroughSubject<Int, Never>()
let publisher = subject.replayLatest(capacity: 2)
```

# Installation

Swift Package Manager:

```swift
dependencies: [
	.package(url: "https://github.com/abdalaliii/ReplayLatest.git")
]
```

# Developer Notes

This whole project is a work in progress, a learning exercise and has been released "early" so that it can be built and collaborated on with valuable feedback.
