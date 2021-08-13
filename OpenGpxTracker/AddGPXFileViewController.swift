//
//  AddGPXFileViewController.swift
//  OpenGpxTracker
//
//  Created by Johan Degraeve on 06/08/2021.
//

import Foundation
import UIKit

fileprivate let tableViewCellReuseIdentifier = "LoadFileCell"

fileprivate let text_labelWithExplanation = "give URL to download GPX file"

fileprivate let userDefaultsKeyForUrlEnteredByUser = "urlEnteredByUser"

fileprivate let userDefaultsKeyForFilenameEnteredByUser = "filenameEnteredByUser"

fileprivate let defaults = UserDefaults.standard

class AddGPXFileViewController: UITableViewController, UITextFieldDelegate {
    
    
    
    /// text field for user to key in url where gpx can be downloaded
    var urlTextField = UITextField()

    /// temp storage for url (domain + path)
    var urlEnteredByUser = defaults.string(forKey: userDefaultsKeyForUrlEnteredByUser) ?? "" {
        
        didSet {
        
            defaults.setValue(urlEnteredByUser, forKey: userDefaultsKeyForUrlEnteredByUser)
            
        }
        
    }
    
    /// temp storage for filename (gpx extension)
    var filenameEnteredByUser = defaults.string(forKey: userDefaultsKeyForFilenameEnteredByUser) ?? "" {
        
        didSet {
            
            defaults.setValue(filenameEnteredByUser, forKey: userDefaultsKeyForFilenameEnteredByUser)
            
        }
        
    }

