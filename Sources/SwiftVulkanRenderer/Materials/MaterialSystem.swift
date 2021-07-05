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

        let commandBuffer = try renderer.beginSingleTimeCommands()
        try gpuImage.transitionLayout(format: VK_FORMAT_R8G8B8A8_SRGB, oldLayout: VK_IMAGE_LAYOUT_UNDEFINED, newLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, commandBuffer: commandBuffer)
        try gpuImage.copy(buffer: materialImagesStagingBuffer.buffer, width: UInt32(cpuImage.width), height: UInt32(cpuImage.height), commandBuffer: commandBuffer)
        try gpuImage.transitionLayout(format: VK_FORMAT_R8G8B8A8_SRGB, oldLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, newLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL, commandBuffer: commandBuffer)
        try renderer.endSingleTimeCommands(commandBuffer: commandBuffer)

        vkDeviceWaitIdle(renderer.device)

        return gpuImage
    }

    /// sync material draw information with gpu (image data is already uploaded as soon as new material is registered)
    public func updateGPUData() throws {
        print("UPDATE GPU")
        try materialDataBuffer.store(materialDrawInfos, strideMultiple16: false)
        print("FINISH UPDATE GU")
    }
}