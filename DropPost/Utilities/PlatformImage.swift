import SwiftUI

#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#else
import AppKit
typealias PlatformImage = NSImage
#endif

extension PlatformImage {
    /// Resize image to max width, preserving aspect ratio
    func resizedToMaxWidth(_ maxWidth: CGFloat) -> PlatformImage {
        #if os(iOS)
        let size = self.size
        guard size.width > maxWidth else { return self }
        let scale = maxWidth / size.width
        let newSize = CGSize(width: maxWidth, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
        #else
        let size = self.size
        guard size.width > maxWidth else { return self }
        let scale = maxWidth / size.width
        let newSize = CGSize(width: maxWidth, height: size.height * scale)
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: newSize),
                  from: NSRect(origin: .zero, size: size),
                  operation: .copy,
                  fraction: 1.0)
        newImage.unlockFocus()
        return newImage
        #endif
    }

    /// Convert to JPEG data
    func jpegDataCompressed(quality: CGFloat) -> Data? {
        #if os(iOS)
        return self.jpegData(compressionQuality: quality)
        #else
        guard let tiffData = self.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
        #endif
    }
}

/// Cross-platform SwiftUI Image from PlatformImage
func platformImage(_ image: PlatformImage) -> Image {
    #if os(iOS)
    return Image(uiImage: image)
    #else
    return Image(nsImage: image)
    #endif
}
