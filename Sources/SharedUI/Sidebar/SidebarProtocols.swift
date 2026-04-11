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
    var sidebarReorderID: String? { get }
    var isSidebarReorderable: Bool { get }
    var sidebarPromotionTargets: Set<SectionType> { get }
}

public extension AppKitSidebarItemType {
    var sidebarReorderID: String? { nil }
    var isSidebarReorderable: Bool { false }
    var sidebarPromotionTargets: Set<SectionType> { [] }
}
