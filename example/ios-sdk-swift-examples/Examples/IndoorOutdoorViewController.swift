//
//  AppleMapsOverlayViewController.swift
//
//  IndoorAtlas iOS SDK Swift Examples
//  Apple Maps Indoor-Outdoor Example
//

import UIKit
import MapKit
import IndoorAtlas
import SVProgressHUD

// Blue dot & accuracy circle annotation class
class LocationAnnotation: MKPointAnnotation {
    enum LocationType {
        case blueDot
        case accuracyCircle
    }
    
    var radius: Double
    var locationType: LocationType
    
    required init(locationType: LocationType, radius: Double) {
        self.radius = radius
        self.locationType = locationType
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// View controller for Apple Maps Overlay Example
class IndoorOutdoorViewController: UIViewController, IALocationManagerDelegate, MKMapViewDelegate {
    
    var floorPlanFetch:IAFetchTask!
    var imageFetch:AnyObject!
    
    var fpImage = UIImage()
    
    var map = MKMapView()
    var camera = MKMapCamera()
    var circle = MKCircle()
    var currentCircle: LocationAnnotation? = nil
    var currentAccuracyCircle: MKCircle? = nil
    var currentLocation: CLLocation? = nil
    var flooorPlanOverlay: MapOverlay? = nil
    var updateCamera = true
    
    var floorPlan = IAFloorPlan()
    var locationManager = IALocationManager.sharedInstance()
    var resourceManager = IAResourceManager()
    
    var rotated = CGRect()
    
    var label = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Show spinner while waiting for location information from IALocationManager
        SVProgressHUD.show(withStatus: NSLocalizedString("Waiting for location data", comment: ""))
    }
    
    // Function to change the map overlay
    func changeMapOverlay() {
        
        //Width and height in MapPoints for the floorplan
        let mapPointsPerMeter = MKMapPointsPerMeterAtLatitude(floorPlan.center.latitude)
        let widthMapPoints = floorPlan.widthMeters * Float(mapPointsPerMeter)
        let heightMapPoints = floorPlan.heightMeters * Float(mapPointsPerMeter)
        
        let cgRect = CGRect(x: 0, y: 0, width: CGFloat(widthMapPoints), height: CGFloat(heightMapPoints))
        let a = degreesToRadians(self.floorPlan.bearing)
        rotated = cgRect.applying(CGAffineTransform(rotationAngle: CGFloat(a)));
        flooorPlanOverlay = MapOverlay(floorPlan: floorPlan, andRotatedRect: rotated)
        map.add(flooorPlanOverlay!)
        updateCircles()
    }
    
    // Function for rendering overlay objects
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        var circleRenderer:MKCircleRenderer!
        
        // If it is possible to convert overlay to MKCircle then render the circle with given properties. Else if the overlay is class of MapOverlay set up its own MapOverlayRenderer. Else render red circle.
        if overlay is MapOverlay {
            let overlayView = MapOverlayRenderer(overlay: overlay, overlayImage: fpImage, fp: floorPlan, rotated: rotated)
            return overlayView
            
        } else {
            circleRenderer = MKCircleRenderer(overlay: overlay)
            circleRenderer.fillColor = UIColor.init(red: 0.08627, green: 0.5059, blue: 0.9843, alpha: 0.4)
            return circleRenderer
        }
    }
    
    func indoorLocationManager(_ manager: IALocationManager, didUpdateLocations locations: [Any]) {
        
        // Convert last location to IALocation
        let l = locations.last as! IALocation
        
        // Check that the location is not nil
        if let newLocation = l.location?.coordinate {
            
            SVProgressHUD.dismiss()
            currentLocation = l.location
            
            if currentAccuracyCircle != nil {
                map.remove(currentAccuracyCircle!)
            }
            
            currentAccuracyCircle = MKCircle(center: newLocation, radius: (l.location?.horizontalAccuracy)!)
            map.add(currentAccuracyCircle!)
            
            // Remove the previous circle overlay and set up a new overlay
            if currentCircle == nil {
                currentCircle = LocationAnnotation(locationType: .blueDot, radius: 25)
                map.addAnnotation(currentCircle!)
            }
            currentCircle?.coordinate = newLocation
            
            if updateCamera {
                // Ask Map Kit for a camera that looks at the location from an altitude of 300 meters above the eye coordinates.
                camera = MKMapCamera(lookingAtCenter: (l.location?.coordinate)!, fromEyeCoordinate: (l.location?.coordinate)!, eyeAltitude: 300)
                
                // Assign the camera to your map view.
                map.camera = camera
                updateCamera = false
            }
        }
        
        if let traceId = manager.extraInfo?[kIATraceId] as? NSString {
            label.text = "TraceID: \(traceId)"
        }
    }
    
    func updateCircles() {
        if currentAccuracyCircle != nil {
            map.remove(currentAccuracyCircle!)
        }
        
        if currentCircle == nil {
            currentCircle = LocationAnnotation(locationType: .blueDot, radius: 25)
            map.addAnnotation(currentCircle!)
        }
        
        currentAccuracyCircle = MKCircle(center: (currentLocation?.coordinate)!, radius: (currentLocation?.horizontalAccuracy)!)
        map.add(currentAccuracyCircle!)
        currentCircle?.coordinate = (currentLocation?.coordinate)!
    }
    
    // Fetches image with the given IAFloorplan
    func fetchImage(_ floorPlan:IAFloorPlan) {
        imageFetch = self.resourceManager.fetchFloorPlanImage(with: floorPlan.imageUrl!, andCompletion: { (data, error) in
            if (error != nil) {
                print(error as Any)
            } else {
                self.fpImage = UIImage.init(data: data!)!
                self.changeMapOverlay()
            }
        })
    }
    
