import Foundation

#if canImport(UIKit)
import UIKit
public typealias PlatformColor = UIColor
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
public typealias PlatformColor = NSColor
public typealias PlatformImage = NSImage
#endif
