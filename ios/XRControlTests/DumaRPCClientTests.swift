import XCTest
@testable import XRControl

final class DumaRPCClientTests: XCTestCase {

    // MARK: - Request encoding

    func testRequestBodyMatchesDumaOSWireFormat() throws {
        let body = RPCRequestBody(method: "get_cpu_info", id: 7, params: [])
        let data = try JSONEncoder().encode(body)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(decoded?["jsonrpc"] as? String, "2.0")
        XCTAssertEqual(decoded?["method"] as? String, "get_cpu_info")
        XCTAssertEqual(decoded?["id"] as? Int, 7)
        // The router's client throws a TypeError if params is not an array.
        XCTAssertNotNil(decoded?["params"] as? [Any])
    }

    func testRequestEncodesMixedParameterTypes() throws {
        let body = RPCRequestBody(
            method: "set_device_name",
            id: 1,
            params: [.string("aa:bb:cc"), .bool(true), .number(42)]
        )
        let data = try JSONEncoder().encode(body)
        let text = String(data: data, encoding: .utf8) ?? ""

        XCTAssertTrue(text.contains("\"aa:bb:cc\""))
        XCTAssertTrue(text.contains("true"))
        XCTAssertTrue(text.contains("42"))
    }

    // MARK: - Response decoding

    func testDecodesResultArray() throws {
        let json = #"{"id":1,"result":[{"model":"XR500","uptime":1234}]}"#
        let result = try DumaRPCClient.decodeEnvelope(Data(json.utf8), package: "p", method: "m")

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0]["model"]?.stringValue, "XR500")
        XCTAssertEqual(result[0]["uptime"]?.intValue, 1234)
    }

    func testDecodesScalarResultAsSingleElement() throws {
        let json = #"{"id":1,"result":2}"#
        let result = try DumaRPCClient.decodeEnvelope(Data(json.utf8), package: "p", method: "m")

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].intValue, 2)
    }

    func testThrowsOnDumaErrorEnvelope() {
        // DumaOS reports failures with an eid/msg pair, sometimes alongside 200.
        let json = #"{"id":1,"error":-32000,"eid":"ERROR_UBUS","msg":"Ubus error: 4"}"#

        XCTAssertThrowsError(try DumaRPCClient.decodeEnvelope(Data(json.utf8), package: "p", method: "m")) { error in
            guard case RouterError.rpc(let code, let eid, let message) = error else {
                return XCTFail("Expected a RouterError.rpc, got \(error)")
            }
            XCTAssertEqual(code, -32000)
            XCTAssertEqual(eid, "ERROR_UBUS")
            XCTAssertEqual(message, "Ubus error: 4")
        }
    }

    func testForbiddenRPCCodeMapsToUnauthorized() {
        let json = #"{"id":1,"error":-32604,"eid":"ERROR_FORBIDDEN","msg":"Forbidden access"}"#

        XCTAssertThrowsError(try DumaRPCClient.decodeEnvelope(Data(json.utf8), package: "p", method: "m")) { error in
            XCTAssertEqual(error as? RouterError, .unauthorized)
        }
    }

    func testThrowsOnMissingResult() {
        let json = #"{"id":1}"#

        XCTAssertThrowsError(try DumaRPCClient.decodeEnvelope(Data(json.utf8), package: "sysinfo", method: "get")) { error in
            guard case RouterError.malformedResponse = error else {
                return XCTFail("Expected malformedResponse, got \(error)")
            }
        }
    }

    func testThrowsOnNonJSONBody() {
        let html = "<html><body>401 Unauthorized</body></html>"

        XCTAssertThrowsError(try DumaRPCClient.decodeEnvelope(Data(html.utf8), package: "p", method: "m")) { error in
            guard case RouterError.malformedResponse = error else {
                return XCTFail("Expected malformedResponse, got \(error)")
            }
        }
    }

    // MARK: - URL construction

    func testRPCURLUsesWebPortAndPackagePath() throws {
        let credentials = RouterCredentials(host: "192.168.1.1", webPort: 8080)
        let base = try XCTUnwrap(credentials.webBaseURL)
        let url = try XCTUnwrap(URL(string: "apps/\(DumaPackage.geoFilter)/rpc/", relativeTo: base))

        XCTAssertEqual(
            url.absoluteString,
            "http://192.168.1.1:8080/apps/com.netdumasoftware.geofilter/rpc/"
        )
    }

    func testBasicAuthHeaderIsBase64Encoded() throws {
        let credentials = RouterCredentials(username: "admin", password: "hunter2")
        XCTAssertEqual(credentials.basicAuthHeader, "Basic YWRtaW46aHVudGVyMg==")
    }

    func testHostIsTrimmedBeforeBuildingURLs() throws {
        let credentials = RouterCredentials(host: "  192.168.1.1  ")
        XCTAssertEqual(credentials.webBaseURL?.host, "192.168.1.1")
    }
}
