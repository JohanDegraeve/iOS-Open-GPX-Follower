//
//  PreferencesTableViewControllerDelegate.swift
//  OpenGpxFollower
//
//  Based on Open GPX Tracker created by merlos on 24/10/15.
//

import Foundation

///
/// Delegate protocol of the view controller that displays the list of tile servers
///
///
protocol PreferencesTableViewControllerDelegate: AnyObject {
    
    /// User updated tile server
    func didUpdateTileServer(_ newGpxTileServer: Int)
    
    /// User updated the usage of the caché
    func didUpdateUseCache(_ newUseCache: Bool)
    
    /// User updated the usage of imperial units
    func didUpdateUseImperial(_ newUseImperial: Bool)
    
    /// User updated the activity type
    func didUpdateActivityType(_ newActivityType: Int)
    
    /// user changed device orientation in settings
    func didUpdateDeviceOrientationSetting()

}
