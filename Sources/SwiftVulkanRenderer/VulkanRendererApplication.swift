import Foundation
import Dispatch
import HID
import Vulkan
import GfxMath

public class VulkanRendererApplication {
    let scene: Scene
    var renderer: VulkanRenderer?

    public var beforeFrame: ((Double) -> ())?

    public init(scene: Scene) {
        self.scene = scene
    }

    public func notifySceneContentsUpdated() throws {
        try renderer?.sceneManager.updateSceneContent()
        try renderer?.sceneManager.updateObjectInfos()
    }

    public func notifySceneObjectInfosUpdated() throws {
        try renderer?.sceneManager.updateObjectInfos()
    }

    public func run() throws {
        Platform.initialize()
        print("Platform version: \(Platform.version)")

        // either use a custom surface sub-class
        // or use the default implementation directly
        // let surface = CPUSurface()

        enum VulkanApplicationError: Error {
            case couldNotCreateInstance
        }

        func createVLKInstance() throws -> VkInstance {
            var hidSurfaceExtensions = VLKWindowSurface.getRequiredInstanceExtensionNames()
            var rawExtensionNames = hidSurfaceExtensions + [
                "VK_KHR_get_physical_device_properties2"
            ]

            // strdup copies the string passed in and returns a pointer to copy; copy not managed by swift -> not deallocated
            var enabledLayerNames = [UnsafePointer<CChar>(strdup("VK_LAYER_KHRONOS_validation"))]

            var extNames = rawExtensionNames.map { UnsafePointer<CChar>(strdup($0)) }

            var createInfo = VkInstanceCreateInfo(
                sType: VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
                pNext: nil,
                flags: 0,
                pApplicationInfo: nil,
                enabledLayerCount: UInt32(enabledLayerNames.count),
                ppEnabledLayerNames: enabledLayerNames,
                enabledExtensionCount: UInt32(rawExtensionNames.count),
                ppEnabledExtensionNames: &extNames
            )

            var instanceOpt: VkInstance?
            let result = vkCreateInstance(&createInfo, nil, &instanceOpt)

            guard let instance = instanceOpt, result == VK_SUCCESS else {
                throw VulkanApplicationError.couldNotCreateInstance
            }

            return instance
        }

        func makeVLKSurface(in window: Window) throws -> VLKWindowSurface {
            let vulkanInstance = try createVLKInstance()
            return try VLKWindowSurface(in: window, instance: vulkanInstance)
        }

        let props = WindowProperties(title: "Title", frame: .init(0, 0, 800, 600))

        let window = try Window(properties: props,
                                surface: makeVLKSurface)

        var event = Event()
        var quit = false

        guard let surface = window.surface as? VLKWindowSurface else {
        fatalError("incorrect surface")
        }

        var frameCount = 0

        var keysActive: [KeyCode: Bool] = [
            .LEFT: false,
            .RIGHT: false,
            .UP: false,
            .DOWN: false
        ]

        func setupRenderer() throws {
            renderer = try VulkanRenderer(scene: scene, instance: surface.instance, surface: surface.surface)
            try renderer?.sceneManager.updateSceneContent()
            try renderer?.sceneManager.updateObjectInfos()
            try renderer?.sceneManager.updateSceneUniform()
        }
        
        var previousFrameTimestamp = Date.timeIntervalSinceReferenceDate
        var lastFrameDurationStartTimestamp = Date.timeIntervalSinceReferenceDate
        var fiveFramesDuration = 1.0

        func frame() throws {
            let currentFrameTimestamp = Date.timeIntervalSinceReferenceDate

            if frameCount % 5 == 0 {
                fiveFramesDuration = currentFrameTimestamp - lastFrameDurationStartTimestamp 
                lastFrameDurationStartTimestamp = currentFrameTimestamp
                //print("fps", 1 / (fiveFramesDuration / 5))
            }

            beforeFrame?(currentFrameTimestamp - previousFrameTimestamp)

            previousFrameTimestamp = currentFrameTimestamp

            if renderer == nil && frameCount > 10 {
                usleep(2000 * 100)
                try setupRenderer()
                usleep(2000 * 100)
            }

            try renderer?.sceneManager.updateSceneUniform()
            try renderer?.draw()

            frameCount += 1

            Events.pumpEvents()

            while Events.pollEvent(&event) {
                switch event.variant {
                case .userQuit:
                    quit = true
                
                case .window:
                    if case let .resizedTo(newSize) = event.window.action {
                        if renderer == nil {
                            try setupRenderer()
                        }
                    }

                case .pointerMotion:
                    let eventData = event.pointerMotion

                    scene.camera.pitch -= eventData.deltaY / 360
                    scene.camera.pitch = min(89 / 360, max(-89 / 360, scene.camera.pitch))
                    scene.camera.yaw += eventData.deltaX / 360
                
                case .keyboard:
                    let eventData = event.keyboard
                    
                    if let key = eventData.virtualKey {
                        if keysActive[key] != nil {
                            keysActive[key] = eventData.state == .pressed ? true : false
                        }
                    }

                default:
                    break
                }
            }

            var deltaMove = FVec3.zero
            var stepSize: Float = 0.01
            if keysActive[.UP]! {
                deltaMove += scene.camera.forward * stepSize
            }
            if keysActive[.DOWN]! {
                deltaMove -= scene.camera.forward * stepSize
            }
            if keysActive[.LEFT]! {
                deltaMove -= scene.camera.right * stepSize
            }
            if keysActive[.RIGHT]! {
                deltaMove += scene.camera.right * stepSize
            }
            scene.camera.position += deltaMove

            if quit {
                exit(0)
            } else {
                DispatchQueue.main.async {
                    try! frame()
                }
            }
        }

        DispatchQueue.main.async {
            try! frame()
        }

        #if os(macOS)
        CFRunLoopRun()
        #else
        dispatchMain()
        #endif

        Platform.quit()
    }
}