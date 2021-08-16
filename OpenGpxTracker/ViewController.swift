//
//  ViewController.swift
//  OpenGpxFollower
//
//  Based on Open GPX Tracker created by merlos on 13/09/14.
//
//  Localized by nitricware on 19/08/19.
//
// update to make it a gpx follower in stead of tracker by Johan Degraeve 13/08/2021 at later

import UIKit
import CoreLocation
import MapKit
import CoreGPX

/// determines automatic zooming, if value is for example 1, and I'm moving at 30 km/h, then the top of the screen is 500 meter away
let reachTopOfScreenInMinutes = 1.5

/// minimum distance of top of screen in meters
let minimumTopOfScreenInMeters = 500.0

/// maximum amount to store in measuredSpeads
let maxMeasuredSpeads = 7

/// delta's to apply to latitude longitude (tests show that at 100 km/h the value 0.018 is reached, so to reach 0.058 you would need to drive at 300 km/h
let latitudeLongitudeDeltas = [0.001, 0.003, 0.005, 0.006, 0.007, 0.008, 0.009, 0.010, 0.0110, 0.012, 0.013, 0.014, 0.015, 0.016, 0.017, 0.018, 0.019, 0.020, 0.021, 0.022, 0.023, 0.024, 0.025, 0.026, 0.027, 0.028, 0.029, 0.030, 0.031, 0.032, 0.033, 0.034, 0.035, 0.036, 0.037, 0.038, 0.039, 0.040, 0.041, 0.042, 0.043, 0.044, 0.045, 0.046, 0.047, 0.048, 0.049, 0.050, 0.051, 0.052, 0.053, 0.054, 0.055, 0.056, 0.057, 0.058]

let pauzeUdateMapCenterAfterGestureEndForHowManySeconds = 30.0

/// White color for button background
let kWhiteBackgroundColor: UIColor = UIColor(red: 254.0/255.0, green: 254.0/255.0, blue: 254.0/255.0, alpha: 0.90)

/// Text to display when the system is not providing coordinates.
let kNotGettingLocationText = NSLocalizedString("NO_LOCATION", comment: "no comment")

/// Text to display unknown accuracy
let kUnknownAccuracyText = "±···"

/// Text to display unknown speed.
let kUnknownSpeedText = "·.··"

/// Size for small buttons
let kButtonSmallSize: CGFloat = 48.0

/// Size for large buttons
let kButtonLargeSize: CGFloat = 96.0

/// Separation between buttons
let kButtonSeparation: CGFloat = 6.0

/// Upper limits threshold (in meters) on signal accuracy.
let kSignalAccuracy6 = 6.0
/// Upper limits threshold (in meters) on signal accuracy.
let kSignalAccuracy5 = 11.0
/// Upper limits threshold (in meters) on signal accuracy.
let kSignalAccuracy4 = 31.0
/// Upper limits threshold (in meters) on signal accuracy.
let kSignalAccuracy3 = 51.0
/// Upper limits threshold (in meters) on signal accuracy.
let kSignalAccuracy2 = 101.0
/// Upper limits threshold (in meters) on signal accuracy.
let kSignalAccuracy1 = 201.0

/// to measure the average speeds
var measuredSpeads = [Double]()

/// current index in latitueLongitudedeltas, default 2
var currentLongitudedeltaIndex = 2

///
/// Main View Controller of the Application. It is loaded when the application is launched
///
/// Displays a map and a set the buttons to control the tracking
///
///
class ViewController: UIViewController, UIGestureRecognizerDelegate {
    
