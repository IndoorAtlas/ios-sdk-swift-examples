//
//  MapViewController.swift
//  ios-sdk-swift-examples
//
//  IndoorAtlas iOS SDK Swift Examples
//  IndoorAtlas Map View Example
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

// Function to convert degrees to radians
func degreesToRadians(_ x:Double) -> Double {
    return (Double.pi * x / 180.0)
}

// Class for map overlay object
class MapOverlay: NSObject, MKOverlay {
    var coordinate: CLLocationCoordinate2D
    var boundingMapRect: MKMapRect
    
    
    // Initializer for the class
    init(floorPlan: IAFloorPlan, andRotatedRect rotated: CGRect) {
        coordinate = floorPlan.center
        
        // Area coordinates for the overlay
        let topLeft = MKMapPoint(floorPlan.topLeft)
        boundingMapRect = MKMapRect(x: topLeft.x + Double(rotated.origin.x), y: topLeft.y + Double(rotated.origin.y), width: Double(rotated.size.width), height: Double(rotated.size.height))
    }
}

// Class for rendering map overlay objects
class MapOverlayRenderer: MKOverlayRenderer {
    var overlayImage: UIImage
    var floorPlan: IAFloorPlan
    var rotated: CGRect
    
    init(overlay:MKOverlay, overlayImage:UIImage, fp: IAFloorPlan, rotated: CGRect) {
        self.overlayImage = overlayImage
        self.floorPlan = fp
        self.rotated = rotated
        super.init(overlay: overlay)
    }
    
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in ctx: CGContext) {
        
        // Width and height in MapPoints for the floorplan
        let mapPointsPerMeter = MKMapPointsPerMeterAtLatitude(floorPlan.center.latitude)
        let rect = CGRect(x: 0, y: 0, width: Double(floorPlan.widthMeters) * mapPointsPerMeter, height: Double(floorPlan.heightMeters) * mapPointsPerMeter)
        ctx.translateBy(x: -rotated.origin.x, y: -rotated.origin.y)
        
        // Rotate around top left corner
        ctx.rotate(by: CGFloat(degreesToRadians(floorPlan.bearing)));
        
        // Draw the floorplan image
        UIGraphicsPushContext(ctx)
        overlayImage.draw(in: rect, blendMode: CGBlendMode.normal, alpha: 1.0)
        UIGraphicsPopContext();
    }
}

// View controller for Apple Maps Overlay Example
class MapViewController: UIViewController, IALocationManagerDelegate, MKMapViewDelegate, UIGestureRecognizerDelegate {

    var fpImage = UIImage()

    var map = MKMapView()
    var camera = MKMapCamera()
    var circle = MKCircle()
    var currentCircle: LocationAnnotation? = nil
    var currentAccuracyCircle: MKCircle? = nil
    var currentLocation: CLLocation? = nil
    var floorPlanOverlay: MapOverlay? = nil

    var updateCamera = true

    var floorPlan: IAFloorPlan?
    var locationManager = IALocationManager.sharedInstance()

    var rotated = CGRect()
    var label = UILabel()

    var routeLine: MKPolyline? = nil
    var lineView: MKPolylineRenderer? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        let pressRecognizer = UILongPressGestureRecognizer.init(target: self, action: #selector(handleLongPress(pressGesture:)))
        pressRecognizer.delegate = self
        self.view.addGestureRecognizer(pressRecognizer)

        // Show spinner while waiting for location information from IALocationManager
        SVProgressHUD.show(withStatus: NSLocalizedString("Waiting for location data", comment: ""))
    }

