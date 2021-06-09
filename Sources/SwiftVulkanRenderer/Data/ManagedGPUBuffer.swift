import Vulkan

public class ManagedGPUBuffer {
    public var buffer: VkBuffer
    public var range: Range<VkDeviceSize>

    public init(buffer: VkBuffer, range: Range<VkDeviceSize>) {
        self.buffer = buffer
        self.range = range
    }
}