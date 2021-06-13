import Vulkan
import GfxMath

public class SceneManager {
  let renderer: VulkanRenderer
  var scene: Scene {
    renderer.scene
  }

  @Deferred var stagingBuffer: ManagedGPUBuffer
  @Deferred var vertexBuffer: ManagedGPUBuffer 
  var vertexCount: Int = 0

  public init(renderer: VulkanRenderer) throws {
    self.renderer = renderer

    stagingBuffer = try renderer.geometryStagingMemoryManager.getBuffer(size: 1024 * 1024, usage: VK_BUFFER_USAGE_TRANSFER_SRC_BIT)
    vertexBuffer = try renderer.geometryMemoryManager.getBuffer(size: 1024 * 1024, usage: VkBufferUsageFlagBits(rawValue: VK_BUFFER_USAGE_VERTEX_BUFFER_BIT.rawValue | VK_BUFFER_USAGE_TRANSFER_DST_BIT.rawValue))
  }

  public func updateSceneData() throws {
    vertexCount = scene.objects.reduce(0) { $0 + $1.mesh.flatVertices.count }
    try stagingBuffer.store(scene.objects.flatMap { $0.mesh.flatVertices.flatMap { $0.position.elements } })

    var commandBuffer = try renderer.beginSingleTimeCommands()
    vertexBuffer.copy(from: stagingBuffer, srcRange: 0..<stagingBuffer.size, dstOffset: 0, commandBuffer: commandBuffer)
    try renderer.endSingleTimeCommands(commandBuffer: commandBuffer)

    try updateSceneUniform()
 }

  public func updateSceneUniform() throws {
    var commandBuffer = try renderer.beginSingleTimeCommands()

    let sceneUniformObject = SceneUniformObject(
      viewMatrix: Matrix4<Float>.viewTransformation(up: scene.camera.up, right: scene.camera.right, front: scene.camera.forward, translation: scene.camera.position),
      projectionMatrix: newProjection(aspectRatio: 1, fov: .pi / 2, near: 0.01, far: 1000)
    )

    try renderer.uniformSceneStagingBuffer.store(sceneUniformObject.serializedData)
    renderer.uniformSceneBuffer.copy(from: renderer.uniformSceneStagingBuffer, srcRange: 0..<SceneUniformObject.serializedSize, dstOffset: 0, commandBuffer: commandBuffer)

    try renderer.endSingleTimeCommands(commandBuffer: commandBuffer)

    try renderer.updateSceneDescriptorSet()
  }
}

public func newProjection(aspectRatio: Float, fov: Float, near: Float, far: Float) -> FMat4 {
  //let screenDistance = Float(1)
  //let screenWidth = screenDistance * tan(fov / 2)
  //let screenHeight = screenWidth / aspectRatio 

  let f = cos(fov / 4) / sin(fov / 4)
  print("F", f)

  return FMat4([
    f, 0, 0, 0,
    0, -f, 0, 0,
    0, 0, far/(far - near), -(far * near / (far - near)),
    0, 0, 0, 1
  ])
}