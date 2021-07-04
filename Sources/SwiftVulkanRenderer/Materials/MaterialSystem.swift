import Foundation
import Swim
import Vulkan

class MaterialSystem {
    private let renderer: VulkanRenderer

    let materialDataMemoryManager: MemoryManager
    @Deferred var materialDataBuffer: ManagedGPUBuffer
    var materialDrawInfoIndices: [ObjectIdentifier: Int] = [:]
    var materialDrawInfos: [MaterialDrawInfo] = []

    let materialImagesMemoryManager: MemoryManager
    let materialImagesStagingMemoryManager: MemoryManager
    private(set) var materialImages: [ManagedGPUImage] = []
    @Deferred var materialImagesStagingBuffer: ManagedGPUBuffer

    init(renderer: VulkanRenderer) throws {
        self.renderer = renderer 

        materialDataMemoryManager = try MemoryManager(renderer: renderer, memoryTypeIndex: try renderer.findMemoryType(typeFilter: ~0, properties: VkMemoryPropertyFlagBits(rawValue: VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT.rawValue | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT.rawValue)))

        materialImagesMemoryManager = try MemoryManager(
            renderer: renderer,
            memoryTypeIndex: try renderer.findMemoryType(typeFilter: ~0, properties: VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT),
            minAllocSize: 100 * 1024 * 1024)
        materialImagesStagingMemoryManager = try MemoryManager(
            renderer: renderer,
            memoryTypeIndex: try renderer.findMemoryType(typeFilter: ~0, properties: VkMemoryPropertyFlagBits(rawValue: VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT.rawValue | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT.rawValue)),
            minAllocSize: 50 * 1024 * 1024)

        materialDataBuffer = try materialDataMemoryManager.getBuffer(size: 1024, usage: VK_BUFFER_USAGE_STORAGE_BUFFER_BIT)
        materialImagesStagingBuffer = try materialImagesStagingMemoryManager.getBuffer(size: 10 * 1024 * 1024, usage: VK_BUFFER_USAGE_TRANSFER_SRC_BIT)
    }
    
    /// prepare material data for transfer to gpu, texture is already transferred in this operation, 
    /// if the material has been loaded before already, nothing is done
    /// 
    /// - Returns the index of the material info in the buffer available in shaders
    @discardableResult public func loadMaterial(_ material: Material) throws -> Int {
        if let index = materialDrawInfoIndices[ObjectIdentifier(material)] {
            return index
        }

        let drawInfo: MaterialDrawInfo
        switch material {
        case let material as Dielectric:
            drawInfo = MaterialDrawInfo(type: 0, textureIndex: UInt32(materialImages.count - 1), refractiveIndex: material.refractiveIndex)
        case let material as Lambertian:
            drawInfo = try firstLoadMaterial(lambertian: material)
        default:
            fatalError("unsupported material type")
        }

        materialDrawInfos.append(drawInfo)
        let index = materialDrawInfos.count - 1
        materialDrawInfoIndices[ObjectIdentifier(material)] = index

        return index
    }

    private func firstLoadMaterial(lambertian: Lambertian) throws -> MaterialDrawInfo {
        let loadedTexture = try loadTextureImage(image: lambertian.texture)
        self.materialImages.append(loadedTexture)

        return MaterialDrawInfo(type: 1, textureIndex: UInt32(materialImages.count - 1), refractiveIndex: 0)
    }

    private func loadTextureImage(image cpuImage: Swim.Image<RGBA, UInt8>) throws -> ManagedGPUImage {
        let gpuImage = try materialImagesMemoryManager.getImage(
            width: UInt32(cpuImage.width),
            height: UInt32(cpuImage.height),
            format: VK_FORMAT_R8G8B8A8_SRGB,
            tiling: VK_IMAGE_TILING_OPTIMAL,
            usage: VkImageUsageFlagBits(rawValue: VK_IMAGE_USAGE_TRANSFER_DST_BIT.rawValue | VK_IMAGE_USAGE_SAMPLED_BIT.rawValue))
        
        try materialImagesStagingBuffer.store(cpuImage)

        try transitionImageLayout(image: gpuImage.image, format: VK_FORMAT_R8G8B8A8_SRGB, oldLayout: VK_IMAGE_LAYOUT_UNDEFINED, newLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL)
        try copyBufferToImage(buffer: materialImagesStagingBuffer.buffer, image: gpuImage.image, width: UInt32(cpuImage.width), height: UInt32(cpuImage.height))
        try transitionImageLayout(image: gpuImage.image, format: VK_FORMAT_R8G8B8A8_SRGB, oldLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, newLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL)

        vkDeviceWaitIdle(renderer.device)

        return gpuImage
    }

