import Foundation

class TaskModel {

	enum Section: Int {
		case open = 0
		case completed
		case count
	}

	struct TaskId {
		let value: UInt16

		init(_ value: UInt16) {
			self.value = value
		}

		init(_ value: Int) {
			self.init(UInt16(value))
		}

		var key: KeyValueStorage.Key {
			get {
				return "task_\(value)"
			}
		}
	}

	struct RemoteTask {
		let id: TaskId
		let task: Task?

		var key: KeyValueStorage.Key {
			get {
				return id.key
			}
		}
	}

	private var storage = FakeKeyValueStore()
	private var tasks: [TaskId: Task] = [:]

	private var sortedTaskIdPairs: [RemoteTask] {
		get {
			var result: [RemoteTask] = []
			for id in tasks.keys.sorted() {
				guard let task = tasks[id] else { continue }
				result.append(RemoteTask(id: id, task: task))
			}
			return result
		}
	}

	private var openTaskIdPairs: [RemoteTask] {
		get {
			return sortedTaskIdPairs.filter({ !$0.task!.isCompleted })
		}
	}

	private var completedTaskIdPairs: [RemoteTask] {
		get {
			return sortedTaskIdPairs.filter({ $0.task!.isCompleted })
		}
	}

	var nextFreeTaskId: TaskId {
		get {
			let taskIds = tasks.keys.sorted()
			for current in 0..<taskIds.count {
				let taskId = TaskId(current)
				if taskId < taskIds[current] {
					return taskId
				}
			}
			return TaskId(taskIds.count)
		}
	}

	func numberOfRows(in section: Section) -> Int {
		precondition(section != .count)

		return remoteTasks(for: section).count
	}

	func task(for indexPath: IndexPath) -> Task {
		return remoteTask(for: indexPath).task!
	}

	func taskId(for indexPath: IndexPath) -> TaskId {
		return remoteTask(for: indexPath).id
	}

	func section(for taskId: TaskId) -> Section {
		return tasks[taskId]!.isCompleted ? .completed : .open
	}

	func indexPath(for taskId: TaskId) -> IndexPath {
		let section = self.section(for: taskId)
		let tasks = remoteTasks(for: section)

		guard let idx = tasks.index(where: { $0.id == taskId }) else {
			return IndexPath(row: tasks.count - 1, section: section.rawValue)
		}

		return IndexPath(row: idx, section: section.rawValue)
	}

	func store(task: Task, with id: TaskId, completion: @escaping (Error?) -> Void) {
		do {
			let json = try JSONEncoder().encode(task)
			storage.store(value: json, for: id.key, finished: completion)
		} catch {
			completion(error)
		}
	}

	func removeTask(at indexPath: IndexPath, completion: @escaping (Swift.Error?) -> Void) {
		let remoteTask = self.remoteTask(for: indexPath)
		storage.removeValue(forKey: remoteTask.key, finished: completion)
	}

	private func section(for indexPath: IndexPath) -> Section {
		assert(0 <= indexPath.section)
		assert(indexPath.section < Section.count.rawValue)

		return Section(rawValue: indexPath.section)!
	}

	private func remoteTasks(for section: Section) -> [RemoteTask] {
		switch section {
		case .open:
			return openTaskIdPairs
		case .completed:
			return completedTaskIdPairs
		case .count:
			fatalError("This should not be reachable!")
		}
	}

	private func remoteTask(for indexPath: IndexPath) -> RemoteTask {
		return remoteTasks(for: section(for: indexPath))[indexPath.row]
	}

}

extension TaskModel.TaskId: Equatable {
	static func ==(lhs: TaskModel.TaskId, rhs: TaskModel.TaskId) -> Bool {
		return lhs.value == rhs.value
	}
}

extension TaskModel.TaskId: Comparable {
	static func <(lhs: TaskModel.TaskId, rhs: TaskModel.TaskId) -> Bool {
		return lhs.value < rhs.value
	}
}

extension TaskModel.TaskId: Hashable {
	var hashValue: Int {
		return value.hashValue
	}
}
