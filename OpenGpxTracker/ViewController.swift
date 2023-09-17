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

/// Text to display when the system is not providing coordinates.
let ktextTotalDistance = NSLocalizedString("TOTAL_DISTANCE", comment: "no comment")

/// text to display top right label, when moving from start to end
let kTextToEnd = NSLocalizedString("TO_END", comment: "text top right when moving from start to end")

/// text to display top right label, when moving from end to start
let kTextToStart = NSLocalizedString("TO_START", comment: "text top right when moving from end to start")

/// - if not on track anymore then mapped will be zoomed out further to make sure that the track is still visible in a view 70% of the normal full view
/// - value between 0 and 100, but better take between 50 and 90
let reducedViewPercentageMax = 70

/// - if not on track anymore then mapped will be zoomed out, if track is within reducedViewPercentageMin, then we will zoom back in
/// - value between 0 and 100, but better take between 40 and less than reducedViewPercentageMax
let reducedViewPercentageMin = 40

/// determines automatic zooming, if value is for example 1, and I'm moving at 30 km/h, then the top of the screen is 500 meter away
let reachTopOfScreenInMinutes = 1.5

/// if speed higher than this value, then reachTopOfScreenInMinutes will be increased
let multiplyReachTopOfScreenInMinutesIfSpeedHigherThan1 = 22.0 // this corresponds to 80 km/h

/// if speed higher than this value, then reachTopOfScreenInMinutes will be increased
let multiplyReachTopOfScreenInMinutesIfSpeedHigherThan2 = 28.0 // this corresponds to 100 km/h

/// if speed higher than this value, then reachTopOfScreenInMinutes will be increased
let multiplyReachTopOfScreenInMinutesIfSpeedHigherThan3 = 33.0 // this corresponds to 100 km/h

/// if speed higher than multiplyReachTopOfScreenInMinutesIfSpeedHigherThan then multiply reachTopOfScreenInMinutes with this value
///
/// use 10% more or less to change value, to avoid flipping
let multiplicationFactorForReachTopOfScreenInMinutes1 = 1.5

/// if speed higher than multiplyReachTopOfScreenInMinutesIfSpeedHigherThan then multiply reachTopOfScreenInMinutes with this value
///
/// use 10% more or less to change value, to avoid flipping
let multiplicationFactorForReachTopOfScreenInMinutes2 = 2.0

/// if speed higher than multiplyReachTopOfScreenInMinutesIfSpeedHigherThan then multiply reachTopOfScreenInMinutes with this value
///
/// use 10% more or less to change value, to avoid flipping
let multiplicationFactorForReachTopOfScreenInMinutes3 = 2.5

/// maximum amount to store in measuredSpeads, average of those speeds is used to display
let maxMeasuredSpeads = 6

/// if user gestures the map, then there's no more auto rotation and zoom, this for maximum pauzeUdateMapCenterAfterGestureEndForHowManySeconds seconds
let pauzeUdateMapCenterAfterGestureEndForHowManySeconds = 30.0

/// delta latitude and longitude to use in MKSpan, for zooming in or out
//let latitudeLongitudeDeltas:[Double] = [0.0015, 0.003] + (0...100).map{ 0.005 * pow(1.1, Double($0)) }
let latitudeLongitudeDeltas:[Double] = (0...100).map{ 0.0015 * pow(1.1, Double($0)) }

/// - timer will check latest update of the map, if no recent update, then update will be triggered
/// - normally an update of the map is done by moving or rotating the device, but sometimes (eg at launch) the device is not moving, but still an update might be needed, for instance zoomin or zoomout after loading a track
/// - this value determines how often to do the check
let timeScheduleToCheckMapUpdateInSeconds = 0.25

/// how often to update the fat polyline (the one which is thicker)
///
/// just to avoid this happens to often,  I assume this demands resources
let timeSheduleToUpdateFatMKPolyLineInSeconds = 5.0

/// when user starts panning or zooming, then there's  no more automatic map udpate depending on location (ie follow user) - called 'sreenFrozen'
/// to go back from frozen to not frozen, the user must have ths minimum speed (in m/s),
let minimumSpeedToMoveFromFrozenToNotFrozen = 0.8333

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

/// UserDefaults.standard
fileprivate let defaults = UserDefaults.standard

/// when app is fully launched, value will be true, otherwise false
let userDefaultsKeyForNotInitialAppLaunch = "userDefaultsKeyForNotInitialAppLaunch"

