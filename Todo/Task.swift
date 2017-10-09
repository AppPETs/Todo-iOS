import Foundation

struct Task: Codable {
	let description: String
	let isCompleted: Bool

	init?(description: String, isCompleted: Bool = false) {
		guard !description.isEmpty else {
			return nil
		}

		self.description = description
		self.isCompleted = isCompleted
	}

	func togglingCompletion() -> Task {
		return Task(description: description, isCompleted: !isCompleted)!
	}
}
