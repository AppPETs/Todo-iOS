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

struct TaskIdPair {
	let id: UInt16
	let task: Task?

	var key: KeyValueStorage.Key {
		get {
			return "task_\(id)"
		}
	}

	func replacing(task: Task?) -> TaskIdPair {
		return TaskIdPair(id: id, task: task)
	}
}
