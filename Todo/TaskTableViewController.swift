import UIKit

class TaskTableViewController: UITableViewController, TaskModelObserver {

	enum Section: Int {
		case open = 0
		case completed
		case count
	}

	var model = TaskModel()!
	var tasks: [TaskModel.TaskId: Task] = [:]
	var taskMap: [TaskModel.TaskId: IndexPath] = [:]
	var isRefreshing = false

	var indexPathMap: [IndexPath: TaskModel.TaskId] {
		get {
			return taskMap.reduce([IndexPath: TaskModel.TaskId]()) {
				(akku: [IndexPath: TaskModel.TaskId], current) -> [IndexPath: TaskModel.TaskId] in

				let (taskId, indexPath) = current

				var next = akku
				next[indexPath] = taskId
				return next
			}
		}
	}

	@IBOutlet weak var progressBar: UIProgressView!

	private func showError(_ message: String, title: String = "Error") {
		let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "Ok", style: .default))
		self.present(alert, animated: true)
	}

	@objc
	func refresh() {
		isRefreshing = true

		// Clear task list
		tasks = [:]
		taskMap = [:]
		tableView.reloadData()

		// Load tasks for the new persona
		model = TaskModel()!
		model.addObserver(self)
		model.load()
	}

	// MARK: UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

		refreshControl = UIRefreshControl()
		refreshControl!.addTarget(self, action: #selector(refresh), for: UIControlEvents.primaryActionTriggered)

		model.addObserver(self)
		model.load()
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
		return tasks.values.filter({ $0.isCompleted == (Section(rawValue: section)! == .completed) }).count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TaskTableViewCell", for: indexPath) as! TaskTableViewCell

		let taskId = indexPathMap[indexPath]!
		let task = tasks[taskId]!

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

		let taskId = indexPathMap[indexPath]!

		model.removeTask(withId: taskId)
    }

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

		guard segue.identifier != "ManageKeys" else {
			let manageKeysViewController = segue.destination as! ManageKeysViewController
			manageKeysViewController.persona = model.persona
			return
		}

		guard let mode = TaskViewController.Mode(rawValue: segue.identifier!) else {
			return
		}

		switch mode {
			case .add:
				let navigationController = segue.destination as! UINavigationController
				let viewController = navigationController.topViewController!
				let destination = viewController as! TaskViewController
				destination.taskId = model.nextFreeTaskId
			case .edit:
				let destination = segue.destination as! TaskViewController
				let selectedTaskCell = sender as! TaskTableViewCell
				let indexPath = tableView.indexPath(for: selectedTaskCell)!
				destination.taskId = indexPathMap[indexPath]!
				destination.task = tasks[destination.taskId]!
		}
	}

	// MARK: Actions

	@IBAction func unwindToTasks(sender: UIStoryboardSegue) {
		if let source = sender.source as? TaskViewController, let task = source.task {
			model.store(task: task, with: source.taskId)
		}

		if let source = sender.source as? ManageKeysViewController, source.hasPersonaChanged {
			// Clear task list
			tasks = [:]
			taskMap = [:]
			tableView.reloadData()

			// Load tasks for the new persona
			model = TaskModel()!
			model.addObserver(self)
			model.load()
		}
	}

	@IBAction func toggleTaskCompleted(_ sender: UISwitch) {
		for indexPath in tableView.indexPathsForVisibleRows! {
			let cell = tableView.cellForRow(at: indexPath) as! TaskTableViewCell
			if cell.isCompletedSwitch === sender {

				let taskId = indexPathMap[indexPath]!
				let task = tasks[taskId]!

				assert(task.togglingCompletion().isCompleted == sender.isOn)

				model.store(task: task.togglingCompletion(), with: taskId)

				return
			}
		}
	}

	// MARK: TaskModelObserver

	func startedLoading() {
		DispatchQueue.main.async {
			self.progressBar.isHidden = false
			self.navigationItem.leftBarButtonItem?.isEnabled = false
			self.navigationItem.rightBarButtonItem?.isEnabled = false
		}
	}

	func progress(percentage: Float) {
		DispatchQueue.main.async {
			self.progressBar.progress = percentage
		}
	}

	func errorOccurred(error: Error) {
		DispatchQueue.main.async {
			self.showError(error.localizedDescription)
		}
	}

	func finishedLoading() {
		DispatchQueue.main.async {
			if self.isRefreshing {
				self.refreshControl?.endRefreshing()
				self.isRefreshing = false
			}
			self.progressBar.isHidden = true
			self.navigationItem.leftBarButtonItem?.isEnabled = true
			self.navigationItem.rightBarButtonItem?.isEnabled = true
		}
	}

	func added(task: Task, withId taskId: TaskModel.TaskId) {
		DispatchQueue.main.async {
			assert(!self.taskMap.keys.contains(taskId))

			let section: Section = task.isCompleted ? .completed : .open
			let indexPath = IndexPath(row: self.tableView.numberOfRows(inSection: section.rawValue), section: section.rawValue)
			self.tasks[taskId] = task
			self.taskMap[taskId] = indexPath

			self.tableView.insertRows(at: [indexPath], with: .automatic)
		}
	}

	func edited(task: Task, withId taskId: TaskModel.TaskId) {
		DispatchQueue.main.async {
			assert(self.taskMap.keys.contains(taskId))

			let oldIndexPath = self.taskMap[taskId]!
			let section: Section = task.isCompleted ? .completed : .open
			let newIndexPath = IndexPath(row: self.tableView.numberOfRows(inSection: section.rawValue), section: section.rawValue)
			self.taskMap[taskId] = newIndexPath
			self.tasks[taskId] = task

			if oldIndexPath == newIndexPath {
				self.tableView.reloadRows(at: [newIndexPath], with: .automatic)
			} else {
				self.tableView.moveRow(at: oldIndexPath, to: newIndexPath)
			}
		}
	}

	func removed(taskWithId taskId: TaskModel.TaskId) {
		DispatchQueue.main.async {
			assert(!self.taskMap.keys.contains(taskId))

			let indexPath = self.taskMap[taskId]!
			self.taskMap.removeValue(forKey: taskId)
			self.tasks.removeValue(forKey: taskId)
			self.tableView.deleteRows(at: [indexPath], with: .fade)
		}
	}

}
