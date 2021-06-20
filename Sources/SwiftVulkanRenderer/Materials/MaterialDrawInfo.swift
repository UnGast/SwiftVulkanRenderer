public struct MaterialDrawInfo: BufferSerializableStruct {
    public var textureIndex: UInt32

    public init(textureIndex: UInt32) {
        self.textureIndex = textureIndex
    }

    public static var serializationMeasureInstance: MaterialDrawInfo {
        MaterialDrawInfo(textureIndex: 0)
    }
}