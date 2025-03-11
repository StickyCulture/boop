import os
import Firebase

public class Boop {
    private var db: Firestore
    private var collection: String {
        var name = self.application
        if self.isDevelopment {
            name += "-dev"
        }
        return name
    }
    
    /// An identifier for your application. This will be used as the Firebase collection name.
    public var application: String
    /// An identifier that distinguishes different instances of the same application.
    public var instance: String
    /// If `true`, which is the default value, "-dev" will be appended to the application name in order to separate development boops into a Firebase collection that is distinct from production boops.
    public var isDevelopment: Bool
    /// If `true`, which is the default value, no boops will be sent to Firebase
    public var isDisabled: Bool
    /// If `true`, disables the booping of sessions (including those that might be automatically booped based on other event activity)
    public var isSessionTrackingDisabled: Bool
    /// Toggles whether or not to actually send "Session Start" events to Firebase
    ///
    /// Defaults to `true` meaning the session start events are sent to Firebase. If `false`, you should still call ``trackSessionStart()`` in order to get a recording of the session duration when ``trackSessionStop()`` is called.
    public var isSendingSessionStartEvents: Bool
    /// Toggles whether or not to actually send "Session Flop" events to Firebase
    ///
    /// Defaults to `true` meaning that sessions which do not exceed the minimum duration threshold from ``minimumViableSessionDuration`` will send flop events to Firebase. If `false`, flop events are not tracked.
    public var isSendingSessionFlopEvents: Bool
    /// Set this value to automatically subtract the duration of an inactivity timeout when booping sessions. Defaults to `0`.
    public var sessionTimeout: TimeInterval
    /// If set, the "Session Stop" event will be replaced with "Session Flop" if the session duration is less than this value (in seconds).
    ///
    /// See: ``isSendingSessionFlopEvents`` for configuring whether or not to report these types
    public var minimumViableSessionDuration: TimeInterval?
    /// This value is internally flipped during the very first user-initiated event in order to ensure the first session (after app launch) includes a starting boop.
    ///
    /// You can enable it immediately after instantiating Boop in order to prevent this "first session start" behavior. Disabling session boops with ``isSessionTrackingDisabled`` will also prevent the "first session start" behavior.
    public var didSessionStart: Bool
    private var sessionStart: Date?
    /// The current time (in seconds) since the start of the session, or `0`
    public var currentSessionDuration: TimeInterval {
        var value: TimeInterval = 0
        if self.didSessionStart, let sessionStart = self.sessionStart {
            value = Date().timeIntervalSince(sessionStart) - self.sessionTimeout
        }
        return value
    }
    private var sessionId: UUID?
    private let logSubsystem: String = "tv.sticky.boop"
    
    public init(application: String,
                instance: String = "default",
                isDevelopment: Bool = true,
                isDisabled: Bool = true,
                isSessionTrackingDisabled: Bool = false,
                isSendingSessionStartEvents: Bool = true,
                isSendingSessionFlopEvents: Bool = true,
                sessionTimeout: TimeInterval = 0,
                minimumViableSessionDuration: TimeInterval? = nil,
                firebaseConfigPath: String? = nil
    ) {
        let log = Logger(subsystem: logSubsystem, category: "init")
        
        var filePath: String? = firebaseConfigPath
        if filePath == nil {
            log.debug( "Firebase configuration path not specified. Attempting to locate GoogleService-Info.plist in main bundle...")
            filePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist")
        }
        guard let filePath = filePath else {
            fatalError("A Firebase configuration file (i.e. GoogleService-Info.plist) must be added to your project.")
        }
        
        let app = FirebaseApp.app()
        if app == nil {
            log.notice("Firebase has not been configured yet. Configuring...")
            if let options = FirebaseOptions(contentsOfFile: filePath) {
                FirebaseApp.configure(options: options)
                log.notice("Firebase has been configured with \(filePath)")
            } else {
                FirebaseApp.configure()
                log.notice("Firebase has been configured with default settings")
            }
        }
        
        self.db = Firestore.firestore()
        self.application = application
        self.isDevelopment = isDevelopment
        self.isDisabled = isDisabled
        self.instance = instance
        self.sessionTimeout = sessionTimeout
        self.minimumViableSessionDuration = minimumViableSessionDuration
        self.isSessionTrackingDisabled = isSessionTrackingDisabled
        self.isSendingSessionStartEvents = isSendingSessionStartEvents
        self.isSendingSessionFlopEvents = isSendingSessionFlopEvents
        self.didSessionStart = self.isSessionTrackingDisabled
    }
    
