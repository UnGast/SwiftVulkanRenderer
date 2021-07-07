import Vulkan

public struct VulkanRendererConfig {
	var physicalDevice: VkPhysicalDevice
	var device: VkDevice
	var queueFamilyIndex: UInt32
	var queue: VkQueue
	var drawTargetExtent: VkExtent2D
	var drawTargetImages: [VkImage]
	var drawTargetImageViews: [VkImageView]
}