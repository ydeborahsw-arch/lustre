import Foundation
import Capacitor
import UIKit
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

@objc(PickerPlugin)
public class PickerPlugin: CAPPlugin, CAPBridgedPlugin,
                           PHPickerViewControllerDelegate,
                           UIImagePickerControllerDelegate, UINavigationControllerDelegate,
                           UIDocumentPickerDelegate {
    public let identifier = "PickerPlugin"
    public let jsName = "Picker"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "pickPhotos", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "takePhoto", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "pickFiles", returnType: CAPPluginReturnPromise)
    ]

    var pending: CAPPluginCall?
    var wantOriginal = false
    let maxSide: CGFloat = 2048
    let maxBytes = 10 * 1024 * 1024

    static weak var live: PickerPlugin?
    var nativeDone: (([[String: Any]]) -> Void)?

    override public func load() { Self.live = self }

    func finish(_ files: [[String: Any]]) {
        if let done = nativeDone {
            nativeDone = nil
            DispatchQueue.main.async { done(files) }
            return
        }
        let call = pending
        pending = nil
        call?.resolve(["files": files])
    }

    static func pickNative(_ id: String, original: Bool, done: @escaping ([[String: Any]]) -> Void) {
        guard let s = live else { done([]); return }
        s.nativeDone = done
        s.wantOriginal = original
        switch id {
        case "addCamera":
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else { s.finish([]); return }
            s.onMain {
                let vc = UIImagePickerController()
                vc.sourceType = .camera
                vc.delegate = s
                return vc
            }
        case "addFiles":
            s.onMain {
                let vc = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.item], asCopy: true)
                vc.allowsMultipleSelection = true
                vc.delegate = s
                return vc
            }
        default:
            s.onMain {
                var cfg = PHPickerConfiguration()
                cfg.filter = .any(of: [.images, .videos])
                cfg.selectionLimit = 9
                let vc = PHPickerViewController(configuration: cfg)
                vc.delegate = s
                return vc
            }
        }
    }

    func onMain(_ build: @escaping () -> UIViewController?) {
        DispatchQueue.main.async {
            guard let vc = build() else { return }
            self.bridge?.viewController?.present(vc, animated: true)
        }
    }

    func encode(_ image: UIImage, name: String, original: Bool = false) -> [String: Any]? {
        var img = image
        let w = img.size.width, h = img.size.height
        if !original, w > maxSide || h > maxSide {
            let r = min(maxSide / w, maxSide / h)
            let size = CGSize(width: (w * r).rounded(), height: (h * r).rounded())
            let fmt = UIGraphicsImageRendererFormat.default()
            fmt.scale = 1
            img = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
        }
        var data = img.jpegData(compressionQuality: original ? 1.0 : 0.9)
        if original, let d = data, d.count > maxBytes { data = img.jpegData(compressionQuality: 0.9) }
        guard let data else { return nil }
        return [
            "name": name.hasSuffix(".jpg") ? name : (name as NSString).deletingPathExtension + ".jpg",
            "mime": "image/jpeg",
            "kind": "image",
            "width": Int(img.size.width),
            "height": Int(img.size.height),
            "data": data.base64EncodedString()
        ]
    }

    func encodeVideo(_ url: URL, name: String, done: @escaping ([String: Any]?) -> Void) {
        let base = (name as NSString).deletingPathExtension
        func pack(_ d: Data, _ ext: String, _ mime: String) -> [String: Any] {
            ["name": base.isEmpty ? "video.\(ext)" : "\(base).\(ext)", "mime": mime,
             "kind": "video", "width": 0, "height": 0, "data": d.base64EncodedString()]
        }
        // 0925:录屏这类视频原样传动辄好几 MB,网络一慢就传不完被掐。超过 3MB 先在手机上压成 720p 再发,
        // 压完反而更大/压失败就用原文件(原文件也超 10MB 时退到中等画质)
        let orig = try? Data(contentsOf: url)
        let ext0 = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
        func original() -> [String: Any]? {
            guard let d = orig, d.count <= self.maxBytes else { return nil }
            return pack(d, ext0, ext0.lowercased() == "mov" ? "video/quicktime" : "video/mp4")
        }
        if let d = orig, d.count <= 3 * 1024 * 1024 { done(original()); return }
        func export(_ preset: String, _ next: @escaping () -> Void) {
            let asset = AVURLAsset(url: url)
            guard let ex = AVAssetExportSession(asset: asset, presetName: preset) else { next(); return }
            let out = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
            ex.outputURL = out
            ex.outputFileType = .mp4
            ex.shouldOptimizeForNetworkUse = true
            ex.exportAsynchronously {
                defer { try? FileManager.default.removeItem(at: out) }
                if ex.status == .completed, let d = try? Data(contentsOf: out), d.count <= self.maxBytes,
                   d.count < (orig?.count ?? Int.max) {
                    done(pack(d, "mp4", "video/mp4"))
                } else { next() }
            }
        }
        export(AVAssetExportPreset1280x720) {
            if let o = original() { done(o); return }
            export(AVAssetExportPresetMediumQuality) { done(nil) }
        }
    }

    func loadOriginal(_ provider: NSItemProvider, name: String, done: @escaping ([String: Any]?) -> Void) {
        let types = provider.registeredTypeIdentifiers.filter { UTType($0)?.conforms(to: .image) == true }
        let pick = types.first(where: { $0 == UTType.png.identifier })
            ?? types.first(where: { $0 == UTType.jpeg.identifier })
            ?? types.first
        guard let uti = pick else { done(nil); return }
        provider.loadDataRepresentation(forTypeIdentifier: uti) { data, _ in
            guard let d = data, d.count <= self.maxBytes else { done(nil); return }
            let ut = UTType(uti)
            let ext = ut?.preferredFilenameExtension ?? "img"
            let base = (name as NSString).deletingPathExtension
            let img = UIImage(data: d)
            done([
                "name": base.isEmpty ? "image.\(ext)" : "\(base).\(ext)",
                "mime": ut?.preferredMIMEType ?? "application/octet-stream",
                "kind": "image",
                "width": Int(img?.size.width ?? 0),
                "height": Int(img?.size.height ?? 0),
                "data": d.base64EncodedString()
            ])
        }
    }

    @objc func pickPhotos(_ call: CAPPluginCall) {
        pending = call
        wantOriginal = call.getBool("original") ?? false
        let limit = call.getInt("limit") ?? 9
        onMain {
            var cfg = PHPickerConfiguration()
            cfg.filter = .any(of: [.images, .videos])
            cfg.selectionLimit = limit
            let vc = PHPickerViewController(configuration: cfg)
            vc.delegate = self
            return vc
        }
    }

    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard !results.isEmpty else { finish([]); return }
        var out = [[String: Any]?](repeating: nil, count: results.count)
        let group = DispatchGroup()
        let original = wantOriginal
        for (i, r) in results.enumerated() {
            group.enter()
            let name = r.itemProvider.suggestedName ?? "image"
            if r.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                r.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
                    guard let url else { group.leave(); return }
                    let copy = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)
                    try? FileManager.default.copyItem(at: url, to: copy)
                    self.encodeVideo(copy, name: name) { f in
                        try? FileManager.default.removeItem(at: copy)
                        out[i] = f
                        group.leave()
                    }
                }
            } else if original {
                loadOriginal(r.itemProvider, name: name) { f in
                    if let f = f { out[i] = f; group.leave(); return }
                    r.itemProvider.loadObject(ofClass: UIImage.self) { obj, _ in
                        if let img = obj as? UIImage { out[i] = self.encode(img, name: name) }
                        group.leave()
                    }
                }
            } else {
                r.itemProvider.loadObject(ofClass: UIImage.self) { obj, _ in
                    if let img = obj as? UIImage { out[i] = self.encode(img, name: name) }
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) { self.finish(out.compactMap { $0 }) }
    }

    @objc func takePhoto(_ call: CAPPluginCall) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            call.resolve(["files": [], "error": "no camera"]); return
        }
        pending = call
        wantOriginal = call.getBool("original") ?? false
        onMain {
            let vc = UIImagePickerController()
            vc.sourceType = .camera
            vc.delegate = self
            return vc
        }
    }

    public func imagePickerController(_ picker: UIImagePickerController,
                                      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        if let img = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage),
           let f = encode(img, name: "photo", original: wantOriginal) {
            finish([f])
        } else {
            finish([])
        }
    }

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        finish([])
    }

    @objc func pickFiles(_ call: CAPPluginCall) {
        pending = call
        onMain {
            let vc = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.item], asCopy: true)
            vc.allowsMultipleSelection = true
            vc.delegate = self
            return vc
        }
    }

    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        var out: [[String: Any]] = []
        for url in urls {
            guard let data = try? Data(contentsOf: url), data.count <= maxBytes else { continue }
            let name = url.lastPathComponent
            let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            out.append([
                "name": name,
                "mime": mime,
                "kind": mime.hasPrefix("image/") ? "image" : "file",
                "width": 0, "height": 0,
                "data": data.base64EncodedString()
            ])
        }
        finish(out)
    }

    public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        finish([])
    }
}
