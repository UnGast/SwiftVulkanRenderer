import Vulkan

public protocol VulkanRenderer {
  var physicalDevice: VkPhysicalDevice { get }
	var device: VkDevice { get }
	var swapchainExtent: VkExtent2D { get }
  var queue: VkQueue { get }
  var commandPool: VkCommandPool { get }

	func updateSceneContent() throws
	func updateSceneObjectMeta() throws
	func updateSceneCameraUniforms() throws

	func findMemoryType(typeFilter: UInt32, properties: VkMemoryPropertyFlagBits) throws -> UInt32

	func beginSingleTimeCommands() throws -> VkCommandBuffer

	func endSingleTimeCommands(commandBuffer: VkCommandBuffer, waitSemaphores: [VkSemaphore], signalSemaphores: [VkSemaphore]) throws

	func draw() throws
}

extension VulkanRenderer {
  public func findMemoryType(typeFilter: UInt32, properties: VkMemoryPropertyFlagBits) throws -> UInt32 {
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

  func createImage(width: UInt32, height: UInt32, format: VkFormat, tiling: VkImageTiling, usage: VkImageUsageFlagBits, properties: VkMemoryPropertyFlagBits) throws -> (VkImage, VkDeviceMemory) {
    var imageInfo = VkImageCreateInfo(
      sType: VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
      pNext: nil,
      flags: 0,
      imageType: VK_IMAGE_TYPE_2D,
      format: format,
      extent: VkExtent3D(width: width, height: height, depth: 1),
      mipLevels: 1,
      arrayLayers: 1,
      samples: VK_SAMPLE_COUNT_1_BIT,
      tiling: tiling,
      usage: usage.rawValue,
      sharingMode: VK_SHARING_MODE_EXCLUSIVE,
      queueFamilyIndexCount: 0,
      pQueueFamilyIndices: nil,
      initialLayout: VK_IMAGE_LAYOUT_UNDEFINED
    )
    var image: VkImage? = nil
    vkCreateImage(device, &imageInfo, nil, &image)

    var memoryRequirements = VkMemoryRequirements()
    vkGetImageMemoryRequirements(device, image, &memoryRequirements)

    var imageMemory: VkDeviceMemory? = nil
    var imageMemoryAllocateInfo = VkMemoryAllocateInfo(
      sType: VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
      pNext: nil,
      allocationSize: memoryRequirements.size,
      memoryTypeIndex: try findMemoryType(typeFilter: memoryRequirements.memoryTypeBits, properties: VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)
    )
    vkAllocateMemory(device, &imageMemoryAllocateInfo, nil, &imageMemory)

    vkBindImageMemory(device, image, imageMemory, 0)

    return (image!, imageMemory!)
  }

 func createImageView(image: VkImage, format: VkFormat, aspectFlags: VkImageAspectFlagBits) throws -> VkImageView {
    var createInfo = VkImageViewCreateInfo(
      sType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
      pNext: nil,
      flags: 0,
      image: image,
      viewType: VK_IMAGE_VIEW_TYPE_2D,
      format: format,
      components: VkComponentMapping(
        r: VK_COMPONENT_SWIZZLE_IDENTITY,
        g: VK_COMPONENT_SWIZZLE_IDENTITY,
        b: VK_COMPONENT_SWIZZLE_IDENTITY,
        a: VK_COMPONENT_SWIZZLE_IDENTITY
      ),
      subresourceRange: VkImageSubresourceRange(
        aspectMask: aspectFlags.rawValue,
        baseMipLevel: 0,
        levelCount: 1,
        baseArrayLayer: 0,
        layerCount: 1
      )
    )

    var imageView: VkImageView? = nil
    vkCreateImageView(device, &createInfo, nil, &imageView)

    return imageView!
  }

  public func beginSingleTimeCommands() throws -> VkCommandBuffer {
    var allocateInfo = VkCommandBufferAllocateInfo(
      sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
      pNext: nil,
      commandPool: commandPool,
      level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
      commandBufferCount: 1
    )
    var commandBuffer: VkCommandBuffer? = nil
    vkAllocateCommandBuffers(device, &allocateInfo, &commandBuffer)

    var beginInfo = VkCommandBufferBeginInfo(
      sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
      pNext: nil,
      flags: VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT.rawValue,
      pInheritanceInfo: nil
    )
    vkBeginCommandBuffer(commandBuffer, &beginInfo)

    return commandBuffer!
  }

  /// ends command buffer and submits it
  public func endSingleTimeCommands(commandBuffer: VkCommandBuffer, waitSemaphores: [VkSemaphore] = [], signalSemaphores: [VkSemaphore] = []) throws {
    var waitSemaphores = waitSemaphores as! [VkSemaphore?]
    var signalSemaphores = signalSemaphores as! [VkSemaphore?]
    var submitDstStageMasks = waitSemaphores.map { _ in VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT.rawValue }
    vkEndCommandBuffer(commandBuffer)

    var commandBuffers = [Optional(commandBuffer)]
    var submitInfo = VkSubmitInfo(
      sType: VK_STRUCTURE_TYPE_SUBMIT_INFO,
      pNext: nil,
      waitSemaphoreCount: UInt32(waitSemaphores.count),
      pWaitSemaphores: waitSemaphores,
      pWaitDstStageMask: submitDstStageMasks,
      commandBufferCount: 1,
      pCommandBuffers: commandBuffers,
      signalSemaphoreCount: UInt32(signalSemaphores.count),
      pSignalSemaphores: signalSemaphores
    )
    vkQueueSubmit(queue, 1, &submitInfo, nil)
  }
}
