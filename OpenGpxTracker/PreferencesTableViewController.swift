//
//  PreferencesTableViewController.swift
//  OpenGpxFollower
//
//  Based on Open GPX Tracker created by merlos on 24/10/15.
//
//  Localized by nitricware on 19/08/19.
//

import Foundation
import UIKit
import CoreLocation
import MapCache
import MessageUI

/// Units Section Id in PreferencesTableViewController
let kUnitsSection = 0

/// Map Source Section Id in PreferencesTableViewController
let kMapSourceSection = 1

/// Activity Type Section Id in PreferencesTableViewController
let kActivityTypeSection = 2

let kDeviceOrientationSection = 3

/// developer settings
let kDeveloperSection = 4

/// Cell Id of the Use Imperial units in UnitsSection
let kUseImperialUnitsCell = 0

/// Cell Id for Use offline cache in CacheSection of PreferencesTableViewController
let kUseOfflineCacheCell = 0

/// Cell Id for Clear cache in CacheSection of PreferencesTableViewController
let kClearCacheCell = 1

let kSendTraceFileCell = 0

let traceFileDestinationAddress = "gpxfollower@proximus.be"

///
/// There are two preferences available:
///  * use or not cache
///  * select the map source (tile server)
///
/// Preferences are kept on UserDefaults with the keys `kDefaultKeyTileServerInt` (Int)
/// and `kDefaultUseCache`` (Bool)
///
class PreferencesTableViewController: UITableViewController {
    
    /// Delegate for this table view controller.
    weak var delegate: PreferencesTableViewControllerDelegate?
    
    /// Global Preferences
    var preferences: Preferences = Preferences.shared
    
    var cache: MapCache = MapCache(withConfig: MapCacheConfig(withUrlTemplate: ""))
    
    /// Does the following:
    /// 1. Defines the areas for navBar and the Table view
    /// 2. Sets the title
    /// 3. Loads the Preferences from defaults
    override func viewDidLoad() {
        super.viewDidLoad()
        let navBarFrame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: 64)
        //let navigationBar : UINavigationBar = UINavigationBar(frame: navBarFrame)
        self.tableView.frame = CGRect(x: navBarFrame.width + 1, y: 0, width: self.view.frame.width, height:
            self.view.frame.height - navBarFrame.height)
        
        self.title = NSLocalizedString("PREFERENCES", comment: "no comment")
        let shareItem = UIBarButtonItem(title: NSLocalizedString("DONE", comment: "no comment"),
                                        style: UIBarButtonItem.Style.plain, target: self,
                                        action: #selector(PreferencesTableViewController.closePreferencesTableViewController))
        self.navigationItem.rightBarButtonItems = [shareItem]
        
    }
    
    /// Close this controller.
    @objc func closePreferencesTableViewController() {
        print("closePreferencesTableViewController()")
        self.dismiss(animated: true, completion: { () -> Void in
        })
    }
    
    /// Loads data
    override func viewDidAppear(_ animated: Bool) {
        self.tableView.reloadData()
    }
    
    /// Does nothing for now.
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Table view data source
    
    /// Returns 4 sections: Units, Map Source, Activity Type and possibly developer
    override func numberOfSections(in tableView: UITableView?) -> Int {
        
        let numberOfSectionsExclusiveDeveloperSection = 4
        
        // Return the number of sections.
        if tracingEnabled {
            return numberOfSectionsExclusiveDeveloperSection + 1
        } else {
            return numberOfSectionsExclusiveDeveloperSection
        }

    }
    
    /// Returns the title of the existing sections.
    /// Uses `kUnitsSection`, `kMapSourceSection` and `kActivityTypeSection`
    /// for deciding which is the section title
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case kUnitsSection: return NSLocalizedString("UNITS", comment: "no comment")
        case kMapSourceSection: return NSLocalizedString("MAP_SOURCE", comment: "no comment")
        case kActivityTypeSection: return NSLocalizedString("ACTIVITY_TYPE", comment: "no comment")
        case kDeviceOrientationSection: return NSLocalizedString("DEVICE_ORIENTATION", comment: "no comment")
        case kDeveloperSection: return "Developer"