    /// location manager instance configuration
    let locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.requestAlwaysAuthorization()
        manager.activityType = CLActivityType(rawValue: Preferences.shared.locationActivityTypeInt)!
        print("Chosen CLActivityType: \(manager.activityType.name)")
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 2 //meters
        manager.headingFilter = 3 //degrees (1 is default)
        manager.pausesLocationUpdatesAutomatically = false
        if #available(iOS 9.0, *) {
            manager.allowsBackgroundLocationUpdates = true
        }
        return manager
    }()
    
    /// Map View
    var map: GPXMapView
    
    /// Map View delegate 
    let mapViewDelegate = MapViewDelegate()
    

    /// Name of the last file that was saved (without extension)
    var lastGpxFilename: String = ""
    
    /// Status variable that indicates if the app was sent to background.
    var wasSentToBackground: Bool = false
    
    /// Status variable that indicates if the location service auth was denied.
    var isDisplayingLocationServicesDenied: Bool = false
    
    //UI
    /// Label with the title of the app
    var appTitleLabel: UILabel

    /// Image with the GPS signal
    var signalImageView: UIImageView
    
    /// Label that displays current latitude and longitude (lat,long)
    var coordsLabel: UILabel
    
    /// Label that displays last known speed (in km/h)
    var speedLabel: UILabel
    
    /// Distance of the total segments tracked
    var totalTrackedDistanceLabel: DistanceLabel
    
    /// Distance of the current segment being tracked (since last time the Tracker button was pressed)
    var currentSegmentDistanceLabel: DistanceLabel
 
    /// Used to display in imperial (foot, miles, mph) or metric system (m, km, km/h)
    var useImperial = false
    
    /// View GPX Files button
    var folderButton: UIButton
    
    /// View app about button
    var aboutButton: UIButton
    
    /// View preferences button
    var preferencesButton: UIButton
    
    /// Share current gpx file button
    var shareButton: UIButton
    
    /// Spinning Activity Indicator for shareButton
    let shareActivityIndicator: UIActivityIndicatorView
    
    /// Spinning Activity Indicator's color
    var shareActivityColor = UIColor(red: 0, green: 0.61, blue: 0.86, alpha: 1)
    
    /// Check if device is notched type phone
    var isIPhoneX = false
    
    // Signal accuracy images
    /// GPS signal image. Level 0 (no signal)
    let signalImage0 = UIImage(named: "signal0")
    /// GPS signal image. Level 1
    let signalImage1 = UIImage(named: "signal1")
    /// GPS signal image. Level 2
    let signalImage2 = UIImage(named: "signal2")
    /// GPS signal image. Level 3
    let signalImage3 = UIImage(named: "signal3")
    /// GPS signal image. Level 4
    let signalImage4 = UIImage(named: "signal4")
    /// GPS signal image. Level 5
    let signalImage5 = UIImage(named: "signal5")
    /// GPS signal image. Level 6
    let signalImage6 = UIImage(named: "signal6")
 
    /// Initializer. Just initializes the class vars/const
    required init(coder aDecoder: NSCoder) {
        self.map = GPXMapView(coder: aDecoder)!
        
        self.appTitleLabel = UILabel(coder: aDecoder)!
        self.signalImageView = UIImageView(coder: aDecoder)!

        self.coordsLabel = UILabel(coder: aDecoder)!
        
        self.speedLabel = UILabel(coder: aDecoder)!
        self.totalTrackedDistanceLabel = DistanceLabel(coder: aDecoder)!
        self.currentSegmentDistanceLabel = DistanceLabel(coder: aDecoder)!
        
        self.folderButton = UIButton(coder: aDecoder)!
        self.aboutButton = UIButton(coder: aDecoder)!
        self.preferencesButton = UIButton(coder: aDecoder)!
        self.shareButton = UIButton(coder: aDecoder)!
        
        self.shareActivityIndicator = UIActivityIndicatorView(coder: aDecoder)
        
        super.init(coder: aDecoder)!
    }
    
    ///
    /// De initalize the ViewController.
    ///
    /// Current implementation removes notification observers
    ///
    deinit {
        print("*** deinit")
        NotificationCenter.default.removeObserver(self)
    }
   
    /// Handles status bar color as a result from iOS 13 appearance changes
    override var preferredStatusBarStyle: UIStatusBarStyle {
        if #available(iOS 13, *) {
            if !isIPhoneX {
                if self.traitCollection.userInterfaceStyle == .dark && map.tileServer == .apple {
                    self.view.backgroundColor = .black
                    return .lightContent
                } else {
                    self.view.backgroundColor = .white
                    return .darkContent
                }
            } else { // > iPhone X has no opaque status bar
                // if is > iP X status bar can be white when map is dark
                return map.tileServer == .apple ? .default : .darkContent
            }
        } else { // < iOS 13
            return .default
        }
    }
    
    ///
    /// Initializes the view. It adds the UI elements to the view.
    ///
    /// All the UI is built programatically on this method. Interface builder is not used.
    ///
    override func viewDidLoad() {
        super.viewDidLoad()
        
        map.coreDataHelper.retrieveFromCoreData()
        
        //Because of the edges, iPhone X* is slightly different on the layout.
        //So, Is the current device an iPhone X?
        if UIDevice.current.userInterfaceIdiom == .phone {
            switch UIScreen.main.nativeBounds.height {
            case 1136:
                print("device: IPHONE 5,5S,5C")
            case 1334:
                print("device: IPHONE 6,7,8 IPHONE 6S,7S,8S ")
            case 1920, 2208:
                print("device: IPHONE 6PLUS, 6SPLUS, 7PLUS, 8PLUS")
            case 2436:
                print("device: IPHONE X, IPHONE XS, iPHONE 12_MINI")
                isIPhoneX = true
            case 2532:
                print("device: IPHONE 12, IPHONE 12_PRO")
                isIPhoneX = true
            case 2688:
                print("device: IPHONE XS_MAX")
                isIPhoneX = true
            case 2778:
                print("device: IPHONE_12_PRO_MAX")
                isIPhoneX = true
            case 1792:
                print("device: IPHONE XR")
                isIPhoneX = true
            default:
                print("UNDETERMINED")
            }
        }
        
        // Map autorotate configuration
        map.autoresizesSubviews = true
        map.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        self.view.autoresizesSubviews = true
        self.view.autoresizingMask = [.flexibleHeight, .flexibleWidth]

        // Map configuration Stuff
        map.delegate = mapViewDelegate
        map.showsUserLocation = true
        let mapH: CGFloat = self.view.bounds.size.height - (isIPhoneX ? 0.0 : 20.0)
        map.frame = CGRect(x: 0.0, y: (isIPhoneX ? 0.0 : 20.0), width: self.view.bounds.size.width, height: mapH)
        map.isZoomEnabled = true
        map.isRotateEnabled = true
        //set the position of the compass.
        map.compassRect = CGRect(x: map.frame.width/2 - 18, y: isIPhoneX ? 105.0 : 70.0, width: 36, height: 36)
        
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        
        //Preferences
        map.tileServer = Preferences.shared.tileServer
        map.useCache = Preferences.shared.useCache
        useImperial = Preferences.shared.useImperial
        
        //
        // Config user interface
        //
        
        // Set default zoom
        let center = locationManager.location?.coordinate ?? CLLocationCoordinate2D(latitude: 8.90, longitude: -79.50)
        let span = MKCoordinateSpan(latitudeDelta: latitudeLongitudeDeltas[currentLongitudedeltaIndex], longitudeDelta: latitudeLongitudeDeltas[currentLongitudedeltaIndex])
        let region = MKCoordinateRegion(center: center, span: span)
        map.setRegion(region, animated: true)
        
        self.view.addSubview(map)
        
        addNotificationObservers()
        
        //
        // ---------------------- Build Interface Area -----------------------------
        //
        // HEADER
        let font36 = UIFont(name: "DinCondensed-Bold", size: 36.0)
        let font18 = UIFont(name: "DinAlternate-Bold", size: 18.0)
        let font12 = UIFont(name: "DinAlternate-Bold", size: 12.0)
        
        //add the app title Label (Branding, branding, branding! )
        let dictionary = Bundle.main.infoDictionary
        appTitleLabel.text = "  "
        if let appname = dictionary?["CFBundleDisplayName"] as? String {
            appTitleLabel.text = "  " + appname
        }

        
        appTitleLabel.textAlignment = .left
        appTitleLabel.font = UIFont.boldSystemFont(ofSize: 10)
        //appTitleLabel.textColor = UIColor(red: 0.0/255.0, green: 0.0/255.0, blue: 0.0/255.0, alpha: 1.0)
        appTitleLabel.textColor = UIColor.yellow
        appTitleLabel.backgroundColor = UIColor(red: 58.0/255.0, green: 57.0/255.0, blue: 54.0/255.0, alpha: 0.80)
        self.view.addSubview(appTitleLabel)
        
        // CoordLabel
        coordsLabel.textAlignment = .right
        coordsLabel.font = font12
        coordsLabel.textColor = UIColor.white
        coordsLabel.text = kNotGettingLocationText
        self.view.addSubview(coordsLabel)
        
        // Tracked info
        let iPhoneXdiff: CGFloat  = isIPhoneX ? 40 : 0

        //speed Label
        speedLabel.textAlignment = .right
        speedLabel.font = font36
        speedLabel.text = 0.00.toSpeed(useImperial: useImperial)
        //timeLabel.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.5)
        map.addSubview(speedLabel)
        
        //tracked distance
        totalTrackedDistanceLabel.textAlignment = .right
        totalTrackedDistanceLabel.font = font36
        totalTrackedDistanceLabel.useImperial = useImperial
        totalTrackedDistanceLabel.distance = 0.00
        totalTrackedDistanceLabel.autoresizingMask = [.flexibleWidth, .flexibleLeftMargin, .flexibleRightMargin]
        //timeLabel.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.5)
        map.addSubview(totalTrackedDistanceLabel)
        
        //about button
        aboutButton.frame = CGRect(x: 5 + 8, y: 14 + 5 + 48 + 5 + iPhoneXdiff, width: 32, height: 32)
        aboutButton.setImage(UIImage(named: "info"), for: UIControl.State())
        aboutButton.setImage(UIImage(named: "info_high"), for: .highlighted)
        aboutButton.addTarget(self, action: #selector(ViewController.openAboutViewController), for: .touchUpInside)
        aboutButton.autoresizingMask = [.flexibleRightMargin]
        //aboutButton.backgroundColor = kWhiteBackgroundColor
        //aboutButton.layer.cornerRadius = 24
        map.addSubview(aboutButton)
        
        // Preferences button
        preferencesButton.frame = CGRect(x: 5 + 10 + 48, y: 14 + 5 + 8  + iPhoneXdiff, width: 32, height: 32)
        preferencesButton.setImage(UIImage(named: "prefs"), for: UIControl.State())
        preferencesButton.setImage(UIImage(named: "prefs_high"), for: .highlighted)
        preferencesButton.addTarget(self, action: #selector(ViewController.openPreferencesTableViewController), for: .touchUpInside)
        preferencesButton.autoresizingMask = [.flexibleRightMargin]
        //aboutButton.backgroundColor = kWhiteBackgroundColor
        //aboutButton.layer.cornerRadius = 24
        map.addSubview(preferencesButton)
        
        // Share button
        shareButton.frame = CGRect(x: 5 + 10 + 48 * 2, y: 14 + 5 + 8  + iPhoneXdiff, width: 32, height: 32)
        shareButton.setImage(UIImage(named: "share"), for: UIControl.State())
        shareButton.setImage(UIImage(named: "share_high"), for: .highlighted)
        shareButton.addTarget(self, action: #selector(ViewController.openShare), for: .touchUpInside)
        shareButton.autoresizingMask = [.flexibleRightMargin]
        //aboutButton.backgroundColor = kWhiteBackgroundColor
        //aboutButton.layer.cornerRadius = 24
        map.addSubview(shareButton)
        
        // Folder button
        let folderW: CGFloat = kButtonSmallSize
        let folderH: CGFloat = kButtonSmallSize
        let folderX: CGFloat = folderW/2 + 5
        let folderY: CGFloat = folderH/2 + 5 + 14  + iPhoneXdiff
        folderButton.frame = CGRect(x: 0, y: 0, width: folderW, height: folderH)
        folderButton.center = CGPoint(x: folderX, y: folderY)
        folderButton.setImage(UIImage(named: "folder"), for: UIControl.State())
        folderButton.setImage(UIImage(named: "folderHigh"), for: .highlighted)
        folderButton.addTarget(self, action: #selector(ViewController.openFolderViewController), for: .touchUpInside)
        folderButton.backgroundColor = kWhiteBackgroundColor
        folderButton.layer.cornerRadius = 24
        folderButton.autoresizingMask = [.flexibleRightMargin]
        map.addSubview(folderButton)
        
        // Add signal accuracy images and labels
        signalImageView.image = signalImage0
        signalImageView.frame = CGRect(x: self.view.frame.width/2 - 25.0, y: 14 + 5 + iPhoneXdiff, width: 50, height: 30)
        signalImageView.autoresizingMask  = [.flexibleLeftMargin, .flexibleRightMargin]
        map.addSubview(signalImageView)

        addConstraints(isIPhoneX)
        
        map.rotationGesture.delegate = self
        map.panGesture.delegate = self
        updateAppearance()
        
        if #available(iOS 13, *) {
            shareActivityColor = .mainUIColor
        }
    }
    
    // MARK: - Add Constraints for views
    /// Adds Constraints to subviews
    ///
    /// The constraints will ensure that subviews will be positioned correctly, when there are orientation changes, or iPad split view width changes.
    ///
    /// - Parameters:
    ///     - isIPhoneX: if device is >= iPhone X, bottom gap will be zero
    func addConstraints(_ isIPhoneX: Bool) {
        addConstraintsToAppTitleBar(isIPhoneX)
        addConstraintsToInfoLabels(isIPhoneX)
    }
    /// Adds constraints to subviews forming the app title bar (top bar)
    func addConstraintsToAppTitleBar(_ isIPhoneX: Bool) {
        // MARK: App Title Bar
        
        // Switch off all autoresizing masks translate
        appTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        coordsLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint(item: coordsLabel, attribute: .trailing, relatedBy: .equal, toItem: self.view, attribute: .trailing, multiplier: 1, constant: -5).isActive = true
        // not using self.topLayoutGuide as it will leave a gap between status bar and this, if used on non-notch devices
        NSLayoutConstraint(item: appTitleLabel, attribute: .top, relatedBy: .equal, toItem: self.view, attribute: .top, multiplier: 1, constant: isIPhoneX ? 40.0 : 20.0).isActive = true
        NSLayoutConstraint(item: appTitleLabel, attribute: .lastBaseline, relatedBy: .equal, toItem: coordsLabel, attribute: .lastBaseline, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: appTitleLabel, attribute: .trailing, relatedBy: .equal, toItem: coordsLabel, attribute: .trailing, multiplier: 1, constant: 5).isActive = true
        NSLayoutConstraint(item: appTitleLabel, attribute: .leading, relatedBy: .equal, toItem: coordsLabel, attribute: .leading, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: appTitleLabel, attribute: .leading, relatedBy: .equal, toItem: self.view, attribute: .leading, multiplier: 1, constant: 0).isActive = true
    }
    
    /// Adds constraints to subviews forming the informational labels (top right side; i.e. speed, elapse time labels)
    func addConstraintsToInfoLabels(_ isIPhoneX: Bool) {
        // MARK: Information Labels
        
        /// offset from center, without obstructing signal view
        let kSignalViewOffset: CGFloat = 25
        
        // Switch off all autoresizing masks translate
        speedLabel.translatesAutoresizingMaskIntoConstraints = false
        totalTrackedDistanceLabel.translatesAutoresizingMaskIntoConstraints = false
        currentSegmentDistanceLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint(item: speedLabel, attribute: .trailing, relatedBy: .equal, toItem: self.view, attribute: .trailing, multiplier: 1, constant: -7).isActive = true
        NSLayoutConstraint(item: speedLabel, attribute: .leading, relatedBy: .equal, toItem: self.view, attribute: .centerX, multiplier: 1, constant: kSignalViewOffset).isActive = true
        NSLayoutConstraint(item: speedLabel, attribute: .top, relatedBy: .equal, toItem: self.topLayoutGuide, attribute: .bottom, multiplier: 1, constant: 20).isActive = true
        
        NSLayoutConstraint(item: totalTrackedDistanceLabel, attribute: .trailing, relatedBy: .equal, toItem: self.view, attribute: .trailing, multiplier: 1, constant: -7).isActive = true
        NSLayoutConstraint(item: totalTrackedDistanceLabel, attribute: .leading, relatedBy: .equal, toItem: self.view, attribute: .centerX, multiplier: 1, constant: kSignalViewOffset).isActive = true
        NSLayoutConstraint(item: totalTrackedDistanceLabel, attribute: .top, relatedBy: .equal, toItem: speedLabel, attribute: .bottom, multiplier: 1, constant: 5).isActive = true
        
    }
    
    /// For handling compass location changes when orientation is switched.
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        DispatchQueue.main.async {
            // set the new position of the compass.
            self.map.compassRect = CGRect(x: size.width/2 - 18, y: 70.0, width: 36, height: 36)
            // update compass frame location
            self.map.layoutSubviews()
        }
        
    }
    
    /// Will update polyline color when invoked
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        updatePolylineColor()
    }
    
    /// Updates polyline color
    func updatePolylineColor() {
        for overlay in map.overlays where overlay is MKPolyline {
                map.removeOverlay(overlay)
                map.addOverlay(overlay)
        }
    }
    
    ///
    /// Asks the system to notify the app on some events
    ///
    /// Current implementation requests the system to notify the app:
    ///
    ///  1. whenever it enters background
    ///  2. whenever it becomes active
    ///  3. whenever it will terminate
    ///  4. whenever it receives a file from Apple Watch
    ///  5. whenever it should load file from Core Data recovery mechanism
    ///
    func addNotificationObservers() {
        let notificationCenter = NotificationCenter.default
        
        notificationCenter.addObserver(self, selector: #selector(ViewController.didEnterBackground),
            name: UIApplication.didEnterBackgroundNotification, object: nil)
       
        notificationCenter.addObserver(self, selector: #selector(applicationDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)

        notificationCenter.addObserver(self, selector: #selector(applicationWillTerminate), name: UIApplication.willTerminateNotification, object: nil)

        notificationCenter.addObserver(self, selector: #selector(loadRecoveredFile(_:)), name: .loadRecoveredFile, object: nil)
        
        notificationCenter.addObserver(self, selector: #selector(updateAppearance), name: .updateAppearance, object: nil)
    }
    
    /// To update appearance when mapView requests to do so
    @objc func updateAppearance() {
        if #available(iOS 13, *) {
            setNeedsStatusBarAppearanceUpdate()
            updatePolylineColor()
        }
    }
    
    /// returns a string with the format of current date dd-MMM-yyyy-HHmm' (20-Jun-2018-1133)
    ///
    func defaultFilename() -> String {
        let defaultDate = DefaultDateFormat()
        //let dateFormatter = DateFormatter()
        //dateFormatter.dateFormat = "dd-MMM-yyyy-HHmm"
        let dateStr = defaultDate.getDateFromPrefs()
        print("fileName:" + dateStr)//dateFormatter.string(from: Date()))
        return dateStr//dateFormatter.string(from: Date())
    }
    
    @objc func loadRecoveredFile(_ notification: Notification) {
        guard let root = notification.userInfo?["recoveredRoot"] as? GPXRoot else {
            return
        }
        guard let fileName = notification.userInfo?["fileName"] as? String else {
            return
        }

        lastGpxFilename = fileName
        // adds last file name to core data as well
        self.map.coreDataHelper.add(toCoreData: fileName, willContinueAfterSave: false)

        //load data
        self.map.continueFromGPXRoot(root)

        //Sets the map region to display all the GPX data in the map (segments and waypoints).
        self.map.regionToGPXExtent()
        
        self.totalTrackedDistanceLabel.distance = self.map.session.totalTrackedDistance

    }
    
    ///
    /// Called when the application Becomes active (background -> foreground) this function verifies if
    /// it has permissions to get the location.
    ///
    @objc func applicationDidBecomeActive() {
        print("viewController:: applicationDidBecomeActive wasSentToBackground: \(wasSentToBackground) locationServices: \(CLLocationManager.locationServicesEnabled())")
        
        //If the app was never sent to background do nothing
        if !wasSentToBackground {
            return
        }
        checkLocationServicesStatus()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }
    
    ///
    /// Actions to do in case the app entered in background
    ///
    /// In current implementation if the app is not tracking it requests the OS to stop
    /// sharing the location to save battery.
    ///
    ///
    @objc func didEnterBackground() {
        wasSentToBackground = true // flag the application was sent to background
        print("viewController:: didEnterBackground")

    }
    
    ///
    /// Actions to do when the app will terminate
    ///
    /// In current implementation it removes all the temporary files that may have been created
    @objc func applicationWillTerminate() {
        print("viewController:: applicationWillTerminate")
        GPXFileManager.removeTemporaryFiles()
    }
    
    ///
    /// Displays the view controller with the list of GPX Files.
    ///
    @objc func openFolderViewController() {
        print("openFolderViewController")
        let vc = GPXFilesTableViewController(nibName: nil, bundle: nil)
        vc.delegate = self
        let navController = UINavigationController(rootViewController: vc)
        self.present(navController, animated: true) { () -> Void in }
    }
    
    ///
    /// Displays the view controller with the About information.
    ///
    @objc func openAboutViewController() {
        let vc = AboutViewController(nibName: nil, bundle: nil)
        let navController = UINavigationController(rootViewController: vc)
        self.present(navController, animated: true) { () -> Void in }
    }
    
    ///
    /// Opens Preferences table view controller
    ///
    @objc func openPreferencesTableViewController() {
        print("openPreferencesTableViewController")
        let vc = PreferencesTableViewController(style: .grouped)
        vc.delegate = self
        let navController = UINavigationController(rootViewController: vc)
        self.present(navController, animated: true) { () -> Void in }
    }
    
    /// Opens an Activity View Controller to share the file
    @objc func openShare() {
        print("ViewController: Share Button tapped")
        
        // async such that process is done in background
        DispatchQueue.global(qos: .utility).async {
            // UI code
            DispatchQueue.main.sync {
                self.shouldShowShareActivityIndicator(true)
            }
            
            //Create a temporary file
            let filename =  self.lastGpxFilename.isEmpty ? self.defaultFilename() : self.lastGpxFilename
            let gpxString: String = self.map.exportToGPXString()
            let tmpFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(filename).gpx")
            GPXFileManager.saveToURL(tmpFile, gpxContents: gpxString)
            //Add it to the list of tmpFiles.
            //Note: it may add more than once the same file to the list.
            
            // UI code
            DispatchQueue.main.sync {
                //Call Share activity View controller
                let activityViewController = UIActivityViewController(activityItems: [tmpFile], applicationActivities: nil)
                activityViewController.popoverPresentationController?.sourceView = self.shareButton
                activityViewController.popoverPresentationController?.sourceRect = self.shareButton.bounds
                self.present(activityViewController, animated: true, completion: nil)
                self.shouldShowShareActivityIndicator(false)
            }
            
        }
    }
    
    /// Displays spinning activity indicator for share button when true
    func shouldShowShareActivityIndicator(_ isTrue: Bool) {
        // setup
        shareActivityIndicator.color = shareActivityColor
        shareActivityIndicator.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        shareActivityIndicator.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        
        if isTrue {
            // cross dissolve from button to indicator
            UIView.transition(with: self.shareButton, duration: 0.35, options: [.transitionCrossDissolve], animations: {
                self.shareButton.addSubview(self.shareActivityIndicator)
            }, completion: nil)
            
            shareActivityIndicator.startAnimating()
            shareButton.setImage(nil, for: UIControl.State())
            shareButton.isUserInteractionEnabled = false
        } else {
            // cross dissolve from indicator to button
            UIView.transition(with: self.shareButton, duration: 0.35, options: [.transitionCrossDissolve], animations: {
                self.shareActivityIndicator.removeFromSuperview()
            }, completion: nil)
            
            shareActivityIndicator.stopAnimating()
            shareButton.setImage(UIImage(named: "share"), for: UIControl.State())
            shareButton.isUserInteractionEnabled = true
        }
    }
    
    ///
    /// UIGestureRecognizerDelegate required for stopFollowingUser
    ///
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
   
    ///
    /// There was a memory warning. Right now, it does nothing but to log a line.
    ///
    override func didReceiveMemoryWarning() {
        print("didReceiveMemoryWarning")
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    ///
    /// Checks the location services status
    /// - Are location services enabled (access to location device wide)? If not => displays an alert
    /// - Are location services allowed to this app? If not => displays an alert
    ///
    /// - Seealso: displayLocationServicesDisabledAlert, displayLocationServicesDeniedAlert
    ///
    func checkLocationServicesStatus() {
        //Are location services enabled?
        if !CLLocationManager.locationServicesEnabled() {
            displayLocationServicesDisabledAlert()
            return
        }
        //Does the app have permissions to use the location servies?
        if !([.authorizedAlways, .authorizedWhenInUse].contains(CLLocationManager.authorizationStatus())) {
            displayLocationServicesDeniedAlert()
            return
        }
    }
    ///
    /// Displays an alert that informs the user that location services are disabled.
    ///
    /// When location services are disabled is for all applications, not only this one.
    ///
    func displayLocationServicesDisabledAlert() {
        
        let alertController = UIAlertController(title: NSLocalizedString("LOCATION_SERVICES_DISABLED", comment: "no comment"), message: NSLocalizedString("ENABLE_LOCATION_SERVICES", comment: "no comment"), preferredStyle: .alert)
        let settingsAction = UIAlertAction(title: NSLocalizedString("SETTINGS", comment: "no comment"), style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.openURL(url)
            }
        }
        let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "no comment"), style: .cancel) { _ in }
        
        alertController.addAction(settingsAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true)

    }

    ///
    /// Displays an alert that informs the user that access to location was denied for this app (other apps may have access).
    /// It also dispays a button allows the user to go to settings to activate the location.
    ///
    func displayLocationServicesDeniedAlert() {
        if isDisplayingLocationServicesDenied {
            return // display it only once.
        }
        let alertController = UIAlertController(title: NSLocalizedString("ACCESS_TO_LOCATION_DENIED", comment: "no comment"),
                                                message: NSLocalizedString("ALLOW_LOCATION", comment: "no comment"),
                                                preferredStyle: .alert)
        let settingsAction = UIAlertAction(title: NSLocalizedString("SETTINGS", comment: "no comment"),
                                           style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.openURL(url)
            }
        }
        let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL",
                                                                  comment: "no comment"),
                                         style: .cancel) { _ in }
        
        alertController.addAction(settingsAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true)
        isDisplayingLocationServicesDenied = false
    }
    
    func updateMapCenter(locationManager: CLLocationManager) {
        
        let newSpeed = locationManager.location?.speed
        
        let newLocation = locationManager.location
        
        // only if speed >= 0, then calculate new average speed
        if let newSpeed = newSpeed, let newLocation = newLocation, newSpeed >= 0.0 {
            
            //Update speed text, start by setting to actual speed report by locationManager
            speedLabel.text = (newSpeed < 0) ? kUnknownSpeedText : newSpeed.toSpeed(useImperial: useImperial)
            
            // store new speed in array, to keep track of recent speeds and calculate the average
            // but remove last one if maximum amount is already stored
            if measuredSpeads.count == maxMeasuredSpeads {
                measuredSpeads.removeLast()
            }
            measuredSpeads.insert(newSpeed, at: 0)
            
            // calculate average of measuredSpeads
            let averageSpeed = measuredSpeads.reduce(0.0, +)/Double(measuredSpeads.count)
            
            // set speedlabel text to average speed
            speedLabel.text = averageSpeed.toSpeed(useImperial: useImperial)

            // if time since last gesture end is less than pauzeUdateMapCenterAfterGestureEndForHowManySeconds, then don't further update the map
            if abs(map.timeStampGestureEnd.timeIntervalSince(Date())) < pauzeUdateMapCenterAfterGestureEndForHowManySeconds {return}
            
            /* ****************************************************************************** */
            /* when moving, the top of the screen should be reached in approximately 1 minute */
            /* zoom in or out to achieve this (approximately)                                 */
            /* ****************************************************************************** */
            
            // when moving, the top of the screen should be reached in approximately 1 minute
            // the 1 minute is configurable later on
            // so the question is where would in one minute if I keep moving at the current speed
            let requiredDistanceToTopOffViewInMeters = max(averageSpeed * reachTopOfScreenInMinutes * 60, minimumTopOfScreenInMeters)
            
            // temporary store current centerCoordinate of map
            let currentCenterCoordinate = map.centerCoordinate // Temporary saved map current center position
            
            // temporary set centerCoordinate of map to current location
            map.centerCoordinate = newLocation.coordinate
            
            // calculate distance in meters, to top off view
            // distance is calculated from current center (which is now set to the location of the user), then multiplied with 0.7/0.5. 0.7 being where the user's location will be in the view after call to map.setCenter, 0.5 being the current location in the view
            let distanceToTopOfViewInMeters = abs(newLocation.distance(from: CLLocation(latitude: map.centerCoordinate.latitude + map.region.span.latitudeDelta, longitude: map.centerCoordinate.longitude))) * 0.7/0.5
            
            // just a piece of code that is used two times, it sets map.region to a region with latitudeDelta, value from latitudeLongitudeDeltas array, using index currentLongitudedeltaIndex
            let setMapRegion = {
                let region = MKCoordinateRegion(center: self.map.centerCoordinate, span: MKCoordinateSpan(latitudeDelta: latitudeLongitudeDeltas[currentLongitudedeltaIndex], longitudeDelta: latitudeLongitudeDeltas[currentLongitudedeltaIndex]))
                
                self.map.setRegion(region, animated: false)
                
                if let storedHeading = self.map.storedHeading {
                    
                    self.map.camera.heading = storedHeading.trueHeading

                }
                
            }

            // now if distanceToTopOfViewInMeters is more than x% more or less than requiredDistanceToTopOffViewInMeters, then decrease or increase the span
            if distanceToTopOfViewInMeters > requiredDistanceToTopOffViewInMeters * 1.2 && currentLongitudedeltaIndex > 0 {
                
                currentLongitudedeltaIndex-=1
                
                setMapRegion()
                
            } else if distanceToTopOfViewInMeters < requiredDistanceToTopOffViewInMeters * 0.8 && currentLongitudedeltaIndex < latitudeLongitudeDeltas.count {
                
                currentLongitudedeltaIndex+=1
                
                setMapRegion()
                
            }

            /* ************************************************************************ */
            /* heading should be on bottom at about 1/5th of total height of the screen */
            /* ************************************************************************ */
            
            // create new center to where we want to shift
            let fakecenter = CGPoint(x: view.center.x, y: view.center.y - view.bounds.height * 0.3)
            
            // create new coordinate to which we want to center the map
            let newCenterCoordinates = map.convert(fakecenter, toCoordinateFrom: view)
            
            // reset centerCoordinate of map to original
            map.centerCoordinate = currentCenterCoordinate
            
            // now move to the new newCenterCoordinates, with animation
            map.setCenter(newCenterCoordinates, animated: true)
            
            // remove compass cause user moves or rotates, it's simply not necessary to see while moving
            if (map.showsCompass) {
                map.showsCompass = false
            }

        }
    }
    
}

