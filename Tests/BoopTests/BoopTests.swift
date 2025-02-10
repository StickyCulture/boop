import XCTest
@testable import Boop

var TEST: Boop? = nil

final class BoopTests: XCTestCase {
    override func setUp() {
        super.setUp()
        
        let bundle = Bundle.module
        XCTAssertNotNil(bundle)
        
        let path = bundle.path(forResource: "GoogleService-Info", ofType: "plist")
        XCTAssertNotNil(path)
        
        if TEST == nil {
            TEST = Boop(
                application: "sticky-boop-swift",
                instance: "xcode-test",
                isDevelopment: true,
                isDisabled: false,
                firebaseConfigPath: path
            )
        }
    }
    
    func testEvent() async throws {
        // generate random test values for event, label, and value
        let inputEvent = UUID().uuidString
        let inputLabel = UUID().uuidString
        let inputValue = UUID().uuidString
        
        TEST?.isSessionTrackingDisabled = false
        TEST?.didSessionStart = true
        let ref = TEST?.trackEvent(event: inputEvent, label: inputLabel, value: inputValue)
        
        let document = try await ref!.getDocument()
        XCTAssertNotNil(document)
        
        let data = document.data()
        XCTAssertNotNil(data)
        
        let outputEvent = data?["event"] as! String
        print(document.documentID, outputEvent)
        XCTAssertEqual(inputEvent, outputEvent)
        
        let outputLabel = data?["label"] as! String
        XCTAssertEqual(inputLabel, outputLabel)
        
        let outputValue = data?["value"] as! String
        XCTAssertEqual(inputValue, outputValue)
    }
    
    func testAppLaunch() async throws {
        let ref = TEST?.trackAppLaunch()
        
        let document = try await ref!.getDocument()
        XCTAssertNotNil(document)
        
        let data = document.data()
        XCTAssertNotNil(data)
        
        let outputEvent = data?["event"] as! String
        XCTAssertEqual("App Launch", outputEvent)
    }
    
    func testSessionStart() async throws {
        TEST?.isSessionTrackingDisabled = false
        TEST?.didSessionStart = false
        let ref = TEST?.trackSessionStart()
        
        let document = try await ref!.getDocument()
        XCTAssertNotNil(document)
        
        let data = document.data()
        XCTAssertNotNil(data)
        
        let outputEvent = data?["event"] as! String
        XCTAssertEqual("Session Start", outputEvent)
    }
    
    func testSessionStop() async throws {
        TEST?.isSessionTrackingDisabled = false
        TEST?.didSessionStart = true
        let ref = TEST?.trackSessionStop()
        
        let document = try await ref!.getDocument()
        XCTAssertNotNil(document)
        
        let data = document.data()
        XCTAssertNotNil(data)
        
        let outputEvent = data?["event"] as! String
        print(document.documentID, outputEvent)
        XCTAssertEqual("Session Stop", outputEvent)
    }
}
