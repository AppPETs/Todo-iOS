import UIKit

class TaskViewController: UIViewController, UITextFieldDelegate {

	enum Mode: String {
		case add = "AddTask"
		case edit = "EditTask"
	}

	@IBOutlet weak var descriptionEdit: UITextField!
	@IBOutlet weak var saveButton: UIBarButtonItem!

	var taskId: TaskModel.TaskId!
	var task: Task?

	var mode: Mode {
		get {
			if presentingViewController is UINavigationController {
				return .add
			}
			return .edit
		}
	}

	private func taskFromUi() -> Task? {
		return Task(description: descriptionEdit.text ?? "")
	}

	private func updateState() {
		saveButton.isEnabled = taskFromUi() != nil
	}

	// MARK: UIViewController

	override func viewDidLoad() {
		super.viewDidLoad()

		descriptionEdit.delegate = self

		if let task = task {
			descriptionEdit.text = task.description
			navigationItem.title = "Edit Task"
		}

		updateState()
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	// MARK: UITextFieldDelegate

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder() // Hide the keyboard
		return true
	}

	func textFieldDidBeginEditing(_ textField: UITextField) {
		saveButton.isEnabled = false
	}

	func textFieldDidEndEditing(_ textField: UITextField) {
		updateState()
	}

	// MARK: Navigation

	@IBAction func cancel(_ sender: UIBarButtonItem) {
		switch mode {
			case .add:
				dismiss(animated: true)
			case .edit:
				navigationController!.popViewController(animated: true)
		}
	}

	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		super.prepare(for: segue, sender: sender)

		guard let button = sender as? UIBarButtonItem, button === saveButton else {
			return
		}

		task = taskFromUi()
	}
}
