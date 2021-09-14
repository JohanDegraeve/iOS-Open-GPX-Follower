//
//  GPXMapView.swift
//  OpenGpxFollower
//
//  Based on Open GPX Tracker created by merlos on 24/09/14.
//

import Foundation
import UIKit
import MapKit
import CoreLocation
import CoreGPX
import MapCache

///
/// A MapView that Tracks user position
///
/// - it is able to convert GPX file into map
///
/// ### Some definitions
///
/// 1. A **track** is a set of segments.
/// 2. A **segment** is set of points. A segment is linked to a MKPolyline overlay in the map.

class GPXMapView: MKMapView {
    
    /// If true, user is moving from start to end, if false, user is moving from end to start
    ///
    /// initial value true, assuming user moves start to end
    private var movesStartToEnd = true
    
    /// how many subsequent trackPoints in the same direction, used together with movesStartToEnd
    private var subsequentTrackPointsInSameDirection:Int = 0

    /// how many subsequent track points in the same moving direction before deciding if user is moving in the direction start to end or end to start
    private let amountOfTrackPointsToDetermineDirection = 3

    /// current location is further away from track than maximumDistanceFromTrackBeforeStartingZoomInInMeter, then consider not on track
    let maximumDistanceFromTrackInMeter = 150

    /// - how often to check if still on track
    let timeScheduleToCheckOnTrackInSeconds = 3.0

    /// minimum distance of top of screen in meters
    let minimumTopOfScreenInMeters = 200.0

    /// Current session of GPX location logging. Handles all background tasks and recording.
    let session = GPXSession()

    /// array of all trackpoints in the session
    private var trackPointDistances = [GPXTrackPointDistance]()
    
    ///
    var extent: GPXExtentCoordinates = GPXExtentCoordinates() //extent of the GPX points and tracks

    ///position of the compass in the map
    ///Example:
    /// map.compassRect = CGRect(x: map.frame.width/2 - 18, y: 70, width: 36, height: 36)
    var compassRect: CGRect
    
    /// Is the map using local image cache??
    var useCache: Bool = true { //use tile overlay cache (
        didSet {
            if tileServerOverlay is CachedTileOverlay {
                print("GPXMapView:: setting useCache \(useCache)")
                // swiftlint:disable force_cast
                (tileServerOverlay as! CachedTileOverlay).useCache = useCache
            }
        }
    }
    
    /// temp storage heading, updated each time a new heading is received from the location manager. Used when user rotates map (not device but map)
    var storedHeading: CLHeading?
    
    /// offset to use in camera heading
    var cameraHeadingOffset = 0.0
    
    /// Arrow image to display heading (orientation of the device)
    /// initialized on MapViewDelegate
    var headingImageView: UIImageView?
    
