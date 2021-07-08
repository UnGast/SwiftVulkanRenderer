import Vulkan

public struct VulkanRendererConfig {
	public var physicalDevice: VkPhysicalDevice
	public var device: VkDevice
	public var queueFamilyIndex: UInt32
	public var queue: VkQueue
	public var drawTargetExtent: VkExtent2D
	public var drawTargetImages: [VkImage]
	public var drawTargetImageViews: [VkImageView]

	public init(
		physicalDevice: VkPhysicalDevice,
		device: VkDevice,
		queueFamilyIndex: UInt32,
		queue: VkQueue,
		drawTargetExtent: VkExtent2D,
		drawTargetImages: [VkImage],
		drawTargetImageViews: [VkImageView]
	) {
		self.physicalDevice = physicalDevice
		self.device = device
		self.queueFamilyIndex = queueFamilyIndex
		self.queue = queue
		self.drawTargetExtent = drawTargetExtent
		self.drawTargetImages = drawTargetImages
		self.drawTargetImageViews = drawTargetImageViews
	}
}