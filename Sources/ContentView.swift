import SwiftUI
import ZIPFoundation

struct ContentView: View {
    @State private var chapters: [SutraChapter] = []
    @State private var loadError: String?
    @State private var currentChapterID: Int?

    var body: some View {
        Group {
            if let loadError {
                Text(loadError)
                    .foregroundStyle(.red)
                    .padding()
            } else if chapters.isEmpty {
                ProgressView()
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(chapters) { chapter in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(chapter.title)
                                    .font(.headline)
                                    .bold()

                                ScrollView {
                                    Text(chapter.body)
                                        .font(.body)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding()
                            .frame(maxHeight: .infinity, alignment: .top)
                            .containerRelativeFrame(.horizontal)
                            .id(chapter.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $currentChapterID)
            }
        }
        .task {
            await loadChaptersFromEPUB()
        }
    }

    @MainActor
    private func loadChaptersFromEPUB() async {
        do {
            chapters = try EpubReader.extractChapters(from: "金剛經", fileExtension: "epub")
            currentChapterID = chapters.first?.id
            loadError = nil
        } catch {
            chapters = []
            currentChapterID = nil
            loadError = "EPUB 解析失敗：\(error.localizedDescription)"
        }
    }
}

struct SutraChapter: Identifiable {
    let id: Int
    let title: String
    let body: String
}

enum EpubReader {
    static func extractChapters(from resourceName: String, fileExtension: String) throws -> [SutraChapter] {
        guard let epubURL = Bundle.main.url(forResource: resourceName, withExtension: fileExtension) else {
            throw NSError(domain: "EpubReader", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bundle 中找不到 \(resourceName).\(fileExtension)"])
        }

        guard let archive = Archive(url: epubURL, accessMode: .read) else {
            throw NSError(domain: "EpubReader", code: 2, userInfo: [NSLocalizedDescriptionKey: "無法開啟 EPUB 壓縮檔"])
        }

        let chapterEntries = archive
            .filter { $0.path.hasPrefix("OEBPS/chap") && $0.path.hasSuffix(".xhtml") }
            .sorted { $0.path < $1.path }

        var chapters: [SutraChapter] = []
        for (index, entry) in chapterEntries.enumerated() {
            let xhtml = try readEntryString(entry, from: archive)
            let title = chapterTitle(in: xhtml) ?? "第 \(index + 1) 章"
            let body = chapterBody(in: xhtml)
            if !body.isEmpty {
                chapters.append(SutraChapter(id: index, title: title, body: body))
            }
        }

        if chapters.isEmpty {
            throw NSError(domain: "EpubReader", code: 3, userInfo: [NSLocalizedDescriptionKey: "EPUB 章節中未找到可顯示內容"])
        }
        return chapters
    }

    private static func readEntryString(_ entry: Entry, from archive: Archive) throws -> String {
        var data = Data()
        _ = try archive.extract(entry) { chunk in
            data.append(chunk)
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func chapterTitle(in xhtml: String) -> String? {
        let pattern = "<h[1-3][^>]*>(.*?)</h[1-3]>"
        guard let raw = firstMatch(in: xhtml, pattern: pattern) else { return nil }
        return cleanHTMLText(raw)
    }

    private static func chapterBody(in xhtml: String) -> String {
        let pattern = "<p[^>]*>(.*?)</p>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else {
            return ""
        }
        let nsRange = NSRange(xhtml.startIndex..<xhtml.endIndex, in: xhtml)
        let matches = regex.matches(in: xhtml, options: [], range: nsRange)
        let paragraphs = matches.compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: xhtml) else { return nil }
            let cleaned = cleanHTMLText(String(xhtml[range]))
            return cleaned.isEmpty ? nil : cleaned
        }
        return paragraphs.joined(separator: "\n\n")
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard
            let match = regex.firstMatch(in: text, options: [], range: range),
            let paragraphRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return String(text[paragraphRange])
    }

    private static func cleanHTMLText(_ raw: String) -> String {
        let noTags = raw.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let cleaned = noTags
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned
    }
}

#Preview {
    ContentView()
}
