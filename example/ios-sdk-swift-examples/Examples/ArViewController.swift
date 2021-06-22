//
//  ArViewController.swift
//
//  IndoorAtlas iOS SDK Swift Examples
//  AR View Example
//

import Foundation
import IndoorAtlas
import SceneKit
import SceneKit.ModelIO
import ARKit
import SVProgressHUD

extension CLLocationCoordinate2D: Equatable {}
public func ==(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
    return (lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude)
}

class PaddingLabel: UILabel {
    @IBInspectable var topInset: CGFloat = 0
    @IBInspectable var bottomInset: CGFloat = 0
    @IBInspectable var leftInset: CGFloat = 10.0
    @IBInspectable var rightInset: CGFloat = 10.0
    
    override func drawText(in rect: CGRect) {
        let insets = UIEdgeInsets(top: topInset, left: leftInset, bottom: bottomInset, right: rightInset)
        super.drawText(in: rect.inset(by: insets))
    }
    
    override var intrinsicContentSize: CGSize {
        get {
            var contentSize = super.intrinsicContentSize
            contentSize.height += topInset + bottomInset
            contentSize.width += leftInset + rightInset
            return contentSize
        }
    }
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

class ARPOI {
    var object: IAARObject!
    var node: SCNNode! = SCNNode()
    var poi: IAPOI!
    
    init(_ poi: IAPOI, _ session: IAARSession) {
        self.poi = poi
        object = session.createPoi(poi.coordinate, floorNumber: Int32(poi.floor.level), heading: 0, zOffset: 0.75)
        let image = UIImage(named: "Models.scnassets/IA_AR_ad_framed.png")
        let material = SCNMaterial()
        material.diffuse.contents = image
        let bound = max(image!.size.width, image!.size.height)
        node.geometry = SCNPlane(width: image!.size.width / bound, height: image!.size.height / bound)
        node.geometry?.materials = [material]
    }
}

class ARViewController: UIViewController, IALocationManagerDelegate, ARSCNViewDelegate, ARSessionDelegate, UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource {
    private var arView: ARSCNView!
    private var target: SCNNode!
    private var arrow: SCNNode!
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
        
        let outline = SCNMaterial()
        outline.diffuse.contents = UIColor.white
        outline.cullMode = .front
        
        repeat {
            target = SCNScene(named: "Models.scnassets/finish.obj")!.rootNode.childNodes[0]
            target.geometry!.materials = [outline]
            let base = deepCopyNode(target)
            base.scale = SCNVector3(0.9, 0.9, 0.9)
            let material = SCNMaterial()
            material.diffuse.contents = UIImage(named: "Models.scnassets/finish.png")
            base.geometry!.materials = [material]
            target.addChildNode(base)
        } while (false)
        
        repeat {
            arrow = SCNScene(named: "Models.scnassets/arrow_stylish.obj")!.rootNode.childNodes[0]
            arrow.geometry!.materials = [outline]
            let base = deepCopyNode(arrow)
            base.scale = SCNVector3(0.9, 0.9, 0.9)
            let material = SCNMaterial()
            material.diffuse.contents = UIColor(red: 22/255, green: 129/255, blue: 251/255, alpha: 1.0)
            base.geometry!.materials = [material]
            arrow.addChildNode(base)
        } while (false)
        
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
            var matrix: simd_float4x4 = matrix_identity_float4x4;
            if (arSession.wayfindingTarget.updateModelMatrix(&matrix) == true) {
                target.simdWorldTransform = matrix
                target.scale = SCNVector3(scale * 1.5, scale * 1.5, scale * 1.5)
                target.opacity = distanceFade(target.position, arView.pointOfView!.position)
            }
            
            if (arSession.wayfindingCompassArrow.updateModelMatrix(&matrix) == true) {
                arrow.simdWorldTransform = matrix
                arrow.scale = SCNVector3(0.3, 0.3, 0.3)
            }
            
            var wnum = 0
            for waypoint in arSession.wayfindingTurnArrows ?? [] {
                if (waypoint.updateModelMatrix(&matrix) == true) {
                    if (waypoints.count <= wnum) { continue }
                    waypoints[wnum].simdWorldTransform = matrix
                    waypoints[wnum].scale = SCNVector3(scale, scale, scale)
                    waypoints[wnum].opacity = distanceFade(waypoints[wnum].position, arView.pointOfView!.position)
                    wnum = wnum + 1
                }
            }
            
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
            var matrix: simd_float4x4 = matrix_identity_float4x4;
            if (arSession.wayfindingTarget.updateModelMatrix(&matrix) == true) {
                arView.scene.rootNode.addChildNode(target)
            }
            
            if (arSession.wayfindingCompassArrow.updateModelMatrix(&matrix) == true) {
                arView.scene.rootNode.addChildNode(arrow)
            }
            
            var wnum = 0
            for waypoint in arSession.wayfindingTurnArrows ?? [] {
                if (waypoint.updateModelMatrix(&matrix) == true) {
                    if (waypoints.count <= wnum) {
                        var node: SCNNode;
                        if (waypoints.count > 0) {
                            node = waypoints[0].clone()
                        } else {
                            let outline = SCNMaterial()
                            outline.diffuse.contents = UIColor.white
                            outline.cullMode = .front
                            node = SCNScene(named: "Models.scnassets/arrow.obj")!.rootNode.childNodes[0]
                            node.geometry!.materials = [outline]
                            let base = deepCopyNode(node)
                            base.scale = SCNVector3(0.9, 0.9, 0.9)
                            let material = SCNMaterial()
                            material.diffuse.contents = UIColor.init(red: 95.0 / 255.0, green: 209.0 / 255.0, blue: 195.0 / 255.0, alpha: 1.0)
                            base.geometry!.materials = [material]
                            node.addChildNode(base)
                        }
                        waypoints.append(node)
                        assert(waypoints.count - 1 == wnum)
                    }
                    arView.scene.rootNode.addChildNode(waypoints[wnum])
                    wnum = wnum + 1
                }
            }
            
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
