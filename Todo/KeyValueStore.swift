import Foundation

protocol KeyValueStorage {
	typealias Key = String
	typealias Value = Data

	func store(value: Value, for key: Key, finished: @escaping (Error?) -> Void)
	func retrieve(for key: Key, finished: @escaping (Value?, Error?) -> Void)
	func removeValue(forKey key: Key, finished: @escaping (Error?) -> Void)
}

class FakeKeyValueStore: KeyValueStorage {

	enum Error: Swift.Error {
		case valueDoesNotExist
	}

	var values: [KeyValueStorage.Key: KeyValueStorage.Value] = [:]

	// MARK: KeyValueStorage

	func store(value: KeyValueStorage.Value, for key: KeyValueStorage.Key, finished: @escaping (Swift.Error?) -> Void) {
		values[key] = value
		finished(nil)
	}

	func retrieve(for key: KeyValueStorage.Key, finished: @escaping (KeyValueStorage.Value?, Swift.Error?) -> Void) {
		finished(values[key], values.keys.contains(key) ? nil : Error.valueDoesNotExist)
	}

	func removeValue(forKey key: KeyValueStorage.Key, finished: @escaping (Swift.Error?) -> Void) {
		let value = values.removeValue(forKey: key)
		finished(value == nil ? Error.valueDoesNotExist : nil)
	}

}
