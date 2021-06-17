import Foundation
import GfxMath



public protocol BufferSerializable {
    static var serializedBaseAlignment: Int { get }
    static var serializedSize: Int { get }

    func serialize(into buffer: UnsafeMutableRawPointer, offset: Int)
}

extension FVec3: BufferSerializable {
    public static var serializedBaseAlignment: Int {
        MemoryLayout<Float>.size
    }

    public static var serializedSize: Int { serializedBaseAlignment * 4 }

    @inlinable public func serialize(into buffer: UnsafeMutableRawPointer, offset: Int) {
        let tup = (self[0], self[1], self[2])
        buffer.storeBytes(of: tup, toByteOffset: offset, as: type(of: tup))
    }
}
extension FVec2: BufferSerializable {
    public static var serializedBaseAlignment: Int {
        MemoryLayout<Float>.size
    }

    public static var serializedSize: Int { serializedBaseAlignment * 2 }

    @inlinable public func serialize(into buffer: UnsafeMutableRawPointer, offset: Int) {
        let tup = (self[0], self[1])
        buffer.storeBytes(of: tup, toByteOffset: offset, as: type(of: tup))
    }
}
extension FpRGBColor: BufferSerializable {
    public static var serializedBaseAlignment: Int {
        MemoryLayout<D>.size
    }

    public static var serializedSize: Int { serializedBaseAlignment * 3 }

    @inlinable public func serialize(into buffer: UnsafeMutableRawPointer, offset: Int) {
        let tup = (r, g, b)
        buffer.storeBytes(of: tup, toByteOffset: offset, as: type(of: tup))
    }
}
extension Matrix4: BufferSerializable {
    public static var serializedBaseAlignment: Int {
        MemoryLayout<Element>.size
    }

    public static var serializedSize: Int { serializedBaseAlignment * 16 }

    @inlinable public func serialize(into buffer: UnsafeMutableRawPointer, offset: Int) {
        buffer.advanced(by: offset).copyMemory(from: transposed.elements, byteCount: Self.serializedSize)
    }
}

fileprivate protocol BufferSerializablePrimitiveScalar: BufferSerializable {}
extension BufferSerializablePrimitiveScalar {
    public static var serializedBaseAlignment: Int {
        MemoryLayout<Self>.size
    }

    public static var serializedSize: Int { serializedBaseAlignment }

    @inlinable public func serialize(into buffer: UnsafeMutableRawPointer, offset: Int) {
        buffer.advanced(by: offset).copyMemory(from: [self], byteCount: Self.serializedSize)
    }
}

extension UInt32: BufferSerializablePrimitiveScalar {}
extension Float: BufferSerializablePrimitiveScalar {}



public protocol AnySerialize {
    var anySerializableValue: BufferSerializable { get }
    var anySerializableType: BufferSerializable.Type { get }
}

@propertyWrapper
public class Serialize<T: BufferSerializable>: AnySerialize {
    public var wrappedValue: T
    public var anySerializableValue: BufferSerializable {
        wrappedValue
    }
    public var anySerializableType: BufferSerializable.Type {
        T.self
    }

    public init(wrappedValue: T) {
        self.wrappedValue = wrappedValue
    }
}



public protocol BufferSerializableStruct: BufferSerializable {
    static var serializationMeasureInstance: Self { get }
}

extension BufferSerializableStruct {
    public static var serializedBaseAlignment: Int {
        let largestMemberSize = serializableMembers(in: serializationMeasureInstance).reduce(0) {
            if $0 > type(of: $1).serializedSize { return $0 }
            else { return type(of: $1).serializedSize }
        }
        return toMultipleOf16(largestMemberSize)
    }

    public static var serializedSize: Int {
        serializableMembers(in: serializationMeasureInstance).count * serializedBaseAlignment
    }

    @usableFromInline static func serializableMembers(in instance: Self) -> [BufferSerializable] {
        let mirror = Mirror(reflecting: instance)
        var members = [BufferSerializable]()
        for child in mirror.children {
            if let value = child.value as? BufferSerializable {
                members.append(value)
            }
        }

        return members
    }

    @inlinable public func serialize(into buffer: UnsafeMutableRawPointer, offset: Int) {
        let baseAlignment = Self.serializedBaseAlignment
        var currentOffset = offset
        for member in Self.serializableMembers(in: self) {
            member.serialize(into: buffer, offset: currentOffset)
            currentOffset += type(of: member).serializedSize
        }
    }
}
/*
extension Array where Element: BufferSerializable {
    public var serializedBaseAlignment: Int {
        toMultipleOf16(Element.serializedSize)
    }

    public var serializedSize: Int {
        serializedBaseAlignment * count
    }

    @inlinable public func serialize(into buffer: UnsafeMutableRawPointer, offset: Int) {
        let baseAlignment = serializedBaseAlignment
        var currentOffset = offset
        for item in self {
            item.serialize(into: buffer, offset: currentOffset)
            currentOffset += baseAlignment
        }
    }
}*/

fileprivate func toMultipleOf16(_ x: Int) -> Int {
    let residual = x % 16
    if residual == 0 { return x }
    else {
        return x - residual + 16
    }
}