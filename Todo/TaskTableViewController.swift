import UIKit

class TaskTableViewController: UITableViewController {

	private enum Section: Int {
		case open = 0
		case completed
		case count
	}

	private var storage = FakeKeyValueStore()
	private var tasks: [UInt16: Task] = [:]

	private var nextFreeTaskId: UInt16 {
		get {
			let taskIds = tasks.keys.sorted()
			for newId in 0..<taskIds.count {
				if UInt16(newId) < taskIds[newId] {
					return UInt16(newId)
				}
			}
			return UInt16(taskIds.count)
		}
	}

	private var sortedTaskIdPairs: [TaskIdPair] {
		get {
			var result: [TaskIdPair] = []
			for id in tasks.keys.sorted() {
				guard let task = tasks[id] else { continue }
				result.append(TaskIdPair(id: id, task: task))
			}
			return result
		}
	}

	private var openTaskIdPairs: [TaskIdPair] {
		get {
			return sortedTaskIdPairs.filter({ !$0.task!.isCompleted })
		}
	}

	private var completedTaskIdPairs: [TaskIdPair] {
		get {
			return sortedTaskIdPairs.filter({ $0.task!.isCompleted })
		}
	}

	private func section(for indexPath: IndexPath) -> Section {
		assert(0 <= indexPath.section)
		assert(indexPath.section < Section.count.rawValue)

		return Section(rawValue: indexPath.section)!
	}

	private func taskIdPairs(for section: Section) -> [TaskIdPair] {
		switch section {
			case .open:
				return openTaskIdPairs
			case .completed:
				return completedTaskIdPairs
			case .count:
				fatalError("This should not be reachable!")
		}
	}

	private func taskIdPair(for indexPath: IndexPath) -> TaskIdPair {
		return taskIdPairs(for: section(for: indexPath))[indexPath.row]
	}

	private func indexPath(for remoteTask: TaskIdPair) -> IndexPath {
		precondition(remoteTask.task != nil)

		let section: Section = remoteTask.task!.isCompleted ? .completed : .open
		let tasks = taskIdPairs(for: section)

		guard let idx = tasks.index(where: { $0.id == remoteTask.id }) else {
			return IndexPath(row: tasks.count - 1, section: section.rawValue)
		}

		return IndexPath(row: idx, section: section.rawValue)
	}

	private func showError(_ message: String, title: String = "Error") {
		let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "Ok", style: .default))
		self.present(alert, animated: true)
	}

	// MARK: UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        self.navigationItem.leftBarButtonItem = self.editButtonItem
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: UITableViewController

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.count.rawValue
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return taskIdPairs(for: Section(rawValue: section)!).count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TaskTableViewCell", for: indexPath) as! TaskTableViewCell

		let task = taskIdPair(for: indexPath).task!

		cell.descriptionLabel.text = task.description
		cell.isCompletedSwitch.isOn = task.isCompleted

        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
		precondition(editingStyle == .delete)

		let remoteTask = self.taskIdPair(for: indexPath)

		storage.removeValue(forKey: remoteTask.key) {
			error in

			guard error == nil else {
				self.showError("Failed to remove value for '\(remoteTask.key)': \(error!.localizedDescription)")
				return
			}

			DispatchQueue.main.async {
				assert(indexPath == self.indexPath(for: remoteTask))

				self.tasks.removeValue(forKey: remoteTask.id)
				tableView.deleteRows(at: [indexPath], with: .fade)
			}
		}

    }

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		assert(0 <= section)
		assert(section < Section.count.rawValue)

		switch Section(rawValue: section)! {
			case .open:
				return "Open Tasks"
			case .completed:
				return "Completed Tasks"
			case .count:
				fatalError("This should not be reachable!")
		}
	}

    // MARK: Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

		let mode = TaskViewController.Mode(rawValue: segue.identifier!)!

		switch mode {
			case .add:
				let navigationController = segue.destination as! UINavigationController
				let viewController = navigationController.topViewController!
				let destination = viewController as! TaskViewController
				destination.remoteTask = TaskIdPair(id: nextFreeTaskId, task: nil)
			case .edit:
				let destination = segue.destination as! TaskViewController
				let selectedTaskCell = sender as! TaskTableViewCell
				let indexPath = tableView.indexPath(for: selectedTaskCell)!
				destination.remoteTask = taskIdPair(for: indexPath)
		}
	}

	// MARK: Actions

	@IBAction func unwindToTasks(sender: UIStoryboardSegue) {
		if let source = sender.source as? TaskViewController, let remoteTask = source.remoteTask {

			guard remoteTask.task != nil else {
				showError("Empty task")
				return
			}

			let selectedIndexPath = tableView.indexPathForSelectedRow

			do {
				let json = try JSONEncoder().encode(remoteTask.task!)
				storage.store(value: json, for: remoteTask.key) {
					error in

					guard error == nil else {
						self.showError("Failed to store task \(remoteTask.key): \(error!.localizedDescription)")
						return
					}

					DispatchQueue.main.async {
						self.tasks[remoteTask.id] = remoteTask.task

						if let selectedIndexPath = selectedIndexPath {
							// Update task
							assert(self.indexPath(for: remoteTask) == selectedIndexPath)

							self.tableView.reloadRows(at: [selectedIndexPath], with: .automatic)
						} else {
							// Add task
							let indexPath = self.indexPath(for: remoteTask)
							self.tableView.insertRows(at: [indexPath], with: .automatic)
						}
					}
				}
			} catch {
				showError("Failed to encode task \(remoteTask.key): \(error.localizedDescription)")
			}
		}
	}

	@IBAction func toggleTaskCompleted(_ sender: UISwitch) {
		for indexPath in tableView.indexPathsForVisibleRows! {
			let cell = tableView.cellForRow(at: indexPath) as! TaskTableViewCell
			if cell.isCompletedSwitch === sender {

				let remoteTask = taskIdPair(for: indexPath)
				let newTask = remoteTask.task!.togglingCompletion()

				assert(newTask.isCompleted == sender.isOn)

				do {
					let json = try JSONEncoder().encode(newTask)
					storage.store(value: json, for: remoteTask.key) {
						error in

						guard error == nil else {
							self.showError("Failed to store task \(remoteTask.key): \(error!.localizedDescription)")
							return
						}

						DispatchQueue.main.async {
							self.tasks[remoteTask.id] = newTask

							let newIndexPath = self.indexPath(for: remoteTask.replacing(task: newTask))

							self.tableView.moveRow(at: indexPath, to: newIndexPath)
						}
					}
				} catch {
					showError("Failed to encode task \(remoteTask.key): \(error.localizedDescription)")
				}

				return
			}
		}
	}
}
