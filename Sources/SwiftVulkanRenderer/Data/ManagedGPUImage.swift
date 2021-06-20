import Vulkan

class ManagedGPUImage {
    var image: VkImage
    var imageView: VkImageView
    //let memory: ManagedGPUMemory
    //let memoryRange: Range<Int>

    init(
        image: VkImage,
        imageView: VkImageView
        //memory: ManagedGPUMemory,
        //memoryRange: Range<Int>
    ) {
        self.image = image
        self.imageView = imageView
        //self.memory = memory
        //self.memoryRange = memoryRange
    }
}