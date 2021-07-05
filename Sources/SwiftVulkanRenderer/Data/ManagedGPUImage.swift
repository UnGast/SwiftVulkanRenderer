import Vulkan

class ManagedGPUImage {
    unowned let memory: ManagedGPUMemory
    let memoryRange: Range<VkDeviceSize>
    var image: VkImage
    var imageView: VkImageView
    var destroyed: Bool = false

    init(
        memory: ManagedGPUMemory,
        memoryRange: Range<VkDeviceSize>,
        image: VkImage,
        imageView: VkImageView
    ) {
        self.memory = memory
        self.memoryRange = memoryRange
        self.image = image
        self.imageView = imageView
    }

    public func transitionLayout(format: VkFormat, oldLayout: VkImageLayout, newLayout: VkImageLayout, commandBuffer: VkCommandBuffer) throws {
        var srcAccessMask: UInt32 = 0
        var dstAccessMask: UInt32 = 0
        var sourceStage: VkPipelineStageFlagBits = VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT
        var destinationStage: VkPipelineStageFlagBits = VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT

        if oldLayout == VK_IMAGE_LAYOUT_UNDEFINED && newLayout == VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL {
            //srcAccessMask = 0
            //dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT.rawValue

            sourceStage = VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT
            destinationStage = VK_PIPELINE_STAGE_TRANSFER_BIT
        } else if oldLayout == VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL && newLayout == VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL {
            //srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT.rawValue
            //dstAccessMask = VK_ACCESS_SHADER_READ_BIT.rawValue

            sourceStage = VK_PIPELINE_STAGE_TRANSFER_BIT
            destinationStage = VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT // TODO: can optimize
        }

        var barrier = VkImageMemoryBarrier(
            sType: VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
            pNext: nil,
            srcAccessMask: srcAccessMask,
            dstAccessMask: dstAccessMask,
            oldLayout: oldLayout,
            newLayout: newLayout,
            srcQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
            dstQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
            image: image,
            subresourceRange: VkImageSubresourceRange(
                aspectMask: VK_IMAGE_ASPECT_COLOR_BIT.rawValue,
                baseMipLevel: 0,
                levelCount: 1,
                baseArrayLayer: 0,
                layerCount: 1
            )
        )
        vkCmdPipelineBarrier(commandBuffer, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT.rawValue, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT.rawValue, 0, 0, nil, 0, nil, 1, &barrier)
    }

    public func copy(buffer: VkBuffer, width: UInt32, height: UInt32, commandBuffer: VkCommandBuffer) throws {
        var region = VkBufferImageCopy(
            bufferOffset: 0,
            bufferRowLength: 0,
            bufferImageHeight: 0,
            imageSubresource: VkImageSubresourceLayers(
                aspectMask: VK_IMAGE_ASPECT_COLOR_BIT.rawValue,
                mipLevel: 0,
                baseArrayLayer: 0,
                layerCount: 1
            ),
            imageOffset: VkOffset3D(x: 0, y: 0, z: 0),
            imageExtent: VkExtent3D(
                width: width,
                height: height,
                depth: 1
            )
        )
        vkCmdCopyBufferToImage(
            commandBuffer,
            buffer,
            image,
            VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            1,
            &region
        )
    }

    public func destroy() {
        destroyed = true
    }

    deinit {
        if !destroyed {
            print("warning: \(self) was deinitialized before being explicitly destroyed")
        }
    }
}