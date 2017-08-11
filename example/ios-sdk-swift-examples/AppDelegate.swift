//
//  AppDelegate.swift
//
//  IndoorAtlas iOS SDK Swift Examples
//

import UIKit
import IndoorAtlas

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        guard kAPIKey.characters.count > 0 || kAPISecret.characters.count > 0 else { print("Configure API key and API secret inside ApiKeys.swift"); return false}
        
        authenticateIALocationManager()
        
        return true
    }
    
    func authenticateIALocationManager() {
        
        // Get IALocationManager shared instance
        let manager = IALocationManager.sharedInstance()
    
        // Set IndoorAtlas API key and secret
        manager.setApiKey(kAPIKey, andSecret: kAPISecret)
    }
}

