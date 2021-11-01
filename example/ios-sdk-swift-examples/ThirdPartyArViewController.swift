//
//  ArViewController.swift
//
//  IndoorAtlas iOS SDK Swift Examples
//  Third Party AR View Example
//

import Foundation
import IndoorAtlas
import SceneKit
import SceneKit.ModelIO
import ARKit
import SVProgressHUD

extension IALatLngFloor {
    var coordinate:CLLocationCoordinate2D { return CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

fileprivate func vec3Distance(_ a: SCNVector3, _ b: SCNVector3) -> Float {
    return hypot(hypot(a.x - b.x, a.y - b.y), a.z - b.z)
}

fileprivate func distanceFade(_ a: SCNVector3, _ b: SCNVector3) -> CGFloat {
    let FADE_END = Float(15.0)
    let FADE_START = Float(5.0)
    let dis = max(vec3Distance(a, b), FADE_START)
    return CGFloat((FADE_END - min(dis - FADE_START, FADE_END)) / FADE_END)
}

fileprivate func deepCopyNode(_ node: SCNNode) -> SCNNode {
    let clone = node.clone()
    clone.geometry = node.geometry?.copy() as? SCNGeometry
    if let g = node.geometry {
        clone.geometry?.materials = g.materials.map{ $0.copy() as! SCNMaterial }
    }
    return clone
}

class RouteBreadCrumb {
    var position:IALatLngFloor!
    var heading:Double!
    var elevation:Double!
    var node: SCNNode! = SCNNode()
    
    init(_ position:IALatLngFloor!, _ heading:Double!, _ elevation:Double!) {
        self.position = position
        self.heading = heading
        self.elevation = elevation
        
        node = deepCopyNode(SCNScene(named: "Models.scnassets/arrow_stylish.obj")!.rootNode.childNodes[0])
        node.scale = SCNVector3(0.1, 0.1, 0.1)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(red: 95.0/255.0, green: 209.0/255.0, blue: 195.0/255.0, alpha: 1.0)
        material.cullMode = .front
        node.geometry?.materials = [material]
    }
}

class ThirdPartyARViewController: UIViewController, IALocationManagerDelegate, ARSCNViewDelegate, ARSessionDelegate, UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource {
    private static let ROUTE_ELEVATION_FROM_FLOOR_M = 0.5
    private static let BREADCRUMB_DISTANCE_M = 1.0
    private static let AR_TRANSFORM_UPDATE_INTERVAL = 4.0
    
    private var arView: ARSCNView!
    private var indooratlas = IALocationManager.sharedInstance()
    private var waypoints: [SCNNode] = []
    private var pois: [ARPOI] = []
    private var floorPlan: IAFloorPlan? = nil
    private var infoLabel = PaddingLabel()
    private var wayfindingStartedYet = false
    private var wayfindingTarget: IAWayfindingRequest? = nil
    private var searchBar: UISearchBar?
    private var searchTableView: UITableView?
    private var searchDataSource: [ARPOI] = []
    private var statusBarBg = UIView()
    private var routeBreadCrumbs:[RouteBreadCrumb] = []
    private var lastArTransformUpdate:NSDate? = nil
    
    func statusBarHeight() -> CGFloat {
        let statusBarSize = UIApplication.shared.statusBarFrame.size
        return Swift.min(statusBarSize.width, statusBarSize.height)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Show spinner while waiting for location information from IALocationManager
        DispatchQueue.main.async {
            SVProgressHUD.show(withStatus: NSLocalizedString("Waiting for location data", comment: ""))
        }
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        arView = ARSCNView(frame: self.view.bounds)
        arView.showsStatistics = false
        arView.automaticallyUpdatesLighting = true
        arView.session.delegate = self
        arView.session.run(ARViewController.configuration())
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.delegate = self
        self.view.addSubview(arView)
        
        infoLabel.backgroundColor = UIColor.init(white: 0, alpha: 0.5)
        infoLabel.alpha = 0
        infoLabel.layer.cornerRadius = 18
        infoLabel.clipsToBounds = true
        infoLabel.text = "Walk 20 meters to any direction so we can orient you. Avoid pointing the camera at blank walls."
        infoLabel.textColor = .white
        infoLabel.textAlignment = .center
        infoLabel.numberOfLines = 5
        arView.addSubview(infoLabel)
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.widthAnchor.constraint(equalTo: arView.widthAnchor, constant: -8).isActive = true
        infoLabel.trailingAnchor.constraint(equalTo: arView.trailingAnchor, constant: -8 / 2).isActive = true
        infoLabel.heightAnchor.constraint(equalToConstant: 120).isActive = true
        infoLabel.topAnchor.constraint(equalTo: arView.topAnchor, constant: 88).isActive = true
        
        searchBar = UISearchBar()
        searchBar?.setBackgroundImage(UIImage(), for: .any, barMetrics: .default)
        searchBar?.searchBarStyle = .minimal
        searchBar?.placeholder = "Search POIs"
        searchBar?.sizeToFit()
        searchBar?.showsCancelButton = true
        searchBar?.delegate = self
        navigationItem.titleView = searchBar
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.view.backgroundColor = .clear
        searchTableView = UITableView(frame: self.view.bounds)
        searchTableView?.isHidden = true
        searchTableView?.dataSource = self
        searchTableView?.delegate = self
        self.view.addSubview(searchTableView!)
        statusBarBg.backgroundColor = .clear
        statusBarBg.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(statusBarBg)
        statusBarBg.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        statusBarBg.widthAnchor.constraint(equalTo: view.widthAnchor, constant: 0).isActive = true
        statusBarBg.heightAnchor.constraint(equalToConstant: statusBarHeight()).isActive = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        wayfindingStartedYet = false
        indooratlas.delegate = self
        indooratlas.startUpdatingLocation()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.setBackgroundImage(nil, for: .default)
        navigationController?.navigationBar.shadowImage = nil
        navigationController?.navigationBar.isTranslucent = false
        hideSearchTable()
        SVProgressHUD.dismiss()
        UIApplication.shared.isIdleTimerDisabled = false
        indooratlas.releaseArSession()
        indooratlas.stopUpdatingLocation()
        indooratlas.delegate = nil
        arView.session.pause()
    }
    
    static func configuration() -> ARConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.worldAlignment = .gravity
        return configuration
    }
    
    static func isSupported() -> Bool {
        return ARWorldTrackingConfiguration.isSupported
    }
    
    func updatePois(_ iapois: [IAPOI]?) {
        pois.removeAll()
        for poi in iapois ?? [] {
            pois.append(ARPOI(poi, indooratlas.arSession!))
        }
    }

    func indoorLocationManager(_ manager: IALocationManager, didEnter region: IARegion) {
        if (region.type == .iaRegionTypeFloorPlan) {
            floorPlan = region.floorplan
        } else if (region.type == .iaRegionTypeVenue) {
            SVProgressHUD.dismiss()
            updatePois(region.venue?.pois)
        }
    }
    
    func indoorLocationManager(_ manager: IALocationManager, didExitRegion region: IARegion) {
        if (region.type == .iaRegionTypeFloorPlan) {
            floorPlan = nil
        } else if (region.type == .iaRegionTypeVenue) {
            updatePois(nil)
        }
    }
    
    func indoorLocationManager(_ manager: IALocationManager, didUpdate route: IARoute) {
        // This is just ad-hoc example of how a route may be transformed into a list of
        // 3D objects ("breadcrumbs") along the route. The argument could be any 3rd party
        // wayfinding route as well
        var newList:[RouteBreadCrumb] = []
        var pathLength = ThirdPartyARViewController.BREADCRUMB_DISTANCE_M
        // iterate in reverse order so all the breadcrumbs do not move unnecessarily when the route is updated
        for leg in route.legs.reversed() {
            if leg.length < 1e-6 {
                continue
            }
            
            // this part is a bit tricky / ugly
            let e = leg.begin, b = leg.end // note: flipped due to reverse order
            var tmpMat = manager.arSession?.geo(toAr: b.coordinate, floorNumber: Int32(b.floor), heading: 0, zOffset: 0)
            let y0 = tmpMat!.columns.3[1]
            tmpMat = manager.arSession?.geo(toAr: e.coordinate, floorNumber: Int32(e.floor), heading: 0, zOffset: 0)
            let floorHeight = tmpMat!.columns.3[1] - y0
            while pathLength < leg.length {
                let s = pathLength / leg.length
                let rbc = RouteBreadCrumb(IALatLngFloor(latitude: (1 - s) * b.coordinate.latitude + s * e.coordinate.latitude, andLongitude: (1 - s) * b.coordinate.longitude + s * e.coordinate.longitude, andFloor: b.floor), leg.direction, ThirdPartyARViewController.ROUTE_ELEVATION_FROM_FLOOR_M + s * Double(floorHeight))
                newList.append(rbc)
                
                pathLength += ThirdPartyARViewController.BREADCRUMB_DISTANCE_M
            }
            pathLength -= leg.length
        }
        self.routeBreadCrumbs = newList
    }
    
    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        guard let frame = arView.session.currentFrame else { return }
        guard let arSession = indooratlas.arSession else { return }
        arSession.setCameraToWorldMatrix(frame.camera.viewMatrix(for: .portrait).inverse)
        
        var scale = Float(0.5);
        if let floorPlan = self.floorPlan {
            scale = (floorPlan.widthMeters * floorPlan.heightMeters) / 50.0
            scale = min(max(scale, 0.4), 1.5)
        }
        
        if (arSession.converged == true) {
            
            for rbc in routeBreadCrumbs {
                let modelMatrix = arSession.geo(toAr: rbc.position.coordinate, floorNumber: Int32(rbc.position.floor), heading: 0, zOffset: 0)
                rbc.node.simdWorldTransform = modelMatrix
                rbc.node.eulerAngles = SCNVector3Make(-Float.pi/2, 0, 0)
                rbc.node.scale = SCNVector3Make(scale, scale, scale)
                rbc.node.opacity = 1.0
                
            }
            
            var matrix: simd_float4x4 = matrix_identity_float4x4;
            for poi in pois {
                if (poi.object.updateModelMatrix(&matrix) == true) {
                    poi.node.simdWorldTransform = matrix
                    poi.node.scale = SCNVector3(scale, scale, scale)
                    poi.node.opacity = distanceFade(poi.node.position, arView.pointOfView!.position)
                    poi.node.look(at: arView.pointOfView!.position, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, 1))
                }
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        while let n = arView.scene.rootNode.childNodes.first { n.removeFromParentNode() }
        guard let arSession = indooratlas.arSession else { return }
        
        UIView.animate(withDuration: 0.25) {
            switch frame.camera.trackingState {
            case .normal:
                self.infoLabel.alpha = (arSession.converged ? 0 : 1)
                break
            default:
                self.infoLabel.alpha = 1
                break
            }
        }
        
        switch frame.camera.trackingState {
        case .normal:break
        default:return
        }
        
        for anchor in frame.anchors {
            guard let planeAnchor = anchor as? ARPlaneAnchor else { continue }
            if (planeAnchor.alignment != .horizontal) { continue }
            arSession.addPlane(withCenterX: planeAnchor.center.x, withCenterY: planeAnchor.center.y, withCenterZ: planeAnchor.center.z, withExtentX: planeAnchor.extent.x, withExtentZ: planeAnchor.extent.z)
        }
        
        arSession.setPoseMatrix(frame.camera.transform)
        
        if (arSession.converged == true) {
            
            for rbc in routeBreadCrumbs {
                arView.scene.rootNode.addChildNode(rbc.node)
            }

            var matrix: simd_float4x4 = matrix_identity_float4x4;
            for poi in pois {
                if (poi.poi.coordinate == wayfindingTarget?.coordinate) { continue }
                if let floorPlan = self.floorPlan {
                    if (floorPlan.floor?.level != poi.poi.floor.level) { continue }
                }
                if (poi.object.updateModelMatrix(&matrix) == true) {
                    arView.scene.rootNode.addChildNode(poi.node)
                }
            }
        }
        
        // Restart wayfinding if we didn't have an active AR session when we started it
        // This is needed for AR wayfinding to start properly as well
        if (!wayfindingStartedYet && wayfindingTarget != nil) {
            indooratlas.stopMonitoringForWayfinding()
            indooratlas.startMonitoring(forWayfinding: wayfindingTarget!)
            wayfindingStartedYet = true
        }
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        resetTracking()
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        resetTracking()
    }
    
    private func resetTracking() {
        arView.session.run(ARViewController.configuration(), options: [.resetTracking, .removeExistingAnchors])
    }
    
    func startWayfindingTo(_ dest: IAWayfindingRequest?) {
        wayfindingTarget = dest
        if dest != nil {
            indooratlas.startMonitoring(forWayfinding: dest!)
        }
    }
    
    func hideSearchTable() {
        UIView.animate(withDuration: 0.25, animations: {
            self.searchTableView?.alpha = 0
            self.navigationController?.navigationBar.backgroundColor = .clear
            self.statusBarBg.backgroundColor = .clear
        }) { (finished) in
            if finished {
                self.searchTableView?.isHidden = true
            }
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = nil
        searchBar.resignFirstResponder()
        hideSearchTable()
        startWayfindingTo(nil)
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchTableView?.alpha = 0
        searchTableView?.isHidden = false
        UIView.animate(withDuration: 0.25) {
            self.searchTableView?.alpha = 1
            self.navigationController?.navigationBar.backgroundColor = UIColor(red: 22/255, green: 129/255, blue: 251/255, alpha: 1.0)
            self.statusBarBg.backgroundColor = UIColor(red: 22/255, green: 129/255, blue: 251/255, alpha: 1.0)
        }
        self.searchBar(searchBar, textDidChange: "")
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchDataSource = pois.filter{
            if let name = $0.poi.name {
                return (searchText.isEmpty ? true : name.lowercased().contains(searchText.lowercased()))
            }
            return false
        }
        searchTableView?.reloadData()
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchDataSource.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "SearchCell")
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: "SearchCell")
        }
        let poi = self.searchDataSource[indexPath.row];
        cell?.textLabel?.text = poi.poi.name
        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        hideSearchTable()
        let poi = searchDataSource[indexPath.row]
        self.searchBar?.text = poi.poi.name
        self.searchBar?.resignFirstResponder()
        hideSearchTable()
        let dest = IAWayfindingRequest()
        dest.coordinate = poi.poi.coordinate
        dest.floor = poi.poi.floor.level
        startWayfindingTo(dest)
    }
}
