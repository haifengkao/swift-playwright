import Foundation

extension Array where Element: AnyObject {
	/// Removes the first element that is identity-equal (`===`) to the given object.
	mutating func removeByIdentity(_ element: Element) {
		if let index = firstIndex(where: { $0 === element }) {
			remove(at: index)
		}
	}
}
