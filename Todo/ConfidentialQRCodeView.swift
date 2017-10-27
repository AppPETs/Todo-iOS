import UIKit

import QRCode

class ConfidentialQRCodeView: UIImageView {

	var coverImage: UIImage? = nil

	var context: AuthenticationContext? = nil
	var isConfidentialValueDisplayed = false
	var qrCode: QRCode! = nil

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)

		coverImage = image

		setup()
	}

	private func setup() {
		isUserInteractionEnabled = true

		let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(toggleDisplayingConfidentialValue))
		tapGestureRecognizer.numberOfTapsRequired = 1
		tapGestureRecognizer.numberOfTouchesRequired = 1
		addGestureRecognizer(tapGestureRecognizer)
	}

	private func uncover() {
		DispatchQueue.main.async {
			self.image = self.qrCode.image
			self.isConfidentialValueDisplayed = true
		}
	}

	private func showError(message: String) {
		let alert = UIAlertController(title: "Authentication failed", message: message, preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "Ok", style: .default))
		UIApplication.shared.keyWindow!.rootViewController!.present(alert, animated: true)
	}

	@objc
	func toggleDisplayingConfidentialValue() {
		if isConfidentialValueDisplayed {
			// Show cover image
			context?.invalidate()
			image = coverImage
			isConfidentialValueDisplayed = false
		} else {
			// Authenticate the user with FaceID or TouchID, if these methods
			// are available
			let reason = "You need to authenticate, in order to show the secret key."
			context = authenticateDeviceOwner(reason: reason) {
				authenticationError in

				// <#FIXME#> Why does an .invalidContext error sometimes occur here?
				guard authenticationError == nil else {
					// Ignored errors do not uncover the QR code.
					let ignoredAuthenticationErrors: [AuthenticationError] = [.systemCancel, .userCancel]
					if !ignoredAuthenticationErrors.contains(authenticationError!) {
						self.showError(message: authenticationError!.localizedDescription)
					}

					return
				}

				self.uncover()
			}

		}

	}

}
