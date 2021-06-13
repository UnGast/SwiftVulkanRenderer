import Foundation
import GfxMath

public final class Camera {
    public var position: FVec3

    let worldUp: FVec3
    public var pitch: Float {
        didSet {
            updateDirections()
        }
    }
    public var yaw: Float {
        didSet {
            updateDirections()
        }
    }
    public private(set) var up: FVec3
    public private(set) var right: FVec3
    public private(set) var forward: FVec3

    public init(worldUp: FVec3 = FVec3(0, 1, 0)) {
        self.position = .zero

        self.worldUp = worldUp
        self.pitch = 0
        self.yaw = 0
        self.up = .zero
        self.right = .zero
        self.forward = .zero

        self.updateDirections()
    }

    private func updateDirections() {
        forward = FVec3(
            sin(yaw),
            sin(pitch),
            cos(pitch) + cos(yaw)
        ).normalized()

        right = worldUp.cross(forward)
        up = forward.cross(right)
    }
}