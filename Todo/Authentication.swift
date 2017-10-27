import LocalAuthentication

public typealias AuthenticationContext = LAContext

public enum AuthenticationError: Error {
	case authenticationFailed
	case invalidContext
	case passcodeNotSet
	case systemCancel
	case userCancel
	case tooManyFailedAttempts
}

public func authenticateDeviceOwner(reason: String, completion: @escaping (_ error: AuthenticationError?) -> Void) -> AuthenticationContext {
	let context = AuthenticationContext()

	context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) {
		success, error in

		guard success else {
			switch error! {
				case LAError.authenticationFailed: completion(.authenticationFailed)
				case LAError.appCancel:            fatalError() // When does this happen?
				case LAError.invalidContext:       completion(.invalidContext)
				case LAError.notInteractive:       fatalError() // When does this happen?
				case LAError.passcodeNotSet:       completion(.passcodeNotSet)
				case LAError.systemCancel:         completion(.systemCancel)
				case LAError.userCancel:           completion(.userCancel)
				case LAError.biometryLockout:      completion(.tooManyFailedAttempts)
				case LAError.userFallback:         fatalError() // No fallback, policy falls back automatically
				case LAError.biometryNotEnrolled:  fatalError() // Policy falls back automatically
				case LAError.biometryNotAvailable: fatalError() // Policy falls back automatically
				default:                           fatalError("UNREACHABLE")
			}
			return
		}

		completion(nil)
	}

	return context
}
