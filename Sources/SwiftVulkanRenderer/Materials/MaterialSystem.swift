import Foundation
import Swim
import Vulkan
/*
public class MaterialSystem {
    private let renderer: VulkanRenderer

    public var materialDrawInfoIndices: [Material: Int] = [:]
    public var materialDrawInfos: [MaterialDrawInfo] = []

    public private(set) var textures: [ManagedGPUImage] = []

    @Deferred var materialDrawInfoBuffer: ManagedGPUBuffer

    public init(renderer: VulkanRenderer) throws {
        self.renderer = renderer 

        //materialDrawInfoBuffer = renderer.geometryMemoryManager.
    }
    
    /// prepare material data for transfer to gpu, texture is already transferred in this operation, 
    /// if the material has been loaded before already, nothing is done
    /// 
    /// - Returns the index of the material info in the buffer available in shaders
    @discardableResult public func loadMaterial(_ material: Material) throws -> Int {
        if let index = materialDrawInfoIndices[material] {
            return index
        }

        let (textureImage, textureMemory) = try self.createTextureImage(image: material.texture)
        let textureView = createImageView(image: textureImage, format: .R8G8B8A8_SRGB)

        let managedTextureImage = ManagedGPUImage(image: textureImage, imageMemory: textureMemory, imageView: textureView)
        self.textures.append(managedTextureImage)

        let drawInfo = MaterialDrawInfo(textureIndex: UInt32(textures.count - 1))

        materialDrawInfos.append(drawInfo)
        let index = materialDrawInfos.count - 1
        materialDrawInfoIndices[material] = index

        return index
    }
    
    /// sync material draw information with gpu, creates a new buffer
    public func transferDataToGPU() throws {
        let dataSize = materialDrawInfos.count * MemoryLayout<MaterialDrawInfo>.size

        let (buffer, bufferMemory) = try createBuffer(size: DeviceSize(dataSize), usage: .storageBuffer, properties: [.hostCoherent, .hostVisible])

        try vulkanRenderer.copyDataToBufferMemory(data: materialDrawInfos, bufferMemory: bufferMemory)

        self.materialDrawInfoBuffer = ManagedGPUBuffer(buffer: buffer, bufferMemory: bufferMemory)
    }

    /*public func createTextureImage(image cpuImage: Swim.Image<RGBA, UInt8>) throws -> (VkImage, VkDeviceMemory) {
        let imageDataSize = DeviceSize(cpuImage.width * cpuImage.height * 4)

        let (stagingBuffer, stagingBufferMemory) = try createBuffer(
            size: imageDataSize, usage: .transferSrc, properties: [.hostVisible, .hostCoherent])
        var stagingBufferMemoryPointer: UnsafeMutableRawPointer?
        vkMapMemory(vulkanRenderer.device.pointer, stagingBufferMemory, 0, imageDataSize, 0, &stagingBufferMemoryPointer)
        stagingBufferMemoryPointer?.copyMemory(from: cpuImage.getData(), byteCount: Int(imageDataSize))
        vkUnmapMemory(vulkanRenderer.device.pointer, stagingBufferMemory)

        let (textureImage, textureImageMemory) = try createImage(
            width: UInt32(cpuImage.width),
            height: UInt32(cpuImage.height),
            format: .R8G8B8A8_SRGB,
            tiling: .optimal,
            usage: [.transferDst, .sampled],
            properties: [.deviceLocal]
        )

        try transitionImageLayout(image: textureImage, format: .R8G8B8A8_SRGB, oldLayout: .undefined, newLayout: .transferDstOptimal)
        try copyBufferToImage(buffer: stagingBuffer, image: textureImage, width: UInt32(cpuImage.width), height: UInt32(cpuImage.height))
        try transitionImageLayout(image: textureImage, format: .R8G8B8A8_SRGB, oldLayout: .transferDstOptimal, newLayout: .shaderReadOnlyOptimal)

        try vulkanRenderer.device.waitIdle()

        return (textureImage, textureImageMemory)
    }

    public func createImageView(image: VkImage, format: Format) -> VkImageView {
        var viewInfo = VkImageViewCreateInfo(
            sType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            pNext: nil,
            flags: 0,
            image: image,
            viewType: VK_IMAGE_VIEW_TYPE_2D,
            format: format.vulkan,
            components: VkComponentMapping(r: VK_COMPONENT_SWIZZLE_IDENTITY, g: VK_COMPONENT_SWIZZLE_IDENTITY, b: VK_COMPONENT_SWIZZLE_IDENTITY, a: VK_COMPONENT_SWIZZLE_IDENTITY),
            subresourceRange: VkImageSubresourceRange(
                aspectMask: VK_IMAGE_ASPECT_COLOR_BIT.rawValue,
                baseMipLevel: 0,
                levelCount: 1,
                baseArrayLayer: 0,
                layerCount: 1
            )
        )

        var imageViewOpt: VkImageView?
        vkCreateImageView(vulkanRenderer.device.pointer, &viewInfo, nil, &imageViewOpt)

        guard let imageView = imageViewOpt else {
            fatalError("could not create imageView")
        }

        return imageView
    }

    public func createImage(width: UInt32, height: UInt32, format: Format, tiling: ImageTiling, usage: ImageUsageFlags, properties: MemoryPropertyFlags) throws -> (VkImage, VkDeviceMemory) {
        var imageInfo = VkImageCreateInfo(
            sType: VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            imageType: VK_IMAGE_TYPE_2D,
            format: format.vulkan,
            extent: VkExtent3D(
                width: width,
                height: height,
                depth: 1
            ),
            mipLevels: 1,
            arrayLayers: 1,
            samples: VK_SAMPLE_COUNT_1_BIT,
            tiling: tiling.vulkan,
            usage: usage.vulkan,
            sharingMode: VK_SHARING_MODE_EXCLUSIVE,
            queueFamilyIndexCount: 0,
            pQueueFamilyIndices: nil,
            initialLayout: VK_IMAGE_LAYOUT_UNDEFINED
        )

        var imageOpt: VkImage?
        vkCreateImage(vulkanRenderer.device.pointer, &imageInfo, nil, &imageOpt)
        
        guard let image = imageOpt else {
            fatalError("could not create image")
        }
        
        var memRequirements = VkMemoryRequirements()
        vkGetImageMemoryRequirements(vulkanRenderer.device.pointer, image, &memRequirements)

        var allocInfo = VkMemoryAllocateInfo(
            sType: VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            pNext: nil,
            allocationSize: memRequirements.size,
            memoryTypeIndex: try vulkanRenderer.findMemoryType(typeFilter: memRequirements.memoryTypeBits, properties: properties.rawValue)
        )

        var imageMemoryOpt: VkDeviceMemory?
        vkAllocateMemory(vulkanRenderer.device.pointer, &allocInfo, nil, &imageMemoryOpt)
        guard let imageMemory = imageMemoryOpt else {
            fatalError("could not create image memory")
        }

        vkBindImageMemory(vulkanRenderer.device.pointer, image, imageMemory, 0)

        return (image, imageMemory)
    }

    public func transitionImageLayout(image: VkImage, format: Format, oldLayout: ImageLayout, newLayout: ImageLayout) throws {
        let commandBuffer = try vulkanRenderer.beginSingleTimeCommands()

        var srcAccessMask: UInt32 = 0
        var dstAccessMask: UInt32 = 0
        var sourceStage: PipelineStageFlags = []
        var destinationStage: PipelineStageFlags = []

        if oldLayout == .undefined && newLayout == .transferDstOptimal {
            //srcAccessMask = 0
            //dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT.rawValue

            sourceStage = .topOfPipe
            destinationStage = .transfer
        } else if oldLayout == .transferDstOptimal && newLayout == .shaderReadOnlyOptimal {
            //srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT.rawValue
            //dstAccessMask = VK_ACCESS_SHADER_READ_BIT.rawValue

            sourceStage = .transfer
            destinationStage = .fragmentShader// TODO: can optimize
        }

        var barrier = VkImageMemoryBarrier(
            sType: VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
            pNext: nil,
            srcAccessMask: srcAccessMask,
            dstAccessMask: dstAccessMask,
            oldLayout: oldLayout.vulkan,
            newLayout: newLayout.vulkan,
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
        vkCmdPipelineBarrier(commandBuffer.pointer, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT.rawValue, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT.rawValue, 0, 0, nil, 0, nil, 1, &barrier)

        try vulkanRenderer.endSingleTimeCommands(commandBuffer: commandBuffer)
    }

    public func copyBufferToImage(buffer: VkBuffer, image: VkImage, width: UInt32, height: UInt32) throws {
        let commandBuffer = try vulkanRenderer.beginSingleTimeCommands()

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
            commandBuffer.pointer,
            buffer,
            image,
            VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            1,
            &region
        )

        try vulkanRenderer.endSingleTimeCommands(commandBuffer: commandBuffer)
    }

    public func createBuffer(size: DeviceSize, usage: BufferUsageFlags, properties: MemoryPropertyFlags) throws -> (VkBuffer, VkDeviceMemory) {
        var bufferInfo = VkBufferCreateInfo(
            sType: VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            pNext: nil,
            flags: 0,
            size: size,
            usage: usage.vulkan,
            sharingMode: VK_SHARING_MODE_EXCLUSIVE,
            queueFamilyIndexCount: 0,
            pQueueFamilyIndices: nil
        )

        var bufferOpt: VkBuffer?
        vkCreateBuffer(vulkanRenderer.device.pointer, &bufferInfo, nil, &bufferOpt)

        guard let buffer = bufferOpt else {
            fatalError("could not create buffer")
        }
        
        var memRequirements = VkMemoryRequirements()
        vkGetBufferMemoryRequirements(vulkanRenderer.device.pointer, buffer, &memRequirements)

        var allocInfo = VkMemoryAllocateInfo(
            sType: VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            pNext: nil,
            allocationSize: memRequirements.size,
            memoryTypeIndex: try vulkanRenderer.findMemoryType(typeFilter: memRequirements.memoryTypeBits, properties: properties.rawValue)
        )

        var bufferMemoryOpt: VkDeviceMemory?
        vkAllocateMemory(vulkanRenderer.device.pointer, &allocInfo, nil, &bufferMemoryOpt)

        guard let bufferMemory = bufferMemoryOpt else {
            fatalError("could not allocate buffer memory")
        }

        vkBindBufferMemory(vulkanRenderer.device.pointer, buffer, bufferMemory, 0)

        return (buffer, bufferMemory)
    }

    public func copyBuffer(srcBuffer: VkBuffer, dstBuffer: VkBuffer, size: DeviceSize) throws {
        let commandBuffer = try vulkanRenderer.beginSingleTimeCommands()

        var copyRegion = VkBufferCopy(
            srcOffset: 0,
            dstOffset: 0,
            size: size
        )
        vkCmdCopyBuffer(commandBuffer.pointer, srcBuffer, dstBuffer, 1, &copyRegion)

        try vulkanRenderer.endSingleTimeCommands(commandBuffer: commandBuffer)
    }

    public func copyDataToBufferMemory(data: Data, bufferMemory: VkDeviceMemory) throws {
        var memoryPointer: UnsafeMutableRawPointer?
        vkMapMemory(vulkanRenderer.device.pointer, bufferMemory, 0, DeviceSize(data.count), 0, &memoryPointer)
        data.withUnsafeBytes {
            memoryPointer?.copyMemory(from: $0, byteCount: data.count)
        }
        vkUnmapMemory(vulkanRenderer.device.pointer, bufferMemory)
    }*/
}*/