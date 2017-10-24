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
    
    @IBOutlet weak var logView: UITextView!
    
    // Manager for IALocationManager
    var manager = IALocationManager.sharedInstance()
    
    // Bool for checking if the HUD has been already changed to "Printing to console"
    var HUDstatusChanged = false
    
    var traceIdPrinted = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Show spinner while waiting for location information from IALocationManager
        SVProgressHUD.show(withStatus: NSLocalizedString("Waiting for location", comment: ""))
    }

    // This function is called whenever new location is received from IALocationManager
    func indoorLocationManager(_ manager: IALocationManager, didUpdateLocations locations: [Any]) {
        
        
        // Check if the HUD status is already changed to "Printing to console" if not, change it
        if !HUDstatusChanged {
            SVProgressHUD.dismiss()
            HUDstatusChanged = true
        }
        
        // Convert last location to IALocation
        let l = locations.last as! IALocation
        
        if !traceIdPrinted, let traceId = manager.extraInfo?[kIATraceId] as? NSString {
            addToLog("TraceID: \n\(traceId)")
            traceIdPrinted = true
        }
        
        // The accuracy of coordinate position depends on the placement of floor plan image.
        addToLog("Position changed to (lat, lon): \n\(l.location?.coordinate.latitude ?? 0.0), \(l.location?.coordinate.longitude ?? 0.0)")
    }
    
    func indoorLocationManager(_ manager: IALocationManager, didEnter region: IARegion) {
        switch region.type {
        case .iaRegionTypeVenue:
            addToLog("Entered venue: \n\(region.identifier)")
        case .iaRegionTypeFloorPlan:
            addToLog("Entered floor plan: \n\(region.identifier)")
        default:
            break
        }
    }
    
    func indoorLocationManager(_ manager: IALocationManager, didExitRegion region: IARegion) {
        switch region.type {
        case .iaRegionTypeVenue:
            addToLog("Exited venue: \n\(region.identifier)")
        case .iaRegionTypeFloorPlan:
            addToLog("Exited floor plan: \n\(region.identifier)")
        default:
            break
        }
    }
    
    // Authenticate to IndoorAtlas services and request location updates
    func requestLocation() {
        
        // Point delegate to receiver
        manager.delegate = self
        
        // Optionally, initial location
        if !kFloorplanId.isEmpty {
            let location = IALocation(floorPlanId: kFloorplanId)
            manager.location = location
        }
        
        // Request location updates
        manager.startUpdatingLocation()
    }
    
    // When view appears start requesting location updates
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        requestLocation()
    }
    
    // When view disappears dismiss SVProgressHUD and stop updating the location
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        
        manager.stopUpdatingLocation()
        manager.delegate = nil
                
        SVProgressHUD.dismiss()
    }
    
    func addToLog(_ text: String) {
        logView.text = logView.text + "\n\n\(text)"
    }
}