    // Function to change the map overlay
    func changeMapOverlay() {

        //Width and height in MapPoints for the floorplan
        let mapPointsPerMeter = MKMapPointsPerMeterAtLatitude(floorPlan!.center.latitude)
        let widthMapPoints = floorPlan!.widthMeters * Float(mapPointsPerMeter)
        let heightMapPoints = floorPlan!.heightMeters * Float(mapPointsPerMeter)

        let cgRect = CGRect(x: 0, y: 0, width: CGFloat(widthMapPoints), height: CGFloat(heightMapPoints))
        let a = degreesToRadians(self.floorPlan!.bearing)
        rotated = cgRect.applying(CGAffineTransform(rotationAngle: CGFloat(a)));
        floorPlanOverlay = MapOverlay(floorPlan: floorPlan!, andRotatedRect: rotated)
        map.addOverlay(floorPlanOverlay!)
        updateCircles()
    }

    // Function for rendering overlay objects
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        var circleRenderer:MKCircleRenderer!

        if let overlay = overlay as? MKPolyline {
            let polylineRenderer = MKPolylineRenderer.init(polyline: overlay)
            polylineRenderer.strokeColor = UIColor.init(red: 0.08627, green: 0.5059, blue: 0.9843, alpha: 0.7)
            polylineRenderer.lineWidth = 3

            return polylineRenderer
        }

        // If it is possible to convert overlay to MKCircle then render the circle with given properties. Else if the overlay is class of MapOverlay set up its own MapOverlayRenderer. Else render red circle.
        if let overlay = overlay as? MKCircle {
            circleRenderer = MKCircleRenderer(circle: overlay)
            circleRenderer.fillColor = UIColor(red: 0.08627, green: 0.5059, blue: 0.9843, alpha:0.4)
            return circleRenderer

        } else if overlay is MapOverlay {
            let overlayView = MapOverlayRenderer(overlay: overlay, overlayImage: fpImage, fp: floorPlan!, rotated: rotated)
            return overlayView

        } else {
            circleRenderer = MKCircleRenderer(overlay: overlay)
            circleRenderer.fillColor = UIColor.init(red: 1, green: 0, blue: 0, alpha: 1.0)
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
                map.removeOverlay(currentAccuracyCircle!)
            }
            
