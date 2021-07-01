import Vulkan
import Swim
import GfxMath

extension RaytracingVulkanRenderer {
  class SceneManager {
    unowned let renderer: RaytracingVulkanRenderer

    let stagingMemoryManager: MemoryManager
    let mainMemoryManager: MemoryManager
    @Deferred var objectGeometryStagingBuffer: ManagedGPUBuffer
    @Deferred var objectGeometryBuffer: ManagedGPUBuffer
    @Deferred var objectDrawInfoStagingBuffer: ManagedGPUBuffer
    @Deferred var objectDrawInfoBuffer: ManagedGPUBuffer
    var meshVertexInfos = [Mesh: (firstIndex: Int, count: Int)]()
    var vertexCount: Int = 0

    var scene: Scene {
      renderer.scene
    }

    init(renderer: RaytracingVulkanRenderer) throws {
      self.renderer = renderer

      self.stagingMemoryManager = try MemoryManager(
        renderer: renderer,
        memoryTypeIndex: try renderer.findMemoryType(typeFilter: ~0, properties: VkMemoryPropertyFlagBits(rawValue: VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT.rawValue | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT.rawValue)))
      self.mainMemoryManager = try MemoryManager(
        renderer: renderer,
        memoryTypeIndex: try renderer.findMemoryType(typeFilter: ~0, properties: VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT))

      objectGeometryStagingBuffer = try stagingMemoryManager.getBuffer(size: 1024 * 1024, usage: VK_BUFFER_USAGE_TRANSFER_SRC_BIT)
      
      objectGeometryBuffer = try mainMemoryManager.getBuffer(
        size: 1024 * 1024, usage: VkBufferUsageFlagBits(rawValue: VK_BUFFER_USAGE_STORAGE_BUFFER_BIT.rawValue | VK_BUFFER_USAGE_TRANSFER_DST_BIT.rawValue))

      objectDrawInfoStagingBuffer = try stagingMemoryManager.getBuffer(size: 1024 * 1024, usage: VK_BUFFER_USAGE_TRANSFER_SRC_BIT)
      
      objectDrawInfoBuffer = try mainMemoryManager.getBuffer(
        size: 1024 * 1024, usage: VkBufferUsageFlagBits(rawValue: VK_BUFFER_USAGE_STORAGE_BUFFER_BIT.rawValue | VK_BUFFER_USAGE_TRANSFER_DST_BIT.rawValue))

      try updateObjectGeometryData()

      try updateObjectDrawInfoData()
    }

    func updateObjectGeometryData() throws {
      meshVertexInfos = [:]

      let commandBuffer = try renderer.beginSingleTimeCommands()

      var vertices = [Vertex]()
      for object in scene.objects {
        if meshVertexInfos[object.mesh] == nil {
          let flatVertices = object.mesh.flatVertices
          meshVertexInfos[object.mesh] = (firstIndex: vertices.count, count: flatVertices.count)
          vertices.append(contentsOf: flatVertices)
        }
      }
      vertexCount = vertices.count
      try objectGeometryStagingBuffer.store(vertices)

      try objectGeometryBuffer.copy(from: objectGeometryStagingBuffer, srcRange: 0..<(vertices.count * Vertex.serializedSize), dstOffset: 0, commandBuffer: commandBuffer)

      try renderer.endSingleTimeCommands(commandBuffer: commandBuffer)
    }

    func updateObjectDrawInfoData() throws {
      var objectDrawInfos = [ObjectDrawInfo]()
      for object in scene.objects {
        let materialIndex = try renderer.materialSystem.loadMaterial(object.material)

        let meshVertexInfo = meshVertexInfos[object.mesh]!
        objectDrawInfos.append(ObjectDrawInfo(
          transformationMatrix: object.transformationMatrix,
          firstVertexIndex: UInt32(meshVertexInfo.firstIndex),
          vertexCount: UInt32(meshVertexInfo.count),
          materialIndex: UInt32(materialIndex)
        ))
      }
      
      try objectDrawInfoStagingBuffer.store(objectDrawInfos)

      let commandBuffer = try renderer.beginSingleTimeCommands()

      print("SIZE", objectDrawInfos.count, ObjectDrawInfo.serializedSize)
      try objectDrawInfoBuffer.copy(from: objectDrawInfoStagingBuffer, srcRange: 0..<(objectDrawInfos.count * ObjectDrawInfo.serializedSize), dstOffset: 0, commandBuffer: commandBuffer)

      try renderer.endSingleTimeCommands(commandBuffer: commandBuffer)
    }
  }
}