import Foundation

/// Downloads a Text-Fabric corpus from a GitHub tree URL to a local directory.
/// Skips the download when .tf files are already present, so subsequent test
/// runs incur no network overhead.
enum TestCorpusLoader {
    static func ensureDownloaded(from githubTreeURL: String, to localPath: String) async throws {
        let fm = FileManager.default
        if let contents = try? fm.contentsOfDirectory(atPath: localPath),
           contents.contains(where: { $0.hasSuffix(".tf") }) {
            return
        }
        guard let apiURL = contentsAPIURL(from: githubTreeURL) else {
            throw CorpusLoaderError.invalidURL(githubTreeURL)
        }
        var req = URLRequest(url: apiURL)
        req.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        let (listing, _) = try await URLSession.shared.data(for: req)
        let items = try JSONDecoder().decode([GitHubItem].self, from: listing)
        try fm.createDirectory(atPath: localPath, withIntermediateDirectories: true)
        for item in items where item.name.hasSuffix(".tf") {
            guard let rawURL = URL(string: item.downloadURL) else { continue }
            let (fileData, _) = try await URLSession.shared.data(from: rawURL)
            let dest = URL(fileURLWithPath: localPath).appendingPathComponent(item.name)
            try fileData.write(to: dest)
        }
    }

    private static func contentsAPIURL(from treeURL: String) -> URL? {
        // https://github.com/{owner}/{repo}/tree/{ref}/{path...}
        guard let url = URL(string: treeURL), url.host == "github.com" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 4, parts[2] == "tree" else { return nil }
        let owner = parts[0], repo = parts[1], ref = parts[3]
        let path = parts.dropFirst(4).joined(separator: "/")
        return URL(string: "https://api.github.com/repos/\(owner)/\(repo)/contents/\(path)?ref=\(ref)")
    }
}

private struct GitHubItem: Decodable {
    let name: String
    let downloadURL: String
    enum CodingKeys: String, CodingKey {
        case name
        case downloadURL = "download_url"
    }
}

enum CorpusLoaderError: Error {
    case invalidURL(String)
}
