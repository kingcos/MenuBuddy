import Foundation
import AppKit

// MARK: - Update Checker

/// Checks GitHub Releases for new versions and optionally downloads + installs updates.
/// Supports both stable releases and pre-release (beta) channels.
final class UpdateChecker {
    static let shared = UpdateChecker()

    private let owner = "kingcos"
    private let repo = "MenuBuddy"
    private let apiBase = "https://api.github.com"

    /// Current app version from bundle.
    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    // MARK: - Public API

    /// Check for updates. Calls completion on main thread with result.
    /// - Parameter includeBeta: if true, also checks pre-release versions
    func checkForUpdate(includeBeta: Bool, completion: @escaping (UpdateResult) -> Void) {
        let urlStr = "\(apiBase)/repos/\(owner)/\(repo)/releases"
        guard let url = URL(string: urlStr) else {
            completion(.error("Invalid URL"))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        logger.debug("Checking for updates (beta=\(includeBeta))...", source: "update")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            if let error {
                DispatchQueue.main.async { completion(.error(error.localizedDescription)) }
                return
            }

            guard let data,
                  let releases = try? JSONDecoder().decode([GitHubRelease].self, from: data) else {
                DispatchQueue.main.async { completion(.error("Failed to parse releases")) }
                return
            }

            // Filter: include pre-releases only if beta channel selected
            let candidates = releases.filter { !$0.draft && (includeBeta || !$0.prerelease) }

            guard let latest = candidates.first else {
                DispatchQueue.main.async { completion(.upToDate) }
                return
            }

            let latestVersion = latest.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))

            if self.isNewer(latestVersion, than: self.currentVersion) {
                let dmgAsset = latest.assets.first { $0.name.hasSuffix(".dmg") }
                let info = UpdateInfo(
                    version: latestVersion,
                    tagName: latest.tagName,
                    isPrerelease: latest.prerelease,
                    releaseNotes: latest.body ?? "",
                    htmlURL: latest.htmlUrl,
                    dmgDownloadURL: dmgAsset?.browserDownloadUrl
                )
                logger.info("Update available: \(latestVersion) (current: \(self.currentVersion))", source: "update")
                DispatchQueue.main.async { completion(.available(info)) }
            } else {
                logger.info("Up to date: \(self.currentVersion)", source: "update")
                DispatchQueue.main.async { completion(.upToDate) }
            }
        }.resume()
    }

    /// Download the DMG and open it for the user to install.
    func downloadAndInstall(info: UpdateInfo, progress: @escaping (Double) -> Void, completion: @escaping (Bool, String?) -> Void) {
        guard let urlStr = info.dmgDownloadURL, let url = URL(string: urlStr) else {
            completion(false, "No DMG asset found for this release")
            return
        }

        logger.info("Downloading update: \(url.lastPathComponent)", source: "update")

        let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            if let error {
                DispatchQueue.main.async { completion(false, error.localizedDescription) }
                return
            }

            guard let tempURL else {
                DispatchQueue.main.async { completion(false, "Download failed") }
                return
            }

            // Move to Downloads folder
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            let destURL = downloads.appendingPathComponent("MenuBuddy-\(info.version).dmg")

            do {
                // Remove existing file if present
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.moveItem(at: tempURL, to: destURL)
                logger.info("DMG saved to: \(destURL.path)", source: "update")

                DispatchQueue.main.async {
                    // Open the DMG
                    NSWorkspace.shared.open(destURL)
                    completion(true, nil)
                }
            } catch {
                DispatchQueue.main.async { completion(false, error.localizedDescription) }
            }
        }

        // Observe download progress
        let observation = task.progress.observe(\.fractionCompleted) { prog, _ in
            DispatchQueue.main.async { progress(prog.fractionCompleted) }
        }
        // Keep observation alive until task completes
        objc_setAssociatedObject(task, "progressObservation", observation, .OBJC_ASSOCIATION_RETAIN)

        task.resume()
    }

    // MARK: - Semantic Version Comparison

    /// Returns true if `a` is newer than `b` using semantic versioning.
    func isNewer(_ a: String, than b: String) -> Bool {
        let partsA = a.split(separator: ".").compactMap { Int($0) }
        let partsB = b.split(separator: ".").compactMap { Int($0) }
        let count = max(partsA.count, partsB.count)
        for i in 0..<count {
            let va = i < partsA.count ? partsA[i] : 0
            let vb = i < partsB.count ? partsB[i] : 0
            if va > vb { return true }
            if va < vb { return false }
        }
        return false
    }
}

// MARK: - Models

enum UpdateResult {
    case upToDate
    case available(UpdateInfo)
    case error(String)
}

struct UpdateInfo {
    let version: String
    let tagName: String
    let isPrerelease: Bool
    let releaseNotes: String
    let htmlURL: String
    let dmgDownloadURL: String?
}

// MARK: - GitHub API Models

struct GitHubRelease: Codable {
    let tagName: String
    let name: String?
    let body: String?
    let draft: Bool
    let prerelease: Bool
    let htmlUrl: String
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name, body, draft, prerelease
        case htmlUrl = "html_url"
        case assets
    }
}

struct GitHubAsset: Codable {
    let name: String
    let browserDownloadUrl: String
    let size: Int

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
}
