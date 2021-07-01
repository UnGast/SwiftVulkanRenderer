import Vulkan
import GfxMath

public class SceneManager {
  let renderer: RasterizationVulkanRenderer 
  var scene: Scene {
    renderer.scene
  }

  @Deferred var drawCommandMemoryManager: MemoryManager
  @Deferred var drawCommandBuffer: ManagedGPUBuffer

  @Deferred var geometryMemoryManager: MemoryManager
  @Deferred var geometryStagingMemoryManager: MemoryManager

  @Deferred var objectStagingBuffer: ManagedGPUBuffer
  @Deferred var objectBuffer: ManagedGPUBuffer

  @Deferred var vertexStagingBuffer: ManagedGPUBuffer
  @Deferred var vertexBuffer: ManagedGPUBuffer 

  @Deferred var uniformMemoryManager: MemoryManager
  @Deferred var uniformStagingMemoryManager: MemoryManager
  @Deferred var uniformSceneBuffer: ManagedGPUBuffer 
  @Deferred var uniformSceneStagingBuffer: ManagedGPUBuffer 

  @Deferred var materialSystem: MaterialSystem

  var sceneContentWaitSemaphore: VkSemaphore?
  var objectInfosWaitSemaphore: VkSemaphore?
  var uniformWaitSemaphore: VkSemaphore?

  public init(renderer: RasterizationVulkanRenderer) throws {
    self.renderer = renderer

    drawCommandMemoryManager = try MemoryManager(renderer: renderer, memoryTypeIndex: renderer.findMemoryType(typeFilter: ~0, properties: VkMemoryPropertyFlagBits(rawValue: VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT.rawValue | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT.rawValue)))
    drawCommandBuffer = try drawCommandMemoryManager.getBuffer(size: 1024, usage: VK_BUFFER_USAGE_INDIRECT_BUFFER_BIT)

    geometryMemoryManager = try MemoryManager(renderer: renderer, memoryTypeIndex: renderer.findMemoryType(typeFilter: ~0, properties: VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT), minAllocSize: 50 * 1024 * 1024)
    geometryStagingMemoryManager = try MemoryManager(
      renderer: renderer,
      memoryTypeIndex: renderer.findMemoryType(
        typeFilter: ~0,
        properties: VkMemoryPropertyFlagBits(rawValue: VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT.rawValue | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT.rawValue)),
      minAllocSize: 50 * 1024 * 1024)

    objectStagingBuffer = try geometryStagingMemoryManager.getBuffer(size: 1024 * 1024, usage: VK_BUFFER_USAGE_TRANSFER_SRC_BIT)
    objectBuffer = try geometryMemoryManager.getBuffer(size: 1024 * 1024, usage: VkBufferUsageFlagBits(rawValue: VK_BUFFER_USAGE_STORAGE_BUFFER_BIT.rawValue | VK_BUFFER_USAGE_TRANSFER_DST_BIT.rawValue))

    vertexStagingBuffer = try geometryStagingMemoryManager.getBuffer(size: 1024 * 1024, usage: VK_BUFFER_USAGE_TRANSFER_SRC_BIT)
    vertexBuffer = try geometryMemoryManager.getBuffer(size: 1024 * 1024, usage: VkBufferUsageFlagBits(rawValue: VK_BUFFER_USAGE_VERTEX_BUFFER_BIT.rawValue | VK_BUFFER_USAGE_TRANSFER_DST_BIT.rawValue))

    uniformMemoryManager = try MemoryManager(renderer: renderer, memoryTypeIndex: renderer.findMemoryType(typeFilter: ~0, properties: VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT))
    uniformStagingMemoryManager = try MemoryManager(renderer: renderer, memoryTypeIndex: renderer.findMemoryType(typeFilter: ~0, properties: VkMemoryPropertyFlagBits(rawValue: VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT.rawValue | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT.rawValue)))

    try createUniformBuffers()

    materialSystem = try MaterialSystem(renderer: renderer)

    renderer.currentDrawFinishSemaphoreCallbacks.append { [unowned self] in
      sceneContentWaitSemaphore = VkSemaphore.create(device: renderer.device)
      objectInfosWaitSemaphore = VkSemaphore.create(device: renderer.device)
      uniformWaitSemaphore = VkSemaphore.create(device: renderer.device)
      return [sceneContentWaitSemaphore!, objectInfosWaitSemaphore!, uniformWaitSemaphore!]
    }
  }

  func createUniformBuffers() throws {
    uniformSceneBuffer = try uniformMemoryManager.getBuffer(size: 1024 * 1024, usage: VkBufferUsageFlagBits(rawValue: VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT.rawValue | VK_BUFFER_USAGE_TRANSFER_DST_BIT.rawValue))
    uniformSceneStagingBuffer = try uniformStagingMemoryManager.getBuffer(size: 1024 * 1024, usage: VkBufferUsageFlagBits(rawValue: VK_BUFFER_USAGE_TRANSFER_SRC_BIT.rawValue))
  }

