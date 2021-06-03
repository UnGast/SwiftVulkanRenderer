import HID
import Vulkan

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

let renderer = try VulkanRenderer(instance: surface.instance, surface: surface.surface)

while !quit {
    Events.pumpEvents()

    while Events.pollEvent(&event) {
        switch event.variant {
        case .userQuit:
            quit = true

        default:
            break
        }
    }
}

Platform.quit()