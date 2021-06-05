import Vulkan

public class ManagedGPUBuffer {
    public var buffer: VkBuffer
    public var bufferMemory: VkDeviceMemory

    public init(buffer: VkBuffer, bufferMemory: VkDeviceMemory) {
        self.buffer = buffer
        self.bufferMemory = bufferMemory
    }
}