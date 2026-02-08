import SwiftUI
import UIKit
import ZIPFoundation

private let readerTopColor = Color(red: 0.99, green: 0.96, blue: 0.90)
private let readerBottomColor = Color(red: 0.97, green: 0.93, blue: 0.84)
private let readerBackground = LinearGradient(
    colors: [readerTopColor, readerBottomColor],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

struct ContentView: View {
    @State private var chapters: [SutraChapter] = []
    @State private var pages: [SutraPage] = []
    @State private var loadError: String?
    @State private var currentPageIndex: Int = 0

    var body: some View {
        Group {
            if let loadError {
                Text(loadError)
                    .foregroundStyle(.red)
                    .padding()
            } else if chapters.isEmpty {
                ProgressView()
            } else {
                VStack(spacing: 0) {
                    PageCurlReaderView(pages: pages, currentPageIndex: $currentPageIndex)
                        .background(readerBackground)

                    Text(progressText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(readerBackground)
                .ignoresSafeArea()
            }
        }
        .task {
            await loadChaptersFromEPUB()
        }
    }

    private var progressText: String {
        guard !pages.isEmpty else { return "" }
        return "第 \(currentPageIndex + 1) / \(pages.count) 頁"
    }

    @MainActor
    private func loadChaptersFromEPUB() async {
        do {
            chapters = try EpubReader.extractChapters(from: "金剛經", fileExtension: "epub")
            pages = paginate(chapters: chapters)
            currentPageIndex = 0
            loadError = nil
        } catch {
            chapters = []
            pages = []
            currentPageIndex = 0
            loadError = "EPUB 解析失敗：\(error.localizedDescription)"
        }
    }

    private func paginate(chapters: [SutraChapter]) -> [SutraPage] {
        let maxCharactersPerPage = 700
        var builtPages: [SutraPage] = []
        var pageIndex = 0

        for chapter in chapters {
            let paragraphs = chapter.body
                .components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            var currentChunk = ""
            for paragraph in paragraphs {
                let separator = currentChunk.isEmpty ? "" : "\n\n"
                let candidate = currentChunk + separator + paragraph
                if candidate.count <= maxCharactersPerPage {
                    currentChunk = candidate
                } else {
                    if !currentChunk.isEmpty {
                        builtPages.append(
                            SutraPage(
                                id: pageIndex,
                                chapterTitle: chapter.title,
                                body: currentChunk
                            )
                        )
                        pageIndex += 1
                    }
                    currentChunk = paragraph
                }
            }

            if !currentChunk.isEmpty {
                builtPages.append(
                    SutraPage(
                        id: pageIndex,
                        chapterTitle: chapter.title,
                        body: currentChunk
                    )
                )
                pageIndex += 1
            }
        }

        if builtPages.isEmpty {
            builtPages = chapters.enumerated().map { index, chapter in
                SutraPage(id: index, chapterTitle: chapter.title, body: chapter.body)
            }
        }

        return builtPages
    }
}

struct SutraChapter: Identifiable {
    let id: Int
    let title: String
    let body: String
}

struct SutraPage: Identifiable, Equatable {
    let id: Int
    let chapterTitle: String
    let body: String
}

struct PageCurlReaderView: UIViewControllerRepresentable {
    let pages: [SutraPage]
    @Binding var currentPageIndex: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageVC = UIPageViewController(
            transitionStyle: .pageCurl,
            navigationOrientation: .horizontal
        )
        pageVC.view.backgroundColor = UIColor(
            red: 0.99,
            green: 0.96,
            blue: 0.90,
            alpha: 1
        )
        pageVC.dataSource = context.coordinator
        pageVC.delegate = context.coordinator
        context.coordinator.reloadControllers(with: pages)

        if let first = context.coordinator.controller(at: currentPageIndex) {
            pageVC.setViewControllers([first], direction: .forward, animated: false)
        }
        return pageVC
    }

    func updateUIViewController(_ uiViewController: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        context.coordinator.reloadControllers(with: pages)

        guard let visible = uiViewController.viewControllers?.first as? PageHostingController else {
            if let first = context.coordinator.controller(at: currentPageIndex) {
                uiViewController.setViewControllers([first], direction: .forward, animated: false)
            }
            return
        }

        guard visible.pageIndex != currentPageIndex else { return }
        let direction: UIPageViewController.NavigationDirection = currentPageIndex > visible.pageIndex ? .forward : .reverse
        if let target = context.coordinator.controller(at: currentPageIndex) {
            uiViewController.setViewControllers([target], direction: direction, animated: true)
        }
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: PageCurlReaderView
        private var controllers: [PageHostingController] = []
        private var snapshotKey: String = ""

        init(_ parent: PageCurlReaderView) {
            self.parent = parent
        }

        func reloadControllers(with pages: [SutraPage]) {
            let newKey = pages.map { "\($0.id)|\($0.chapterTitle)|\($0.body.count)" }.joined(separator: "#")
            guard newKey != snapshotKey else { return }
            snapshotKey = newKey
            controllers = pages.map { PageHostingController(page: $0) }
        }

        func controller(at index: Int) -> PageHostingController? {
            guard controllers.indices.contains(index) else { return nil }
            return controllers[index]
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            guard
                let vc = viewController as? PageHostingController,
                vc.pageIndex > 0
            else {
                return nil
            }
            return controllers[vc.pageIndex - 1]
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard
                let vc = viewController as? PageHostingController,
                vc.pageIndex + 1 < controllers.count
            else {
                return nil
            }
            return controllers[vc.pageIndex + 1]
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            guard
                completed,
                let current = pageViewController.viewControllers?.first as? PageHostingController
            else {
                return
            }
            parent.currentPageIndex = current.pageIndex
        }
    }
}

final class PageHostingController: UIHostingController<SutraPageContentView> {
    let pageIndex: Int

    init(page: SutraPage) {
        self.pageIndex = page.id
        super.init(rootView: SutraPageContentView(page: page))
        view.backgroundColor = UIColor(
            red: 0.99,
            green: 0.96,
            blue: 0.90,
            alpha: 1
        )
    }

    @MainActor @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct SutraPageContentView: View {
    let page: SutraPage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(page.chapterTitle)
                    .font(.headline)
                    .bold()

                Text(page.body)
                    .font(.body)
                    .lineSpacing(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(24)
        }
        .background(readerBackground)
    }
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