    func indoorLocationManager(_ manager: IALocationManager, didEnter region: IARegion) {
        
        switch region.type {
        case .iaRegionTypeVenue:
            map.showsUserLocation = false
            showToast(text: "Enter region \(region.identifier)")

        case .iaRegionTypeFloorPlan:
            
            updateCamera = true
            
            if (floorPlanFetch != nil) {
                floorPlanFetch.cancel()
                floorPlanFetch = nil
            }
            
            // Fetches the floorplan for the given region identifier
            floorPlanFetch = self.resourceManager.fetchFloorPlan(withId: region.identifier, andCompletion: { (floorplan, error) in
                
                if (error == nil) {
                    self.floorPlan = floorplan!
                    self.fetchImage(floorplan!)
                } else {
                    print("There was an error during floorplan fetch: ", error as Any)
                }
            })
        default:
            return
        }
    }
    
    func indoorLocationManager(_ manager: IALocationManager, didExitRegion region: IARegion) {
        switch region.type {
        case .iaRegionTypeVenue:
            showToast(text: "Exit Venue \(region.identifier)")
            map.showsUserLocation = true
            if currentCircle != nil {
                map.removeAnnotation(currentCircle!)
            }
            if currentAccuracyCircle != nil {
                map.remove(currentAccuracyCircle!)
            }
        case .iaRegionTypeFloorPlan:
            if flooorPlanOverlay != nil {
                map.remove(flooorPlanOverlay!)
            }
        default:
            return
        }
    }
    // Authenticate to IndoorAtlas services and request location updates
    func requestLocation() {
        
        locationManager.delegate = self
        
        resourceManager = IAResourceManager(locationManager: locationManager)!
        
        locationManager.startUpdatingLocation()
    }
    
    // Called when view will appear and sets up the map view and its bounds and delegate. Also requests location
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        updateCamera = true
        
        map = MKMapView()
        map.frame = view.bounds
        map.delegate = self
        map.isPitchEnabled = false
        view.addSubview(map)
        view.sendSubview(toBack: map)
        
        label.frame = CGRect(x: 8, y: 14, width: view.bounds.width - 16, height: 42)
        label.textAlignment = NSTextAlignment.center
        label.adjustsFontSizeToFitWidth = true
        label.numberOfLines = 0
        view.addSubview(label)
        
        
        map.showsUserLocation = true
        
        requestLocation()
    }
    
    // Called when view will disappear and will remove the map from the view and sets its delegate to nil
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        
        locationManager.stopUpdatingLocation()
        locationManager.delegate = nil
        
        map.delegate = nil
        map.removeFromSuperview()
        label.removeFromSuperview()
        
        SVProgressHUD.dismiss()
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        if currentCircle != nil {
            map.removeAnnotation(currentCircle!)
        }
        if currentAccuracyCircle != nil {
            map.remove(currentAccuracyCircle!)
        }
        
        let span = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        let location = CLLocationCoordinate2D(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
        let region = MKCoordinateRegion(center: location, span: span)
        
        map.setRegion(region, animated: true)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? LocationAnnotation {
            var type = ""
            let color = UIColor(red: 0, green: 125/255, blue: 1, alpha: 1)
            var alpha: CGFloat = 1.0
            
            var borderWidth:CGFloat = 0
            var borderColor = UIColor(red: 0, green: 30/255, blue: 80/255, alpha: 1)
            
            switch annotation.locationType {
            case LocationAnnotation.LocationType.blueDot:
                type = "blueDot"
                borderColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
                borderWidth = 3
            case LocationAnnotation.LocationType.accuracyCircle:
                type = "accuracyCircle"
                alpha = 0.2
                borderWidth = 0 // 1
            default:
                break
            }
            
            let annotationView: MKAnnotationView = map.dequeueReusableAnnotationView(withIdentifier: type) ?? MKAnnotationView.init(annotation: annotation, reuseIdentifier: type)
            
            annotationView.annotation = annotation
            annotationView.frame = CGRect(x: 0, y: 0, width: annotation.radius, height: annotation.radius)
            annotationView.backgroundColor = color
            annotationView.alpha = alpha
            annotationView.layer.borderWidth = borderWidth
            annotationView.layer.borderColor = borderColor.cgColor
            annotationView.layer.cornerRadius = annotationView.frame.size.width / 2
            
            let mask = CAShapeLayer()
            mask.path = UIBezierPath(ovalIn: annotationView.frame).cgPath
            annotationView.layer.mask = mask
            
            return annotationView
            
        }
        return nil
    }
    
    func showToast(text:String) {
        let toastLabel =
            UILabel(frame:
                CGRect(x: view.frame.size.width/2 - 150,
                       y: view.frame.size.height/2 - 40,
                       width: 300,
                       height: 35))
        toastLabel.backgroundColor = UIColor.black
        view.addSubview(toastLabel)
        toastLabel.alpha = 1.0
        toastLabel.layer.cornerRadius = 10;
        toastLabel.clipsToBounds = true
        
        let textLabel = UILabel(frame: CGRect(x: toastLabel.frame.origin.x + 10, y: toastLabel.frame.origin.y - 2, width: toastLabel.frame.size.width - 20, height: toastLabel.frame.size.height))
        textLabel.text = text
        textLabel.textColor = UIColor.white
        textLabel.textAlignment = NSTextAlignment.center
        textLabel.adjustsFontSizeToFitWidth = true
        textLabel.clipsToBounds = true
        
        view.addSubview(textLabel)
        UIView.animate(withDuration: 5.0, animations: {
            toastLabel.alpha = 0.0
        }, completion:{ (finished) in
            toastLabel.removeFromSuperview()
            textLabel.removeFromSuperview()
        } )
    }
}
