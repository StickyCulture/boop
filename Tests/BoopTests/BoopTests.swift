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
        
        TEST = nil
        TEST = Boop(
            application: "sticky-boop-swift",
            instance: "xcode-test",
            isDevelopment: true,
            isDisabled: false,
            firebaseConfigPath: path
        )
        Firestore.firestore().clearPersistence()
    }
    
    func testEvent() async throws {
        // generate random test values for event, label, and value
        let inputEvent = UUID().uuidString
        let inputLabel = UUID().uuidString
        let inputValue = UUID().uuidString
        
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
    
    func testCodableValue() async throws {
        TEST?.isSessionTrackingDisabled = true
        let inputEvent = "testCodableValues"

       let dictRef = TEST?.trackEvent(event: inputEvent, label: "Dict", value: ["leopard": 1, "gecko": 2])
       let dictDoc = try await dictRef!.getDocument()
       XCTAssertNotNil(dictDoc)
       let dictData = dictDoc.data()
       XCTAssertNotNil(dictData)
       let dictValue: [String: Int] = dictData!["value"] as! [String: Int]
       XCTAssertEqual(dictValue["leopard"], 1)
       XCTAssertEqual(dictValue["gecko"], 2)
       
       let arrayRef = TEST?.trackEvent(event: inputEvent, label: "Array", value: ["leopard", "gecko"])
       let arrayDoc = try await arrayRef!.getDocument()
       XCTAssertNotNil(arrayDoc)
       let arrayData = arrayDoc.data()
       XCTAssertNotNil(arrayData)
       let arrayValue: [String] = arrayData!["value"] as! [String]
       XCTAssertEqual(arrayValue[0], "leopard")
       XCTAssertEqual(arrayValue[1], "gecko")

       let intRef = TEST?.trackEvent(event: inputEvent, label: "Int", value: 42)
       let intDoc = try await intRef!.getDocument()
       XCTAssertNotNil(intDoc)
       let intData = intDoc.data()
       XCTAssertNotNil(intData)
       let intValue: Int = intData!["value"] as! Int
       XCTAssertEqual(intValue, 42)

       let doubleRef = TEST?.trackEvent(event: inputEvent, label: "Double", value: 42.0)
       let doubleDoc = try await doubleRef!.getDocument()
       XCTAssertNotNil(doubleDoc)
       let doubleData = doubleDoc.data()
       XCTAssertNotNil(doubleData)
       let doubleValue: Double = doubleData!["value"] as! Double
       XCTAssertEqual(doubleValue, 42.0)
       
       let stringRef = TEST?.trackEvent(event: inputEvent, label: "String", value: "leopard gecko")
       let stringDoc = try await stringRef!.getDocument()
       XCTAssertNotNil(stringDoc)
       let stringData = stringDoc.data()
       XCTAssertNotNil(stringData)
       let stringValue: String = stringData!["value"] as! String
       XCTAssertEqual(stringValue, "leopard gecko")
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
        let ref = TEST?.trackSessionStart()
        XCTAssertNil(ref)
    }
    
    func testSessionStop() async throws {
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
    
    func testSessionFlop() async throws {
        let minimum = 1.0
        TEST?.minimumViableSessionDuration = minimum
                
        let startRef = TEST?.trackSessionStart()
        XCTAssertNotNil(startRef)
        try await Task.sleep(until: .now + .seconds(minimum * 0.5))
        let flopRef = TEST?.trackSessionStop()
        XCTAssertNotNil(flopRef)
        let flopDoc = try await flopRef!.getDocument()
        XCTAssertNotNil(flopDoc)
        let flopData = flopDoc.data()
        XCTAssertNotNil(flopData)
        let flopEvent = flopData?["event"] as! String
        XCTAssertEqual("Session Flop", flopEvent)
        
        let duration = minimum + 0.1
        let startRef2 = TEST?.trackSessionStart()
        XCTAssertNotNil(startRef2)
        try await Task.sleep(until: .now + .seconds(duration))
        let stopRef = TEST?.trackSessionStop()
        XCTAssertNotNil(stopRef)
        let stopDoc = try await stopRef!.getDocument()
        XCTAssertNotNil(stopDoc)
        let stopData = stopDoc.data()
        XCTAssertNotNil(stopData)
        let stopEvent = stopData?["event"] as! String
        XCTAssertEqual("Session Stop", stopEvent)
        
        let durationMs = stopData?["value"] as? Int
        XCTAssertNotNil(durationMs)
        XCTAssertGreaterThanOrEqual(Double(durationMs ?? 0), duration)
    }
}

