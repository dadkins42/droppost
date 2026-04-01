import Foundation
import SwiftUI
import PhotosUI
import Photos
import CoreLocation
#if os(iOS)
import UIKit
#else
import AppKit
#endif

@MainActor
class ComposeViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var body: String = ""
    @Published var selectedPhotos: [PhotosPickerItem] = []
    @Published var loadedImages: [SelectedImage] = []
    @Published var youtubeURL: String = ""
    @Published var isPublishing = false
    @Published var publishSuccess = false
    @Published var errorMessage: String?
    @Published var publishProgress: String = ""

    private let locationManager = LocationHelper()

    struct SelectedImage: Identifiable {
        let id = UUID()
        let image: PlatformImage
        let data: Data
        let dateTaken: Date?
    }

    func loadImages() async {
        var newImages: [SelectedImage] = []
        for item in selectedPhotos {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = PlatformImage(data: data) {
                // Get date from PHAsset (most reliable) or EXIF fallback
                let dateTaken = Self.getDateFromPickerItem(item) ?? Self.extractDateFromImageData(data)
                // Resize to max 1200px wide for reasonable file size
                let resized = image.resizedToMaxWidth(1200)
                if let jpegData = resized.jpegDataCompressed(quality: 0.7) {
                    newImages.append(SelectedImage(image: resized, data: jpegData, dateTaken: dateTaken))
                }
            }
        }
        loadedImages = newImages
    }

    static func getDateFromPickerItem(_ item: PhotosPickerItem) -> Date? {
        guard let assetId = item.itemIdentifier else { return nil }
        // Request limited access if not already authorized
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            // Can't do async request here, so return nil and rely on EXIF
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in }
            return nil
        }
        guard status == .authorized || status == .limited else { return nil }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
        return assets.firstObject?.creationDate
    }

    static func extractDateFromImageData(_ data: Data) -> Date? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
              let dateStr = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: dateStr)
    }

    static func formatPhotoDate(_ date: Date?) -> String? {
        guard let date = date else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    func removeImage(at index: Int) {
        guard index < loadedImages.count else { return }
        loadedImages.remove(at: index)
        if index < selectedPhotos.count {
            selectedPhotos.remove(at: index)
        }
    }

    func publish(to blog: Blog, using service: GitHubService) async {
        guard !title.isEmpty else {
            errorMessage = "Please enter a title"
            return
        }
        guard !body.isEmpty else {
            errorMessage = "Please write something"
            return
        }

        isPublishing = true
        errorMessage = nil
        publishProgress = "Preparing post..."

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: Date())

        let titleSlug = title.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "'", with: "")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        let slug = "\(dateStr)-\(titleSlug)"

        // Prepare image data
        var imageFilenames: [String] = []
        var imageUploads: [(filename: String, data: Data)] = []
        for (index, img) in loadedImages.enumerated() {
            let filename = "\(slug)-img\(index + 1).jpg"
            imageFilenames.append(filename)
            imageUploads.append((filename: filename, data: img.data))
        }

        // Get location
        let location = locationManager.currentLocationString

        // Build excerpt
        let excerpt = String(body.prefix(150)) + (body.count > 150 ? "..." : "")

        // Collect videos
        var videos: [String] = []
        if !youtubeURL.isEmpty {
            videos.append(youtubeURL)
        }

        let post = Post(
            slug: slug,
            title: title,
            date: dateStr,
            excerpt: excerpt,
            content: body,
            location: location,
            images: imageFilenames,
            videos: videos
        )

        do {
            // Generate post HTML
            let postHTML = await service.generatePostHTML(post: post, blogSlug: blog.slug)

            // Publish everything in a single atomic commit
            try await service.atomicPublishPost(
                post,
                to: blog.slug,
                imageData: imageUploads,
                postHTML: postHTML,
                progressCallback: { @Sendable [weak self] progress in
                    Task { @MainActor in
                        self?.publishProgress = progress
                    }
                }
            )

            publishProgress = "Published!"
            publishSuccess = true
            isPublishing = false

            // Reset form
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.resetForm()
            }
        } catch {
            errorMessage = "Publish failed: \(error.localizedDescription)"
            isPublishing = false
            publishProgress = ""
        }
    }

    func resetForm() {
        title = ""
        body = ""
        selectedPhotos = []
        loadedImages = []
        youtubeURL = ""
        publishSuccess = false
        publishProgress = ""
        errorMessage = nil
    }

    private func resizeImage(_ image: PlatformImage, maxWidth: CGFloat) -> PlatformImage {
        return image.resizedToMaxWidth(maxWidth)
    }
}

// Simple location helper
class LocationHelper: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var currentLocationString: String?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            if let place = placemarks?.first {
                let parts = [place.locality, place.administrativeArea].compactMap { $0 }
                self?.currentLocationString = parts.joined(separator: ", ")
            }
        }
        manager.stopUpdatingLocation()
    }
}