    /// Selected tile server.
    /// - SeeAlso: GPXTileServer
    var tileServer: GPXTileServer = .apple {
        willSet {
            print("Setting map tiles overlay to: \(newValue.name)" )
            updateMapInformation(newValue)
            // remove current overlay
            if tileServer != .apple {
                //to see apple maps we need to remove the overlay added by map cache.
                removeOverlay(tileServerOverlay)
            }
            
            //add new overlay to map if not using Apple Maps
            if newValue != .apple {
                //Update cacheConfig
                var config = MapCacheConfig(withUrlTemplate: newValue.templateUrl)
                config.subdomains = newValue.subdomains
                config.tileSize = CGSize(width: newValue.tileSize, height: newValue.tileSize)
                if newValue.maximumZ > 0 {
                    config.maximumZ = newValue.maximumZ
                }
                if newValue.minimumZ > 0 {
                    config.minimumZ = newValue.minimumZ
                }
                let cache = MapCache(withConfig: config)
                // the overlay returned substitutes Apple Maps tile overlay.
                // we need to keep a reference to remove it, in case we return back to Apple Maps.
                tileServerOverlay = useCache(cache)
            }
        }
        didSet {
            if #available(iOS 13, *) {
                if tileServer == .apple {
                    overrideUserInterfaceStyle = .unspecified
                    NotificationCenter.default.post(name: .updateAppearance, object: nil, userInfo: nil)
                } else { // if map is third party, dark mode is disabled.
                    overrideUserInterfaceStyle = .light
                    NotificationCenter.default.post(name: .updateAppearance, object: nil, userInfo: nil)
                }
            }
        }
    }
    
    /// Overlay that holds map tiles
    var tileServerOverlay: MKTileOverlay = MKTileOverlay()
    
    /// Offset to heading due to user's map rotation
    var headingOffset: CGFloat?
    
    /// Gesture for heading arrow to be updated in realtime during user's map interactions
    var rotationGesture = UIRotationGestureRecognizer()
    
    var panGesture = UIPanGestureRecognizer()
    
    /// when did the last gesture end ?
    var timeStampGestureEnd:Date = Date(timeIntervalSince1970: 0)
    
    /// value will be set by background process
    var isOnTrack = false
    
    /// last trackPoint less than expected maximum distance from user
    ///
    /// initialize to 0 means we assume we start at the start of the session
    private var currentGPXTrackPointIndex = 0
    
    /// coordinates for which a more fat polyline must be drawn on the screen, so that user clearly sees which track to follow
    public var fatPolylineCoordinates = [CLLocationCoordinate2D]()
    
    /// last but one trackPoint less than expected maximum distance from user
    ///
    /// initialize to 0 means we assume we start at the start of the session
    private var previousGPXTrackPointIndex = 0
    
    private var currentGPXTrackPointDistanceFromStart: Double = 0.0
    
    /// used for background processing, like check if on track
    private var operationQueue = OperationQueue()
    
    /// when fired, a call will be made to updateMapCenter
    var timerToCheckOnTrack: Timer?

    /// set in calculation of zoom, and used to calculate length of fat polyline
    var requiredDistanceToTopOffViewInMeters: Double

    ///
    /// Initializes the map with an empty currentSegmentOverlay.
    ///
    required init?(coder aDecoder: NSCoder) {

        compassRect = CGRect.init(x: 0, y: 0, width: 36, height: 36)

        requiredDistanceToTopOffViewInMeters = minimumTopOfScreenInMeters
        
        super.init(coder: aDecoder)
        
        // Rotation Gesture handling (for the map rotation's influence towards heading pointing arrow)
        rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(rotationGestureHandling(_:)))
        addGestureRecognizer(rotationGesture)
        
        // Initialize Swipe Gesture Recognizer - needed to set
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(didPan(_:)))
        addGestureRecognizer(panGesture)
        
        isUserInteractionEnabled = true
        isMultipleTouchEnabled = true
        
        // used for calculating on track in background, no need to calculate this mulitple times in parallel
        operationQueue.maxConcurrentOperationCount = 1
        
    }
    
    ///
    /// Override default implementation to set the compass that appears in the map in a better position.
    ///
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // set compass position by setting its frame
        if let compassView = subviews.filter({ $0.isKind(of: NSClassFromString("MKCompassView")!) }).first {
            if compassRect.origin.x != 0 {
                compassView.frame = compassRect
            }
        }
        
        updateMapInformation(tileServer)
    }
    
    /// hides apple maps stuff when map tile != apple.
    func updateMapInformation(_ tileServer: GPXTileServer) {
        if let logoClass = NSClassFromString("MKAppleLogoImageView"),
           let mapLogo = subviews.filter({ $0.isKind(of: logoClass) }).first {
            mapLogo.isHidden = (tileServer != .apple)
        }
        
        if let textClass = NSClassFromString("MKAttributionLabel"),
           let mapText = subviews.filter({ $0.isKind(of: textClass) }).first {
            mapText.isHidden = (tileServer != .apple)
        }
    }
    
    /// Handles rotation detected from user, for heading arrow to update.
    @objc func rotationGestureHandling(_ gesture: UIRotationGestureRecognizer) {
        
        // show compass when user rotates
        showsCompass = true
        
        headingOffset = gesture.rotation
        
        if let storedHeading = storedHeading {
            updateHeading(to: storedHeading)
        }
        
        if gesture.state == .ended {
            
            headingOffset = nil

            timeStampGestureEnd = Date()
            
        }
        
    }
    
    @objc private func didPan(_ sender: UIPanGestureRecognizer) {
        
        // show compass when user pans
        showsCompass = true

        if sender.state == .ended {
            
            timeStampGestureEnd = Date()

        }
        
    }
    
    ///
    /// - Updates the heading arrow based on the heading information
    func updateHeading(to heading: CLHeading) {
        
        // why setting only here to false ?
        headingImageView?.isHidden = false
        
        var rotation: CGFloat!
        
        // if heading nil then set rotation to north
        rotation = CGFloat((heading.trueHeading - camera.heading)/180 * Double.pi)
        
        if let headingOffset = headingOffset {
            rotation = rotation + headingOffset
        }
 
        headingImageView?.transform = CGAffineTransform(rotationAngle: rotation)
        
    }
    
    ///
    /// Clears map.
    ///
    func clearMap() {
        session.reset()
        
        trackPointDistances = [GPXTrackPointDistance]()
            
        removeOverlays(overlays)
        removeAnnotations(annotations)
        extent = GPXExtentCoordinates()
        
        //add tile server overlay
        //by removing all overlays, tile server overlay is also removed. We need to add it back
        if tileServer != .apple {
            addOverlay(tileServerOverlay, level: .aboveLabels)
        }
        
        // variables used to track distance to start or end of the track (depending on direction), reset all
        previousGPXTrackPointIndex = 0
        currentGPXTrackPointIndex = 0
        currentGPXTrackPointDistanceFromStart = 0.0
        movesStartToEnd = true
        subsequentTrackPointsInSameDirection = 0
        fatPolylineCoordinates = [CLLocationCoordinate2D]()
        isOnTrack = false
        
    }
    
    ///
    ///
    /// Converts current map into a GPX String
    ///
    ///
    func exportToGPXString() -> String {
        return session.exportToGPXString()
    }
   
    ///
    /// Sets the map region to display all the GPX data in the map (segments and waypoints).
    ///
    func regionToGPXExtent() {
        setRegion(extent.region, animated: true)
    }
    
    /// Imports GPX contents into the map.
    ///
    /// - Parameters:
    ///     - gpx: The result of loading a gpx file with iOS-GPX-Framework.
    ///
    /// - returns:
    ///     - total distance of all tracks in gpx
    func importFromGPXRoot(_ gpx: GPXRoot) -> Double {

        clearMap()

        return addTrackSegments(for: gpx)

    }

    /// - returns:
    ///     - total distance of all tracks in gpx
    private func addTrackSegments(for gpx: GPXRoot) -> Double {
        
        session.tracks = gpx.tracks
        
        for oneTrack in session.tracks {
            
            session.distance += oneTrack.length(actualDistanceFromStart: session.distance, trackPointDistances: &trackPointDistances)
            for segment in oneTrack.tracksegments {
                let overlay = segment.overlay
                addOverlay(overlay)
                let segmentTrackpoints = segment.trackpoints
                //add point to map extent
                for waypoint in segmentTrackpoints {
                    extent.extendAreaToIncludeLocation(waypoint.coordinate)
                }
            }
        }
        
        return session.distance
        
    }
    
    /// checks if track is currently in the view, reducing view with x percent
    /// - parameters:
    ///     - reduceView : use a value between 50 and 100. If for instance 80, then the track must be in a view that is 80 percent of size of the real view
    func trackIsInTheMapView(reduceView percentage: Int) -> Bool {
        
        // Latitude runs 0–90° north and south. Longitude runs 0–180° east and west.
        
        /// topLeft of the map
        let mapTopLeft = CLLocationCoordinate2D(latitude: region.center.latitude + region.span.latitudeDelta / 2, longitude: region.center.longitude - region.span.longitudeDelta / 2)
        
        /// bottomRight of the map
        let mapBottomRight = CLLocationCoordinate2D(latitude: region.center.latitude - region.span.latitudeDelta / 2, longitude: region.center.longitude + region.span.longitudeDelta / 2)

        /// how much to reduce longitude region to verify if extent falls within region
        let diffLongitude = region.span.longitudeDelta * Double(100 - percentage) / 100.0 / 2

        /// how much to reduce latitude of region to verify if extent falls within region
        let diffLatitude = region.span.latitudeDelta * Double(100 - percentage) / 100.0 / 2

        /// topLeft of reduced map in which extent should be
        let reducedMapTopLeft = CLLocationCoordinate2D(latitude: mapTopLeft.latitude - abs(diffLatitude), longitude: mapTopLeft.longitude + diffLongitude)

        /// bottomRight of reduced map in which extent should be
        let reducedBottomRight = CLLocationCoordinate2D(latitude: mapBottomRight.latitude + abs(diffLatitude), longitude: mapBottomRight.longitude - diffLongitude)

        /// iterate through all tracks, segments and trackpoints
        for track in session.tracks {
            
            for segment in track.tracksegments {
                
                for trackpoint in segment.trackpoints {
                    
                    if let latitude = trackpoint.latitude, let longitude = trackpoint.longitude {
                        
                        if latitude < reducedMapTopLeft.latitude && latitude > reducedBottomRight.latitude
                            &&
                            longitude > reducedMapTopLeft.longitude && longitude < reducedBottomRight.longitude {
                            
                            return true
                            
                        }

                    }
                    
                }
                
            }
            
        }
        
        return false
        
    }
    
    /// distance to destination = end of the all tracks in the session
    func calculateDistanceToDestination(currentDistanceToDestination: Double) -> Double {
        
        // case where current gpx trackpoint did not change
        if  currentGPXTrackPointIndex == previousGPXTrackPointIndex {
            
            // there's been no move, no change in distance
            return currentDistanceToDestination
            
        }
        
        // check if value of movesStartToEnd is in a changing mood
        if abs(subsequentTrackPointsInSameDirection) < amountOfTrackPointsToDetermineDirection {
            
            print("subsequentTrackPointsInSameDirection =  \(subsequentTrackPointsInSameDirection), abs value is less than \(amountOfTrackPointsToDetermineDirection)")
            return currentDistanceToDestination
            
        }
        
        if movesStartToEnd {
            
            return session.distance - currentGPXTrackPointDistanceFromStart
            
        } else {
            
            return -currentGPXTrackPointDistanceFromStart
            
        }

    }
    
    @objc private func checkOnTrackInBackground() {
        
        let operation = BlockOperation(block: {
            
            // new values used, just to avoid that values are used in main thread while being updated in background thread
            
            /// new value of isOnTrack calculated in the operation
            var newIsOntrack = self.isOnTrack
            
            /// new value of previousGPXTrackPointIndex calculated in the operation
            var newPreviousGPXTrackPointIndex = self.previousGPXTrackPointIndex
            
            /// new value of currentGPXTrackPointIndex calculated in the operation
            var newCurrentGPXTrackPointIndex = self.currentGPXTrackPointIndex
            
            /// new value of currentGPXTrackPointDistanceFromStart calculated in the operation
            var newCurrentGPXTrackPointDistanceFromStart = self.currentGPXTrackPointDistanceFromStart
            
            // before leaving the function, assign values to new values, in main thread
            // also calculate newFatPolylineCoordinates (not in the main thread)
            defer {
                
                trace("in defer")

                // calculate newFatPolylineCoordinates
                // only if current gpx trackpoint changed, or it didn't change and it's 0 which is the case when loading the track while you're at point 0
                var newFatPolylineCoordinates = self.fatPolylineCoordinates
                if (self.currentGPXTrackPointIndex != newCurrentGPXTrackPointIndex) ||  (self.currentGPXTrackPointIndex == newCurrentGPXTrackPointIndex && newCurrentGPXTrackPointIndex == 0){
                    
                    newFatPolylineCoordinates = self.calculateFatpolyLineCoordinates(currentGPXTrackPointIndex: newCurrentGPXTrackPointIndex)
                    trace("calculated newFatPolylineCoordinates with currentGPXTrackPointIndex = %{public}@", newCurrentGPXTrackPointIndex.description)
                    
                }
                
                // assign values to new values, in main thread
                DispatchQueue.main.async {
                    
                    trace("newIsOntrack = %{public}@", newIsOntrack.description)
                    trace("newPreviousGPXTrackPointIndex = %{public}@", newPreviousGPXTrackPointIndex.description)
                    trace("newCurrentGPXTrackPointIndex = %{public}@", newCurrentGPXTrackPointIndex.description)
                    trace("newCurrentGPXTrackPointDistanceFromStart = %{public}@", newCurrentGPXTrackPointDistanceFromStart.description)
                    
                    self.isOnTrack = newIsOntrack
                    self.previousGPXTrackPointIndex = newPreviousGPXTrackPointIndex
                    self.currentGPXTrackPointIndex = newCurrentGPXTrackPointIndex
                    self.currentGPXTrackPointDistanceFromStart = newCurrentGPXTrackPointDistanceFromStart
                    self.fatPolylineCoordinates = newFatPolylineCoordinates
                    
                    // recalculate value for movesStartToEnd
                    self.updateMovesStartToEnd()
                    
                }
                
            }
            
            // if there's more than one operation waiting for execution, it makes no sense to execute this one
            guard self.operationQueue.operations.count <= 1 else {return}
            
            // if no session exists (distance 0) then for sure not on track
            if self.session.distance == 0 {
                
                newIsOntrack = false
                return
                
            }
            
            trace("start checkontrack")
            
            // assume not on track
            newIsOntrack = false
            
            // should never be the case, because if session.distance != 0, then there must be elements in this array - anyway let's check to avoid crashes
            if self.trackPointDistances.count == 0 {

                trace("trackPointDistances.count = 0")
                
                return

            }

            // assign previousGPXTrackPointIndex to currentGPXTrackPointIndex
            newPreviousGPXTrackPointIndex = newCurrentGPXTrackPointIndex

            /// piece off code to call two times, it checks if the given trackpoint is within minimum distance and if yes sets the values for previousGPXTrackPointIndex, currentGPXTrackPointIndex and currentGPXTrackPointDistanceFromStart
            let checkOnTrack = { (trackPointDistanceIndex: Int) -> Bool in
                
                let trackPointDistance = self.trackPointDistances[trackPointDistanceIndex]
                
                if let latitude = trackPointDistance.gpxTrackPoint.latitude, let longitude = trackPointDistance.gpxTrackPoint.longitude {
                    
                    if let location = self.userLocation.location {
                        
                        if location.distance(from: CLLocation(latitude: latitude, longitude: longitude)) <= Double(self.maximumDistanceFromTrackInMeter) {
                            
                            // assign currentGPXTrackPointIndex to current trackPointDistanceIndex
                            newCurrentGPXTrackPointIndex = trackPointDistanceIndex
                            
                            // currentGPXTrackPointDistanceFromStart to distance of trackPointDistance
                            newCurrentGPXTrackPointDistanceFromStart = trackPointDistance.distance
                            
                            return true
                            
                        }
                        
                    }
                    
                }
                
                return false
                
            }
            
            if self.movesStartToEnd {
                trace("movesStartToEnd is currently true")
                // start checking as of previous index found
                forloop: for n in newPreviousGPXTrackPointIndex...(self.trackPointDistances.count - 1) {
                    
                    newIsOntrack = checkOnTrack(n)
                    if newIsOntrack {
                        trace("newIsOntrack is true with n = %{public}@", n.description)
                        break forloop
                        
                    }
                    
                }
                
                if !newIsOntrack {
                    
                    // not found from previous index up to end of the array, restart at 0
                    forloop:for n in 0...(newPreviousGPXTrackPointIndex) {
                        
                        newIsOntrack = checkOnTrack(n)
                        if newIsOntrack {
                            trace("newIsOntrack is true with n = %{public}@", n.description)
                            break forloop
                            
                        }

                    }
                    
                }
                
            } else {
                
                trace("movesStartToEnd is currently false")
                
                // moving end to start
                // start checking as of previous index found
                forloop:for n in (0...newPreviousGPXTrackPointIndex).reversed() {
                    
                    newIsOntrack = checkOnTrack(n)
                    if newIsOntrack {
                        trace("newIsOntrack is true with n = %{public}@", n.description)
                        break forloop
                        
                    }

                }
                
                if !newIsOntrack {
                    
                    forloop:for n in (newPreviousGPXTrackPointIndex...(self.trackPointDistances.count - 1)).reversed() {
                        
                        newIsOntrack = checkOnTrack(n)
                        if newIsOntrack {
                            trace("newIsOntrack is true with n = %{public}@", n.description)
                            break forloop
                            
                        }

                    }
                    
                }
                
            }
            
            trace("before leaving function, right before calling defer, newIsOntrack = %{public}@", newIsOntrack.description)
            
        })
        
        operationQueue.addOperation {
            operation.start()
        }
        
    }

    private func updateMovesStartToEnd() {
        
        // case where current gpxtrackpointindex increased
        if currentGPXTrackPointIndex > previousGPXTrackPointIndex {
            
            // check if movesStartToEnd needs to be set to true
            if subsequentTrackPointsInSameDirection == amountOfTrackPointsToDetermineDirection && !movesStartToEnd {
                
                // reached amountOfTrackPointsToDetermineDirection to determine the moving direction
                trace("setting movesStartToEnd to true")
                movesStartToEnd = true
                
            } else if subsequentTrackPointsInSameDirection < amountOfTrackPointsToDetermineDirection {
                
                // did not reach amountOfTrackPointsToDetermineDirection to determine the moving direction
                // increase the value
                subsequentTrackPointsInSameDirection += 1
                trace("setting subsequentTrackPointsInSameDirection to %{public}@", subsequentTrackPointsInSameDirection.description)
                
            }
            
        }
        
        // case where current gpxtrackpointindex decreased
        if currentGPXTrackPointIndex < previousGPXTrackPointIndex {
            
            // check if movesStartToEnd needs to be set to false
            // this is the case of subsequentTrackPointsInSameDirection equals negative value for amountOfTrackPointsToDetermineDirection
            if subsequentTrackPointsInSameDirection == -amountOfTrackPointsToDetermineDirection && movesStartToEnd {
                
                // reached amountOfTrackPointsToDetermineDirection to determine the moving direction
                trace("setting movesStartToEnd to false")
                movesStartToEnd = false
                
            } else if subsequentTrackPointsInSameDirection > -amountOfTrackPointsToDetermineDirection {
                
                // did not reach amountOfTrackPointsToDetermineDirection to determine the moving direction
                // decrease the value
                subsequentTrackPointsInSameDirection -= 1
                trace("setting subsequentTrackPointsInSameDirection to %{public}@", subsequentTrackPointsInSameDirection.description)
                
            }
            
        }
        
    }
    
    public func launchTimerToCheckOnTrack() {
        
        timerToCheckOnTrack = Timer.scheduledTimer(timeInterval: timeScheduleToCheckOnTrackInSeconds, target: self, selector: #selector(checkOnTrackInBackground), userInfo: nil, repeats: true)
        
    }
    
    private func calculateFatpolyLineCoordinates(currentGPXTrackPointIndex: Int) -> [CLLocationCoordinate2D] {
        
        var fatPolylineCoordinates = [CLLocationCoordinate2D]()

        if trackPointDistances.count > 0 {
            
            // nr of trackpoints to add to fat polyline depends on speed
            let lengthOfFatLineInMeters = requiredDistanceToTopOffViewInMeters * 3
            
            for cntr in (currentGPXTrackPointIndex-500...currentGPXTrackPointIndex).reversed() {
                
                if cntr < 0 {break}
                
                if abs(trackPointDistances[currentGPXTrackPointIndex].distance - trackPointDistances[cntr].distance) > lengthOfFatLineInMeters {break}
                
                if  let latitude = trackPointDistances[cntr].gpxTrackPoint.latitude, let longitude = trackPointDistances[cntr].gpxTrackPoint.longitude {
                    
                    //trace("adding point to fatpolyline with index %{public}@", cntr.description)
                    
                    fatPolylineCoordinates.insert(CLLocationCoordinate2D(latitude: latitude, longitude: longitude), at: 0)
                    
                }
                
            }
            
            for cntr in currentGPXTrackPointIndex+1...currentGPXTrackPointIndex+500 {
                
                if cntr >= trackPointDistances.count {break}
                
                if abs(trackPointDistances[currentGPXTrackPointIndex].distance - trackPointDistances[cntr].distance) > lengthOfFatLineInMeters {break}
                
                if let latitude = trackPointDistances[cntr].gpxTrackPoint.latitude, let longitude = trackPointDistances[cntr].gpxTrackPoint.longitude {
                    trace("adding point to fatpolyline with index %{public}@", cntr.description)

                    fatPolylineCoordinates.append(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                    
                }
                
            }
            
        }
        
        return fatPolylineCoordinates
        
    }

}
