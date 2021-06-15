import Vulkan

public class ManagedGPUBuffer {
    let memory: ManagedGPUMemory
    public var buffer: VkBuffer
    public var range: Range<VkDeviceSize>
    var dataPointer: UnsafeMutableRawPointer? = nil

    public var size: Int {
        range.count
    }

    init(memory: ManagedGPUMemory, buffer: VkBuffer, range: Range<VkDeviceSize>) {
        self.memory = memory
        self.buffer = buffer
        self.range = range
    }

    func map() {
        if dataPointer == nil {
            vkMapMemory(memory.manager.renderer.device, memory.memory, range.lowerBound, VkDeviceSize(range.count), 0, &dataPointer)
        }
    }

    func unmap() {

    }

    public func store(_ data: [Float]) throws {
        map()

        let dataSize = MemoryLayout<Float>.size * data.count

        dataPointer?.copyMemory(from: data, byteCount: dataSize)
    }

    public func copy(from srcBuffer: ManagedGPUBuffer, srcRange: Range<Int>, dstOffset: Int, commandBuffer: VkCommandBuffer) {
        var region = VkBufferCopy(
            srcOffset: VkDeviceSize(srcRange.lowerBound),
            dstOffset: VkDeviceSize(dstOffset),
            size: VkDeviceSize(srcRange.count)
        )
        vkCmdCopyBuffer(commandBuffer, srcBuffer.buffer, buffer, 1, &region)
    }

    deinit {
        unmap()
    }
}