    /// sync material draw information with gpu (image data is already uploaded as soon as new material is registered)
    public func updateGPUData() throws {
        print("UPDATE GPU")
        try materialDataBuffer.store(materialDrawInfos, strideMultiple16: false)
        print("FINISH UPDATE GU")
    }

    public func createTextureImage(image cpuImage: Swim.Image<RGBA, UInt8>) throws -> VkImage {
        let imageDataSize = VkDeviceSize(cpuImage.width * cpuImage.height * 4)

        let (stagingBuffer, stagingBufferMemory) = try createBuffer(
            size: imageDataSize, usage: VK_BUFFER_USAGE_TRANSFER_SRC_BIT, properties: VkMemoryPropertyFlagBits(rawValue: VK_MEMORY_PROPERTY_HOST_COHERENT_BIT.rawValue | VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT.rawValue))
        var stagingBufferMemoryPointer: UnsafeMutableRawPointer?
        vkMapMemory(renderer.device, stagingBufferMemory, 0, imageDataSize, 0, &stagingBufferMemoryPointer)
        stagingBufferMemoryPointer?.copyMemory(from: cpuImage.getData(), byteCount: Int(imageDataSize))
        vkUnmapMemory(renderer.device, stagingBufferMemory)

        let (textureImage, textureImageMemory) = try createImage(
            width: UInt32(cpuImage.width),
            height: UInt32(cpuImage.height),
            format: VK_FORMAT_R8G8B8A8_SRGB,
            tiling: VK_IMAGE_TILING_OPTIMAL,
            usage: VkImageUsageFlagBits(rawValue: VK_IMAGE_USAGE_TRANSFER_DST_BIT.rawValue | VK_IMAGE_USAGE_SAMPLED_BIT.rawValue),
            properties: VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT
        )

        try transitionImageLayout(image: textureImage, format: VK_FORMAT_R8G8B8A8_SRGB, oldLayout: VK_IMAGE_LAYOUT_UNDEFINED, newLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL)
        try copyBufferToImage(buffer: stagingBuffer, image: textureImage, width: UInt32(cpuImage.width), height: UInt32(cpuImage.height))
        try transitionImageLayout(image: textureImage, format: VK_FORMAT_R8G8B8A8_SRGB, oldLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, newLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL)

        vkDeviceWaitIdle(renderer.device)

        return textureImage
    }

