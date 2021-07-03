import Swim

public protocol Material: class {
}

public class Lambertian: Material {
    public var texture: Swim.Image<RGBA, UInt8>

    public init(texture: Swim.Image<RGBA, UInt8>) {
        self.texture = texture
    }
}

public class Dielectric: Material {
    public var refractiveIndex: Float

    public init(refractiveIndex: Float) {
        self.refractiveIndex = refractiveIndex
    }
}