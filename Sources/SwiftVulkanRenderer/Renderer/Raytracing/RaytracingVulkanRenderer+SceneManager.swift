extension RaytracingVulkanRenderer {
  class SceneManager {
    unowned let renderer: RaytracingVulkanRenderer

    var scene: Scene {
      renderer.scene
    }

    init(renderer: RaytracingVulkanRenderer) {
      self.renderer = renderer
    }
  }
}