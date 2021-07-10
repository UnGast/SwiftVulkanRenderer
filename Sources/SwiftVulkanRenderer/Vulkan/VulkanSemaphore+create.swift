import Vulkan

public struct VulkanSemaphore {
  public static func create(device: VkDevice) -> VkSemaphore {
    var createInfo = VkSemaphoreCreateInfo(
      sType: VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
      pNext: nil,
      flags: 0
    )

    var semaphore: VkSemaphore? = nil
    vkCreateSemaphore(device, &createInfo, nil, &semaphore)

    return semaphore!
  }
}