import Foundation

extension Array {
	public func asUnsafeMutableBufferPointer() -> UnsafeMutableBufferPointer<Element> {
		let result = UnsafeMutableBufferPointer<Element>.allocate(capacity: count)
		result.initialize(from: self)
		return result
	}
}