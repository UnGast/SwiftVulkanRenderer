import Foundation
import Vulkan

public class ManagedGPUBuffer {
    let memory: ManagedGPUMemory
    public var buffer: VkBuffer
    public var range: Range<VkDeviceSize>
    var dataPointer: UnsafeMutableRawPointer {
        if memory.dataPointer == nil {
            memory.map()
        }
        return memory.dataPointer!.advanced(by: Int(range.lowerBound))
    }

    public var size: Int {
        range.count
    }

    init(memory: ManagedGPUMemory, buffer: VkBuffer, range: Range<VkDeviceSize>) {
        self.memory = memory
        self.buffer = buffer
        self.range = range
    }

    public func store<T>(_ data: [T], offset: Int = 0) throws {
        let dataSize = MemoryLayout<T>.size * data.count

        dataPointer.advanced(by: offset).copyMemory(from: data, byteCount: dataSize)
    }

    public func store(_ data: Data, offset: Int = 0) throws {
        fatalError("untested")
        data.withUnsafeBytes {
            dataPointer.advanced(by: offset).copyMemory(from: $0, byteCount: data.count)
        }
    }

    public func store<S: BufferSerializable>(_ data: S, offset: Int = 0) throws {
        data.serialize(into: dataPointer.advanced(by: offset), offset: 0)
    }

    public func copy(from srcBuffer: ManagedGPUBuffer, srcRange: Range<Int>, dstOffset: Int, commandBuffer: VkCommandBuffer) {
        var region = VkBufferCopy(
            srcOffset: VkDeviceSize(srcRange.lowerBound),
            dstOffset: VkDeviceSize(dstOffset),
            size: VkDeviceSize(srcRange.count)
        )
        vkCmdCopyBuffer(commandBuffer, srcBuffer.buffer, buffer, 1, &region)
    }
}