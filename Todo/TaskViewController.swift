import UIKit

class TaskViewController: UIViewController, UITextFieldDelegate {

	enum Mode: String {
		case add = "AddTask"
		case edit = "EditTask"
	}

	@IBOutlet weak var descriptionEdit: UITextField!
	@IBOutlet weak var saveButton: UIBarButtonItem!

	var remoteTask: TaskIdPair?

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

		if let task = remoteTask?.task {
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
				if let owningNavigationController = navigationController {
					owningNavigationController.popViewController(animated: true)
				} else {
					fatalError("There should be a navigation controller!")
				}
		}
	}

	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		super.prepare(for: segue, sender: sender)

		guard let button = sender as? UIBarButtonItem, button === saveButton else {
			return
		}

		remoteTask = remoteTask!.replacing(task: taskFromUi())
	}
}
