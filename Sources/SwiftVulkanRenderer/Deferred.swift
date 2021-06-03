@propertyWrapper
public class Deferred<T> {
  var value: T? = nil

  public var wrappedValue: T {
    get { value! }
    set { value = newValue }
  }

  public var projectedValue: Deferred<T> {
    self
  } 

  public init() {}
}

