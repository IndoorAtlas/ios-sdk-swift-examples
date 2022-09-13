//
//  AppDelegate.swift
//
//  IndoorAtlas iOS SDK Swift Examples
//

import UIKit
import IndoorAtlas
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, CLLocationManagerDelegate, IALocationManagerDelegate {

    var window: UIWindow?
    let locationManager = CLLocationManager()
    let notificationCenter = UNUserNotificationCenter.current()
    let notificationId = "beacon-wakeup"
    var beaconRegions: Array<CLRegion> = []
    var dwellingRegions: Set<CLRegion> = []
    
    let notification: UNNotificationContent = {
        let notification = UNMutableNotificationContent()
        notification.title = "Beacon wake up"
        notification.body = "Known beacon was detected in the proximity"
        notification.sound = UNNotificationSound.default
        return notification
    }()
    
    func sendDebugMessage(_ msg: String) {
        print(msg)
        if (!kBeaconWakeupDebugServer.isEmpty) {
            var request = URLRequest(url: URL(string: kBeaconWakeupDebugServer)!)
            request.httpMethod = "PUT"
            request.httpBody = Data(msg.utf8)
            NSURLConnection.sendAsynchronousRequest(request, queue: OperationQueue()) {
                _, __, ___ in
            }
        }
    }
    
    func clearBeaconNotification() {
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [notificationId])
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationId])
    }
    
    func showBeaconNotification() {
        // NOTE: The notification does not show up after device restart, the app must be launched by a user at least once
        //       The app seems to be launched by the operating system, but won't allow local notification to be shown
        //       Maybe this can be worked around with push notification instead?
        notificationCenter.getDeliveredNotifications(completionHandler: { (notifications) in
            for n in notifications {
                if (n.request.identifier == self.notificationId) {
                    return
                }
            }
            let request = UNNotificationRequest(identifier: self.notificationId, content: self.notification, trigger: nil)
            self.notificationCenter.add(request) { (error) in
                if (error != nil) {
                    print("notificationCenter.add error: \(error!)")
                }
            }
        })
    }
    
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        if (beaconRegions.contains(region)) {
            let wasDwelling = !dwellingRegions.isEmpty
            
            if (state == .inside) {
                sendDebugMessage("A wake up beacon is in range: \(region.identifier)")
                dwellingRegions.insert(region)
                showBeaconNotification()
            } else if (state == .outside) {
                sendDebugMessage("A wake up beacon disappeared: \(region.identifier)")
                dwellingRegions.remove(region)
            }
            
            if (wasDwelling != !dwellingRegions.isEmpty) {
                if (dwellingRegions.isEmpty) {
                    sendDebugMessage("All wake up beacons are out of range")
                    clearBeaconNotification()
                }
            }
        }
    }
    
    func indoorLocationManager(_ manager: IALocationManager, didUpdate locations: [IALocation]) {
        let l = locations.last!
        sendDebugMessage("loc: \(l.location!.coordinate.latitude), \(l.location!.coordinate.longitude) \(l.floor?.level ?? 0)")
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        sendDebugMessage("applicationDidBecomeActive")
        clearBeaconNotification()
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        sendDebugMessage("applicationWillTerminate")
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        sendDebugMessage("application:didFinishLaunchingWithOptions:")
        
        // Beacon wake up example
        // It is important to have all this code in the didFinishLaunchingWithOptions: method, so the wake up works in all cases:
        // - Foreground, Background, Terminated state, Device reboot
        if (!kBeaconWakeupUuids.isEmpty) {            
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
            for uuidStr in kBeaconWakeupUuids {
                let uuid = UUID(uuidString: uuidStr)!
                let beaconRegion: CLBeaconRegion = {
                    if #available(iOS 13.0, *) {
                        return CLBeaconRegion(beaconIdentityConstraint: CLBeaconIdentityConstraint(uuid: uuid), identifier: uuidStr)
                    } else {
                        return CLBeaconRegion(proximityUUID: uuid, identifier: uuidStr)
                    }
                }()
                beaconRegion.notifyEntryStateOnDisplay = true
                beaconRegion.notifyOnEntry = true
                beaconRegion.notifyOnExit = true
                beaconRegions.append(beaconRegion)
                locationManager.startMonitoring(for: beaconRegion)
            }
        }
        
        if (kAPIKey.isEmpty) {
            fatalError("Configure API key inside ApiKeys.swift")
        }
        
        authenticateIALocationManager()
        
        // This code is here only to demonstrate that IA can run in the background with wake up beacons
        // If you open any sample, they will hijack the IALocationManager delegate
        if (!kBeaconWakeupUuids.isEmpty && !kBeaconWakeupDebugServer.isEmpty) {
            let manager = IALocationManager.sharedInstance()
            manager.delegate = self
            manager.lockIndoors(true)
            manager.startUpdatingLocation()
        }
        
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