    /// AddGPXFileViewControllerDelegate
    weak var delegate: AddGPXFileViewControllerDelegate?
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.title = "Download file"
        
    }
    
    // MARK: - Table view data source
    
    /// Returns 2 sections for the moment
    /// - section 1 = the url  = domain + path, without filename
    /// - section 2 = the filename with extension gpx
    override func numberOfSections(in tableView: UITableView?) -> Int {

        return 2
        
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        switch section {
        
        case 0: return "URL (domain + path)"
            
        case 1: return "filename (.gpx)"

        default: fatalError("Unknown section")
            
        }
    }

    override func tableView(_ tableView: UITableView?, numberOfRowsInSection section: Int) -> Int {
        
        switch section {
        
        // section to give url
        // there's the textfield to let user give the url (domain + path)
        case 0: return 1
          
        // section to give filename
        // it's a textfield
        case 1: return 1
            
        default: fatalError("Unknown section")

        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        //let cell = tableView.dequeueReusableCell(withIdentifier: tableViewCellReuseIdentifier, for: indexPath)
        
        let cell = UITableViewCell(style: .value1, reuseIdentifier: tableViewCellReuseIdentifier)
        
        // section to give url (domain + path)
        if indexPath.section == 0 {
            
            switch indexPath.row {
            
            // textfield to set url (domain + path)
            case 0:
                cell.textLabel?.text = "URL"
                cell.detailTextLabel?.text = urlEnteredByUser
                
            default: fatalError("Unknown row")
                
            }
            
        }
        
        // section to give filename
        if indexPath.section == 1 {
            
            switch indexPath.row {
            
            // textfield to set filename
            case 0:
                cell.textLabel?.text = "File"
                cell.detailTextLabel?.text = filenameEnteredByUser
                
            default: fatalError("Unknown row")
                
            }
            
        }
        
        return cell
        
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 {
            
            switch indexPath.row {
            
            // textfield to set url (domain + path)
            case 0:
                let alert = UIAlertController(title: "Give URL", message: "Give URL only domain name + (optionally) the path, without filename", keyboardType: .URL, text: urlEnteredByUser, placeHolder: "", actionTitle: "Ok", cancelTitle: "Cancel", actionHandler: { (text:String) in
                    
                    self.urlEnteredByUser = text
                    
                    // do the action
                    //self.downloadGPX(siteUrl: self.urlEnteredByUser, completionHandler: {
                        
                    //})

                    
                }, cancelHandler: nil)
                
                // present the alert
                self.present(alert, animated: true, completion: nil)
            
                
            default: fatalError("Unknown section")
                
            }
            
        }
        
        if indexPath.section == 1 {
            
            switch indexPath.row {
            
            // textfield to set filename, clicking action button will load the file
            case 0:
                let alert = UIAlertController(title: "Give filename", message: "Give filename (.gpx)", keyboardType: .default, text: filenameEnteredByUser, placeHolder: "", actionTitle: "Load", cancelTitle: "Cancel", actionHandler: { (text:String) in
                    
                    self.filenameEnteredByUser = text
                    
                    // check if url ends on "/", if not add it
                    if (!(self.urlEnteredByUser.last == "/")) {
                        
                        self.urlEnteredByUser = self.urlEnteredByUser + "/"
                        
                    }
                    
                    // check if filename ends on .gpx, if not add it
                    if (!(self.filenameEnteredByUser.hasSuffix(".gpx"))) {
                        
                        self.filenameEnteredByUser = self.filenameEnteredByUser + ".gpx"
                        
                    }
                    
                    self.downloadGPX(siteUrl: self.urlEnteredByUser + self.filenameEnteredByUser, completionHandler: { (text, error) in
                        
                        if let text = text {
                            
                            // save the contents of file with name filenameEnteredByUser
                            GPXFileManager.save(self.filenameEnteredByUser, gpxContents: text)
                            
                            // inform delegate that table should refreshed
                            self.delegate?.finishedLoadingGPXFile()
                            
                            // close the viewcontroller
                            self.dismiss(animated: true, completion: nil)

                        }
                        
                        if let error = error {
                            
                            let alertController = UIAlertController(title: "Download Failed", message: error, actionHandler: nil)
                            
                            self.present(alertController, animated: true, completion: nil)
                            
                        }
                        
                    })
                    
                    
                }, cancelHandler: nil)
                
                // present the alert
                self.present(alert, animated: true, completion: nil)
                
            default: fatalError("Unknown section")
                
            }
            
        }
        
    }
    
    /// - parameters:
    ///     - url : url as given by user
    ///     - completionhandler : first string = text, if successfully downloaded, second string = error if failed
    private func downloadGPX(siteUrl: String, completionHandler:@escaping (String?, String?) -> ()) {
      
        var newUrl = siteUrl
        
        if (!newUrl.starts(with: "http") && !newUrl.starts(with: "https")) {
            
            newUrl = "https://" + newUrl
            
        }
        
        if let url = URL(string: newUrl) {
                
            let task = URLSession.shared.dataTask(with: url, completionHandler: { data, response, error in
                
                print("AddGPXFileViewController : in downloadGPX, finished task")
                
                if let error = error {
                    
                    print("AddGPXFileViewController : in downloadGPX, error = \(error.localizedDescription)")
                    
                    // call completionHandler on main thread
                    DispatchQueue.main.sync {
                        
                        completionHandler(nil, error.localizedDescription)

                    }
                    
                    return
                    
                }
                
                if let httpResponse = response as? HTTPURLResponse ,
                   httpResponse.statusCode != 200, let data = data {
                    
                    let errorMessage = String(data: data, encoding: String.Encoding.utf8)!
                    
                    print("AddGPXFileViewController : in downloadGPX, error = \(errorMessage)")
                    
                    // call completionHandler on main thread
                    DispatchQueue.main.sync {
                        
                        completionHandler(nil, errorMessage)
                        
                    }
                    
                    return
                    
                } else {
                    
                    print("AddGPXFileViewController : in downloadGPX, successful")
                    
                    if let data = data {

                        if let dataAsString = String(data: data, encoding: String.Encoding.utf8) {
                            
                            print("    response from download = \(dataAsString)")
                            
                            // call completionHandler on main thread
                            DispatchQueue.main.sync {
                                
                                completionHandler(dataAsString, nil)
                                
                            }

                        }

                    }
                    
                    return
                    
                }
                
            })
            
            task.resume()
            
        }
       
    }
    
}
