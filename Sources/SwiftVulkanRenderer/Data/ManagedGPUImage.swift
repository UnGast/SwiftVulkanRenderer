import Vulkan

class ManagedGPUImage {
    unowned let memory: ManagedGPUMemory
    let memoryRange: Range<Int>
    var image: VkImage
    var imageView: VkImageView

    init(
        memory: ManagedGPUMemory,
        memoryRange: Range<Int>,
        image: VkImage,
        imageView: VkImageView
    ) {
        self.memory = memory
        self.memoryRange = memoryRange
        self.image = image
        self.imageView = imageView
    }
}