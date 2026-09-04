public struct DCEliteProfile: DeviceProfile {
    public init() {}

    public let info = DeviceProfileInfo(
        id: "ibasso.dc-elite",
        displayName: "iBasso DC Elite",
        vendorID: 0x2FC6,
        productID: 0xF0B5,
        controllerFamily: .dcEliteHIDV1,
        capabilities: [
            .pcmFilter,
            .dsdFilter,
            .pcmVolumeReduction,
            .volumeMatch,
            .coax
        ],
        audioDeviceName: "Primary Play Interface",
        audioManufacturer: "iBasso",
        notes: "The final byte of the main settings group is preserved as opaque data."
    )
}
