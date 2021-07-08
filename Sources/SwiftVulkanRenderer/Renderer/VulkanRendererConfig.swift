import Vulkan

public struct VulkanRendererConfig {
	public var physicalDevice: VkPhysicalDevice
	public var device: VkDevice
	public var queueFamilyIndex: UInt32
	public var queue: VkQueue

	public init(
		physicalDevice: VkPhysicalDevice,
		device: VkDevice,
		queueFamilyIndex: UInt32,
		queue: VkQueue
	) {
		self.physicalDevice = physicalDevice
		self.device = device
		self.queueFamilyIndex = queueFamilyIndex
		self.queue = queue
	}
}