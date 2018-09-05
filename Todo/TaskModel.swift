import Foundation

import PrivacyKit
import Tafelsalz

protocol TaskModelObserver {
	func startedLoading()
	func progress(percentage: Float)
	func errorOccurred(error: Error)
	func finishedLoading()
	func added(task: Task, withId: TaskModel.TaskId)
	func edited(task: Task, withId: TaskModel.TaskId)
	func removed(taskWithId: TaskModel.TaskId)
}

class TaskModel {

	enum Error: Swift.Error {
		case invalidMaximumTaskId
	}

	struct TaskId {
		let value: UInt16

		init(_ value: UInt16) {
			self.value = value
		}

		init(_ value: Int) {
			self.init(UInt16(value))
		}

		init?(bytes: Bytes) {
			guard bytes.count == MemoryLayout<UInt16>.size else {
				return nil
			}

			self.init((UInt16(bytes[0]) << 8) + UInt16(bytes[1]))
		}

		var key: KeyValueStorage.Key {
			return "task_\(value)"
		}

		var bytes: Bytes {
			return [UInt8(value >> 8), UInt8(value & 0xFF)]
		}

		func next() -> TaskId {
			return TaskId(value + 1)
		}
	}

	static let MaximimumIdKey = "task_max"

	private var observers: [TaskModelObserver] = []

	private var pending: Set<KeyValueStorage.Key> = [] {
		didSet {
			observers.forEach { $0.progress(percentage: currentProgress) }
			if pending.isEmpty {
				observers.forEach { $0.finishedLoading() }
			}
		}
	}

	let persona = Persona(uniqueName: "primaryUser")

	private let context = SecureKeyValueStorage.Context("TODOLIST")!
	private let privacyService = PrivacyService(baseUrl: URL(string: "httpss://shalon1.jondonym.net:443/services.app-pets.org")!)
	private let storage: SecureKeyValueStorage
	private var taskIds: Set<TaskId> = []

	init?() {
		guard let storage = SecureKeyValueStorage(with: privacyService, for: persona, context: context) else {
			return nil
		}

		self.storage = storage
	}

	func addObserver(_ observer: TaskModelObserver) {
		precondition(pending.isEmpty)

		observers.append(observer)
	}

	var cachedMaximumTaskId: TaskId = TaskId(0)

	var nextFreeTaskId: TaskId {
		let taskIds = self.taskIds.sorted()
		for current in 0..<taskIds.count {
			let taskId = TaskId(current)
			if taskId < taskIds[current] {
				return taskId
			}
		}
		return TaskId(taskIds.count)
	}

	var currentProgress: Float {
		let overall = Int(cachedMaximumTaskId.value)
		guard overall != 0 else { return 0 }
		return Float(overall - pending.count) / Float(overall)
	}

	func load() {
		precondition(pending.isEmpty)

		observers.forEach { $0.startedLoading() }
		pending.insert(TaskModel.MaximimumIdKey)

		storage.retrieve(for: TaskModel.MaximimumIdKey) {
			optionalValue, optionalError in

			assert((optionalValue == nil) != (optionalError == nil))

			guard let value = optionalValue else {
				if let error = optionalError as? SecureKeyValueStorage.Error, error == .valueDoesNotExist {
					// Ignore
				} else {
					self.observers.forEach { $0.errorOccurred(error: optionalError!) }
				}
				self.pending.remove(TaskModel.MaximimumIdKey)
				return
			}

			guard let maximiumTaskId = TaskId(bytes: value) else {
				self.observers.forEach { $0.errorOccurred(error: Error.invalidMaximumTaskId) }
				self.pending.remove(TaskModel.MaximimumIdKey)
				return
			}

			self.cachedMaximumTaskId = maximiumTaskId

			for current in 0..<maximiumTaskId.value {
				let taskId = TaskId(current)
				self.pending.insert(taskId.key)
				let semaphore = DispatchSemaphore(value: 0)

				self.storage.retrieve(for: taskId.key) {
					optionalValue, optionalError in

					assert((optionalValue == nil) != (optionalError == nil))

					guard let json = optionalValue else {
						if let error = optionalError as? SecureKeyValueStorage.Error, error == .valueDoesNotExist {
							// Ignore
						} else {
							self.observers.forEach { $0.errorOccurred(error: optionalError!) }
						}
						self.pending.remove(taskId.key)
						semaphore.signal()
						return
					}

					do {
						let task = try JSONDecoder().decode(Task.self, from: Data(json))
						self.taskIds.insert(taskId)
						self.observers.forEach { $0.added(task: task, withId: taskId) }
					} catch {
						self.observers.forEach { $0.errorOccurred(error: error) }
					}
					self.pending.remove(taskId.key)
					semaphore.signal()
				}

				semaphore.wait()
			}

			self.pending.remove(TaskModel.MaximimumIdKey)
		}
	}

