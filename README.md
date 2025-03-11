# Boop

A convenience class for submitting events (boops) to a Firestore Database. Sticky Culture uses Boop to collect realtime usage data for interactive experiences.

## Usage

1. Create a Firestore application and add the configuration (i.e. "GoogleService-Info.plist") to your project.

1. Import `Boop` and initialize the configuration.

   ```swift
   import Boop

   let boop = Boop(application: "my-application")
   ```

   By default, Boop will try to use "GoogleService-Info.plist" from the main bundle path for configuration. If you have a different configuration file or location, you can specify the path manually.

   ```swift
   let path = Bundle.main.path(forResource: "My-Firebase-Config", ofType: "plist")
   let boop = Boop(application: "my-application", firebaseConfigPath: path)
   ```

   See documentation in Xcode for more configuration options.

1. Make boops.

   ```swift
   /// Report your app launch
   boop.trackAppLaunch()

   /// When a visitor starts playing with your app
   boop.trackSessionStart()

   /// When a visitor interacts with a button
   boop.trackEvent(event: "Tap", label: "Navigation Button", value: "Next")

   /// events can be simple or complex
   boop.trackEvent(event: "New Game")
   boop.trackEvent(event: "Status", label: "Player", value: ["id": "926F943D", "name": "Beep Beep", "score": 100])
   
   /// When the visitor has stopped playing with your app
   analytics.trackSessionStop()
   ```

1. Roll your own analytics solution to interpret the data 🤭
   
   Documents always have the following structure:

   | Field | Type | |
   | --- | --- | --- |
   | `instance` | `String` | Distinguishes multiple instances of the application, if needed |
   | `sessionId` | `UUID` | For grouping session data[^1]. Refreshed whenever `trackSessionStart()` is called |
   | `event` | `String` | "Session Start", "Session Stop", "Session Flop"[^2], "App Launch" or whatever |
   | `label` | `String?` | Optional, maybe it classifies the `value`? |
   | `value` | `Any?` | Whatever you want |
   | `timestamp` | `FirebaseFirestore.Timestamp` | When it happened (UTC) |

[^1]: Boop assumes session events occur synchronously on one device. It is not intended for tracking multiple, simultaneous sessions on one device.

[^2]: A "Session Flop" event is recorded when a session does not meet the minimum duration threshold as configured by the `minimumViableSessionDuration` property. You can disable recording these events by setting `minimumViableSessionDuration` to `nil` or `isSendingSessionFlopEvents` to `false`.