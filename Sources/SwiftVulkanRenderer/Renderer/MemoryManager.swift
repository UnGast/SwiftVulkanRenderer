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
    let size = 10 * 1024 * 1024

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

    let memoryOffset = VkDeviceSize(memory.usedRanges.last?.upperBound ?? 0)
    let memorySize = memoryRequirements.size
    let memoryEnd = memoryOffset + memorySize

    guard Int(memoryEnd) < memory.size else {
      throw MemoryCapacityExceededError()
    }

    vkBindBufferMemory(renderer.device, buffer, memory.memory, memoryOffset)

    memory.usedRanges.append(Int(memoryOffset)..<Int(memoryEnd))

    return ManagedGPUBuffer(memory: memory, buffer: buffer!, range: memoryOffset..<memoryEnd)
  }

  public struct MemoryCapacityExceededError: Error {
  }
}