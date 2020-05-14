import Publish
import Plot

extension Theme where Site == OliverEpper {
    static var oliep: Self {
        Theme(htmlFactory: OliverEpperHTMLFactory(), resourcePaths: [
            "Resources/css/styles.css",
            "Resources/css/pygments-xcode.css",
            "Resources/css/pygments-monokai.css"
        ])
    }

    private struct OliverEpperHTMLFactory: HTMLFactory {
        func makeIndexHTML(for index: Index, context: PublishingContext<OliverEpper>) throws -> HTML {
            HTML(
                .lang(context.site.language),
                .head(for: index, on: context.site),
                .body(
                    .layout(for: context, selectedSection: nil, mainCentered: true,
                        .div(.class("about"),
                            .div(.class("avatar"),
                                .img(
                                    .alt("Oliver Epper"),
                                    .src("images/oliep.jpg")
                                )
                            ),
                            .contentBody(index.body),
                            .div(.class("social-icons"),
                                .ul(
                                    .li(
                                        .a(
                                            .href("https://github.com/oliverepper"),
                                            .target(.blank),
                                            .span(.class("fab fa-github fa-2x"))
                                        )
                                    ),
                                    .li(
                                        .a(
                                            .href("https://twitter.com/oliverepper"),
                                            .target(.blank),
                                            .span(.class("fab fa-twitter fa-2x"))
                                        )
                                    )
                                )
                            )
                        )
                    ),
                    .script(
                        .src("https://kit.fontawesome.com/fd7cbf6928.js"),
                        .attribute(named: "crossorigin", value: "anonmous")
                    )
                )
            )
        }

        func makeSectionHTML(for section: Section<OliverEpper>, context: PublishingContext<OliverEpper>) throws -> HTML {
            HTML(
                .lang(context.site.language),
                .head(for: section, on: context.site),
                .body(
                    .layout(for: context, selectedSection: section.id,
                        .contentBody(section.body),
                        .itemList(for: section.items.sorted { $0.date > $1.date}, onSite: context.site)
                    )
                )
            )
        }

        func makeItemHTML(for item: Item<OliverEpper>, context: PublishingContext<OliverEpper>) throws -> HTML {
            HTML(
                .lang(context.site.language),
                .head(for: item, on: context.site),
                .body(
                    .layout(for: context, selectedSection: item.sectionID,
                        .article(
                            .h1(.text(item.title)),
                            .itemMetaData(for: item, onSite: context.site),
                            .contentBody(item.body)
                        )
                    ),
                    .script(
                        .src("https://kit.fontawesome.com/fd7cbf6928.js"),
                        .attribute(named: "crossorigin", value: "anonmous")
                    )
                )
            )
        }

        func makePageHTML(for page: Page, context: PublishingContext<OliverEpper>) throws -> HTML {
            HTML(
                .lang(context.site.language),
                .head(for: page, on: context.site),
                .body(
                    .layout(for: context, selectedSection: nil,
                        .div(.class("page"),
                             .contentBody(page.body)
                        )
                    )
                )
            )
        }

        func makeTagListHTML(for page: TagListPage, context: PublishingContext<OliverEpper>) throws -> HTML? {
            HTML(
                .lang(context.site.language),
                .head(for: page, on: context.site),
                .body(
                    .layout(for: context, selectedSection: nil,
                        .h1(
                            .text("Tags")
                        ),
                        .div(.class("tag-list"),
                            .ul(
                                .forEach(page.tags.sorted()) { tag in
                                    .li(
                                        .a(
                                            .href(context.site.path(for: tag)),
                                            .text("\(tag.string) (\(context.items(taggedWith: tag).count))")
                                        ),
                                        .if(tag != page.tags.sorted().last,
                                            .text("&middot;")
                                        )
                                    )
                                }
                            )
                        )
                    )
                )
            )

        }

