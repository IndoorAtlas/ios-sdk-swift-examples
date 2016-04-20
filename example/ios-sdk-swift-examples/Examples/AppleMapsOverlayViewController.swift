//
//  AppleMapsOverlayViewController.swift
//
//  IndoorAtlas iOS SDK Swift Examples
//  Apple Maps Overlay Example
//

import UIKit
import MapKit
import IndoorAtlas
import SVProgressHUD

// Class for map overlay object
class MapOverlay: NSObject, MKOverlay {
    var coordinate: CLLocationCoordinate2D
    var boundingMapRect: MKMapRect
    
    var center: CLLocationCoordinate2D
    var rect: MKMapRect
    
    // Initializer for the class
    init(floorPlan: IAFloorPlan) {
        coordinate = floorPlan.center
        boundingMapRect = MKMapRect()
        rect = MKMapRect()
        center = floorPlan.center
        
        //Width and height in MapPoints for the floorplan
        let mapPointsPerMeter = MKMapPointsPerMeterAtLatitude(center.latitude)
        let widthMapPoints = floorPlan.widthMeters * Float(mapPointsPerMeter)
        let heightMapPoints = floorPlan.heightMeters * Float(mapPointsPerMeter)
        
        // Area coordinates for the overlay
        let topLeft = MKMapPointForCoordinate(floorPlan.topLeft)
        rect = MKMapRectMake(topLeft.x, topLeft.y, Double(widthMapPoints), Double(heightMapPoints))
        boundingMapRect = rect
    }
}

// Class for rendering map overlay objects
class MapOverlayRenderer: MKOverlayRenderer {
    var overlayImage: UIImage
    var floorPlan: IAFloorPlan
    
    init(overlay:MKOverlay, overlayImage:UIImage, fp: IAFloorPlan) {
        self.overlayImage = overlayImage
        self.floorPlan = fp
        super.init(overlay: overlay)
    }
    
    override func drawMapRect(mapRect: MKMapRect, zoomScale: MKZoomScale, inContext ctx: CGContext) {
        
        let theMapRect = overlay.boundingMapRect
        let theRect = rectForMapRect(theMapRect)
        
        // Rotate around top left corner
        CGContextRotateCTM(ctx, CGFloat(degreesToRadians(floorPlan.bearing)));
        
        // Draw the floorplan image
        UIGraphicsPushContext(ctx)
        overlayImage.drawInRect(theRect, blendMode: CGBlendMode.Normal, alpha: 1.0)
        UIGraphicsPopContext();
    }
    
    // Function to convert degrees to radians
    func degreesToRadians(x:Double) -> Double {
        return (M_PI * x / 180.0)
    }
}


// View controller for Apple Maps Overlay Example
class AppleMapsOverlayViewController: UIViewController, IALocationManagerDelegate, MKMapViewDelegate {
    
    var floorPlanFetch:AnyObject!
    var imageFetch:AnyObject!
    
    var fpImage = UIImage()
    
    var map = MKMapView()
    var camera = MKMapCamera()
    var updateCamera = Bool()
    var circle = MKCircle()
    
