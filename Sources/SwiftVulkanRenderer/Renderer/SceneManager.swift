import Vulkan
import GfxMath

public class SceneManager {
  let renderer: VulkanRenderer
  var scene: Scene {
    renderer.scene
  }

  @Deferred var objectStagingBuffer: ManagedGPUBuffer
  @Deferred var objectBuffer: ManagedGPUBuffer

  @Deferred var vertexStagingBuffer: ManagedGPUBuffer
  @Deferred var vertexBuffer: ManagedGPUBuffer 
  var vertexCount: Int = 0

  var sceneContentWaitSemaphore: VkSemaphore?
  var objectInfosWaitSemaphore: VkSemaphore?
  var uniformWaitSemaphore: VkSemaphore?

  public init(renderer: VulkanRenderer) throws {
    self.renderer = renderer

    objectStagingBuffer = try renderer.geometryStagingMemoryManager.getBuffer(size: 1024 * 1024, usage: VK_BUFFER_USAGE_TRANSFER_SRC_BIT)
    objectBuffer = try renderer.geometryMemoryManager.getBuffer(size: 1024 * 1024, usage: VkBufferUsageFlagBits(rawValue: VK_BUFFER_USAGE_STORAGE_BUFFER_BIT.rawValue | VK_BUFFER_USAGE_TRANSFER_DST_BIT.rawValue))

    vertexStagingBuffer = try renderer.geometryStagingMemoryManager.getBuffer(size: 1024 * 1024, usage: VK_BUFFER_USAGE_TRANSFER_SRC_BIT)
    vertexBuffer = try renderer.geometryMemoryManager.getBuffer(size: 1024 * 1024, usage: VkBufferUsageFlagBits(rawValue: VK_BUFFER_USAGE_VERTEX_BUFFER_BIT.rawValue | VK_BUFFER_USAGE_TRANSFER_DST_BIT.rawValue))

    renderer.currentDrawFinishSemaphoreCallbacks.append { [unowned self] in
      sceneContentWaitSemaphore = VkSemaphore.create(device: renderer.device)
      objectInfosWaitSemaphore = VkSemaphore.create(device: renderer.device)
      uniformWaitSemaphore = VkSemaphore.create(device: renderer.device)
      return [sceneContentWaitSemaphore!, objectInfosWaitSemaphore!, uniformWaitSemaphore!]
    }
  }

  public func updateSceneContent() throws {
    var commandBuffer = try renderer.beginSingleTimeCommands()

    vertexCount = scene.objects.reduce(0) { $0 + $1.mesh.flatVertices.count }
    try vertexStagingBuffer.store(scene.objects.flatMap { $0.mesh.flatVertices.flatMap { $0.position.elements } })
    vertexBuffer.copy(from: vertexStagingBuffer, srcRange: 0..<vertexStagingBuffer.size, dstOffset: 0, commandBuffer: commandBuffer)
    
    let waitSemaphores = sceneContentWaitSemaphore != nil ? [sceneContentWaitSemaphore!] : []

    let signalSemaphore: VkSemaphore = VkSemaphore.create(device: renderer.device)
    renderer.nextDrawSubmitWaits.append((signalSemaphore, VK_PIPELINE_STAGE_VERTEX_INPUT_BIT.rawValue))

    try renderer.endSingleTimeCommands(commandBuffer: commandBuffer, waitSemaphores: waitSemaphores, signalSemaphores: [signalSemaphore])
  }

  public func updateObjectInfos() throws {
    var commandBuffer = try renderer.beginSingleTimeCommands()

   var offset = 0
    for object in scene.objects {
      let drawInfo = SceneObjectDrawInfo(transformationMatrix: object.transformationMatrix)
      try objectStagingBuffer.store(drawInfo.serializedData, offset: offset)
      offset += SceneObjectDrawInfo.serializedSize
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
      projectionMatrix: newProjection(aspectRatio: Float(renderer.swapchainExtent.height) / Float(renderer.swapchainExtent.width), fov: .pi / 4, near: 0.01, far: 1000)
    )

    try renderer.uniformSceneStagingBuffer.store(sceneUniformObject.serializedData)
    renderer.uniformSceneBuffer.copy(from: renderer.uniformSceneStagingBuffer, srcRange: 0..<SceneUniformObject.serializedSize, dstOffset: 0, commandBuffer: commandBuffer)

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