        default: fatalError("Unknown section")
        }
    }
    
    /// for `kUnitsSection` returns 1,
    /// for `kMapSourceSection` returns the number of tile servers defined in `GPXTileServer`,
    /// and for kActivityTypeSection returns `CLActivityType.count`
    override func tableView(_ tableView: UITableView?, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case kUnitsSection: return 1
        case kMapSourceSection: return GPXTileServer.count
        case kActivityTypeSection: return CLActivityType.count
        case kDeviceOrientationSection: return 5
        case kDeveloperSection: return 1

        default: fatalError("Unknown section")
        }
    }
    
    /// If the section is kMapSourceSection, it returns a chekmark cell with the name of
    /// the tile server in the  `indexPath.row` index in `GPXTileServer`. The cell is marked
    /// if `selectedTileServerInt` is the same as `indexPath.row`.
    ///
    /// If the section is kActivityTypeSection it returns a checkmark cell with the name
    /// and description of the CLActivityType whose indexPath.row matches with the activity type.
    ///
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = UITableViewCell(style: .value1, reuseIdentifier: "MapCell")
        
        // Units section
        if indexPath.section == kUnitsSection {
             switch indexPath.row {
             case kUseImperialUnitsCell:
                cell = UITableViewCell(style: .value1, reuseIdentifier: "CacheCell")
                cell.textLabel?.text = NSLocalizedString("USE_IMPERIAL_UNITS", comment: "no comment")
                if preferences.useImperial {
                    cell.accessoryType = .checkmark
                }
             default: fatalError("Unknown section")
            }
        }
        
        // Map Section
        if indexPath.section == kMapSourceSection {
            //cell.accessoryType = UITableViewCellAccessoryType.DetailDisclosureButton
            //cell.accessoryView = [[ UIImageView alloc ] initWithImage:[UIImage imageNamed:@"Something" ]];
            let tileServer = GPXTileServer(rawValue: indexPath.row)
            cell.textLabel?.text = tileServer!.name
            if indexPath.row == preferences.tileServerInt {
                cell.accessoryType = .checkmark
            }
        }
        
        // Activity type section
        if indexPath.section == kActivityTypeSection {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: "ActivityCell")
            let activity = CLActivityType(rawValue: indexPath.row + 1)!
            cell.textLabel?.text = activity.name
            cell.detailTextLabel?.text = activity.description
            if indexPath.row + 1 == preferences.locationActivityTypeInt {
                cell.accessoryType = .checkmark
            }
        }
        
        // device orientation sectin
        if indexPath.section == kDeviceOrientationSection {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: "ActivityCell")
            
            // 0 = automatic
            // 1 = portrait
            // 2 = portraitupsidedown
            // 3 = landscapeleft
            // 4 = landscaperight
            let orientation = UIDeviceOrientation(rawValue: indexPath.row)
            switch orientation?.rawValue {
            case 0: //0 is for unknown but let's use that for automatic, ie follow device orientation
                cell.textLabel?.text = NSLocalizedString("Automatic_Orientation", comment: "no comment")
            case 1:
                cell.textLabel?.text = NSLocalizedString("Portrait", comment: "no comment")
            case 2:
                cell.textLabel?.text = NSLocalizedString("Portrait Upside Down", comment: "no comment")
            case 3:
                cell.textLabel?.text = NSLocalizedString("Landscape Left", comment: "no comment")
            case 4:
                cell.textLabel?.text = NSLocalizedString("Landscape Right", comment: "no comment")
            default:
                cell.textLabel?.text = "unknown"
            }
            
            if indexPath.row == preferences.deviceOrientation {
                cell.accessoryType = .checkmark
            }
            
        }
        
        if indexPath.section == kDeveloperSection {
            
            cell = UITableViewCell(style: .value1, reuseIdentifier: "CacheCell")
            cell.textLabel?.text = "Send Trace File"
            cell.accessoryType = .none
            
        }
        
        return cell
    }
    
    /// Performs the following actions depending on the section and row selected:
    /// If the cell `kUseImperialUnitCell` in `kUnitsSection`it sets or unsets the use of imperial
    /// units (`useImperial` in `Preferences``and calls the delegate method `didUpdateUseImperial`.
    ///
    /// If a cell in kCacheSection is selected and the cell is
    ///     1. kUseOfflineCacheCell: Activates or desactivates the `useCache` in `Preferences`,
    ///        and calls the delegate method `didUpdateUseCache`
    ///     2. KClearCacheCacheCell: Clears the current cache and calls
    ///
    /// If a cell in `kMapSourceSection` is selected: Updates `tileServerInt` in `Preferences` and
    /// calls the delegate method `didUpdateTileServer`
    ///
    /// If a cell in `kActivitySection` is selected: Updates the `activityType` in `Preferences` and
    /// calls the delegate method `didUpdateActivityType`.
    ///
    /// In each case checks or unchecks the corresponding cell in the UI.
    ///
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if indexPath.section == kUnitsSection {
            switch indexPath.row {
            case kUseImperialUnitsCell:
                let newUseImperial = !preferences.useImperial
                preferences.useImperial = newUseImperial
                print("PreferencesTableViewController: toggle imperial units to \(newUseImperial)")
                //update cell UI
                tableView.cellForRow(at: indexPath)?.accessoryType = newUseImperial ? .checkmark : .none
                //notify the map
                self.delegate?.didUpdateUseImperial(newUseImperial)
            default:
                fatalError("didSelectRowAt: Unknown cell")
            }
        }
        
        if indexPath.section == kMapSourceSection { // section 1 (sets tileServerInt in defaults
            print("PreferenccesTableView Map Tile Server section Row at index:  \(indexPath.row)")
            
            //remove checkmark from selected tile server
            let selectedTileServerIndexPath = IndexPath(row: preferences.tileServerInt, section: indexPath.section)
            tableView.cellForRow(at: selectedTileServerIndexPath)?.accessoryType = .none
            
            //add checkmark to new tile server
            tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
            preferences.tileServerInt = indexPath.row
            
            //update map
            self.delegate?.didUpdateTileServer((indexPath as NSIndexPath).row)
        }
        
        if indexPath.section == kActivityTypeSection {
            print("PreferencesTableView Activity Type section Row at index:  \(indexPath.row + 1)")
            let selected = IndexPath(row: preferences.locationActivityTypeInt - 1, section: indexPath.section)
            
            tableView.cellForRow(at: selected)?.accessoryType = .none
            
            //add checkmark to new tile server
            tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
            preferences.locationActivityTypeInt = indexPath.row + 1 // +1 as activityType raw value starts at index 1
            
            self.delegate?.didUpdateActivityType((indexPath as NSIndexPath).row + 1)
        }
        
        if indexPath.section == kDeviceOrientationSection {
            print("PreferencesTableView Orientation section Row at index:  \(indexPath.row + 1)")
            
            let selected = IndexPath(row: preferences.deviceOrientation, section: indexPath.section)
            
            tableView.cellForRow(at: selected)?.accessoryType = .none
            
            //add checkmark to new orientation
            tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
            preferences.deviceOrientation = indexPath.row
            
            self.delegate?.didUpdateDeviceOrientationSetting()
        }
        
        if indexPath.section == kDeveloperSection {
            
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self
            mail.setToRecipients([traceFileDestinationAddress])
            mail.setMessageBody("See attachment", isHTML: true)
            
            // add all trace files as attachment
            let traceFilesInData = Trace.getTraceFilesInData()
            for (index, traceFileInData) in traceFilesInData.0.enumerated() {
                mail.addAttachmentData(traceFileInData as Data, mimeType: "text/txt", fileName: traceFilesInData.1[index])
            }
            
            self.present(mail, animated: true)

        }
        
        //unselect row
        tableView.deselectRow(at: indexPath, animated: true)
        
    }
}

extension PreferencesTableViewController: MFMailComposeViewControllerDelegate {
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        
        controller.dismiss(animated: true, completion: nil)
        
        switch result {
        
        case .cancelled:
            break
            
        case .sent, .saved:
            break
            
        case .failed:
            break
            
        @unknown default:
            break
            
        }
        
    }
    
}
