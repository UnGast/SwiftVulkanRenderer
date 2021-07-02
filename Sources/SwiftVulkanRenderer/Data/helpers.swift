func toMultipleOf16(_ x: Int) -> Int {
    let residual = x % 16
    if residual == 0 { return x }
    else {
        return x - residual + 16
    }
}