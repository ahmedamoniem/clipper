import AppKit

struct ImageProcessor {
    static func generateThumbnail(from imageData: Data, maxSize: CGFloat = 200) -> Data? {
        guard let image = NSImage(data: imageData) else { return nil }
        
        let size = image.size
        let aspectRatio = size.width / size.height
        let thumbnailSize: NSSize
        
        if aspectRatio > 1 {
            thumbnailSize = NSSize(width: maxSize, height: maxSize / aspectRatio)
        } else {
            thumbnailSize = NSSize(width: maxSize * aspectRatio, height: maxSize)
        }
        
        let thumbnail = NSImage(size: thumbnailSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: thumbnailSize),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy,
                   fraction: 1.0)
        thumbnail.unlockFocus()
        
        guard let tiffData = thumbnail.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else { return nil }
        
        return bitmapImage.representation(using: .png, properties: [:])
    }
    
    static func imageDimensions(from data: Data) -> NSSize? {
        guard let image = NSImage(data: data) else { return nil }
        return image.size
    }
}
