import XCTest
import FirebaseFirestore
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
        let settings = FirestoreSettings()
        settings.cacheSettings = MemoryCacheSettings()
        Firestore.firestore().settings = settings
        Firestore.firestore().clearPersistence()
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
    
    func testSessionStartSilent() async throws {
        TEST?.isSendingSessionStartEvents = false
        TEST?.isSessionTrackingDisabled = false
        TEST?.didSessionStart = false
        let ref = TEST?.trackSessionStart()
        XCTAssertNil(ref)
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
    
    /// Simulates 2 sessions. Each start and stop of a session should have the same `sessionId`, but the `sessionId` between 2 sessions should be different
    func testSessionId() async throws {
        TEST?.isSessionTrackingDisabled = false
        TEST?.didSessionStart = false
        let startRef = TEST?.trackSessionStart()
        let startDoc = try await startRef!.getDocument()
        XCTAssertNotNil(startDoc)
        let startData = startDoc.data()
        XCTAssertNotNil(startData)
        let startId = startData?["sessionId"] as? String
        XCTAssertNotNil(startId)
        
        let inputEvent = "Test"
        let inputLabel = "testSessionId"
        let inputValue = 1
        let eventRef = TEST?.trackEvent(event: inputEvent, label: inputLabel, value: inputValue)
        let eventDoc = try await eventRef!.getDocument()
        XCTAssertNotNil(eventDoc)
        let eventData = eventDoc.data()
        XCTAssertNotNil(eventData)
        let outputEvent = eventData?["event"] as! String
        XCTAssertEqual(inputEvent, outputEvent)
        let outputLabel = eventData?["label"] as! String
        XCTAssertEqual(inputLabel, outputLabel)
        let outputValue = eventData?["value"] as! Int
        XCTAssertEqual(inputValue, outputValue)
        let outputSessionId = eventData?["sessionId"] as? String
        XCTAssertNotNil(outputSessionId)
        XCTAssertEqual(startId, outputSessionId)
        
        let stopRef = TEST?.trackSessionStop()
        let stopDoc = try await stopRef!.getDocument()
        XCTAssertNotNil(stopDoc)
        let stopData = stopDoc.data()
        XCTAssertNotNil(stopData)
        let stopId = stopData?["sessionId"] as? String
        
        // make sure start and stop ids are the same
        XCTAssertEqual(startId, stopId)
        
        let nextStartRef = TEST?.trackSessionStart()
        let nextStartDoc = try await nextStartRef!.getDocument()
        XCTAssertNotNil(nextStartDoc)
        let nextStartData = nextStartDoc.data()
        XCTAssertNotNil(nextStartData)
        let nextStartId = nextStartData?["sessionId"] as? String
        XCTAssertNotNil(nextStartId)
        
        let nextStopRef = TEST?.trackSessionStop()
        let nextStopDoc = try await nextStopRef!.getDocument()
        XCTAssertNotNil(nextStopDoc)
        let nextStopData = nextStopDoc.data()
        XCTAssertNotNil(nextStopData)
        let nextStopId = nextStopData?["sessionId"] as? String
        
        // make sure next start and stop ids are the same
        XCTAssertEqual(nextStartId, nextStopId)
        
        // make sure first start and next start ids are different
        XCTAssertNotEqual(startId, nextStartId)
    }
    
    func testDisabledSessions() async throws {
        TEST?.isSessionTrackingDisabled = true
        let startRef = TEST?.trackSessionStart()
        XCTAssertNil(startRef)
        
        let inputEvent = "Test"
        let inputLabel = "testDisabledSessions"
        let inputValue = UUID().uuidString
        let ref = TEST?.trackEvent(event: inputEvent, label: inputLabel, value: inputValue)
        let document = try await ref!.getDocument()
        XCTAssertNotNil(document)
        let data = document.data()
        XCTAssertNotNil(data)
        let outputEvent = data?["event"] as! String
        XCTAssertEqual(inputEvent, outputEvent)
        let outputLabel = data?["label"] as! String
        XCTAssertEqual(inputLabel, outputLabel)
        let outputValue = data?["value"] as! String
        XCTAssertEqual(inputValue, outputValue)
        let outputSessionId = data?["sessionId"] as? String
        XCTAssertNil(outputSessionId)
        
        let stopRef = TEST?.trackSessionStop()
        XCTAssertNil(stopRef)
    }
    
    func testSessionDuration() async throws {
        TEST?.isSessionTrackingDisabled = false
        let startRef = TEST?.trackSessionStart()
        XCTAssertNotNil(startRef)
        
        XCTAssertNotNil(TEST?.currentSessionDuration)
        XCTAssertLessThan(TEST?.currentSessionDuration ?? 0, 1.0)
        
        // Wait for 1 second
        try await Task.sleep(until: .now + .seconds(1.0))
        
        XCTAssertGreaterThanOrEqual(TEST?.currentSessionDuration ?? 0, 1.0)
        
        let stopRef = TEST?.trackSessionStop()
        XCTAssertNotNil(stopRef)
        
        let document = try await stopRef!.getDocument()
        XCTAssertNotNil(document)
        let data = document.data()
        XCTAssertNotNil(data)
        
        // Check session duration in milliseconds from the document
        let durationMs = data?["value"] as? Double
        XCTAssertNotNil(durationMs)
        XCTAssertGreaterThanOrEqual(durationMs ?? 0, 1000.0)
    }
}
