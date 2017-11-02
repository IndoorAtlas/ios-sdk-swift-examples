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
    var camera: MKMapCamera? = nil
    var circle: MKCircle? = nil    
    var label = UILabel()
    
    // Manager for IALocationManager
    var manager = IALocationManager.sharedInstance()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Show spinner while waiting for location information from IALocationManager
        SVProgressHUD.show(withStatus: NSLocalizedString("Waiting for location data", comment: ""))
    }
    
    // This function is called whenever new location is received from IALocationManager
    func indoorLocationManager(_ manager: IALocationManager, didUpdateLocations locations: [Any]) {
        
        // Conversion to IALocation
        let l = locations.last as! IALocation
        
        // Check if there is newLocation and that it is not a nil
        if let newLocation = l.location?.coordinate {
            
            SVProgressHUD.dismiss()
            
            // Remove previous circle from the map and add new
            if (circle != nil) {
                map.remove(circle!)
            }
            circle = MKCircle(center: newLocation, radius: 1)
            map.add(circle!)
            
            if (camera == nil) {

                // Ask Map Kit for a camera that looks at the location from an altitude of 300 meters above the eye coordinates.
                camera = MKMapCamera(lookingAtCenter: (l.location?.coordinate)!, fromEyeCoordinate: (l.location?.coordinate)!, eyeAltitude: 300)
                
                // Assign the camera to your map view.
                map.camera = camera!;
            }
        }
        
        if let traceId = manager.extraInfo?[kIATraceId] as? NSString {
            label.text = "TraceID: \(traceId)"
        }
    }
    
    // This function is used for rendering the overlay components
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        
        var circleRenderer = MKCircleRenderer()
        
        // Try conversion to MKCircle for the overlay
        if let overlay = overlay as? MKCircle {
            
            // Set up circleRenderer for rending the circle
            circleRenderer = MKCircleRenderer(circle: overlay)
            circleRenderer.fillColor = UIColor(red: 0.08627, green: 0.5059, blue: 0.9843, alpha:1.0)
        }
        
        return circleRenderer
    }
    
    // Authenticate to IndoorAtlas services and request location updates
    func requestLocation() {
        
        // Point delegate to receiver
        manager.delegate = self
        
        // Request location updates
        manager.startUpdatingLocation()
    }
    
    // When the view will appear, set up the mapView and its delegate and start requesting location
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        map.frame = view.bounds
        view.addSubview(map)
        view.sendSubview(toBack: map)
        map.delegate = self
        
        label.frame = CGRect(x: 8, y: 14, width: view.bounds.width - 16, height: 42)
        label.textAlignment = NSTextAlignment.center
        label.adjustsFontSizeToFitWidth = true
        label.numberOfLines = 0
        view.addSubview(label)
        
        requestLocation()
    }
    
    // When the view will disappear, stop updating location, remove map from the view and dismiss the HUD
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        
        self.manager.stopUpdatingLocation()
        
        manager.delegate = nil
        map.delegate = nil
        map.removeFromSuperview()
        label.removeFromSuperview()
        
        SVProgressHUD.dismiss()
    }
}