        func makeTagDetailsHTML(for page: TagDetailsPage, context: PublishingContext<OliverEpper>) throws -> HTML? {
            HTML(
                .lang(context.site.language),
                .head(for: page, on: context.site),
                .body(
                    .layout(for: context, selectedSection: nil,
                        .h1(
                            "Tagged with ",
                            .text(page.tag.string)
                        ),
                        .itemList(for: context.items(taggedWith: page.tag, sortedBy: \.date), onSite: context.site)
                    )
                )
            )
        }
    }
}

private extension Node where Context == HTML.BodyContext {
    static func wrapper(_ nodes: Node...) -> Node {
        .div(.class("wrapper"), .group(nodes))
    }

    static func container(_ nodes: Node...) -> Node {
        .div(.class("container"), .group(nodes))
    }

    static func layout<T: Website>(for context: PublishingContext<T>, selectedSection: T.SectionID?, mainCentered: Bool = false, _ nodes: Node...) -> Node {
        .div(.class("wrapper"),
            .header(for: context, selectedSection: nil),
            .main(for: context, isCentered: mainCentered, .group(nodes)),
            .footer(for: context)
        )
    }

    static func header<T: Website>(for context: PublishingContext<T>, selectedSection: T.SectionID?) -> Node {
        let sectionsIDs = T.SectionID.allCases

        return .header(
            .container(
                .nav(.class("navigation"),
                    .a(.href("/"), .text(context.site.name)),
                    .if(sectionsIDs.count > 1,
                        .ul(
                            .forEach(sectionsIDs) { section in
                                .group(
                                    .li(.a(
                                        .class(section == selectedSection ? "selected" : ""),
                                        .href(context.sections[section].path),
                                        .text(context.sections[section].title)
                                        )),
                                    .if(section as! OliverEpper.SectionID == OliverEpper.SectionID.posts,
                                        .li(.a(
                                            .href("https://golf.oliver-epper.de"),
                                            .text("Golf")
                                        ))
                                    )
                                )
                            }
                        )
                    )
                )
            )
        )
    }

    static func main<T: Website>(for context: PublishingContext<T>, isCentered: Bool, _ nodes: Node...) -> Node {
        return .main(.class(isCentered ? "grow centered" : "grow"),
            .container(.group(nodes))
        )
    }

    static func footer<T: Website>(for context: PublishingContext<T>) -> Node {
        return .footer(
            .container(
                .div(.class("credits"),
                    .text("Oliver Epper &middot; made with "),
                    .a(
                        .href("https://github.com/johnsundell/publish"),
                        .text("Publish"),
                        .target(.blank)
                    ),
                    .text(" &middot; "),
                    .text(" inspired by "),
                    .a(
                        .href("https://github.com/luizdepra/hugo-coder"),
                        .text("Coder"),
                        .target(.blank)
                    ),
                    .text(" &middot; "),
                    .a(
                        .href("/feed.rss"),
                        .text("RSS feed")
                    )
                )
            )
        )
    }

    static func itemList<T: Website>(for items: [Item<T>], onSite: T) -> Node {
        return .div(.class("item-list"),
            .if(items.count > 0,
                .ul(
                    .forEach(items) { item in
                        .li(
                            .span(.class("date"),
                                .text(OliverEpper.dateFormatter.string(from: item.date))
                            ),
                            .a(
                                .href(item.path),
                                .text(item.title)
                            )
                        )
                    }
                )
            )
        )
    }

    static func itemMetaData<T: Website>(for item: Item<T>, onSite site: T) -> Node {
        let readingTime = Int(item.readingTime.minutes)

        return .div(.class("item-metadata"),
            .ul(
                .li(
                    .span(.class("fas fa-calendar")),
                    .text(OliverEpper.dateFormatter.string(from: item.date))
                ),
                .li(
                    .span(.class("fas fa-clock")),
                    .text("\(readingTime)-minute read")
                )
            ),
            .if(item.tags.count > 0,
                .div(.class("taglist"),
                    .span(.class("fas fa-tags")),
                    .forEach(item.tags) { tag in
                        .group(
                            .a(
                                .href(site.path(for: tag)),
                                .text(tag.string)
                            ),
                            .if(tag != item.tags.last,
                                .text("&middot;")
                            )
                        )
                    }
                )
            )
        )
    }
}