    public func createImageView(image: VkImage, format: VkFormat) -> VkImageView {
        var viewInfo = VkImageViewCreateInfo(
            sType: VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            pNext: nil,
            flags: 0,
            image: image,
            viewType: VK_IMAGE_VIEW_TYPE_2D,
            format: format,
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
        vkCreateImageView(renderer.device, &viewInfo, nil, &imageViewOpt)

        guard let imageView = imageViewOpt else {
            fatalError("could not create imageView")
        }

        return imageView
    }

    public func createImage(width: UInt32, height: UInt32, format: VkFormat, tiling: VkImageTiling, usage: VkImageUsageFlagBits, properties: VkMemoryPropertyFlagBits) throws -> (VkImage, VkDeviceMemory) {
        var imageInfo = VkImageCreateInfo(
            sType: VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
            pNext: nil,
            flags: 0,
            imageType: VK_IMAGE_TYPE_2D,
            format: format,
            extent: VkExtent3D(
                width: width,
                height: height,
                depth: 1
            ),
            mipLevels: 1,
            arrayLayers: 1,
            samples: VK_SAMPLE_COUNT_1_BIT,
            tiling: tiling,
            usage: usage.rawValue,
            sharingMode: VK_SHARING_MODE_EXCLUSIVE,
            queueFamilyIndexCount: 0,
            pQueueFamilyIndices: nil,
            initialLayout: VK_IMAGE_LAYOUT_UNDEFINED
        )

        var imageOpt: VkImage?
        vkCreateImage(renderer.device, &imageInfo, nil, &imageOpt)
        
        guard let image = imageOpt else {
            fatalError("could not create image")
        }
        
        var memRequirements = VkMemoryRequirements()
        vkGetImageMemoryRequirements(renderer.device, image, &memRequirements)

        var allocInfo = VkMemoryAllocateInfo(
            sType: VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            pNext: nil,
            allocationSize: memRequirements.size,
            memoryTypeIndex: try renderer.findMemoryType(typeFilter: memRequirements.memoryTypeBits, properties: properties)
        )

        var imageMemoryOpt: VkDeviceMemory?
        vkAllocateMemory(renderer.device, &allocInfo, nil, &imageMemoryOpt)
        guard let imageMemory = imageMemoryOpt else {
            fatalError("could not create image memory")
        }

        vkBindImageMemory(renderer.device, image, imageMemory, 0)

        return (image, imageMemory)
    }

    public func transitionImageLayout(image: VkImage, format: VkFormat, oldLayout: VkImageLayout, newLayout: VkImageLayout) throws {
        let commandBuffer = try renderer.beginSingleTimeCommands()

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

        try renderer.endSingleTimeCommands(commandBuffer: commandBuffer)
    }

    public func copyBufferToImage(buffer: VkBuffer, image: VkImage, width: UInt32, height: UInt32) throws {
        let commandBuffer = try renderer.beginSingleTimeCommands()

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

        try renderer.endSingleTimeCommands(commandBuffer: commandBuffer)
    }

    public func createBuffer(size: VkDeviceSize, usage: VkBufferUsageFlagBits, properties: VkMemoryPropertyFlagBits) throws -> (VkBuffer, VkDeviceMemory) {
        var bufferInfo = VkBufferCreateInfo(
            sType: VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            pNext: nil,
            flags: 0,
            size: size,
            usage: usage.rawValue,
            sharingMode: VK_SHARING_MODE_EXCLUSIVE,
            queueFamilyIndexCount: 0,
            pQueueFamilyIndices: nil
        )

        var bufferOpt: VkBuffer?
        vkCreateBuffer(renderer.device, &bufferInfo, nil, &bufferOpt)

        guard let buffer = bufferOpt else {
            fatalError("could not create buffer")
        }
        
        var memRequirements = VkMemoryRequirements()
        vkGetBufferMemoryRequirements(renderer.device, buffer, &memRequirements)

        var allocInfo = VkMemoryAllocateInfo(
            sType: VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            pNext: nil,
            allocationSize: memRequirements.size,
            memoryTypeIndex: try renderer.findMemoryType(typeFilter: memRequirements.memoryTypeBits, properties: properties)
        )

        var bufferMemoryOpt: VkDeviceMemory?
        vkAllocateMemory(renderer.device, &allocInfo, nil, &bufferMemoryOpt)

        guard let bufferMemory = bufferMemoryOpt else {
            fatalError("could not allocate buffer memory")
        }

        vkBindBufferMemory(renderer.device, buffer, bufferMemory, 0)

        return (buffer, bufferMemory)
    }

    public func copyBuffer(srcBuffer: VkBuffer, dstBuffer: VkBuffer, size: VkDeviceSize) throws {
        let commandBuffer = try renderer.beginSingleTimeCommands()

        var copyRegion = VkBufferCopy(
            srcOffset: 0,
            dstOffset: 0,
            size: size
        )
        vkCmdCopyBuffer(commandBuffer, srcBuffer, dstBuffer, 1, &copyRegion)

        try renderer.endSingleTimeCommands(commandBuffer: commandBuffer)
    }

    public func copyDataToBufferMemory(data: Data, bufferMemory: VkDeviceMemory) throws {
        var memoryPointer: UnsafeMutableRawPointer?
        vkMapMemory(renderer.device, bufferMemory, 0, VkDeviceSize(data.count), 0, &memoryPointer)
        data.withUnsafeBytes {
            memoryPointer?.copyMemory(from: $0, byteCount: data.count)
        }
        vkUnmapMemory(renderer.device, bufferMemory)
    }
}