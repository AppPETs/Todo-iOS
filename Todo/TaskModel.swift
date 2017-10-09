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

		init?(bytes: Data) {
			guard bytes.count == MemoryLayout<UInt16>.size else {
				return nil
			}

			self.init((UInt16(bytes[0]) << 8) + UInt16(bytes[1]))
		}

		var key: KeyValueStorage.Key {
			get {
				return "task_\(value)"
			}
		}

		var bytes: Data {
			get {
				var bytes = Data()
				bytes.append(UInt8(value >> 8))
				bytes.append(UInt8(value & 0xFF))
				return bytes
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

	static let MaximimumIdKey = "task_max"

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

	var cachedMaximumTaskId: TaskId = TaskId(0)

	var maximumTaskId: TaskId {
		get {
			return tasks.keys.max() ?? TaskId(0)
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
			tasks[id] = task

			if cachedMaximumTaskId < maximumTaskId {
				storage.store(value: maximumTaskId.bytes, for: TaskModel.MaximimumIdKey) {
					error in

					guard error == nil else {
						completion(error)
						return
					}

					self.cachedMaximumTaskId = self.maximumTaskId
					self.storage.store(value: json, for: id.key, finished: completion)
				}
			} else {
				storage.store(value: json, for: id.key, finished: completion)
			}
		} catch {
			completion(error)
		}
	}

	func removeTask(at indexPath: IndexPath, completion: @escaping (Swift.Error?) -> Void) {
		let remoteTask = self.remoteTask(for: indexPath)
		tasks.removeValue(forKey: remoteTask.id)

		if maximumTaskId < cachedMaximumTaskId {
			storage.store(value: maximumTaskId.bytes, for: TaskModel.MaximimumIdKey) {
				error in

				guard error == nil else {
					completion(error)
					return
				}

				self.cachedMaximumTaskId = self.maximumTaskId
				self.storage.removeValue(forKey: remoteTask.key, finished: completion)
			}
		} else {
			storage.removeValue(forKey: remoteTask.key, finished: completion)
		}
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