// MARK: PreferencesTableViewControllerDelegate

extension ViewController: PreferencesTableViewControllerDelegate {
    
    /// Update the activity type that the location manager is using.
    ///
    /// When user changes the activity type in preferences, this function is invoked to update the activity type of the location manager.
    ///
    func didUpdateActivityType(_ newActivityType: Int) {
        print("PreferencesTableViewControllerDelegate:: didUpdateActivityType: \(newActivityType)")
        self.locationManager.activityType = CLActivityType(rawValue: newActivityType)!
    }
    
    ///
    /// Updates the `tileServer` the map is using.
    ///
    /// If user enters preferences and he changes his preferences regarding the `tileServer`,
    /// the map of the main `ViewController` needs to be aware of it.
    ///
    /// `PreferencesTableViewController` informs the main `ViewController` through this delegate.
    ///
    func didUpdateTileServer(_ newGpxTileServer: Int) {
        print("PreferencesTableViewControllerDelegate:: didUpdateTileServer: \(newGpxTileServer)")
        self.map.tileServer = GPXTileServer(rawValue: newGpxTileServer)!
    }
    
    ///
    /// If user changed the setting of using cache, through this delegate, the main `ViewController`
    /// informs the map to behave accordingly.
    ///
    func didUpdateUseCache(_ newUseCache: Bool) {
        print("PreferencesTableViewControllerDelegate:: didUpdateUseCache: \(newUseCache)")
        self.map.useCache = newUseCache
    }
    
