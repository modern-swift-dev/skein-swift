#if os(macOS) || os(Linux)
import Skein

enum SpecialQualifier: String, SkeinQualifier {
    case value
}
#endif
