import XCTest
@testable import XRControl

final class NetgearSOAPTests: XCTestCase {

    func testEnvelopeCarriesSessionIDAndNamespacedMethod() {
        let envelope = NetgearSOAPClient.envelope(
            service: .deviceInfo,
            method: "GetAttachDevice2",
            parameters: []
        )

        XCTAssertTrue(envelope.contains("<SessionID>\(NetgearSOAPClient.sessionID)</SessionID>"))
        XCTAssertTrue(envelope.contains("urn:NETGEAR-ROUTER:service:DeviceInfo:1"))
        XCTAssertTrue(envelope.contains("<M1:GetAttachDevice2"))
        XCTAssertTrue(envelope.contains("</M1:GetAttachDevice2>"))
    }

    func testEnvelopeEscapesParameterValues() {
        let envelope = NetgearSOAPClient.envelope(
            service: .parentalControl,
            method: "Authenticate",
            parameters: [("NewUsername", "admin"), ("NewPassword", "a&b<c\"")]
        )

        XCTAssertTrue(envelope.contains("<NewPassword>a&amp;b&lt;c&quot;</NewPassword>"))
    }

    func testSuccessResponseCodePasses() throws {
        let xml = """
        <?xml version="1.0"?>
        <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
          <SOAP-ENV:Body><ResponseCode>000</ResponseCode></SOAP-ENV:Body>
        </SOAP-ENV:Envelope>
        """
        let tree = try XMLTreeParser.parse(Data(xml.utf8))
        XCTAssertNoThrow(try NetgearSOAPClient.validateResponseCode(in: tree))
    }

    func testResponseCode401MapsToUnauthorized() throws {
        let xml = "<Envelope><Body><ResponseCode>401</ResponseCode></Body></Envelope>"
        let tree = try XMLTreeParser.parse(Data(xml.utf8))

        XCTAssertThrowsError(try NetgearSOAPClient.validateResponseCode(in: tree)) { error in
            XCTAssertEqual(error as? RouterError, .unauthorized)
        }
    }

    func testOtherResponseCodesSurfaceAsSOAPErrors() throws {
        let xml = "<Envelope><Body><ResponseCode>001</ResponseCode></Body></Envelope>"
        let tree = try XMLTreeParser.parse(Data(xml.utf8))

        XCTAssertThrowsError(try NetgearSOAPClient.validateResponseCode(in: tree)) { error in
            XCTAssertEqual(error as? RouterError, .soap(code: "001"))
        }
    }

    func testParsesAttachedDeviceTable() throws {
        let xml = """
        <?xml version="1.0"?>
        <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
          <SOAP-ENV:Body>
            <m:GetAttachDevice2Response xmlns:m="urn:NETGEAR-ROUTER:service:DeviceInfo:1">
              <NewAttachDevice>
                <Device>
                  <IP>192.168.1.24</IP>
                  <Name>PS5</Name>
                  <MAC>AA:BB:CC:DD:EE:01</MAC>
                  <ConnectionType>wired</ConnectionType>
                  <Linkspeed>1000</Linkspeed>
                  <SignalStrength>100</SignalStrength>
                  <AllowOrBlock>Allow</AllowOrBlock>
                  <DeviceType>playstation</DeviceType>
                </Device>
                <Device>
                  <IP>192.168.1.31</IP>
                  <Name>TV</Name>
                  <MAC>AA:BB:CC:DD:EE:02</MAC>
                  <ConnectionType>2.4GHz</ConnectionType>
                  <SSID>Nighthawk</SSID>
                  <Linkspeed>144</Linkspeed>
                  <SignalStrength>61</SignalStrength>
                  <AllowOrBlock>Block</AllowOrBlock>
                </Device>
              </NewAttachDevice>
              <ResponseCode>000</ResponseCode>
            </m:GetAttachDevice2Response>
          </SOAP-ENV:Body>
        </SOAP-ENV:Envelope>
        """

        let tree = try XMLTreeParser.parse(Data(xml.utf8))
        let devices = tree.descendants(named: "Device").compactMap(NetworkDevice.init(soapNode:))

        XCTAssertEqual(devices.count, 2)
        XCTAssertEqual(devices[0].name, "PS5")
        XCTAssertEqual(devices[0].linkSpeed, 1000)
        XCTAssertFalse(devices[0].isBlocked)
        XCTAssertEqual(devices[1].ssid, "Nighthawk")
        XCTAssertEqual(devices[1].signalStrength, 61)
        XCTAssertTrue(devices[1].isBlocked)
    }

    func testNamespacePrefixesAreIgnoredWhenLookingUpValues() throws {
        let xml = "<root><m:GetInfoResponse xmlns:m=\"urn:x\"><ModelName>XR500</ModelName></m:GetInfoResponse></root>"
        let tree = try XMLTreeParser.parse(Data(xml.utf8))

        XCTAssertEqual(tree.firstDescendant(named: "GetInfoResponse")?.localName, "GetInfoResponse")
        XCTAssertEqual(tree.value("ModelName"), "XR500")
    }

    func testMalformedXMLThrows() {
        XCTAssertThrowsError(try XMLTreeParser.parse(Data("<a><b></a>".utf8)))
    }
}
