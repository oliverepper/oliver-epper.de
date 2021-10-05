import Foundation
import Publish
import Plot
import SwiftPygmentsPublishPlugin
import DarkImagePublishPlugin
import ReadingTimePublishPlugin

// This type acts as the configuration for your website.
struct OliverEpper: Website {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    enum SectionID: String, WebsiteSectionID {
        // Add the sections that you want your website to contain here:
        case posts
        case apps
        case about
    }

    struct ItemMetadata: WebsiteItemMetadata {
        // Add any site-specific metadata that you want to use here.
    }

    // Update these properties to configure your website:
    var url = URL(string: "https://oliver-epper.de")!
    var name = "oliep"
    var description = "Golf Professional & Professional Software Developer"
    var language: Language { .english }
    var imagePath: Path? { nil }
}

// This will generate your website using the built-in Foundation theme:
try OliverEpper().publish(using: [
    .installPlugin(.pygments()),
    .installPlugin(.darkImage()),
    .copyResources(),
    .addMarkdownFiles(),
    .installPlugin(.readingTime()),
    .generateHTML(withTheme: .oliep),
    .generateRSSFeed(including: [.posts]),
    .generateSiteMap(),
    .deploy(using: .gitHub("oliverepper/oliverepper.github.io", useSSH: false))
])
