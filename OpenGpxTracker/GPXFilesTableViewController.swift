//
//  GPXFilesTableViewController.swift
//  OpenGpxFollower
//
//  Based on Open GPX Tracker created by merlos on 14/09/14.
//
//  Localized by nitricware on 19/08/19.
//

import Foundation
import UIKit
import CoreGPX
import MessageUI

/// Text displayed when there are no GPX files in the folder.
let kNoFiles = NSLocalizedString("NO_FILES", comment: "no comment")

///
/// TableViewController that displays the list of files that have been saved in previous sessions.
///
/// This view controller allows users to manage their GPX Files.
///
/// Currently the following actions with a file are supported
///
/// 1. Send it by email
/// 2. Load in the map
/// 3. Delete the file
///
/// It also displays a button "Done" in the navigation bar to return to the map.
///
class GPXFilesTableViewController: UITableViewController, UINavigationBarDelegate {
   
    /// List of strings with the filenames.
    var fileList: NSMutableArray = [kNoFiles]
    
    /// Is there any GPX file in the directory?
    var gpxFilesFound = false
    
    /// Temporary variable to manage.
    var selectedRowIndex = -1
    
    ///
    weak var delegate: GPXFilesTableViewControllerDelegate?
    
    ///
    /// Setups the view controller.
    ///
    /// 1. Sets the title
    /// 2. Adds the "Done" button
    /// 3. Loads existing GPX File list.
    ///
    override func viewDidLoad() {
        super.viewDidLoad()
        let navBarFrame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: 64)
        self.tableView.frame = CGRect(x: navBarFrame.width + 1, y: 0, width: self.view.frame.width, height:
            self.view.frame.height - navBarFrame.height)
        
        self.title = NSLocalizedString("YOUR_FILES", comment: "no comment")
        
        // add notification observer for reloading table when file is added.
        addNotificationObservers()
        
        // Button to return to the map
        let addItem = UIBarButtonItem(title: NSLocalizedString("Add", comment: "no comment"),
                                        style: UIBarButtonItem.Style.plain,
                                        target: self,
                                        action: #selector(openAddGPXFileViewController))
        
        self.navigationItem.rightBarButtonItems = [addItem]
        
        // Get gpx files
        let list: [GPXFileInfo] = GPXFileManager.fileList
        if list.count != 0 {
            self.fileList.removeAllObjects()
            self.fileList.addObjects(from: list)
            self.gpxFilesFound = true
        }
    }
    
    /// Removes notfication observers
    deinit {
        removeNotificationObservers()
    }
    
    ///
    /// Displays the view controller to load gpx file from url
    ///
    @objc func openAddGPXFileViewController() {
        print("openAddGPXFileViewController")
        let vc = AddGPXFileViewController(nibName: nil, bundle: nil)
        vc.delegate = self
        let navController = UINavigationController(rootViewController: vc)
        self.present(navController, animated: true) { () -> Void in }
    }

    
    /// Disposes resources in case of a mermory warning.
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: Table view data source
    
    /// returns the number of sections. Always returns 1.
    override func numberOfSections(in tableView: UITableView?) -> Int {
        // Return the number of sections.
        return 1
    }

    /// Returns the number of files in the section.
    override func tableView(_ tableView: UITableView?, numberOfRowsInSection section: Int) -> Int {
        return fileList.count
    }

