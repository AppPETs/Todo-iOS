import UIKit

import QRCode

class ConfidentialQRCodeView: UIImageView {

	var coverImage: UIImage? = nil

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

	@objc
	func toggleDisplayingConfidentialValue() {
		if isConfidentialValueDisplayed {
			// Show cover image
			image = coverImage
		} else {
			// Show confidential image
			// <#TODO#> Authenticate with TouchID (if available) before unlocking
			image = qrCode.image
		}
		isConfidentialValueDisplayed = !isConfidentialValueDisplayed
	}

}