/// if true, then this is at least the second time the app is launched
var notInitialAppLaunch = defaults.bool(forKey: userDefaultsKeyForNotInitialAppLaunch) {
    
    didSet {
        
        defaults.setValue(notInitialAppLaunch, forKey: userDefaultsKeyForNotInitialAppLaunch)
        
    }
    
}

/// average speed measured
var averageSpeed = 0.0

///
/// Main View Controller of the Application. It is loaded when the application is launched
///
/// Displays a map and a set the buttons to control the tracking
///
///
class ViewController: UIViewController, UIGestureRecognizerDelegate {
    
    /// when fired, a call will be made to updateMapCenter
    var timerToCheckMapUpdate: Timer?
    
    /// is reachTopOfScreenInMinutes currently multiplied with multiplicationFactorForReachTopOfScreenInMinutes ?
    var reachTopOfScreenInMinutesMultiplied1 = false
    
    /// is reachTopOfScreenInMinutes currently multiplied with multiplicationFactorForReachTopOfScreenInMinutes ?
    var reachTopOfScreenInMinutesMultiplied2 = false
    
    /// is reachTopOfScreenInMinutes currently multiplied with multiplicationFactorForReachTopOfScreenInMinutes ?
    var reachTopOfScreenInMinutesMultiplied3 = false
    
    /// to support device orientation
    var headingOffsetInDegrees = 0.0
    
    /// location manager instance configuration
    let locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.requestWhenInUseAuthorization()
        manager.activityType = CLActivityType(rawValue: Preferences.shared.locationActivityTypeInt)!
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 2 //meters
        manager.headingFilter = 3 //degrees (1 is default)
        manager.pausesLocationUpdatesAutomatically = false
        
        if #available(iOS 9.0, *) {
            manager.allowsBackgroundLocationUpdates = false
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
    /// Label that displays "distance to start", or "distnace to end" or "total distance"
    var movingDirectionLabel: UILabel
    
    /// Distance of the total segments tracked
    var distanceLabel: DistanceLabel
    
    /// Used to display in imperial (foot, miles, mph) or metric system (m, km, km/h)
    var useImperial = false
    
    /// View GPX Files button
    var folderButton: UIButton
    
    /// View app about button
    var aboutButton: UIButton
    
    /// View preferences button
    var preferencesButton: UIButton
    
    /// Follow user button
    var followUserButton: UIButton
    
    /// Check if device is notched type phone
    var isIPhoneX = false
    
    /// to keep track when last time map view as updated
    var timestampLastCallToUpdateMapCenter = Date(timeIntervalSince1970: 0)
    
    /// to keep track when last time fat polyline
    var timestampLastUpdateFatPolyline = Date(timeIntervalSince1970: 0)
    
    /// to measure the average speeds
    private var measuredSpeads = [Double]()
    
    /// current index in latitueLongitudedeltas, default 2
    var currentLongitudedeltaIndex = 2
    
    /// default X value for frame, assuming frame is in landscape mode
    var frameX: CGFloat = 0.0
    
    /// default X value for frame, assuming frame is in landscape mode
    var frameY: CGFloat = 0.0
    
    /// default width value for frame, assuming frame is in landscape mode
    var frameWidth: CGFloat = 0.0
    
    /// default height value for frame, assuming frame is in landscape mode
    var frameHeight: CGFloat = 0.0
    
    /// Initializer. Just initializes the class vars/const
    required init(coder aDecoder: NSCoder) {
        
        self.map = GPXMapView(coder: aDecoder)!
        
        fatPolyline = MKPolyline(coordinates: &map.fatPolylineCoordinates, count: map.fatPolylineCoordinates.count)
        
        self.map.addOverlay(fatPolyline)
        
        self.movingDirectionLabel = UILabel(coder: aDecoder)!
        self.distanceLabel = DistanceLabel(coder: aDecoder)!

        self.folderButton = UIButton(coder: aDecoder)!
        self.aboutButton = UIButton(coder: aDecoder)!
        self.preferencesButton = UIButton(coder: aDecoder)!
        self.followUserButton = UIButton(coder: aDecoder)!
        
        super.init(coder: aDecoder)!
        
        launchTimerToCheckMapUpdate()
        
        map.launchTimerToCheckOnTrack()
        
    }
    
