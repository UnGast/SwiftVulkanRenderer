import Vulkan

class ManagedGPUMemory {
  unowned let manager: MemoryManager
  let memory: VkDeviceMemory
  let size: Int
  var usedRanges: [Range<VkDeviceSize>] = []
	var dataPointer: UnsafeMutableRawPointer? = nil

  public init(manager: MemoryManager, memory: VkDeviceMemory, size: Int) {
    self.manager = manager
    self.memory = memory
    self.size = size
  }

  func free(range: Range<VkDeviceSize>) {
    var updatedRanges = [Range<VkDeviceSize>]()
    for (index, var usedRange) in usedRanges.enumerated() {
      if range.lowerBound >= usedRange.lowerBound && range.upperBound <= usedRange.upperBound {
        continue
      } else if range.lowerBound < usedRange.upperBound && range.lowerBound >= usedRange.lowerBound {
        usedRange = range.lowerBound..<usedRange.upperBound
      } else if range.upperBound > usedRange.lowerBound && range.upperBound <= usedRange.upperBound {
        usedRange = usedRange.lowerBound..<range.upperBound
      }
      updatedRanges.append(usedRange)
    }
    usedRanges = updatedRanges

    flattenUsedRanges()
  }

  func flattenUsedRanges() {
    usedRanges.removeAll {
      $0.count == 0
    }
  }

  func map() {
    if dataPointer == nil {
      vkMapMemory(manager.renderer.device, memory, 0, VkDeviceSize(size), 0, &dataPointer)
    }
  }

  func unmap() {

  }

  deinit {
    unmap()
  }
}