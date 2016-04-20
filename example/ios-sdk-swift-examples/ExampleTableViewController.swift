//
//  ExampleTableViewController.swift
//
//  IndoorAtlas iOS SDK Swift Examples
//

import UIKit
import SVProgressHUD

class ExampleTableViewController: UITableViewController {
    
    var examplesList = [String]()
    
    @IBAction func unwindToMenu(segue: UIStoryboardSegue) {}
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UIApplication.sharedApplication().statusBarStyle = UIStatusBarStyle.LightContent
        

        loadData()
        setUpHUD()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // Loads the example titles which are same as segue IDs
    func loadData() {
        examplesList = ["Console Print", "Image View", "Apple Maps", "Apple Maps Overlay"]
    }
    
    // Sets up the SVProgressHUD with a bit slower animation
    func setUpHUD() {
        SVProgressHUD.setFadeInAnimationDuration(0.6)
    }
    
    //
    // Normal table functions
    //
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return examplesList.count
    }
    
    // Sets the label texts for the table cells
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cellIdentifier = "ExampleTableViewCell"
        let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as! ExampleTableViewCell
        let example = examplesList[indexPath.row]
        cell.labelForExamples.text = example
        return cell
    }
    
    // Identifier is same as the name in examplesList, that way the segue can be performed easily
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let identifier = examplesList[indexPath.row]
        performSegueWithIdentifier(identifier, sender: nil)
    }
    
    // Sets the title of the section
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Positioning"
    }
}
