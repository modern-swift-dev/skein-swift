/// Wraps a type-erased provider value for unchecked isolation transfer.
package struct UncheckedProviderValue: @unchecked Sendable {
    /// The wrapped provider value.
    package let value: Any
}
