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
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        guard kAPIKey.count > 0 else { print("Configure API key inside ApiKeys.swift"); return false}
        
        authenticateIALocationManager()
        
        return true
    }
    
    func authenticateIALocationManager() {
        
        // Get IALocationManager shared instance
        let manager = IALocationManager.sharedInstance()
    
        // Set IndoorAtlas API key
        manager.setApiKey(kAPIKey, andSecret: "")
    }
}

