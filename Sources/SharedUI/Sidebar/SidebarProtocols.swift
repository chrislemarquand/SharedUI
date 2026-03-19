import Foundation

public protocol AppKitSidebarSectionType: Hashable {
    var title: String { get }
}

public protocol AppKitSidebarItemType: Hashable {
    associatedtype SectionType: AppKitSidebarSectionType
    var section: SectionType { get }
    var title: String { get }
    var symbolName: String { get }
    var badgeText: String? { get }
}
