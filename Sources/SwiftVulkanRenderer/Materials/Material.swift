import Swim

public class Material: Hashable {
    public var texture: Swim.Image<RGBA, UInt8>

    public init(texture: Swim.Image<RGBA, UInt8>) {
        self.texture = texture
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    public static func == (lhs: Material, rhs: Material) -> Bool {
        lhs === rhs
    }
}