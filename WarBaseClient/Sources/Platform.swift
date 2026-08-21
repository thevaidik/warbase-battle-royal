import Foundation

#if canImport(UIKit)
import UIKit
import SwiftUI
public typealias PlatformColor = UIColor
public typealias PlatformImage = UIImage
public typealias PlatformViewRepresentable = UIViewRepresentable
#elseif canImport(AppKit)
import AppKit
import SwiftUI
public typealias PlatformColor = NSColor
public typealias PlatformImage = NSImage
public typealias PlatformViewRepresentable = NSViewRepresentable
#endif
public typealias PlatformFloat = Float
