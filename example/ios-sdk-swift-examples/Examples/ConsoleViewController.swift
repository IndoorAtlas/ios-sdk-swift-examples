//
//  ConsoleViewController.swift
//
//  IndoorAtlas iOS SDK Swift Examples
//  Console Print Example
//

import UIKit
import IndoorAtlas
import SVProgressHUD

// View controller for Console Print Example
class ConsoleViewController: UIViewController, IALocationManagerDelegate {
    
    // Manager for IALocationManager
    var manager = IALocationManager()
    
    // Bool for checking if the HUD has been already changed to "Printing to console"
    var HUDstatusChanged = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Show spinner while waiting for location information from IALocationManager
        SVProgressHUD.showWithStatus(NSLocalizedString("Waiting for location", comment: ""))
    }
    
    // Hide status bar
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    // This function is called whenever new location is received from IALocationManager
    func indoorLocationManager(manager: IALocationManager, didUpdateLocations locations: [AnyObject]) {
        
        
        // Check if the HUD status is already changed to "Printing to console" if not, change it
        if !HUDstatusChanged {
            SVProgressHUD.showWithStatus(NSLocalizedString("Printing to console", comment: ""))
            HUDstatusChanged = true
        }
        
        // Convert last location to IALocation
        let l = locations.last as! IALocation
        
        // The accuracy of coordinate position depends on the placement of floor plan image.
        print("Position changed to coordinate (lat,lon): ", (l.location?.coordinate.latitude)!, (l.location?.coordinate.longitude)!)

    }
    
    // Authenticate to IndoorAtlas services and request location updates
    func requestLocation() {
        
        // Point delegate to receiver
        manager.delegate = self
        
        // Optionally, initial location
        let location: IALocation = IALocation(floorPlanId: kFloorplanId)
        manager.location = location
        
        // Request location updates
        manager.startUpdatingLocation()
    }
    
    // When view appears start requesting location updates
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        UIApplication.sharedApplication().statusBarHidden = true

        requestLocation()
    }
    
    // When view disappears dismiss SVProgressHUD and stop updating the location
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(true)
        
        manager.stopUpdatingLocation()
        manager.delegate = nil
        
        UIApplication.sharedApplication().statusBarHidden = false
        
        SVProgressHUD.dismiss()
    }
}

