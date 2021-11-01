//
//  ExampleTableViewController.swift
//
//  IndoorAtlas iOS SDK Swift Examples
//

import UIKit
import SVProgressHUD

class ExampleTableViewController: UITableViewController {
    
    var examplesList = [String]()
    
    @IBAction func unwindToMenu(_ segue: UIStoryboardSegue) {}
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadData()
        setUpHUD()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        get {
            return UIStatusBarStyle.lightContent
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // Loads the example titles which are same as segue IDs
    func loadData() {
        examplesList = ["Map View", "Image View"]
        if (ARViewController.isSupported()) {
            examplesList.append("AR View")
            examplesList.append("Third Party AR View")
        }
    }
    
    // Sets up the SVProgressHUD with a bit slower animation
    func setUpHUD() {
        SVProgressHUD.setFadeInAnimationDuration(0.6)
    }
    
    //
    // Normal table functions
    //
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return examplesList.count
    }
    
    // Sets the label texts for the table cells
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "ExampleTableViewCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! ExampleTableViewCell
        let example = examplesList[indexPath.row]
        cell.labelForExamples.text = example
        return cell
    }
    
    // Identifier is same as the name in examplesList, that way the segue can be performed easily
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let identifier = examplesList[indexPath.row]
        performSegue(withIdentifier: identifier, sender: nil)
    }
    
    // Sets the title of the section
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Positioning"
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
      let backItem = UIBarButtonItem()
      backItem.title = ""
      navigationItem.backBarButtonItem = backItem
    }
}
