import Vulkan

public struct VulkanFence {
	public static func create(device: VkDevice) -> VkFence {
		var fence: VkFence? = nil
		var createInfo = VkFenceCreateInfo(
			sType: VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
			pNext: nil,
			flags: 0
		)
		vkCreateFence(device, &createInfo, nil, &fence)
		return fence!
	}

	public static func waitFor(fence: VkFence, device: VkDevice, timeout: UInt64) {
		var fences = [Optional(fence)]
		vkWaitForFences(device, UInt32(fences.count), fences, 1, timeout)
	}
}