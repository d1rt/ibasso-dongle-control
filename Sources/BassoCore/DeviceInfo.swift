public struct DeviceInfo: Equatable, Sendable {
    public let manufacturer: String
    public let product: String
    public let serialNumber: String?
    public let vendorID: Int
    public let productID: Int
    public let primaryUsagePage: Int
    public let primaryUsage: Int
    public let maxInputReportSize: Int
    public let maxOutputReportSize: Int

    public init(
        manufacturer: String,
        product: String,
        serialNumber: String?,
        vendorID: Int,
        productID: Int,
        primaryUsagePage: Int,
        primaryUsage: Int,
        maxInputReportSize: Int,
        maxOutputReportSize: Int
    ) {
        self.manufacturer = manufacturer
        self.product = product
        self.serialNumber = serialNumber
        self.vendorID = vendorID
        self.productID = productID
        self.primaryUsagePage = primaryUsagePage
        self.primaryUsage = primaryUsage
        self.maxInputReportSize = maxInputReportSize
        self.maxOutputReportSize = maxOutputReportSize
    }
}
