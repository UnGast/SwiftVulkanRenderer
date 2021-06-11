import Vulkan

public class MemoryManager {
  let renderer: VulkanRenderer
  let memoryTypeIndex: UInt32
  @Deferred var memory: ManagedGPUMemory

  public init(renderer: VulkanRenderer, memoryTypeIndex: UInt32) throws {
    self.renderer = renderer
    self.memoryTypeIndex = memoryTypeIndex

    try allocateMemory()
  }

  func allocateMemory() throws {
    var allocateInfo = VkMemoryAllocateInfo(
      sType: VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
      pNext: nil,
      allocationSize: 1024 * 1024,
      memoryTypeIndex: memoryTypeIndex
    )

    var deviceMemory: VkDeviceMemory? = nil
    vkAllocateMemory(renderer.device, &allocateInfo, nil, &deviceMemory)

    self.memory = ManagedGPUMemory(manager: self, memory: deviceMemory!)
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

    let memoryOffset = VkDeviceSize(0)
    let memorySize = memoryRequirements.size

    vkBindBufferMemory(renderer.device, buffer, memory.memory, memoryOffset)

    return ManagedGPUBuffer(memory: memory, buffer: buffer!, range: memoryOffset..<(memoryOffset + memorySize))
  }
}

class ManagedGPUMemory {
  unowned let manager: MemoryManager
  let memory: VkDeviceMemory
  let usedRanges: [Range<Int>] = []

  public init(manager: MemoryManager, memory: VkDeviceMemory) {
    self.manager = manager
    self.memory = memory
  }
}