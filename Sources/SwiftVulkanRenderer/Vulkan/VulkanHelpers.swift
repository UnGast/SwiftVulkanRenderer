import Vulkan

public func makeApiVersion(variant: UInt32, major: UInt32, minor: UInt32, patch: UInt32) -> UInt32 {
	(variant << 29) | (major << 22) | (minor << 12) | (patch)
}

public func findMemoryType(physicalDevice: VkPhysicalDevice, typeFilter: UInt32, properties: VkMemoryPropertyFlagBits) throws -> UInt32 {
	var memoryProperties = VkPhysicalDeviceMemoryProperties()
	var memoryTypes = withUnsafePointer(to: &memoryProperties.memoryTypes) {
		$0.withMemoryRebound(to: VkMemoryType.self, capacity: 32) {
			UnsafeBufferPointer(start: $0, count: 32)
		}
	}

	vkGetPhysicalDeviceMemoryProperties(physicalDevice, &memoryProperties)

	for index in 0..<memoryProperties.memoryTypeCount {
		let checkType = memoryTypes[Int(index)]

		if typeFilter & (1 << index) != 0 && checkType.propertyFlags & properties.rawValue == properties.rawValue {
			return UInt32(index)
		}
	}

	fatalError("no suitable memory type found")
}