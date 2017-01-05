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
    var manager = IALocationManager()
    var resourceManager = IAResourceManager()
    
    var imageFetch:AnyObject!
    var floorplanFetch:AnyObject!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Show spinner while waiting for location information from IALocationManager
        SVProgressHUD.show(withStatus: NSLocalizedString("Waiting for location data", comment: ""))
    }
    
    // Hide status bar
    override var prefersStatusBarHidden : Bool {
        return true
    }
    
    // This function is called whenever new location is received from IALocationManager
    func indoorLocationManager(_ manager: IALocationManager, didUpdateLocations locations: [AnyObject]) {
        
        SVProgressHUD.dismiss()
        
        // Conversion to IALocation
        let l = locations.last as! IALocation
        
        // The accuracy of coordinate position depends on the placement of floor plan image.
        let point = floorPlan.coordinate(toPoint: (l.location?.coordinate)!)
        
        // Animate circle with duration 0 or 0.35 depending if the circle is hidden or not
        UIView.animate(withDuration: self.circle.isHidden ? 0 : 0.35, animations: {
            self.circle.center = point
        }) 
        circle.isHidden = false
    }
    
    func indoorLocationManager(_ manager: IALocationManager, didEnter region: IARegion) {
        
        // If the region type is different than kIARegionTypeFloorPlan app quits
        guard region.type == kIARegionTypeFloorPlan else { return }
        
        // Fetches floorplan with the given region identifier
        fetchFloorplanWithId(region.identifier!)
    }
    
    // Function to fetch floorplan with an ID
    func fetchFloorplanWithId(_ floorPlanId:String) {
        floorplanFetch = resourceManager.fetchFloorPlan(withId: floorPlanId) { (floorplan, error) in
            
            // If there is an error, print error. Else fetch the floorplan image with the floorplan URL
            if (error != nil) {
                print(error)
                
            } else {
                self.imageFetch = self.resourceManager.fetchFloorPlanImage(with: (floorplan?.imageUrl)!, andCompletion: { (data, error) in
                    if (error != nil) {
                        print(error)
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
        
        // Optionally, initial location
        let location = IALocation(floorPlanId: kFloorplanId)
        manager.location = location
        
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
        circle = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        circle.backgroundColor = UIColor.init(colorLiteralRed: 0, green: 0.647, blue: 0.961, alpha: 1.0)
        circle.isHidden = true
        imageView.addSubview(circle)
        
        UIApplication.shared.isStatusBarHidden = true

        // Start requesting updates
        requestLocation()
    }
    
    // When view will disappear, stop updating location and dismiss SVProgressHUD
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        
        manager.stopUpdatingLocation()
        manager.delegate = nil
        imageView.image = nil
        
        UIApplication.shared.isStatusBarHidden = false
        
        SVProgressHUD.dismiss()
    }
}
