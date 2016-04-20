//
//  AppleMapsViewController.swift
//
//  IndoorAtlas iOS SDK Swift Examples
//  Apple Maps Example
//

import UIKit
import MapKit
import IndoorAtlas
import SVProgressHUD

// View controller for Apple Maps Example
class AppleMapsViewController: UIViewController, IALocationManagerDelegate, MKMapViewDelegate {
    
    var map = MKMapView()
    var camera = MKMapCamera()
    var circle = MKCircle()
    
    // Manager for IALocationManager
    var manager = IALocationManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Show spinner while waiting for location information from IALocationManager
        SVProgressHUD.showWithStatus(NSLocalizedString("Waiting for location data", comment: ""))
    }
    
    // Hide status bar
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    // This function is called whenever new location is received from IALocationManager
    func indoorLocationManager(manager: IALocationManager, didUpdateLocations locations: [AnyObject]) {
        
        // Conversion to IALocation
        let l = locations.last as! IALocation
        
        // Check if there is newLocation and that it is not a nil
        if let newLocation = l.location?.coordinate {
            
            SVProgressHUD.dismiss()
            
            // Remove all previous overlays from the map and add new
            map.removeOverlays(map.overlays)
            circle = MKCircle(centerCoordinate: newLocation, radius: 2)
            map.addOverlay(circle)
            
            // Ask Map Kit for a camera that looks at the location from an altitude of 300 meters above the eye coordinates.
            camera = MKMapCamera(lookingAtCenterCoordinate: (l.location?.coordinate)!, fromEyeCoordinate: (l.location?.coordinate)!, eyeAltitude: 300)
            
            // Assign the camera to your map view.
            map.camera = camera;
        }
    }
    
    // This function is used for rendering the overlay components
    func mapView(mapView: MKMapView, rendererForOverlay overlay: MKOverlay) -> MKOverlayRenderer {
        
        var circleRenderer = MKCircleRenderer()
        
        // Try conversion to MKCircle for the overlay
        if let overlay = overlay as? MKCircle {
            
            // Set up circleRenderer for rending the circle
            circleRenderer = MKCircleRenderer(circle: overlay)
            circleRenderer.fillColor = UIColor(colorLiteralRed: 0, green: 0.647, blue: 0.961, alpha: 1.0)
        }
        
        return circleRenderer
    }
    
    // Authenticate to IndoorAtlas services and request location updates
    func requestLocation() {
        
        // Point delegate to receiver
        manager.delegate = self
        
        // Optionally initial location
        let location: IALocation = IALocation(floorPlanId: kFloorplanId)
        manager.location = location
        
        // Request location updates
        manager.startUpdatingLocation()
    }
    
    // When the view will appear, set up the mapView and its delegate and start requesting location
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        map.frame = view.bounds
        view.addSubview(map)
        view.sendSubviewToBack(map)
        map.delegate = self
        
        UIApplication.sharedApplication().statusBarHidden = true
        
        requestLocation()
    }
    
    // When the view will disappear, stop updating location, remove map from the view and dismiss the HUD
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(true)
        
        self.manager.stopUpdatingLocation()
        
        manager.delegate = nil
        map.delegate = nil
        map.removeFromSuperview()
        
        UIApplication.sharedApplication().statusBarHidden = false

        
        SVProgressHUD.dismiss()
    }
}