            currentAccuracyCircle = MKCircle(center: newLocation, radius: (l.location?.horizontalAccuracy)!)
            map.addOverlay(currentAccuracyCircle!)
            
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
            map.removeOverlay(currentAccuracyCircle!)
        }
        
        if currentCircle == nil {
            currentCircle = LocationAnnotation(locationType: .blueDot, radius: 25)
            map.addAnnotation(currentCircle!)
        }
        
        currentAccuracyCircle = MKCircle(center: (currentLocation?.coordinate)!, radius: (currentLocation?.horizontalAccuracy)!)
        map.addOverlay(currentAccuracyCircle!)
        currentCircle?.coordinate = (currentLocation?.coordinate)!
    }

    // Fetches image with the given IAFloorplan
    func fetchImage(_ floorPlan:IAFloorPlan) {
        
        DispatchQueue.global(qos: .userInitiated).async {
            let imageData = try? Data(contentsOf: floorPlan.imageUrl!)
            if (imageData == nil) {
                NSLog("Error fetching floor plan image")
            }
            // Bounce back to the main thread to update the UI
            DispatchQueue.main.async {
                self.fpImage = UIImage.init(data: imageData!)!
                self.changeMapOverlay()
            }
        }
    }
    
    func indoorLocationManager(_ manager: IALocationManager, didUpdate route: IARoute) {
        if hasArrivedToDestination(route: route) {
            self.locationManager.stopMonitoringForWayfinding()
            self.locationManager.lockIndoors(false)
            showToast(message: "You have arrived to destination")
            if routeLine != nil {
                map.removeOverlay(routeLine!)
            }
        } else {
            self.plotRoute(route: route)
        }
    }
    
    func hasArrivedToDestination(route:IARoute) -> Bool {
        if (route.legs.count == 0) {
            return false
        }
        let FINISH_THRESHOLD_METERS = 8.0
        var routeLength = 0.0
        for leg in route.legs {
            routeLength += leg.length
        }
        return routeLength < FINISH_THRESHOLD_METERS
    }

    func indoorLocationManager(_ manager: IALocationManager, didEnter region: IARegion) {
        switch region.type {
        case .iaRegionTypeVenue:
            showToast(message: "Enter venue \(region.venue!.name)")
        case .iaRegionTypeFloorPlan:
            updateCamera = true
            if (region.floorplan != nil) {
                self.floorPlan = region.floorplan!
                self.fetchImage(region.floorplan!)
            }
        default:
            return
        }
    }

    // Authenticate to IndoorAtlas services and request location updates
    func requestLocation() {

        locationManager.delegate = self
        
        // Set the desired accuracy of location updates to one of the following:
        // kIALocationAccuracyBest : High accuracy mode (default)
        // kIALocationAccuracyLow : Low accuracy mode, uses less power
        locationManager.desiredAccuracy = ia_location_accuracy.iaLocationAccuracyBest

        locationManager.startUpdatingLocation()
    }
    
    func indoorLocationManager(_ manager: IALocationManager, didExitRegion region: IARegion) {
        switch region.type {
        case .iaRegionTypeVenue:
            showToast(message: "Exit Venue \(region.venue!.name)")
        case .iaRegionTypeFloorPlan:
            if floorPlanOverlay != nil {
                map.removeOverlay(floorPlanOverlay!)
            }
        default:
            return
        }
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
        view.sendSubviewToBack(map)

        label.frame = CGRect(x: 8, y: 14, width: view.bounds.width - 16, height: 42)
        label.textAlignment = NSTextAlignment.center
        label.adjustsFontSizeToFitWidth = true
        label.numberOfLines = 0
        view.addSubview(label)

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
            map.removeOverlay(currentAccuracyCircle!)
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

    @objc func handleLongPress(pressGesture: UILongPressGestureRecognizer) {
        if pressGesture.state != UIGestureRecognizer.State.began { return }

        let touchPoint = pressGesture.location(in: map)
        let coord = map.convert(touchPoint, toCoordinateFrom: map)
        
        // Wayfinding requests are meaningful only when positioning on a floor plan
        if (self.floorPlan != nil && self.floorPlan!.floor != nil) {
            let req = IAWayfindingRequest()
            req.coordinate = coord
            req.floor = self.floorPlan!.floor!.level
            self.locationManager.lockIndoors(true)
            self.locationManager.startMonitoring(forWayfinding: req)
        }
    }


    func plotRoute(route:IARoute) {
        if route.legs.count == 0 { return }

        var coordinateArray = [CLLocationCoordinate2D]()
        var coord = CLLocationCoordinate2D()
        var leg = route.legs[0]

        coord.latitude = leg.begin.coordinate.latitude;
        coord.longitude = leg.begin.coordinate.longitude

        coordinateArray.append(coord)

        for i in 0..<route.legs.count {
            leg = route.legs[i]
            coord.latitude = leg.end.coordinate.latitude
            coord.longitude = leg.end.coordinate.longitude
            coordinateArray.append(coord)
        }

        if routeLine != nil {
            map.removeOverlay(routeLine!)
        }

        routeLine = MKPolyline.init(coordinates: coordinateArray, count: route.legs.count + 1)
        map.addOverlay(routeLine!)
    }
    
    
    func showToast(message : String) {
            
        let toastLabel = UILabel(frame: CGRect(x: self.view.frame.size.width/2 - 150, y: self.view.frame.size.height-40, width: 300, height: 35))
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        toastLabel.textColor = UIColor.white
        toastLabel.textAlignment = .center;
        toastLabel.font = UIFont(name: "Montserrat-Light", size: 12.0)
        toastLabel.text = message
        toastLabel.alpha = 0.8
        toastLabel.layer.cornerRadius = 10;
        toastLabel.clipsToBounds  =  true
        self.view.addSubview(toastLabel)
        UIView.animate(withDuration: 3.0, delay: 0.1, options: .curveEaseOut, animations: {
            toastLabel.alpha = 0.0
        }, completion: {(isCompleted) in
            toastLabel.removeFromSuperview()
        })
    }
}
