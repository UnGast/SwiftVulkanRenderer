import Vulkan

public class MemoryManager {
  let renderer: VulkanRenderer
  let memoryTypeIndex: UInt32
  let minAllocSize: Int
  @Deferred var memory: ManagedGPUMemory

  public init(renderer: VulkanRenderer, memoryTypeIndex: UInt32, minAllocSize: Int = 10 * 1024 * 1024) throws {
    self.renderer = renderer
    self.memoryTypeIndex = memoryTypeIndex
    self.minAllocSize = minAllocSize

    try allocateManagedMemory()
  }

  private func allocateManagedMemory() throws {
    let size = minAllocSize

    var allocateInfo = VkMemoryAllocateInfo(
      sType: VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
      pNext: nil,
      allocationSize: VkDeviceSize(size),
      memoryTypeIndex: memoryTypeIndex
    )

    var deviceMemory: VkDeviceMemory? = nil
    vkAllocateMemory(renderer.device, &allocateInfo, nil, &deviceMemory)

    self.memory = ManagedGPUMemory(manager: self, memory: deviceMemory!, size: size)
  }

  private func allocateMemoryRange(size: VkDeviceSize) throws -> Range<VkDeviceSize> {
    let memoryOffset = VkDeviceSize(memory.usedRanges.last?.upperBound ?? 0)
    let memoryEnd = memoryOffset + size 

    guard Int(memoryEnd) < memory.size else {
      throw MemoryCapacityExceededError()
    }

    return memoryOffset..<memoryEnd
  }

  public func getBuffer(size: Int, usage: VkBufferUsageFlagBits) throws -> ManagedGPUBuffer {
    var bufferCreateInfo = VkBufferCreateInfo(
      sType: VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
      pNext: nil,
      flags: 0,
      size: VkDeviceSize(size),
      usage: usage.rawValue,
      sharingMode: VK_SHARING_MODE_EXCLUSIVE,
      queueFamilyIndexCount: 0,
      pQueueFamilyIndices: nil
    )

    var buffer: VkBuffer? = nil
    vkCreateBuffer(renderer.device, &bufferCreateInfo, nil, &buffer)

    var memoryRequirements = VkMemoryRequirements()
    vkGetBufferMemoryRequirements(renderer.device, buffer, &memoryRequirements)

    let memorySize = memoryRequirements.size
    let memoryRange = try allocateMemoryRange(size: memorySize)

    vkBindBufferMemory(renderer.device, buffer, memory.memory, memoryRange.lowerBound)

    memory.usedRanges.append(memoryRange)

    return ManagedGPUBuffer(memory: memory, buffer: buffer!, range: memoryRange)
  }

  /*public func getImage(width: UInt32, height: UInt32, format: VkFormat, tiling: VkIMageTiling, usage: VkImageUsageFlagBits) throws -> ManagedGPUImage {

  }*/

  /*private func createRawImage(image cpuImage: Swim.Image<RGBA, UInt8>) throws -> VkImage {
    let imageDataSize = VkDeviceSize(cpuImage.width * cpuImage.height * 4)

    let (stagingBuffer, stagingBufferMemory) = try createBuffer(
        size: imageDataSize, usage: VK_BUFFER_USAGE_TRANSFER_SRC_BIT, properties: VkMemoryPropertyFlagBits(rawValue: VK_MEMORY_PROPERTY_HOST_COHERENT_BIT.rawValue | VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT.rawValue))
    var stagingBufferMemoryPointer: UnsafeMutableRawPointer?
    vkMapMemory(renderer.device, stagingBufferMemory, 0, imageDataSize, 0, &stagingBufferMemoryPointer)
    stagingBufferMemoryPointer?.copyMemory(from: cpuImage.getData(), byteCount: Int(imageDataSize))
    vkUnmapMemory(renderer.device, stagingBufferMemory)

    let (textureImage, textureImageMemory) = try createImage(
        width: UInt32(cpuImage.width),
        height: UInt32(cpuImage.height),
        format: VK_FORMAT_R8G8B8A8_SRGB,
        tiling: VK_IMAGE_TILING_OPTIMAL,
        usage: VkImageUsageFlagBits(rawValue: VK_IMAGE_USAGE_TRANSFER_DST_BIT.rawValue | VK_IMAGE_USAGE_SAMPLED_BIT.rawValue),
        properties: VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT
    )

    /*try transitionImageLayout(image: textureImage, format: VK_FORMAT_R8G8B8A8_SRGB, oldLayout: VK_IMAGE_LAYOUT_UNDEFINED, newLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL)
    try copyBufferToImage(buffer: stagingBuffer, image: textureImage, width: UInt32(cpuImage.width), height: UInt32(cpuImage.height))
    try transitionImageLayout(image: textureImage, format: VK_FORMAT_R8G8B8A8_SRGB, oldLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, newLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL)

    vkDeviceWaitIdle(renderer.device)*/

    return textureImage
  }*/

  /*private func createImageView(image: VkImage, format: VkFormat) -> VkImageView {
    var viewInfo = VkImageViewCreateInfo(
      sType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
      pNext: nil,
      flags: 0,
      image: image,
      viewType: VK_IMAGE_VIEW_TYPE_2D,
      format: format,
      components: VkComponentMapping(r: VK_COMPONENT_SWIZZLE_IDENTITY, g: VK_COMPONENT_SWIZZLE_IDENTITY, b: VK_COMPONENT_SWIZZLE_IDENTITY, a: VK_COMPONENT_SWIZZLE_IDENTITY),
      subresourceRange: VkImageSubresourceRange(
        aspectMask: VK_IMAGE_ASPECT_COLOR_BIT.rawValue,
        baseMipLevel: 0,
        levelCount: 1,
        baseArrayLayer: 0,
        layerCount: 1
      )
    )

    var imageViewOpt: VkImageView?
    vkCreateImageView(renderer.device, &viewInfo, nil, &imageViewOpt)

    guard let imageView = imageViewOpt else {
        fatalError("could not create imageView")
    }

    return imageView
  }

  private func createImage(width: UInt32, height: UInt32, format: VkFormat, tiling: VkImageTiling, usage: VkImageUsageFlagBits, properties: VkMemoryPropertyFlagBits) throws -> (VkImage, ) {
    var imageInfo = VkImageCreateInfo(
      sType: VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
      pNext: nil,
      flags: 0,
      imageType: VK_IMAGE_TYPE_2D,
      format: format,
      extent: VkExtent3D(
          width: width,
          height: height,
          depth: 1
      ),
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

    var imageOpt: VkImage?
    vkCreateImage(renderer.device, &imageInfo, nil, &imageOpt)
    
    guard let image = imageOpt else {
        fatalError("could not create image")
    }
    
    var memRequirements = VkMemoryRequirements()
    vkGetImageMemoryRequirements(renderer.device, image, &memRequirements)

    var allocInfo = VkMemoryAllocateInfo(
        sType: VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        pNext: nil,
        allocationSize: memRequirements.size,
        memoryTypeIndex: try renderer.findMemoryType(typeFilter: memRequirements.memoryTypeBits, properties: properties)
    )

    /*var imageMemoryOpt: VkDeviceMemory?
    vkAllocateMemory(renderer.device, &allocInfo, nil, &imageMemoryOpt)
    guard let imageMemory = imageMemoryOpt else {
        fatalError("could not create image memory")
    }*/

    vkBindImageMemory(renderer.device, image, imageMemory, 0)

    return (image, imageMemory)
  }*/

  public struct MemoryCapacityExceededError: Error {
  }
}