	private func onlyStoreSingle(task: Task, withId taskId: TaskId) {
		let json = try! JSONEncoder().encode(task)

		let isEdit = taskIds.contains(taskId)

		storage.store(value: Bytes(json), for: taskId.key) {
			optionalError in

			if let error = optionalError {
				self.observers.forEach { $0.errorOccurred(error: error) }
			}

			self.taskIds.insert(taskId)
			if isEdit {
				self.observers.forEach { $0.edited(task: task, withId: taskId) }
			} else {
				self.observers.forEach { $0.added(task: task, withId: taskId) }
			}
			self.pending.remove(taskId.key)
		}
	}

	func store(task: Task, with taskId: TaskId) {
		precondition(pending.isEmpty)

		observers.forEach { $0.startedLoading() }
		pending.insert(taskId.key)

		do {
			let _ = try JSONEncoder().encode(task)

			let nextId = taskId.next()
			if cachedMaximumTaskId < nextId {
				pending.insert(TaskModel.MaximimumIdKey)
				storage.store(value: nextId.bytes, for: TaskModel.MaximimumIdKey) {
					optionalError in

					guard optionalError == nil else {
						self.observers.forEach { $0.errorOccurred(error: optionalError!) }
						self.pending.remove(TaskModel.MaximimumIdKey)
						return
					}

					self.cachedMaximumTaskId = nextId
					self.pending.remove(TaskModel.MaximimumIdKey)

					self.onlyStoreSingle(task: task, withId: taskId)
				}
			} else {
				onlyStoreSingle(task: task, withId: taskId)
			}
		} catch {
			observers.forEach { $0.errorOccurred(error: error) }
			pending.remove(taskId.key)
		}
	}

	private func onlyRemoveSingleTask(withId taskId: TaskId) {
		self.storage.remove(for: taskId.key) {
			optionalError in

			if let error = optionalError {
				self.observers.forEach { $0.errorOccurred(error: error) }
			} else {
				self.taskIds.remove(taskId)
				self.observers.forEach { $0.removed(taskWithId: taskId) }
			}

			self.pending.remove(taskId.key)
		}
	}

	func removeTask(withId taskId: TaskId) {
		precondition(pending.isEmpty)

		observers.forEach { $0.startedLoading() }
		pending.insert(taskId.key)

		onlyRemoveSingleTask(withId: taskId)
		
		// Maximum ID in use after removing this task
		let maxNext = taskIds.filter({ $0 != taskId }).max()?.next() ?? TaskId(0)
		
		// Can we reduce the maximum task id? If so,
		// this results in fewer network calls on startup.
		if cachedMaximumTaskId > maxNext {
			pending.insert(TaskModel.MaximimumIdKey)
			storage.store(value: maxNext.bytes, for: TaskModel.MaximimumIdKey) {
				error in

				guard error == nil else {
					self.observers.forEach { $0.errorOccurred(error: error!) }
					self.pending.remove(TaskModel.MaximimumIdKey)
					return
				}

				self.cachedMaximumTaskId = maxNext
				print("New max key: \(self.cachedMaximumTaskId)")
				self.pending.remove(TaskModel.MaximimumIdKey)
			}
		}
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
