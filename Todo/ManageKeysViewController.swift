import UIKit

import QRCodeReader
import Tafelsalz

class ManageKeysViewController: UIViewController, UITextFieldDelegate {

	var persona: Persona! = nil

	public var hasPersonaChanged = false

	var qrCodeReader: QRCodeReader? = nil

	@IBOutlet weak var exportMasterKeyView: ConfidentialQRCodeView!
	@IBOutlet weak var importTextField: UITextField!
	@IBOutlet weak var importButton: UIButton!

	func importMasterKey(_ masterKey: MasterKey) {
		let alert = UIAlertController(title: "Import key", message: "Importing a key will result in the deletion of all tasks currently displayed in the application. The tasks for the imported key will be loaded instead.", preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "Cancel", style: .default))
		alert.addAction(UIAlertAction(title: "Continue", style: .destructive, handler: {
			_ in

			DispatchQueue.main.async {
				do {
					try self.persona.setMasterKey(masterKey)
					self.hasPersonaChanged = true
					self.performSegue(withIdentifier: "unwindToTasks", sender: self)
				} catch {
					self.showError(title: "Cannot import key", message: error.localizedDescription)
				}
			}
		}))
		self.present(alert, animated: true)
	}

	func showError(title: String, message: String) {
		let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "Ok", style: .default))
		self.present(alert, animated: true)
	}

	private func masterKeyFromTextField() -> MasterKey? {
		guard let text = importTextField.text else {
			return nil
		}
		return MasterKey(base64Encoded: text)
	}

	// MARK: UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()

		importTextField.delegate = self

		navigationItem.title = "Manage Keys"

		let item = UIBarButtonItem(barButtonSystemItem: .camera, target: self, action: #selector(scanMasterKey))
		navigationItem.rightBarButtonItem = item

		exportMasterKeyView.qrCode = try! persona.masterKey().qrCode()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

	// MARK: Actions

	@objc
	func scanMasterKey() {
		qrCodeReader = QRCodeReader()
		do {
			try qrCodeReader!.startScanning() {
				decodedQrCode in

				guard let decodedQrCode = decodedQrCode else {
					return
				}

				guard let masterKey = MasterKey(base64Encoded: decodedQrCode) else {
					DispatchQueue.main.async {
						self.showError(title: "Cannot import key", message: "Invalid key")
					}
					return
				}

				DispatchQueue.main.async {
					self.importTextField.text = masterKey.base64EncodedString()
				}

				self.qrCodeReader = nil
			}
		} catch {
			qrCodeReader = nil
			showError(title: "Cannot import key", message: error.localizedDescription)
		}
	}

	@IBAction func importFromTextField() {
		guard let masterKey = masterKeyFromTextField() else {
			return
		}

		self.importMasterKey(masterKey)
	}

	// MARK: UITextFieldDelegate

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder() // Hide the keyboard
		return true
	}

	func textFieldDidEndEditing(_ textField: UITextField) {
		if textField === importTextField {
			importButton.isEnabled = masterKeyFromTextField() != nil
		}
	}

}
