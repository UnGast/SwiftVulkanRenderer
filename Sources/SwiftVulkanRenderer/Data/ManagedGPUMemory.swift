import Vulkan

class ManagedGPUMemory {
  unowned let manager: MemoryManager
  let memory: VkDeviceMemory
  let size: Int
  var usedRanges: [Range<Int>] = []

  public init(manager: MemoryManager, memory: VkDeviceMemory, size: Int) {
    self.manager = manager
    self.memory = memory
    self.size = size
  }
}