    // User changed the setting of use imperial units.
    func didUpdateUseImperial(_ newUseImperial: Bool) {
        print("PreferencesTableViewControllerDelegate:: didUpdateUseImperial: \(newUseImperial)")
        useImperial = newUseImperial
        totalTrackedDistanceLabel.useImperial = useImperial
        currentSegmentDistanceLabel.useImperial = useImperial
        //Because we dont know if last speed was unknown we set it as unknown.
        // In regular circunstances it will go to the new units relatively fast.
        speedLabel.text = kUnknownSpeedText
    }}

// MARK: location manager Delegate

/// Extends `ViewController`` to support `GPXFilesTableViewControllerDelegate` function
/// that loads into the map a the file selected by the user.
extension ViewController: GPXFilesTableViewControllerDelegate {
    ///
    /// Loads the selected GPX File into the map.
    ///
    /// Resets whatever estatus was before.
    ///
    func didLoadGPXFileWithName(_ gpxFilename: String, gpxRoot: GPXRoot) {

        lastGpxFilename = gpxFilename
        // adds last file name to core data as well
        self.map.coreDataHelper.add(toCoreData: gpxFilename, willContinueAfterSave: false)

        //load data
        self.map.importFromGPXRoot(gpxRoot)

        //center map in GPX data
        self.map.regionToGPXExtent()
        
        self.totalTrackedDistanceLabel.distance = self.map.session.totalTrackedDistance
        
    }
}

