public struct MaterialDrawInfo: BufferSerializableStruct {
    public var type: UInt32
    public var textureIndex: UInt32
    public var refractiveIndex: Float

    public init(type: UInt32, textureIndex: UInt32, refractiveIndex: Float) {
        self.type = type
        self.textureIndex = textureIndex
        self.refractiveIndex = refractiveIndex
    }

    public static var serializationMeasureInstance: MaterialDrawInfo {
        MaterialDrawInfo(type: 0, textureIndex: 0, refractiveIndex: 0)
    }
}