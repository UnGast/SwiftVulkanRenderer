public struct MaterialDrawInfo: BufferSerializableStruct {
    public var textureIndex: UInt32
    public var refractiveIndex: Float

    public init(textureIndex: UInt32, refractiveIndex: Float) {
        self.textureIndex = textureIndex
        self.refractiveIndex = refractiveIndex
    }

    public static var serializationMeasureInstance: MaterialDrawInfo {
        MaterialDrawInfo(textureIndex: 0, refractiveIndex: 0)
    }
}