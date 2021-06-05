import Foundation
import GfxMath

public final class Camera {
    public var frameCount: UInt32
    public var position: FVec3
    public var up: FVec3
    public var right: FVec3
    public var forward: FVec3 {
        didSet {
            updateDirections()
        }
    }

    public init(frameCount: UInt32, position: FVec3, direction: FVec3) {
        self.frameCount = frameCount
        self.position = position
        self.forward = direction
        self.up = .zero
        self.right = .zero
        self.updateDirections()
    }

    private func updateDirections() {
        self.right = FVec3(0, 1, 0).cross(forward)
        self.up = forward.cross(right)
    }

    public static var serializationMeasureInstance: Camera {
        Camera(frameCount: 0, position: .zero, direction: .zero)
    }
}