    /// timer will check latest update of the map, if no recent update, then update will be triggered
    /// normally an update of the map is done by moving or rotating the device, but sometimes (eg at launch) the device is not moving, but still an update might be needed, for instance zoomin or zoomout after loading a track
    private func launchTimerToCheckMapUpdate() {

        timerToCheckMapUpdate = Timer.scheduledTimer(timeInterval: timeScheduleToCheckMapUpdateInSeconds, target: self, selector: #selector(regularCallToUpdateMapCenter), userInfo: nil, repeats: true)

    }
    
    /// polyLine to show points on next 1 km in different color, or more fat
    private var fatPolyline:MKPolyline
    
    ///
    /// De initalize the ViewController.
    ///
    /// Current implementation removes notification observers
    ///
    deinit {
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
        
        frameX = 0.0
        frameY = (isIPhoneX ? 0.0 : 20.0)
        frameWidth = self.view.bounds.size.width
        frameHeight = self.view.bounds.size.height - (isIPhoneX ? 0.0 : 20.0)

        // Map autoresize configuration
        map.autoresizesSubviews = true
        map.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        self.view.autoresizesSubviews = true
        self.view.autoresizingMask = [.flexibleHeight, .flexibleWidth]

        // Map configuration Stuff
        map.delegate = mapViewDelegate
        map.showsUserLocation = true
        
        map.isZoomEnabled = true
        map.isRotateEnabled = true
        
        // this will create the frame for the map with correct sizing
        self.map.frame = CGRect(x: 0, y: 0, width: super.view.frame.width, height: super.view.frame.height)

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
        
        //add the app title Label (Branding, branding, branding! )

        // Tracked info
        let iPhoneXdiff: CGFloat  = isIPhoneX ? 40 : 0

        movingDirectionLabel.textAlignment = .right
        movingDirectionLabel.font = font36
        movingDirectionLabel.text = ""
        map.addSubview(movingDirectionLabel)
        
        // distance from star to end or from end to start, depending on moving direction
        distanceLabel.textAlignment = .right
        distanceLabel.font = font36
        distanceLabel.useImperial = useImperial
        distanceLabel.distance = 0.00
        distanceLabel.autoresizingMask = [.flexibleWidth, .flexibleLeftMargin, .flexibleRightMargin]
        map.addSubview(distanceLabel)
        
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
        //folderButton.backgroundColor = kWhiteBackgroundColor
        folderButton.layer.cornerRadius = 24
        folderButton.autoresizingMask = [.flexibleRightMargin]
        map.addSubview(folderButton)
        
        // Follow user button
        followUserButton.layer.cornerRadius = kButtonSmallSize/2
        followUserButton.backgroundColor = kWhiteBackgroundColor
        //follow_user represents the user is not being followed. Default status when app starts
        followUserButton.setImage(UIImage(named: "follow_user"), for: UIControl.State())
        followUserButton.setImage(UIImage(named: "follow_user"), for: .highlighted)
        followUserButton.addTarget(self, action: #selector(ViewController.followButtonTroggler), for: .touchUpInside)
        map.addSubview(followUserButton)
        
        // initially set follow user button to hidden, because by default the user is followed
        followUserButton.isHidden = true
        
        
        addConstraints(isIPhoneX)
        
        map.rotationGesture.delegate = self
        map.panGesture.delegate = self
        updateAppearance()
        
        // prevent screen dim/lock - once opened, the app will stay in the foreground
        UIApplication.shared.isIdleTimerDisabled = true
        
    }
    
    // MARK: - Add Constraints for views
    /// Adds Constraints to subviews
    ///
    /// The constraints will ensure that subviews will be positioned correctly, when there are orientation changes, or iPad split view width changes.
    ///
    /// - Parameters:
    ///     - isIPhoneX: if device is >= iPhone X, bottom gap will be zero
    func addConstraints(_ isIPhoneX: Bool) {
        addConstraintsToInfoLabels(isIPhoneX)
        addConstraintsToButtonBar(isIPhoneX)
    }
    
    /// Adds constraints to subviews forming the informational labels (top right side; i.e. speed, elapse time labels)
    func addConstraintsToInfoLabels(_ isIPhoneX: Bool) {
        // MARK: Information Labels
        
        /// offset from center, without obstructing signal view
        let kSignalViewOffset: CGFloat = 25
        
        // Switch off all autoresizing masks translate
        movingDirectionLabel.translatesAutoresizingMaskIntoConstraints = false
        distanceLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint(item: movingDirectionLabel, attribute: .trailing, relatedBy: .equal, toItem: self.view, attribute: .trailing, multiplier: 1, constant: -7).isActive = true
        
        //  this restricts the width of the label, too small.
        //NSLayoutConstraint(item: movingDirectionLabel, attribute: .leading, relatedBy: .equal, toItem: self.view, attribute: .centerX, multiplier: 1, constant: kSignalViewOffset).isActive = true
        
        NSLayoutConstraint(item: movingDirectionLabel, attribute: .top, relatedBy: .equal, toItem: self.topLayoutGuide, attribute: .bottom, multiplier: 1, constant: 20).isActive = true
        
        NSLayoutConstraint(item: distanceLabel, attribute: .trailing, relatedBy: .equal, toItem: self.view, attribute: .trailing, multiplier: 1, constant: -7).isActive = true
        NSLayoutConstraint(item: distanceLabel, attribute: .leading, relatedBy: .equal, toItem: self.view, attribute: .centerX, multiplier: 1, constant: kSignalViewOffset).isActive = true
        NSLayoutConstraint(item: distanceLabel, attribute: .top, relatedBy: .equal, toItem: movingDirectionLabel, attribute: .bottom, multiplier: 1, constant: 5).isActive = true
        
    }
    
    /// Adds constraints to subviews forming the button bar (bottom session controls bar)
    func addConstraintsToButtonBar(_ isIPhoneX: Bool) {
        // MARK: Button Bar
        
        // constants
        let kBottomGap: CGFloat = isIPhoneX ? 0 : 15
        let kBottomDistance: CGFloat = kBottomGap + 16
        
        followUserButton.translatesAutoresizingMaskIntoConstraints = false
        
        // seperation distance between button and bottom of view
        NSLayoutConstraint(item: self.bottomLayoutGuide, attribute: .top, relatedBy: .equal, toItem: followUserButton, attribute: .bottom, multiplier: 1, constant: kBottomDistance).isActive = true
        NSLayoutConstraint(item: map, attribute: .left, relatedBy: .equal, toItem: followUserButton, attribute: .left, multiplier: 1, constant: -kBottomDistance).isActive = true
        
        // fixed dimensions for all buttons
        NSLayoutConstraint(item: followUserButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: kButtonSmallSize).isActive = true
        NSLayoutConstraint(item: followUserButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: kButtonSmallSize).isActive = true
        
    }
    
    func setHeadingOffsetInDegrees() {
        switch Preferences.shared.deviceOrientation {
        case 0:
            switch UIDevice.current.orientation {
             case .portrait:
                headingOffsetInDegrees = 0.0

             case .landscapeLeft:
                headingOffsetInDegrees = 90.0

             case .landscapeRight:
                headingOffsetInDegrees = -90.0
                
            case .portraitUpsideDown:
                headingOffsetInDegrees = 180.0
                 
             case .unknown, .faceUp, .faceDown:
                 break
             
             @unknown default:
                 fatalError("Unknown device orientation")

             }
        case 1:// forced portrait
            headingOffsetInDegrees = 0.0
        case 2: // portrait upside down
            headingOffsetInDegrees = 180.0
        case 3: // landscape left
            headingOffsetInDegrees = 90.0
        case 4: // landscape right
            headingOffsetInDegrees = -90.0
        default:
            headingOffsetInDegrees = 0.0
        }
    }

    override func viewWillLayoutSubviews() {
        
        setHeadingOffsetInDegrees()
        

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
                map.addOverlayOnTop(overlay)
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

        notificationCenter.addObserver(self, selector: #selector(updateAppearance), name: .updateAppearance, object: nil)
        
        notificationCenter.addObserver(self, selector: #selector(loadNewFile),
                                       name: .didReceiveFileFromURL, object: nil)

    }
    
    /// will load most recent file and use as current gpx track to follow
    ///
    /// used when user opens gpx file from "Files" app or downloads via browser and opens the file with GPX Follower
    ///
    /// assuming that this is always the most recent file stored in the GPXFileManager
    @objc func loadNewFile() {
        
        /// most recent file
        if let mostRecentFile = GPXFileManager.mostRecentFile() {
            
                print("Load gpx File in ViewController: \(mostRecentFile.fileName)")
            
                guard let gpx = GPXParser(withURL: mostRecentFile.fileURL)?.parsedData() else {
                    
                    print("ViewController failed to load file \(mostRecentFile.fileName): failed to parse GPX file")
                    
                    return
                    
                }

                didLoadGPXFileWithName(gpxRoot: gpx)

            }
    }
    
    /// To update appearance when mapView requests to do so
    @objc func updateAppearance() {
        if #available(iOS 13, *) {
            setNeedsStatusBarAppearanceUpdate()
            updatePolylineColor()
        }
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
        
        launchTimerToCheckMapUpdate()
        
        map.launchTimerToCheckOnTrack()
        
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
        
        // stop timerToCheckMapUpdateInSeconds
        timerToCheckMapUpdate?.invalidate()
        
        // stop timerToCheckOnTrack
        map.timerToCheckOnTrack?.invalidate()

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
    /// Triggered when follow Button is taped.
    @objc func followButtonTroggler() {
        // this will cause removal of the button, because when setting timeStampGestureEnd to 1.1.1970, then map follows user
        map.timeStampGestureEnd = Date(timeIntervalSince1970: 0)
        
        followUserButton.isHidden = true
        
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
        
        // if this is the first launch, then no need to display alerts, because iOS itself is at the same time requesting access to location services for the app
        // set userDefaultsKeyForNotInitialAppLaunch to true now, so next time, if stil no access to location services, it will show the alerts
        if !UserDefaults.standard.bool(forKey: userDefaultsKeyForNotInitialAppLaunch) {
            
            UserDefaults.standard.setValue(true, forKey: userDefaultsKeyForNotInitialAppLaunch)
            
            return
            
        }
        
        //Are location services enabled?
        if !CLLocationManager.locationServicesEnabled() {
            displayLocationServicesDisabledAlert()
            return
        }
        //Does the app have permissions to use the location servies?
        if !([.authorizedWhenInUse].contains(CLLocationManager.authorizationStatus())) {
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
    
    /// for use in timer as selector, makes a call to updateMapCenter
    @objc func regularCallToUpdateMapCenter() {
        
        // update distance
        distanceLabel.distance = map.calculateDistanceToDestination(currentDistanceToDestination: distanceLabel.distance)

        // set movingDirectionLabel text
        // if distanceLabel.distance == 0.0 then there's no track loaded yet, no need to show any text
        // if distanceLabel.distance > 0.0 and on track, then show "to end"
        // if distanceLabel.distance < 0.0 and on track, then show "to start"
        // if distanceLabel.distance != 0.0 (ie < or >) and not on track, then don't change the text
        //      it will say "Track distance" until arriving at least once on track
        if distanceLabel.distance == 0.0 {
            
            movingDirectionLabel.text = ""
            
        } else if distanceLabel.distance > 0.0 && map.isOnTrack {
            
            movingDirectionLabel.text = kTextToEnd
            
        } else if distanceLabel.distance < 0.0 && map.isOnTrack {
            
            movingDirectionLabel.text = kTextToStart
            
        }
        
        if abs(timestampLastUpdateFatPolyline.timeIntervalSince(Date())) > timeSheduleToUpdateFatMKPolyLineInSeconds {
            
            // udpate the fat polyline
            updateFatPolyLine()
            
            timestampLastUpdateFatPolyline = Date()

        }


    }
    
    func updateFatPolyLine() {

        trace("updating fatPolyline")
        
        map.removeOverlay(fatPolyline)

        fatPolyline = FatMKPolyline(coordinates: &map.fatPolylineCoordinates, count: map.fatPolylineCoordinates.count)
        
        map.addOverlay(fatPolyline)
        
    }
    
    /// updates the map center, map zoom, map rotation, depending on user location, speed, distance from track and wheter or not user reacently did a gesture
    func updateMapCenter(locationManager: CLLocationManager) {

        if abs(timestampLastCallToUpdateMapCenter.timeIntervalSince(Date())) < timeScheduleToCheckMapUpdateInSeconds {

            return

        }

        // set lastCallToUpdateMapCenter
        timestampLastCallToUpdateMapCenter = Date()
        
        // unwrap location
        if let newLocation = locationManager.location {
            
            // only if speed >= 0, then calculate new average speed
            if let newSpeed = locationManager.location?.speed, newSpeed >= 0.0 {
                
                // store new speed in array, to keep track of recent speeds and calculate the average
                // but remove last one if maximum amount is already stored
                if measuredSpeads.count == maxMeasuredSpeads {
                    measuredSpeads.removeLast()
                }
                measuredSpeads.insert(newSpeed, at: 0)
                
            }
            
            // calculate average of measuredSpeads
            averageSpeed = measuredSpeads.reduce(0.0, +)/(measuredSpeads.count > 0 ? Double(measuredSpeads.count) : 1.0)
            
            // change locationManager.distanceFilter depending on speed, an update in max 1 second
            if averageSpeed < 1.38 { // 5 km/h
                self.locationManager.distanceFilter = 2
            } else if averageSpeed < 5.55 { // 20 km/h
                self.locationManager.distanceFilter = 6
            } else if averageSpeed < 16.66 { // 60 km/h
                self.locationManager.distanceFilter = 17
            } else if averageSpeed < 22.22 { // 80 km/h
                self.locationManager.distanceFilter = 23
            } else if averageSpeed < 27.77 { // 100 km/h
                self.locationManager.distanceFilter = 28
            } else {
                self.locationManager.distanceFilter = 35
            }
            
            // if time since last gesture end is less than pauzeUdateMapCenterAfterGestureEndForHowManySeconds, then don't further update the map
            if screenFrozen() {
                
                followUserButton.isHidden = false
                
                return
                
            } else {
                
                // if currently the followUserButton is shown, then switch to hidden, only if at least walking speed for the moment (3 km/h)
                if !followUserButton.isHidden {
                    
                    if averageSpeed > minimumSpeedToMoveFromFrozenToNotFrozen {
                        
                        // so last gesture was at least pauzeUdateMapCenterAfterGestureEndForHowManySeconds seconds ago
                        // and
                        // user is moving at least 3 km/h
                        // hide the follow user button and then continue
                        followUserButton.isHidden = true
                        
                    } else {
                        
                        // last gesture was at least pauzeUdateMapCenterAfterGestureEndForHowManySeconds seconds ago
                        // but user is not really moving fast
                        // and currnetly followUserButton is shown
                        // so don't follow user yet, user is probably still panning, zooming .. or anyting else
                        return

                    }

                }
                
            }
            
            /* ****************************************************************************** */
            /* when moving, the top of the screen should be reached in approximately          */
            /* reachTopOfScreenInMinutes minute                                               */
            /* zoom in or out to achieve this (approximately)                                 */
            /*                                                                                */
            /* And if not on track anymore then also zoom out should occur to make sure the   */
            /* track stays on sreen                                                           */
            /* ****************************************************************************** */
            map.requiredDistanceToTopOffViewInMeters = max(averageSpeed * reachTopOfScreenInMinutes * 60, map.minimumTopOfScreenInMeters)
            
            // check if multiplication is needed, if speed higher than certain value, eg for highways, we want to see more on the screen
            if (reachTopOfScreenInMinutesMultiplied1 && averageSpeed > multiplyReachTopOfScreenInMinutesIfSpeedHigherThan1 * 0.9) || (!reachTopOfScreenInMinutesMultiplied1 && averageSpeed > multiplyReachTopOfScreenInMinutesIfSpeedHigherThan1 * 1.1) {
                
                reachTopOfScreenInMinutesMultiplied1 = true

                if (reachTopOfScreenInMinutesMultiplied2 && averageSpeed > multiplyReachTopOfScreenInMinutesIfSpeedHigherThan2 * 0.9) || (!reachTopOfScreenInMinutesMultiplied2 && averageSpeed > multiplyReachTopOfScreenInMinutesIfSpeedHigherThan2 * 1.1) {
                    
                    reachTopOfScreenInMinutesMultiplied2 = true
                    
                    if (reachTopOfScreenInMinutesMultiplied3 && averageSpeed > multiplyReachTopOfScreenInMinutesIfSpeedHigherThan3 * 0.9) || (!reachTopOfScreenInMinutesMultiplied3 && averageSpeed > multiplyReachTopOfScreenInMinutesIfSpeedHigherThan3 * 1.1) {
                        
                        reachTopOfScreenInMinutesMultiplied3 = true
                        
                        trace("averagespeed =  %{public}@, multiplying requiredDistanceToTopOffViewInMeters with %{public}@", averageSpeed.description, multiplicationFactorForReachTopOfScreenInMinutes3.description)
                        
                        map.requiredDistanceToTopOffViewInMeters = map.requiredDistanceToTopOffViewInMeters * multiplicationFactorForReachTopOfScreenInMinutes3
                        
                    } else {
                        
                        reachTopOfScreenInMinutesMultiplied3 = false
                        
                        trace("averagespeed =  %{public}@, multiplying requiredDistanceToTopOffViewInMeters with %{public}@", averageSpeed.description, multiplicationFactorForReachTopOfScreenInMinutes2.description)
                        
                        map.requiredDistanceToTopOffViewInMeters = map.requiredDistanceToTopOffViewInMeters * multiplicationFactorForReachTopOfScreenInMinutes2
                        
                    }
                    
                } else {

                    reachTopOfScreenInMinutesMultiplied2 = false
                    reachTopOfScreenInMinutesMultiplied3 = false
                    
                    trace("averagespeed =  %{public}@, multiplying requiredDistanceToTopOffViewInMeters with %{public}@", averageSpeed.description, multiplicationFactorForReachTopOfScreenInMinutes1.description)
                    
                    map.requiredDistanceToTopOffViewInMeters = map.requiredDistanceToTopOffViewInMeters * multiplicationFactorForReachTopOfScreenInMinutes1

                }
                
            } else {
                
                trace("averagespeed =  %{public}@, not multiplying requiredDistanceToTopOffViewInMeters", averageSpeed.description)

                reachTopOfScreenInMinutesMultiplied1 = false
                reachTopOfScreenInMinutesMultiplied2 = false
                reachTopOfScreenInMinutesMultiplied3 = false
                
            }
            
            // temporary store current centerCoordinate of map
            let currentCenterCoordinate = map.centerCoordinate // Temporary saved map current center position
            
            // temporary set centerCoordinate of map to current location
            map.centerCoordinate = newLocation.coordinate
            
            // calculate distance in meters, to top off view
            // distance is calculated from current center (which is now set to the location of the user), then multiplied with 0.7/0.5. 0.7 being where the user's location will be in the view after call to map.setCenter, 0.5 being the current location in the view
            // Latitude runs 0–90° north and south. Longitude runs 0–180° east and west.
            let distanceToTopOfViewInMeters = abs(newLocation.distance(from: CLLocation(latitude: map.centerCoordinate.latitude, longitude: map.centerCoordinate.longitude + map.region.span.longitudeDelta))) * 0.7/0.5
            
            /// is user on track or not ? (storing in a variable because it's used two times)
            let userIsOntrack = map.isOnTrack
            
            // If there's a track then first off all check that the user is currently on track, within maximumDistanceFromTrackBeforeStartingZoomInInMeter
            // if there's no track loaded yet, then the zoom will only depend on the speed
            if userIsOntrack || map.session.tracks.count == 0 {

                // now if distanceToTopOfViewInMeters is more than x% more or less than requiredDistanceToTopOffViewInMeters, then decrease or increase the span
                if distanceToTopOfViewInMeters > map.requiredDistanceToTopOffViewInMeters * 1.3 {
                    
                    zoomIn()
                    
                } else if distanceToTopOfViewInMeters < map.requiredDistanceToTopOffViewInMeters * 0.7 {
                    
                    zoomOut()
                    
                }

            } else {
                
                // user is not on the track
                
                if map.trackIsInTheMapView(reduceView: reducedViewPercentageMax) {
                    
                    // track is visible, but maybe we can further zoom in
                    if map.trackIsInTheMapView(reduceView: reducedViewPercentageMin) {
                        
                        // zoom in
                        zoomIn()
                        
                    }
                    
                } else {
                    
                    // zoom out
                    zoomOut()
                    
                }
                
            }

            /* ************************************************************************ */
            /* heading should be on bottom at about 1/5th of total height of the screen */
            /* only if user is on track, otherwise we put the location in the center    */
            /* ************************************************************************ */
            
            // create new center to where we want to shift
            let fakecenter = CGPoint(x: view.center.x, y: view.center.y - view.bounds.height * 0.3)
            
            // create new coordinate to which we want to center the map
            let newCenterCoordinates = map.convert(fakecenter, toCoordinateFrom: view)
            
            // now move to the new newCenterCoordinates, with animation - only if on track
            // if not on track then map.centerCoordinate = newLocation.coordinate (just be done a few statements earlier)
            if userIsOntrack {

                // reset centerCoordinate of map to original
                map.centerCoordinate = currentCenterCoordinate
                
                map.setCenter(newCenterCoordinates, animated: true)

            }
            
            // remove compass cause user moves or rotates, it's simply not necessary to see while moving
            if (map.showsCompass) {
                map.showsCompass = false
            }

        }
        
    }
    
    /// - just a piece of code that is used several times, it sets map.region to a region with latitudeDelta, value from latitudeLongitudeDeltas array, using index currentLongitudedeltaIndex
    /// - also sets back map.camera.heading to storedHeading.trueHeading (probaly this has changed by setting map.centerCoordinate = newLocation.coordinate ?
    func setMapRegion() {
        
        let region = MKCoordinateRegion(center: self.map.centerCoordinate, span: MKCoordinateSpan(latitudeDelta: latitudeLongitudeDeltas[currentLongitudedeltaIndex], longitudeDelta: latitudeLongitudeDeltas[currentLongitudedeltaIndex]))
        
        self.map.setRegion(region, animated: false)
        
        if let storedHeading = self.map.storedHeading {
            
            self.map.camera.heading = storedHeading.trueHeading + headingOffsetInDegrees
            
        }
        
    }

    /// reduces currentLongitudedeltaIndex, if not yet 0
    func zoomIn() {
        
        if (currentLongitudedeltaIndex > 0) {
            currentLongitudedeltaIndex-=1
        }
        
        setMapRegion()

    }
    
    /// increases currentLongitudedeltaIndex , if not yet reached maximum
    func zoomOut() {
        
        if (currentLongitudedeltaIndex < latitudeLongitudeDeltas.count - 1) {
            
            currentLongitudedeltaIndex+=1

        }
        
        setMapRegion()
        
    }
    
    /// if screen is frozen, then user has been doing a gesture, or just clicked the screen, which stops the map following the user
    /// and also displays buttons like settings, information, folder.
    /// initial value = true, means at startup, buttons are visible, for instance to load a gpx file
    func screenFrozen() -> Bool {
        
        return abs(map.timeStampGestureEnd.timeIntervalSince(Date())) < pauzeUdateMapCenterAfterGestureEndForHowManySeconds
        
    }
    
    func findViewOfType(type: String, inView view: UIView) -> UIView? {
          // function scans subviews recursively and returns reference to the found one of a type
        if view.subviews.count > 0 {
            for v in view.subviews {
                NSLog("view type = %@", String(describing: v))
            }
        }
        if view.subviews.count > 0 {
            for v in view.subviews {
                if String(describing: v).containsIgnoringCase(find: type) {
                    return v
                }
                if let inSubviews = self.findViewOfType(type: type, inView: v) {
                    return inSubviews
                }
            }
            return nil
        } else {
            return nil
        }
      }
    
}

// MARK: PreferencesTableViewControllerDelegate

extension ViewController: PreferencesTableViewControllerDelegate {
    
    func didUpdateDeviceOrientationSetting() {
        setHeadingOffsetInDegrees()
    }
    
    
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
        distanceLabel.useImperial = useImperial

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
    func didLoadGPXFileWithName(gpxRoot: GPXRoot) {

        //load data and assign distanceLabel.distance to distance of all tracks in the session
        self.distanceLabel.distance = self.map.importFromGPXRoot(gpxRoot)

        //center map in GPX data
        self.map.regionToGPXExtent()
        
        // user isn't moving yet (or at least moving isn't detected because gpx just loaded
        // set text to "Total distance"
        self.movingDirectionLabel.text = ktextTotalDistance
        
        currentLongitudedeltaIndex = 2
        
        reachTopOfScreenInMinutesMultiplied1 = false
        reachTopOfScreenInMinutesMultiplied2 = false
        reachTopOfScreenInMinutesMultiplied3 = false

    }
}

// MARK: CLLocationManagerDelegate

// Extends view controller to support Location Manager delegate protocol
extension ViewController: CLLocationManagerDelegate {

    /// Location manager calls this func to inform there was an error.
    ///
    /// It performs the following actions:
    ///  - Sets coordsLabel with `kNotGettingLocationText
    ///  - If the error code is `CLError.denied` it calls `checkLocationServicesStatus`
    
    ///
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("didFailWithError \(error)")

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
        
        // user moved location, so update center of the map
        updateMapCenter(locationManager: locationManager)
        
    }

    ///
    ///
    /// When there is a change on the heading (direction in which the device oriented) it makes a request to the map
    /// to updathe the heading indicator (a small arrow next to user location point)
    ///
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        
        // map possibly rotated, so update center off the map
        updateMapCenter(locationManager: locationManager)
        
        // then turn the map in the moving direction
        // only if
        //     currently followbutton is hidden
        //     or (if not hidden)
        //     if end of last gesture > pauzeUdateMapCenterAfterGestureEndForHowManySeconds and averageSpeed > minimumSpeedToMoveFromFrozenToNotFrozen
        if followUserButton.isHidden || (!screenFrozen() && averageSpeed > minimumSpeedToMoveFromFrozenToNotFrozen) {
            
            map.camera.heading = newHeading.trueHeading + headingOffsetInDegrees

        }
        
        map.storedHeading = newHeading // updates heading variable
        
    }
}

extension Notification.Name {
    static let updateAppearance = Notification.Name("updateAppearance")
}
