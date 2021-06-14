import HID
import Vulkan
import Swim
import GfxMath

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

    // strdup copies the string passed in and returns a pointer to copy; copy not managed by swift -> not deallocated
    var enabledLayerNames = [UnsafePointer<CChar>(strdup("VK_LAYER_KHRONOS_validation"))]

    var extNames = hidSurfaceExtensions.map { UnsafePointer<CChar>(strdup($0)) }

    var createInfo = VkInstanceCreateInfo(
        sType: VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        pNext: nil,
        flags: 0,
        pApplicationInfo: nil,
        enabledLayerCount: UInt32(enabledLayerNames.count),
        ppEnabledLayerNames: enabledLayerNames,
        enabledExtensionCount: UInt32(hidSurfaceExtensions.count),
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

let mainMaterial = Material(texture: Swim.Image(width: 1, height: 1, value: 1))

let scene = Scene()
scene.objects.append(SceneObject(mesh: Mesh.cuboid(material: mainMaterial), transformation: [[1]]))

var renderer: VulkanRenderer? = nil

var frameCount = 0

var keysActive: [KeyCode: Bool] = [
    .LEFT: false,
    .RIGHT: false,
    .UP: false,
    .DOWN: false
]

while !quit {
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
                renderer = try VulkanRenderer(scene: scene, instance: surface.instance, surface: surface.surface)
                try renderer?.sceneManager.updateSceneData()
            }

        case .pointerMotion:
            let eventData = event.pointerMotion

            scene.camera.pitch -= eventData.deltaY / 360
            scene.camera.pitch = min(89 / 360, max(-89 / 360, scene.camera.pitch))
            scene.camera.yaw += Float(eventData.deltaX) / 360
        
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

    /*
    renderer.raytracingRenderer.camera.forward = forwardDirection
        if let keyDown = $0 as? KeyDownEvent {
        let speed = Float(100)
        var move: FVec3 = .zero
        let forward = renderer.raytracingRenderer.camera.forward
        let right = renderer.raytracingRenderer.camera.right
        switch keyDown.key {
            case .arrowUp:
                move += forward * speed
            case .arrowDown:
                move -= forward * speed
            case .arrowLeft:
                move -= right * speed
            case .arrowRight:
                move += right * speed
            default: break
        }

        renderer.raytracingRenderer.camera.position += move
    } else if let mouseMove = $0 as? MouseMoveEvent {
        
    }*/
}

Platform.quit()