    public func trackEvent(event: String, label: String?, value: Any?, isUserInitiated: Bool = true) -> DocumentReference? {
        if self.isDisabled {
            return nil
        }
        
        if !self.isSessionTrackingDisabled,
           !self.didSessionStart,
           isUserInitiated,
           event != "Session Start",
           event != "App Launch",
           event != "Session Stop" {
            _ = self.trackSessionStart()
        }
        
        var eventData: [String: Any] = [
            "event": event,
            "label": label ?? NSNull(),
            "value": value ?? NSNull(),
            "instance": self.instance,
            "timestamp": Date()
        ]
        
        if !self.isSessionTrackingDisabled,
           event != "App Launch" {
            eventData["sessionId"] = self.sessionId?.uuidString ?? NSNull()
        }
        
        let log = Logger(subsystem: logSubsystem, category: "trackEvent")
        var ref: DocumentReference? = nil
        ref = db.collection(self.collection).addDocument(data: eventData) { err in
            if let err = err {
                log.error("Error adding document: \(err)")
            } else {
                if self.isDevelopment {
                    log.debug("Tracked event: \(ref!.documentID), \(eventData)")
                }
            }
        }
        return ref
    }
    
    public func trackAppLaunch(label: String? = nil, value: String? = nil) -> DocumentReference? {
        self.sessionId = nil
        self.sessionStart = Date()
        return self.trackEvent(event: "App Launch", label: label, value: value, isUserInitiated: false)
    }
    
    public func trackSessionStart() -> DocumentReference? {
        if self.isSessionTrackingDisabled {
            let log = Logger(subsystem: logSubsystem, category: "trackSessionStart")
            log.warning("You have set isSessionsTrackingDisabled to true. trackSessionStart() will not run. Did you mean to do this?")
            return nil
        }
        
        let label = "Minimum Session Timeout in Milliseconds"
        let value = Int(self.sessionTimeout * 1000)
        self.sessionId = UUID()
        self.sessionStart = Date()
        self.didSessionStart = true
        return self.isSendingSessionStartEvents ? self.trackEvent(event: "Session Start", label: label, value: value) : nil
    }
    
    public func trackSessionStop() -> DocumentReference? {
        if self.isSessionTrackingDisabled {
            let log = Logger(subsystem: logSubsystem, category: "trackSessionStop")
            log.warning("You have set isSessionsTrackingDisabled to true. trackSessionStop() will not run. Did you mean to do this?")
            return nil
        }
        
        if !self.didSessionStart {
            return nil
        }
        
        var label = "Session Duration in Milliseconds"
        if self.sessionTimeout > 0 {
            label += " (minus Timeout delay)"
        }
        
        let duration = self.currentSessionDuration
        let value = Int(duration * 1000)
        
        var event = "Session Stop"
        if let minimumDuration = self.minimumViableSessionDuration, duration < minimumDuration {
            if !isSendingSessionFlopEvents {
                let log = Logger(subsystem: logSubsystem, category: "trackSessionStop")
                log.warning("Session duration is below minimumViableSessionDuration, but isSendingSessionFlopEvents is false. Skipping Session Flop event.")
                return nil
            }
            event = "Session Flop"
        }
        return self.trackEvent(event: event, label: label, value: value, isUserInitiated: false)
    }
}
