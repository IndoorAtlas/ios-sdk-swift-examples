//
//  ImageViewController.swift
//
//  IndoorAtlas iOS SDK Swift Examples
//  Image View Example
//

import UIKit
import IndoorAtlas
import SVProgressHUD

// View controller for Image View Example
class ImageViewController: UIViewController, IALocationManagerDelegate {
    
    var floorPlan = IAFloorPlan()
    var imageView = UIImageView()
    var circle = UIView()
    var accuracyCircle = UIView()
    var manager = IALocationManager.sharedInstance()
    var resourceManager = IAResourceManager()
    
    var imageFetch:AnyObject!
    var floorplanFetch:AnyObject!
    
    var label = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Show spinner while waiting for location information from IALocationManager
        DispatchQueue.main.async {
            SVProgressHUD.show(withStatus: NSLocalizedString("Waiting for location data", comment: ""))
        }
    }
    
    // This function is called whenever new location is received from IALocationManager
    func indoorLocationManager(_ manager: IALocationManager, didUpdateLocations locations: [Any]) {
        
        SVProgressHUD.dismiss()
        
        // Conversion to IALocation
        let l = locations.last as! IALocation
        
        // The accuracy of coordinate position depends on the placement of floor plan image.
        let point = floorPlan.coordinate(toPoint: (l.location?.coordinate)!)
        
        
        guard let accuracy = l.location?.horizontalAccuracy else { return }
        let conversion = floorPlan.meterToPixelConversion
        
        let size = CGFloat(accuracy * Double(conversion))
        
        self.view.bringSubview(toFront: self.accuracyCircle)
        self.view.bringSubview(toFront: self.circle)
        
        // Animate circle with duration 0 or 0.35 depending if the circle is hidden or not
        UIView.animate(withDuration: self.circle.isHidden ? 0 : 0.35, animations: {
            self.accuracyCircle.center = point
            self.circle.center = point
            self.accuracyCircle.transform = CGAffineTransform(scaleX: CGFloat(size), y: CGFloat(size))

        })

        circle.isHidden = false
        accuracyCircle.isHidden = false
        
        if let traceId = manager.extraInfo?[kIATraceId] as? NSString {
            label.text = "TraceID: \n\(traceId)"
        }
    }
    
    func indoorLocationManager(_ manager: IALocationManager, didEnter region: IARegion) {
        
        // If the region type is different than kIARegionTypeFloorPlan app quits
        guard region.type == ia_region_type.iaRegionTypeFloorPlan else { return }
        
        // Fetches floorplan with the given region identifier
        fetchFloorplanWithId(region.identifier)
    }
    
    // Function to fetch floorplan with an ID
    func fetchFloorplanWithId(_ floorPlanId:String) {
        floorplanFetch = resourceManager.fetchFloorPlan(withId: floorPlanId) { (floorplan, error) in
            
            // If there is an error, print error. Else fetch the floorplan image with the floorplan URL
            if (error != nil) {
                print(error as Any)
                
            } else {
                self.imageFetch = self.resourceManager.fetchFloorPlanImage(with: (floorplan?.imageUrl)!, andCompletion: { (data, error) in
                    if (error != nil) {
                        print(error as Any)
                    } else {
                        
                        // Initialize the image with the data from the server
                        let image = UIImage.init(data: data!)
                        
                        // Scale the image and do CGAffineTransform
                        let scale = fmin(1.0, fmin(self.view.bounds.size.width / CGFloat((floorplan?.width)!), self.view.bounds.size.height / CGFloat((floorplan?.height)!)))
                        let t:CGAffineTransform = CGAffineTransform(scaleX: scale, y: scale)
                        self.imageView.transform = CGAffineTransform.identity
                        self.imageView.image = image
                        self.imageView.frame = CGRect(x: 0, y: 0, width: CGFloat((floorplan?.width)!), height: CGFloat((floorplan?.height)!))
                        self.imageView.transform = t
                        self.imageView.center = self.view.center
                        
                        self.imageView.backgroundColor = UIColor.white
                        
                        // Scale the blue dot as well
                        let size = CGFloat((floorplan?.meterToPixelConversion)!)
                        self.circle.transform = CGAffineTransform(scaleX: size, y: size)
                    }
                })
                
                self.floorPlan = floorplan!
            }
        }
    }
    
    // Authenticate to IndoorAtlas Services and request location updates
    func requestLocation() {
        
        // Point delegate to receiver
        manager.delegate = self
        
        // Initialize ResourceManager
        resourceManager = IAResourceManager(locationManager: manager)!
        
        // Request location updates
        manager.startUpdatingLocation()
    }
    
    // When view will appear add imageview, set up the circle and start requesting location
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        
        // Add imageview as a subview to the current view
        imageView.frame = view.frame
        view.addSubview(imageView)
        
        // Settings for the dot that is displayed on the image
        self.circle = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        self.circle.backgroundColor = UIColor.init(red: 22/255, green: 129/255, blue: 251/255, alpha: 1.0)
        self.circle.layer.cornerRadius = self.circle.frame.size.width / 2
        self.circle.layer.borderColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1).cgColor
        self.circle.layer.borderWidth = 0.1
        circle.isHidden = true
        
        self.accuracyCircle = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        self.accuracyCircle.layer.cornerRadius = accuracyCircle.frame.width / 2
        self.accuracyCircle.backgroundColor = UIColor(red: 22/255, green: 129/255, blue: 251/255, alpha: 0.2)
        self.accuracyCircle.isHidden = true
        self.accuracyCircle.layer.borderWidth = 0.005
        self.accuracyCircle.layer.borderColor = UIColor(red: 22/255, green: 129/255, blue: 251/255, alpha: 0.3).cgColor
        imageView.addSubview(self.accuracyCircle)
        imageView.addSubview(circle)

        label.frame = CGRect(x: 8, y: 24, width: view.bounds.width - 16, height: 34)
        label.textAlignment = NSTextAlignment.center
        label.adjustsFontSizeToFitWidth = true
        label.numberOfLines = 0
        view.addSubview(label)
        
        // Start requesting updates
        requestLocation()
    }
    
    // When view will disappear, stop updating location and dismiss SVProgressHUD
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        
        manager.stopUpdatingLocation()
        manager.delegate = nil
        imageView.image = nil
        
        label.removeFromSuperview()
        
        SVProgressHUD.dismiss()
    }
}
