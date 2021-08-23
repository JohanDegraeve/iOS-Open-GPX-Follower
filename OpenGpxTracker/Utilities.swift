//
//  Utilities.swift
//  OpenGpxTracker
//
//  Created by Johan Degraeve on 22/08/2021.
//

import UIKit

/// Displays an alert with a activity indicator view to indicate loading of gpx file to map
func displayLoadingFileAlert(viewController: UIViewController, _ loading: Bool, completion: (() -> Void)? = nil) {
    // setup of controllers and views
    let alertController = UIAlertController(title: NSLocalizedString("LOADING_FILE", comment: "no comment"), message: nil, preferredStyle: .alert)
    let activityIndicatorView = UIActivityIndicatorView(frame: CGRect(x: 35, y: 30, width: 32, height: 32))
    activityIndicatorView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    activityIndicatorView.style = .whiteLarge
    
    if #available(iOS 13, *) {
        activityIndicatorView.color = .blackAndWhite
    } else {
        activityIndicatorView.color = .black
    }
    
    if loading { // will display alert
        activityIndicatorView.startAnimating()
        alertController.view.addSubview(activityIndicatorView)
        
        viewController.present(alertController, animated: true, completion: nil)
    } else { // will dismiss alert
        activityIndicatorView.stopAnimating()
        viewController.presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    // if completion handler is used
    guard let completion = completion else { return }
    completion()
}


