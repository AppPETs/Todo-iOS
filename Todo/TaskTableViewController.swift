import UIKit

class TaskTableViewController: UITableViewController {

	typealias Section = TaskModel.Section

	let model = TaskModel()

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

		self.navigationItem.leftBarButtonItem?.isEnabled = false
		self.navigationItem.rightBarButtonItem?.isEnabled = false

		model.load {
			error in

			guard error == nil else {
				self.showError("Failed to load tasks: \(error!.localizedDescription)")
				return
			}

			DispatchQueue.main.async {
				self.navigationItem.leftBarButtonItem?.isEnabled = true
				self.navigationItem.rightBarButtonItem?.isEnabled = true
			}
		}
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
		return model.numberOfRows(in: Section(rawValue: section)!)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TaskTableViewCell", for: indexPath) as! TaskTableViewCell

		let task = model.task(for: indexPath)

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

		model.removeTask(at: indexPath) {
			error in

			guard error == nil else {
				self.showError("Failed to remove value: \(error!.localizedDescription)")
				return
			}

			DispatchQueue.main.async {
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
				destination.taskId = model.nextFreeTaskId
			case .edit:
				let destination = segue.destination as! TaskViewController
				let selectedTaskCell = sender as! TaskTableViewCell
				let indexPath = tableView.indexPath(for: selectedTaskCell)!
				destination.taskId = model.taskId(for: indexPath)
				destination.task = model.task(for: indexPath)
		}
	}

	// MARK: Actions

	@IBAction func unwindToTasks(sender: UIStoryboardSegue) {
		if let source = sender.source as? TaskViewController, let task = source.task {

			let taskId = source.taskId!
			let selectedIndexPath = tableView.indexPathForSelectedRow

			model.store(task: task, with: taskId) {
				error in

				guard error == nil else {
					self.showError("Failed to store task '\(taskId.key)': \(error!.localizedDescription)")
					return
				}

				DispatchQueue.main.async {
					if let selectedIndexPath = selectedIndexPath {
						// Update task
						self.tableView.reloadRows(at: [selectedIndexPath], with: .automatic)
					} else {
						// Add task
						let indexPath = self.model.indexPath(for: taskId)
						self.tableView.insertRows(at: [indexPath], with: .automatic)
					}
				}
			}
		}
	}

	@IBAction func toggleTaskCompleted(_ sender: UISwitch) {
		for indexPath in tableView.indexPathsForVisibleRows! {
			let cell = tableView.cellForRow(at: indexPath) as! TaskTableViewCell
			if cell.isCompletedSwitch === sender {

				let taskId = model.taskId(for: indexPath)
				let task = model.task(for: indexPath)

				assert(task.togglingCompletion().isCompleted == sender.isOn)

				model.store(task: task.togglingCompletion(), with: taskId) {
					error in

					guard error == nil else {
						self.showError("Failed to store task '\(taskId.key)': \(error!.localizedDescription)")
						return
					}

					DispatchQueue.main.async {
						let newIndexPath = self.model.indexPath(for: taskId)

						self.tableView.moveRow(at: indexPath, to: newIndexPath)
					}
				}

				return
			}
		}
	}
}