    /// Allow edit rows? Returns true only if there are files.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return gpxFilesFound
    }

    /// Displays the delete button.
    override func tableView(_ tableView: UITableView,
                            commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {
        
        if editingStyle == UITableViewCell.EditingStyle.delete {
            actionDeleteFileAtIndex((indexPath as NSIndexPath).row)
        }
    }

    /// Displays the name of the cell.
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        //let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as UITableViewCell
        if gpxFilesFound {
            
            let cell: UITableViewCell = UITableViewCell(style: UITableViewCell.CellStyle.subtitle, reuseIdentifier: "Cell")

            let gpxFileInfo = fileList.object(at: (indexPath as NSIndexPath).row) as! GPXFileInfo
            
            cell.textLabel?.text = gpxFileInfo.fileName


            return cell

        } else {
            let cell: UITableViewCell = UITableViewCell(style: UITableViewCell.CellStyle.subtitle, reuseIdentifier: "Cell")
            cell.textLabel?.text = fileList.object(at: (indexPath as NSIndexPath).row) as? NSString as String? ?? ""
            return cell
        }
    }

    /// Displays an action sheet with the actions for that file (Send it by email, Load in map and Delete).
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        let sheet = UIAlertController(title: nil, message: NSLocalizedString("SELECT_OPTION", comment: "no comment"), preferredStyle: .actionSheet)
        let mapOption = UIAlertAction(title: NSLocalizedString("LOAD_IN_MAP", comment: "no comment"), style: .default) { _ in
            self.actionLoadFileAtIndex(indexPath.row)
        }
        let shareOption = UIAlertAction(title: NSLocalizedString("SHARE", comment: "no comment"), style: .default) { _ in
            self.actionShareFileAtIndex(indexPath.row, tableView: tableView, indexPath: indexPath)
        }
        
        let cancelOption = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "no comment"), style: .cancel) { _ in
            self.actionSheetCancel(sheet)
        }
        
        let deleteOption = UIAlertAction(title: NSLocalizedString("DELETE", comment: "no comment"), style: .destructive) { _ in
            self.actionDeleteFileAtIndex(indexPath.row)
        }
        
        sheet.addAction(mapOption)
        sheet.addAction(shareOption)
        sheet.addAction(cancelOption)
        sheet.addAction(deleteOption)
        
        var cellRect = tableView.rectForRow(at: indexPath)
        cellRect.origin = CGPoint(x: 0, y: 0) // origin must be at 0 or sheet will display offset due to height of cell
        
        sheet.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath)
        sheet.popoverPresentationController?.sourceRect = cellRect
        
        self.present(sheet, animated: true) {
            print("Loaded actionSheet")
        }
    }

    // MARK: UITableView delegate methods
    
    /// Only highlight rows if there are files.
    override func tableView(_ tableView: UITableView,
                            shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return gpxFilesFound
    }
    
    /// Returns the name of the file in the `rowIndex` passed as parameter.
    internal func fileListObjectTitle(_ rowIndex: Int) -> String {
        // swiftlint:disable force_cast
        return (fileList.object(at: rowIndex) as! GPXFileInfo).fileName
    }
    
    //
    // MARK: Action Sheet - Actions
    //
    
    /// Cancel button is tapped.
    ///
    /// Does nothing, it only displays a log message.
    internal func actionSheetCancel(_ actionSheet: UIAlertController) {
        print("ActionSheet cancel")
    }

    /// Deletes from the disk storage the file of `fileList` at `rowIndex`.
    internal func actionDeleteFileAtIndex(_ rowIndex: Int) {

        guard let fileURL: URL = (fileList.object(at: rowIndex) as? GPXFileInfo)?.fileURL else {
            print("GPXFileTableViewController:: actionDeleteFileAtIndex: failed to get fileURL")
            return
        }
        GPXFileManager.removeFileFromURL(fileURL)
        
        //Delete from list and Table
        fileList.removeObject(at: rowIndex)
        let indexPath = IndexPath(row: rowIndex, section: 0)
        tableView.deleteRows(at: [indexPath], with: UITableView.RowAnimation.fade)
        tableView.reloadData()
    }

    /// Loads the GPX file that corresponds to rowIndex in fileList in the map.
    internal func actionLoadFileAtIndex(_ rowIndex: Int) {
        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.sync {
                displayLoadingFileAlert(viewController: self, true)
            }
            
            guard let gpxFileInfo: GPXFileInfo = (self.fileList.object(at: rowIndex) as? GPXFileInfo) else {
                print("GPXFileTableViewController:: actionLoadFileAtIndex(\(rowIndex)): failed to get fileURL")
                displayLoadingFileAlert(viewController: self, false)
                return
            }
            
            print("Load gpx File: \(gpxFileInfo.fileName)")
            guard let gpx = GPXParser(withURL: gpxFileInfo.fileURL)?.parsedData() else {
                print("GPXFileTableViewController:: actionLoadFileAtIndex(\(rowIndex)): failed to parse GPX file")
                displayLoadingFileAlert(viewController: self, false)
                return
            }
            
            DispatchQueue.main.sync {
                displayLoadingFileAlert(viewController: self, false) {
                    self.delegate?.didLoadGPXFileWithName(gpxRoot: gpx)
                    self.dismiss(animated: true, completion: nil)
                }
            }
        }

    }
    
    /// Shares file at `rowIndex`.
    internal func actionShareFileAtIndex(_ rowIndex: Int, tableView: UITableView, indexPath: IndexPath) {
        guard let gpxFileInfo: GPXFileInfo = (fileList.object(at: rowIndex) as? GPXFileInfo) else {
            print("Unable to get filename at row \(rowIndex), cannot respond to \(type(of: self))didSelectRowAt")
            return
        }
        print("GPXTableViewController: actionShareFileAtIndex")
        
        let activityViewController = UIActivityViewController(activityItems: [gpxFileInfo.fileURL], applicationActivities: nil)
        
        var cellRect = tableView.rectForRow(at: indexPath)
        cellRect.origin = CGPoint(x: 0, y: 0) // origin must be at 0 or sheet will display offset due to height of cell
        
        activityViewController.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath)
        activityViewController.popoverPresentationController?.sourceRect = cellRect
        
        // NOTE: As the activity view controller can be quite tall at times,
        //       the display of it may be offset automatically at times to ensure the activity view popup fits the screen.
        
        activityViewController.completionWithItemsHandler = {
            (activityType: UIActivity.ActivityType?, completed: Bool, returnedItems: [Any]?, error: Error?) in
            if !completed {
                // User canceled
                print("actionShareAtIndex: Cancelled")
                return
            }
            // User completed activity
            print("actionShareFileAtIndex: User completed activity")
        }
        self.present(activityViewController, animated: true, completion: nil)
    }
    
}

// MARK: - comply to AddGPXFileViewControllerDelegate

extension GPXFilesTableViewController: AddGPXFileViewControllerDelegate {
    
    func finishedLoadingGPXFile() {
        
        reloadTableData()
        
    }
    
}

// MARK: - why are these functions in an extension ?

///
/// Handles reloading of table view when file is added while user is still in current view.
///
extension GPXFilesTableViewController {
    
    ///
    /// Asks the system to notify the app on some events
    ///
    /// Current implementation requests the system to notify the app:
    ///
    ///  When a file is received from an external source, (i.e AirDrop)
    ///
    func addNotificationObservers() {
        let notificationCenter = NotificationCenter.default
        
        notificationCenter.addObserver(self, selector: #selector(reloadTableData),
                                       name: .didReceiveFileFromURL, object: nil)
    }
    
    ///
    /// Removes the notification observers
    ///
    func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    ///
    /// Reload Table View data
    ///
    /// For reloading table when a new file is added while user is in `GPXFileTableViewController`
    ///
    @objc func reloadTableData() {
        print("TableViewController: reloadTableData")
        let list: [GPXFileInfo] = GPXFileManager.fileList
        if self.fileList.count < list.count && list.count != 0 {
            self.fileList.removeAllObjects()
            self.fileList.addObjects(from: list)
            self.gpxFilesFound = true
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
}