    var floorPlan = IAFloorPlan()
    var locationManager = IALocationManager()
    var resourceManager = IAResourceManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Show spinner while waiting for location information from IALocationManager
        SVProgressHUD.showWithStatus(NSLocalizedString("Waiting for location data", comment: ""))
    }
    
    // Hide status bar
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    // Function to change the map overlay
    func changeMapOverlay() {
        let overlay = MapOverlay(floorPlan: floorPlan)
        map.addOverlay(overlay)
    }
    
    // Function for rendering overlay objects
    func mapView(mapView: MKMapView, rendererForOverlay overlay: MKOverlay) -> MKOverlayRenderer {
        var circleRenderer:MKCircleRenderer!
        
        // If it is possible to convert overlay to MKCircle then render the circle with given properties. Else if the overlay is class of MapOverlay set up its own MapOverlayRenderer. Else render red circle.
        if let overlay = overlay as? MKCircle {
            circleRenderer = MKCircleRenderer(circle: overlay)
            circleRenderer.fillColor = UIColor(colorLiteralRed: 0, green: 0.647, blue: 0.961, alpha: 1.0)
            return circleRenderer
            
        } else if overlay is MapOverlay {
            let overlayView = MapOverlayRenderer(overlay: overlay, overlayImage: fpImage, fp: floorPlan)
            return overlayView
            
        } else {
            circleRenderer = MKCircleRenderer(overlay: overlay)
            circleRenderer.fillColor = UIColor.init(colorLiteralRed: 1, green: 0, blue: 0, alpha: 1.0)
            return circleRenderer
        }
    }
    
    func indoorLocationManager(manager: IALocationManager, didUpdateLocations locations: [AnyObject]) {
        
        // Convert last location to IALocation
        let l = locations.last as! IALocation
        
        // Check that the location is not nil
        if let newLocation = l.location?.coordinate {
            
            SVProgressHUD.dismiss()
            
            // Remove the previous circle overlay and set up a new overlay
            map.removeOverlay(circle as MKOverlay)
            circle = MKCircle(centerCoordinate: newLocation, radius: 1)
            map.addOverlay(circle)
            
            // Ask Map Kit for a camera that looks at the location from an altitude of 300 meters above the eye coordinates.
            camera = MKMapCamera(lookingAtCenterCoordinate: (l.location?.coordinate)!, fromEyeCoordinate: (l.location?.coordinate)!, eyeAltitude: 300)
            
            // Assign the camera to your map view.
            map.camera = camera;
        }
    }
    
    // Fetches image with the given IAFloorplan
    func fetchImage(floorPlan:IAFloorPlan) {
        imageFetch = self.resourceManager.fetchFloorPlanImageWithUrl(floorPlan.imageUrl!, andCompletion: { (data, error) in
            if (error != nil) {
                print(error)
            } else {
                self.fpImage = UIImage.init(data: data!)!
                self.changeMapOverlay()
            }
        })
    }
    
    func indoorLocationManager(manager: IALocationManager, didEnterRegion region: IARegion) {
        
        guard region.type == kIARegionTypeFloorPlan else { return }
        
        updateCamera = true
        
        if (floorPlanFetch != nil) {
            floorPlanFetch.cancel()
            floorPlanFetch = nil
        }
        
        // Fetches the floorplan for the given region identifier
        floorPlanFetch = self.resourceManager.fetchFloorPlanWithId(region.identifier, andCompletion: { (floorplan, error) in
            
            if (error == nil) {
                self.floorPlan = floorplan!
                self.fetchImage(floorplan!)
            } else {
                print("There was an error during floorplan fetch: ", error)
            }
        })
    }
    
    // Authenticate to IndoorAtlas services and request location updates
    func requestLocation() {
        
        let location = IALocation(floorPlanId: kFloorplanId)
        locationManager.location = location
        
        locationManager.delegate = self
        
        resourceManager = IAResourceManager(locationManager: locationManager)!
        
        locationManager.startUpdatingLocation()
    }
    
    // Called when view will appear and sets up the map view and its bounds and delegate. Also requests location
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(true)
        updateCamera = true
        
        map = MKMapView()
        map.frame = view.bounds
        map.delegate = self
        view.addSubview(map)
        view.sendSubviewToBack(map)
        
        UIApplication.sharedApplication().statusBarHidden = true
        
        requestLocation()
    }
    
    // Called when view will disappear and will remove the map from the view and sets its delegate to nil
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(true)
        
        locationManager.stopUpdatingLocation()
        locationManager.delegate = nil
        
        map.delegate = nil
        map.removeFromSuperview()
        
        UIApplication.sharedApplication().statusBarHidden = false
        
        SVProgressHUD.dismiss()
    }
}
