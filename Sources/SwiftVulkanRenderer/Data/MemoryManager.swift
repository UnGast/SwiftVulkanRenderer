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

    let range = memoryOffset..<memoryEnd

    memory.usedRanges.append(range)

    return range
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

    return ManagedGPUBuffer(memory: memory, buffer: buffer!, range: memoryRange)
  }

  func getImage(width: UInt32, height: UInt32, format: VkFormat, tiling: VkImageTiling, usage: VkImageUsageFlagBits) throws -> ManagedGPUImage {
   let (image, memoryRange) = try createImage(
      width: width,
      height: height,
      format: VK_FORMAT_R8G8B8A8_SRGB,
      tiling: VK_IMAGE_TILING_OPTIMAL,
      usage: VkImageUsageFlagBits(rawValue: VK_IMAGE_USAGE_TRANSFER_DST_BIT.rawValue | VK_IMAGE_USAGE_SAMPLED_BIT.rawValue),
      properties: VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT
    )

    let imageView = createImageView(image: image, format: format)

    return ManagedGPUImage(memory: memory, memoryRange: memoryRange, image: image, imageView: imageView)
  }

  private func createImageView(image: VkImage, format: VkFormat) -> VkImageView {
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

  private func createImage(width: UInt32, height: UInt32, format: VkFormat, tiling: VkImageTiling, usage: VkImageUsageFlagBits, properties: VkMemoryPropertyFlagBits) throws -> (VkImage, Range<VkDeviceSize>) {
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

    let memoryRange = try allocateMemoryRange(size: memRequirements.size)

    /*var allocInfo = VkMemoryAllocateInfo(
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
    */

    vkBindImageMemory(renderer.device, image, memory.memory, memoryRange.lowerBound)

    return (image, memoryRange)
  }

  public struct MemoryCapacityExceededError: Error {
  }
}