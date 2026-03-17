import Foundation

public struct ViewBinding: Codable, Sendable {
    public let module: String
    public let viewType: String
    public let viewModelType: String
    public let wrapper: String
    public let publishedProperties: [String]

    public init(
        module: String,
        viewType: String,
        viewModelType: String,
        wrapper: String,
        publishedProperties: [String]
    ) {
        self.module = module
        self.viewType = viewType
        self.viewModelType = viewModelType
        self.wrapper = wrapper
        self.publishedProperties = publishedProperties
    }
}