// MARK: CLLocationManagerDelegate

// Extends view controller to support Location Manager delegate protocol
extension ViewController: CLLocationManagerDelegate {

    /// Location manager calls this func to inform there was an error.
    ///
    /// It performs the following actions:
    ///  - Sets coordsLabel with `kNotGettingLocationText`, signal accuracy to
    ///    kUnknownAccuracyText and signalImageView to signalImage0.
    ///  - If the error code is `CLError.denied` it calls `checkLocationServicesStatus`
    
    ///
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("didFailWithError \(error)")
        coordsLabel.text = kNotGettingLocationText

        signalImageView.image = signalImage0
        let locationError = error as? CLError
        switch locationError?.code {
        case CLError.locationUnknown:
            print("Location Unknown")
        case CLError.denied:
            print("Access to location services denied. Display message")
            checkLocationServicesStatus()
        case CLError.headingFailure:
            print("Heading failure")
        default:
            print("Default error")
        }
  
    }
    
    ///
    /// Updates location accuracy and map information when user is in a new position
    ///
    ///
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        let newLocation = locations.first!
        
        // Update horizontal accuracy
        let hAcc = newLocation.horizontalAccuracy

        //updates signal image accuracy
        if hAcc < kSignalAccuracy6 {
            self.signalImageView.image = signalImage6
        } else if hAcc < kSignalAccuracy5 {
            self.signalImageView.image = signalImage5
        } else if hAcc < kSignalAccuracy4 {
            self.signalImageView.image = signalImage4
        } else if hAcc < kSignalAccuracy3 {
            self.signalImageView.image = signalImage3
        } else if hAcc < kSignalAccuracy2 {
            self.signalImageView.image = signalImage2
        } else if hAcc < kSignalAccuracy1 {
            self.signalImageView.image = signalImage1
        } else {
            self.signalImageView.image = signalImage0
        }
        
        //Update coordsLabel
        let latFormat = String(format: "%.6f", newLocation.coordinate.latitude)
        let lonFormat = String(format: "%.6f", newLocation.coordinate.longitude)
        let altitude = newLocation.altitude.toAltitude(useImperial: useImperial)
        coordsLabel.text = String(format: NSLocalizedString("COORDS_LABEL", comment: "no comment"), latFormat, lonFormat, altitude)
        
        // user moved location, so udpate center of the map
        updateMapCenter(locationManager: locationManager)

    }

    ///
    ///
    /// When there is a change on the heading (direction in which the device oriented) it makes a request to the map
    /// to updathe the heading indicator (a small arrow next to user location point)
    ///
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        print("ViewController::didUpdateHeading true: \(newHeading.trueHeading) magnetic: \(newHeading.magneticHeading)")
        print("mkMapcamera heading=\(map.camera.heading)")

        // map possibly rotated, so update center off the map
        updateMapCenter(locationManager: locationManager)
        
        // then turn the map in the moving direction
        // only if end of last gesture > pauzeUdateMapCenterAfterGestureEndForHowManySeconds
        if abs(map.timeStampGestureEnd.timeIntervalSince(Date())) >= pauzeUdateMapCenterAfterGestureEndForHowManySeconds {
            
            map.camera.heading = newHeading.trueHeading

        }

        
        map.storedHeading = newHeading // updates heading variable
        map.updateHeading(to: newHeading) // updates heading view's rotation
        
    }
}

extension Notification.Name {
    static let loadRecoveredFile = Notification.Name("loadRecoveredFile")
    static let updateAppearance = Notification.Name("updateAppearance")
}
