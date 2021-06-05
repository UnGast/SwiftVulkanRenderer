import Foundation
import GfxMath
import Vulkan

public struct Vertex {
  public var position: FVec3
  //public var normal: FVec3
  //public var color: Color
  public var texCoords: FVec2

  public init(position: FVec3, texCoords: FVec2/*, normal: FVec3 = .zero, color: Color = .white, texCoord: FVec2 = .zero*/) {
    self.position = position
    self.texCoords = texCoords
    /*self.normal = normal
    self.color = color
    self.texCoord = texCoord*/
  }

  public static var serializationMeasureInstance: Vertex {
    Self(position: .zero, texCoords: .zero)
  }

  /*public func serializedData(aligned: Bool) -> Data {
    var alignment: Int = 1
    if aligned {
      alignment = getAlignment()
    }

    var result = Data(count: serializedSize(aligned: aligned))
    serialize(into: &result, offset: 0, alignment: alignment)
    return result
  }

  public func serialize(into data: inout Data, offset: Int, alignment: Int) {
    var serializeWrappers = getSerializeWrappers()

    var nextStartIndex = offset

    _position.withSerialized {
      data.replaceSubrange(offset..<(offset + MemoryLayout<Float>.size * 3), with: $0)
    }

    _texCoord.withSerialized {
      let start = offset + MemoryLayout<Float>.size * 3
      data.replaceSubrange(start..<(start + MemoryLayout<Float>.size * 2), with: $0)
    }

    /*for (index, wrapper) in serializeWrappers.enumerated() {
      wrapper.withSerialized {
        let startIndex = nextStartIndex
        let endIndex = nextStartIndex + $0.count
        data.replaceSubrange(startIndex..<endIndex, with: $0)
        nextStartIndex = startIndex + $0.count//MemoryLayout<Float>.size * 4//Int(ceil(Double($0.count) / Double(alignment))) * alignment
      }
    }*/
  }

  public func serializedSize(aligned: Bool) -> Int {
    let alignment = aligned ? getAlignment() : 1
    var size = 0
    for wrapper in getSerializeWrappers() {
      size += Int(ceil(Double(wrapper.byteCount) / Double(alignment))) * alignment
    }
    return size
  }

 public func getAlignment() -> Int {
    16
  }
/*
  public var serializedData: [Float] {
    position.elements/* + normal.elements + [
      Float(color.r) / 255,
      Float(color.g) / 255,
      Float(color.b) / 255,
      Float(color.a) / 255
    ] + texCoord.elements*/
  }

  public static var inputBindingDescription: VertexInputBindingDescription {
    VertexInputBindingDescription(
      binding: 0,
      stride: UInt32(MemoryLayout<Float>.size * 12),
      inputRate: .vertex
    )
  }

  public static var inputAttributeDescriptions: [VertexInputAttributeDescription] {
    [
      VertexInputAttributeDescription(
        location: 0,
        binding: 0,
        format: .R32G32B32_SFLOAT,
        offset: 0
      ),
      VertexInputAttributeDescription(
        location: 1,
        binding: 0,
        format: .R32G32B32_SFLOAT,
        offset: UInt32(MemoryLayout<Float>.size * 3)
      ),
      VertexInputAttributeDescription(
        location: 2,
        binding: 0,
        format: .R32G32B32A32_SFLOAT,
        offset: UInt32(MemoryLayout<Float>.size * 6)
      ),
      VertexInputAttributeDescription(
        location: 3,
        binding: 0,
        format: .R32G32_SFLOAT,
        offset: UInt32(MemoryLayout<Float>.size * 10)
      )
    ]
  }*/*/
}
/*
public struct Position2 {
  public var x: Float
  public var y: Float
}

public struct Position3 {
  public var x: Float
  public var y: Float
  public var z: Float
}

public struct Color {
  public var r: Float
  public var g: Float
  public var b: Float
}*/
/*
extension Array where Element == Vertex {
  public func serialize(into data: inout Data, offset: Int, alignment: Int) {
    if count == 0 {
      return
    }

    let itemAlignment = self[0].getAlignment()
    for (index, item) in self.enumerated() {
      item.serialize(into: &data, offset: offset + alignment * index, alignment: MemoryLayout<Float>.size * 4)
    }
  }

  public func serializedData(aligned: Bool) -> Data {
    var result = Data(count: serializedSize(aligned: aligned))
    if count > 0 {
      serialize(into: &result, offset: 0, alignment: MemoryLayout<Float>.size * 5)
    }
    return result
  }

  public func getAlignment() -> Int {
    self[0].serializedSize(aligned: true)
  }

  public func serializedSize(aligned: Bool) -> Int {
    if count == 0 {
      return 0
    } else {
      if aligned {
        return count * MemoryLayout<Float>.size * 5
      } else {
        return count * self[0].serializedSize(aligned: aligned)
      }
    }
  }
}*/