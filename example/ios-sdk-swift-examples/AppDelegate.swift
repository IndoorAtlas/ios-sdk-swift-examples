//
//  AppDelegate.swift
//
//  IndoorAtlas iOS SDK Swift Examples
//

import UIKit
import IndoorAtlas
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, CLLocationManagerDelegate {

    var window: UIWindow?
    let locationManager = CLLocationManager()
    let notificationCenter = UNUserNotificationCenter.current()
    let notificationId = "beacon-wakeup"
    var beaconRegion: CLBeaconRegion?
    
    let notification: UNNotificationContent = {
        let notification = UNMutableNotificationContent()
        notification.title = "Beacon wake up"
        notification.body = "Known beacon was detected in the proximity"
        notification.sound = UNNotificationSound.default
        return notification
    }()
    
    func clearBeaconNotification() {
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [notificationId])
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationId])
    }
    
    func showBeaconNotification() {
        // NOTE: The notification does not show up after device restart, the app must be launched by a user at least once
        //       The app seems to be launched by the operating system, but won't allow local notification to be shown
        //       Maybe this can be worked around with push notification instead?
        let request = UNNotificationRequest(identifier: notificationId, content: notification, trigger: nil)
        notificationCenter.add(request) { (error) in
            if (error != nil) {
                print("notificationCenter.add error: \(error!)")
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        if (region == beaconRegion) {
            if (state == .inside) {
                print("Wake up beacon is in range")
                showBeaconNotification()
            } else if (state == .outside) {
                print("Wake up beacon is out of range")
                clearBeaconNotification()
            }
        }
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Beacon wake up example
        // It is important to have all this code in the didFinishLaunchingWithOptions: method, so the wake up works in all cases:
        // - Foreground, Background, Terminated state, Device reboot
        if (!kBeaconWakeupUuid.isEmpty) {
            // 1. Setup delegate for didEnterRegion: and didExitRegion: callbacks
            locationManager.delegate = self
            
            // 2. Request authorization to the NotificationCenter
            notificationCenter.requestAuthorization(options: [.alert, .sound]) { (result, error) in
                if (error != nil) {
                    print("notificationCenter.requestAuthorization error: \(error!)")
                }
            }
            
            // 3. Ensure app is using always authorization
            locationManager.requestAlwaysAuthorization()
            
            // 4. Start monitoring for the beacons
            let uuid = UUID(uuidString: kBeaconWakeupUuid)
            if #available(iOS 13.0, *) {
                beaconRegion = CLBeaconRegion(beaconIdentityConstraint: CLBeaconIdentityConstraint(uuid: uuid!), identifier: kBeaconWakeupUuid)
            } else {
                beaconRegion = CLBeaconRegion(proximityUUID: uuid!, identifier: kBeaconWakeupUuid)
            }
            beaconRegion!.notifyEntryStateOnDisplay = true
            beaconRegion!.notifyOnEntry = true
            beaconRegion!.notifyOnExit = true
            locationManager.startMonitoring(for: beaconRegion!)
        }
        
        if (kAPIKey.isEmpty) {
            fatalError("Configure API key inside ApiKeys.swift")
        }
        
        authenticateIALocationManager()
        
        return true
    }
    
    func authenticateIALocationManager() {
        
        // Get IALocationManager shared instance
        let manager = IALocationManager.sharedInstance()

        // Set IndoorAtlas API key
        manager.setApiKey(kAPIKey, andSecret: "")
        
        // Allows testing IndoorAtlas in background mode
        // See: https://developer.apple.com/documentation/xcode/configuring-background-execution-modes
        if let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as! Array<String>? {
            if (modes.contains("location")) {
                manager.allowsBackgroundLocationUpdates = true
            }
        }
    }
}

