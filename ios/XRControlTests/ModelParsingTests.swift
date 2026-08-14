import XCTest
@testable import XRControl

final class ModelParsingTests: XCTestCase {

    // MARK: - System info

    func testSystemInfoReadsDumaOSPayload() throws {
        let json = try JSONValue.parse(#"""
        {
          "model": "XR500",
          "board_name": "Nighthawk XR500",
          "platform": "BROADCOM",
          "firmware_version": "2.3.2.114",
          "dumaos_version": "3.0.128",
          "uptime": 412338,
          "load": [0.24, 0.31, 0.28],
          "date": "Thu Aug 14 09:12:00 2026"
        }
        """#)

        let info = SystemInfo(json: json)
        XCTAssertEqual(info.model, "XR500")
        XCTAssertEqual(info.firmwareVersion, "2.3.2.114")
        XCTAssertEqual(info.dumaOSVersion, "3.0.128")
        XCTAssertEqual(info.uptime, 412_338)
        XCTAssertEqual(info.loadAverage, [0.24, 0.31, 0.28])
    }

    func testSystemInfoFallsBackWhenKeysAreMissing() throws {
        let info = SystemInfo(json: try JSONValue.parse(#"{"board_name":"XR500","version":"1.0"}"#))
        // `model` falls back to board_name, `firmware_version` to `version`.
        XCTAssertEqual(info.model, "XR500")
        XCTAssertEqual(info.firmwareVersion, "1.0")
        XCTAssertEqual(info.dumaOSVersion, "—")
    }

    func testCPUInfoNormalizesPercentagesToFractions() throws {
        let fractions = CPUInfo(json: try JSONValue.parse("[0.2, 0.4]"))
        XCTAssertEqual(fractions.averageUsage, 0.3, accuracy: 0.0001)

        let percentages = CPUInfo(json: try JSONValue.parse("[20, 40]"))
        XCTAssertEqual(percentages.averageUsage, 0.3, accuracy: 0.0001)

        let objects = CPUInfo(json: try JSONValue.parse(#"[{"usage": 50}]"#))
        XCTAssertEqual(objects.averageUsage, 0.5, accuracy: 0.0001)
    }

    func testStorageInfoDerivesUsedFromFree() throws {
        let info = StorageInfo(json: try JSONValue.parse(#"{"total": 1000, "free": 250}"#), scale: 1024)
        XCTAssertEqual(info.totalBytes, 1_024_000)
        XCTAssertEqual(info.usedBytes, 768_000)
        XCTAssertEqual(info.usedFraction, 0.75, accuracy: 0.0001)
    }

    func testNetworkStatisticsReadsNestedCounters() throws {
        let json = try JSONValue.parse(#"""
        {"ip_address":"203.0.113.47",
         "received":{"bytes":1000,"packets":10,"dropped":1},
         "transmitted":{"bytes":500,"packets":5,"dropped":0}}
        """#)

        let stats = NetworkStatistics(json: json)
        XCTAssertEqual(stats.wanIPAddress, "203.0.113.47")
        XCTAssertEqual(stats.receivedBytes, 1000)
        XCTAssertEqual(stats.transmittedDropped, 0)
    }

    // MARK: - Throughput

    func testThroughputIsDerivedFromCounterDelta() {
        let start = Date()
        var previous = NetworkStatistics()
        previous.receivedBytes = 1_000_000
        previous.transmittedBytes = 500_000

        var current = NetworkStatistics()
        current.receivedBytes = 2_000_000   // +1 MB
        current.transmittedBytes = 750_000  // +250 KB

        let sample = ThroughputSample.between(
            previous: previous,
            previousDate: start,
            current: current,
            currentDate: start.addingTimeInterval(2)
        )

        // 1 MB over 2 s = 4 Mbit/s.
        XCTAssertEqual(sample?.downstream ?? 0, 4_000_000, accuracy: 1)
        XCTAssertEqual(sample?.upstream ?? 0, 1_000_000, accuracy: 1)
    }

    func testThroughputIgnoresCounterResetAfterReboot() {
        let start = Date()
        var previous = NetworkStatistics()
        previous.receivedBytes = 5_000_000

        let current = NetworkStatistics()  // counters back to zero

        XCTAssertNil(ThroughputSample.between(
            previous: previous,
            previousDate: start,
            current: current,
            currentDate: start.addingTimeInterval(5)
        ))
    }

    // MARK: - Devices

    func testDeviceParsesNestedInterface() throws {
        let json = try JSONValue.parse(#"""
        {"devid":"aa:bb:cc:dd:ee:01","name":"PlayStation 5","type":"playstation",
         "state":"online","blocked":false,
         "interfaces":[{"ip":"192.168.1.24","mac":"aa:bb:cc:dd:ee:01","type":"wired"}]}
        """#)

        let device = try XCTUnwrap(NetworkDevice(dumaJSON: json))
        XCTAssertEqual(device.id, "aa:bb:cc:dd:ee:01")
        XCTAssertEqual(device.ipAddress, "192.168.1.24")
        XCTAssertTrue(device.isOnline)
        XCTAssertEqual(device.symbolName, "gamecontroller.fill")
        XCTAssertNotNil(device.raw)
    }

    func testDeviceRejectsEntryWithoutIdentifier() throws {
        XCTAssertNil(NetworkDevice(dumaJSON: try JSONValue.parse(#"{"name":"mystery"}"#)))
    }

    func testSOAPDetailsMergeIntoDumaDevice() {
        let duma = NetworkDevice(id: "m", name: "TV", ipAddress: "192.168.1.31", macAddress: "m")
        let soap = NetworkDevice(id: "m", name: "TV", macAddress: "m",
                                 linkSpeed: 144, signalStrength: 61)

        let merged = duma.merging(soap: soap)
        XCTAssertEqual(merged.linkSpeed, 144)
        XCTAssertEqual(merged.signalStrength, 61)
        XCTAssertEqual(merged.ipAddress, "192.168.1.31")
    }

    // MARK: - Geo-Filter

    func testGeoPeerAcceptsSeveralCoordinateShapes() throws {
        let flat = GeoPeer(json: try JSONValue.parse(#"{"ip":"1.1.1.1","lat":40.7,"long":-74.0}"#))
        XCTAssertEqual(flat?.latitude, 40.7)

        let nested = GeoPeer(json: try JSONValue.parse(#"{"ip":"1.1.1.2","location":{"latitude":51.5,"longitude":-0.13}}"#))
        XCTAssertEqual(nested?.longitude ?? 0, -0.13, accuracy: 0.001)

        let tuple = GeoPeer(json: try JSONValue.parse(#"{"ip":"1.1.1.3","location":[35.6,139.7]}"#))
        XCTAssertEqual(tuple?.latitude, 35.6)

        XCTAssertNil(GeoPeer(json: try JSONValue.parse(#"{"ip":"1.1.1.4"}"#)))
    }

    func testGeoPeerDistanceIsInKilometres() {
        let home = GeoFilterSettings(homeLatitude: 40.7128, homeLongitude: -74.0060).homeCoordinate
        let london = GeoPeer(id: "1", ipAddress: "1.1.1.1", latitude: 51.5074, longitude: -0.1278)

        // New York to London is roughly 5,570 km.
        XCTAssertEqual(london.distanceKilometers(from: home), 5570, accuracy: 60)
    }

    // MARK: - QoS

    func testBandwidthConvertsKilobitsToMegabits() {
        let settings = BandwidthSettings(downKbps: 450_000, upKbps: 42_000)
        XCTAssertEqual(settings.downloadMbps, 450)
        XCTAssertEqual(settings.uploadMbps, 42)
        XCTAssertEqual(settings.downKbps, 450_000)
    }

    func testThrottleAcceptsFractionsAndPercentages() throws {
        let fraction = ThrottleSettings(json: try JSONValue.parse(#"{"enabled":true,"dthrottle":0.7,"uthrottle":0.6}"#))
        XCTAssertTrue(fraction.isEnabled)
        XCTAssertEqual(fraction.downstreamFraction, 0.7, accuracy: 0.0001)

        let percentage = ThrottleSettings(json: try JSONValue.parse(#"{"enabled":false,"dthrottle":70,"uthrottle":60}"#))
        XCTAssertEqual(percentage.downstreamFraction, 0.7, accuracy: 0.0001)
    }

    func testAllocationTreeIsFlattenedToLeafDevices() throws {
        let json = try JSONValue.parse(#"""
        {"children":[
          {"devid":"a","down_normprop":0.6,"up_normprop":0.5,"children":[]},
          {"name":"group","children":[
             {"devid":"b","down_normprop":0.4,"up_normprop":0.5,"children":[]}
          ]}
        ]}
        """#)

        let allocations = BandwidthAllocation.flatten(json, deviceNames: ["a": "PS5"])
        XCTAssertEqual(allocations.count, 2)
        XCTAssertEqual(allocations[0].name, "PS5")
        XCTAssertEqual(allocations[1].id, "b")
        XCTAssertEqual(allocations[1].downstreamShare, 0.4, accuracy: 0.0001)
    }

    // MARK: - Traffic rules

    func testRuleActionComesFromBooleanFlags() throws {
        let block = TrafficRule(json: try JSONValue.parse(#"{"id":"1","name":"Ads","block":true}"#), order: 0)
        XCTAssertEqual(block?.action, .block)

        let reject = TrafficRule(json: try JSONValue.parse(#"{"id":"2","name":"X","reject":true}"#), order: 1)
        XCTAssertEqual(reject?.action, .reject)

        let allow = TrafficRule(json: try JSONValue.parse(#"{"id":"3","name":"Y","allow":true}"#), order: 2)
        XCTAssertEqual(allow?.action, .allow)
    }

    func testRuleSummaryFallsBackToAllTraffic() throws {
        let rule = try XCTUnwrap(TrafficRule(json: try JSONValue.parse(#"{"id":"1","name":"X"}"#), order: 0))
        XCTAssertEqual(rule.summary, "All traffic")
    }

    // MARK: - Result unwrapping

    func testListPayloadUnwrapsCollectionAtResultZero() throws {
        let result = [try JSONValue.parse(#"[{"id":"a"},{"id":"b"}]"#)]
        XCTAssertEqual(LiveRouterService.listPayload(result).count, 2)
    }

    func testListPayloadHandlesLuaNumericKeyTables() throws {
        // Lua tables with integer keys serialise as objects, not arrays.
        let result = [try JSONValue.parse(#"{"1":{"id":"a"},"2":{"id":"b"},"10":{"id":"c"}}"#)]
        let list = LiveRouterService.listPayload(result)

        XCTAssertEqual(list.count, 3)
        XCTAssertEqual(list[0]["id"]?.stringValue, "a")
        XCTAssertEqual(list[2]["id"]?.stringValue, "c")
    }

    func testListPayloadLeavesPlainObjectAlone() throws {
        let result = [try JSONValue.parse(#"{"model":"XR500"}"#)]
        XCTAssertEqual(LiveRouterService.listPayload(result).count, 1)
    }
}

// MARK: - Helpers

extension JSONValue {
    /// Test helper: decodes a JSON literal into a `JSONValue`.
    static func parse(_ text: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
    }
}