  public func updateSceneContent() throws {
    var drawCommands = [VkDrawIndirectCommand]()

    var commandBuffer = try renderer.beginSingleTimeCommands()

    let oldTextureCount = materialSystem.textures.count

    var vertexData = [Float]()
    var currentVertexCount = 0
    for (index, object) in scene.objects.enumerated() {
      try materialSystem.loadMaterial(object.material)

      let flatVertices = object.mesh.flatVertices

      drawCommands.append(VkDrawIndirectCommand(
        vertexCount: UInt32(flatVertices.count),
        instanceCount: 1,
        firstVertex: UInt32(currentVertexCount),
        firstInstance: UInt32(index)
      ))

      currentVertexCount += flatVertices.count
      //vertexData.append(contentsOf: flatVertices.flatMap { $0.serializedData })
      fatalError("reimplement vertex data transfer with buffer serializable")
    }

    let newTextureCount = materialSystem.textures.count

    if newTextureCount != oldTextureCount {
      try renderer.recreateGraphicsPipeline()
    }

    try vertexStagingBuffer.store(vertexData)
    vertexBuffer.copy(from: vertexStagingBuffer, srcRange: 0..<vertexStagingBuffer.size, dstOffset: 0, commandBuffer: commandBuffer)

    try drawCommandBuffer.store(drawCommands)
    
    let waitSemaphores = sceneContentWaitSemaphore != nil ? [sceneContentWaitSemaphore!] : []

    let signalSemaphore: VkSemaphore = VkSemaphore.create(device: renderer.device)
    renderer.nextDrawSubmitWaits.append((signalSemaphore, VK_PIPELINE_STAGE_VERTEX_INPUT_BIT.rawValue))

    try renderer.endSingleTimeCommands(commandBuffer: commandBuffer, waitSemaphores: waitSemaphores, signalSemaphores: [signalSemaphore])
  }

  public func updateObjectInfos() throws {
    var commandBuffer = try renderer.beginSingleTimeCommands()

   var offset = 0
    for object in scene.objects {
      let drawInfo = SceneObjectDrawInfo(
        transformationMatrix: object.transformationMatrix,
        materialIndex: UInt32(materialSystem.materialDrawInfoIndices[object.material]!))

      try objectStagingBuffer.store(drawInfo, offset: offset)
      offset += SceneObjectDrawInfo.serializedStride
    }
    objectBuffer.copy(from: objectStagingBuffer, srcRange: 0..<objectStagingBuffer.size, dstOffset: 0, commandBuffer: commandBuffer)

    let waitSemaphores = objectInfosWaitSemaphore != nil ? [objectInfosWaitSemaphore!] : []

    let signalSemaphore: VkSemaphore = VkSemaphore.create(device: renderer.device)
    renderer.nextDrawSubmitWaits.append((signalSemaphore, VK_PIPELINE_STAGE_VERTEX_INPUT_BIT.rawValue))

    try renderer.endSingleTimeCommands(commandBuffer: commandBuffer, waitSemaphores: waitSemaphores, signalSemaphores: [signalSemaphore])
  }

  public func updateSceneUniform() throws {
    var commandBuffer = try renderer.beginSingleTimeCommands()

    let sceneUniformObject = SceneUniformObject(
      viewMatrix: Matrix4<Float>.viewTransformation(up: scene.camera.up, right: scene.camera.right, front: scene.camera.forward, translation: -scene.camera.position),
      projectionMatrix: newProjection(aspectRatio: Float(renderer.swapchainExtent.height) / Float(renderer.swapchainExtent.width), fov: .pi / 4, near: 0.01, far: 1000),
      ambientLightColor: scene.ambientLight.color,
      ambientLightIntensity: scene.ambientLight.intensity,
      directionalLightDirection: scene.directionalLight.direction,
      directionalLightColor: scene.directionalLight.color,
      directionalLightIntensity: scene.directionalLight.intensity
    )

    try uniformSceneStagingBuffer.store(sceneUniformObject)
    uniformSceneBuffer.copy(from: uniformSceneStagingBuffer, srcRange: 0..<SceneUniformObject.serializedSize, dstOffset: 0, commandBuffer: commandBuffer)

    let waitSemaphores = uniformWaitSemaphore != nil ? [uniformWaitSemaphore!] : []
    
    try renderer.endSingleTimeCommands(commandBuffer: commandBuffer, waitSemaphores: waitSemaphores)

    try renderer.updateSceneDescriptorSet()
  }
}

/// - Parameter aspectRatio: height / width
public func newProjection(aspectRatio: Float, fov: Float, near: Float, far: Float) -> FMat4 {
  let xMax = Float(tan(fov))
  let yMax = xMax * aspectRatio

  return FMat4([
    1/xMax, 0, 0, 0,
    0, -1/yMax, 0, 0,
    0, 0, far/(far - near), -(far * near / (far - near)),
    0, 0, 1, 0
  ])
}