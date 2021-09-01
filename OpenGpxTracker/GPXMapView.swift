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
import CoreData
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
    
    /// last  one trackPoint less than expected maximum distance from user
    ///
    /// initialize to 0 means we assume we start at the start of the session
    private var currentGPXTrackPointIndex = 0
    
    /// last but one trackPoint less than expected maximum distance from user
    ///
    /// initialize to 0 means we assume we start at the start of the session
    private var previousGPXTrackPointIndex = 0
    
    private var currentGPXTrackPointDistanceFromStart: Double = 0.0
    
    ///
    /// Initializes the map with an empty currentSegmentOverlay.
    ///
    required init?(coder aDecoder: NSCoder) {

        compassRect = CGRect.init(x: 0, y: 0, width: 36, height: 36)
        super.init(coder: aDecoder)
        
        // Rotation Gesture handling (for the map rotation's influence towards heading pointing arrow)
        rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(rotationGestureHandling(_:)))
        addGestureRecognizer(rotationGesture)
        
        // Initialize Swipe Gesture Recognizer - needed to set
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(didPan(_:)))
        addGestureRecognizer(panGesture)
        
        isUserInteractionEnabled = true
        isMultipleTouchEnabled = true
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
    
    /// onTrack
    /// - returns
    ///     - boolean : that tells if there's at least one trackpoint within maximumDistanceInMeters, (circle around userlocation of maximumDistanceInMeters radius, should have at least one trackpoint)
    func onTrack(maximumDistanceInMeters: Int) -> Bool {
        
        // if no session exists (distance 0) then for sure not on track
        if session.distance == 0 {return false}
        
        // should never be the case, because if session.distance != 0, then there must be elements in this array - anyway let's check to avoid crashes
        if trackPointDistances.count == 0 {return false}
        
        /// piece off code to call two times, it checks if the given trackpoint is within minimum distance and if yes sets the values for previousGPXTrackPointIndex, currentGPXTrackPointIndex and currentGPXTrackPointDistanceFromStart
        let checkOnTrack = { (trackPointDistanceIndex: Int) -> Bool in
            
            let trackPointDistance = self.trackPointDistances[trackPointDistanceIndex]
            
            if let latitude = trackPointDistance.gpxTrackPoint.latitude, let longitude = trackPointDistance.gpxTrackPoint.longitude {
                
                if let location = self.userLocation.location {
                    
                    if location.distance(from: CLLocation(latitude: latitude, longitude: longitude)) <= Double(maximumDistanceInMeters) {
                        
                        // assign previousGPXTrackPointIndex to currentGPXTrackPointIndex
                        self.previousGPXTrackPointIndex = self.currentGPXTrackPointIndex
                        
                        // assign currentGPXTrackPointIndex to current trackPointDistanceIndex
                        self.currentGPXTrackPointIndex = trackPointDistanceIndex
                        
                        // currentGPXTrackPointDistanceFromStart to distance of trackPointDistance
                        self.currentGPXTrackPointDistanceFromStart = trackPointDistance.distance
                        
                        return true
                        
                    }
                    
                }
                
            }
            
            return false
            
        }
        
        if movesStartToEnd {

            // start checking as of previous index found
            for n in previousGPXTrackPointIndex...(trackPointDistances.count - 1) {

                if checkOnTrack(n) {
                    
                    return true
                    
                } else {
                    
                    // not found from previous index up to end of the array, restart at 0
                    for n in 0...(previousGPXTrackPointIndex) {
                        
                        if checkOnTrack(n) {
                            
                            return true
                            
                        }
                        
                    }
                    
                }
                
            }

        } else {
            
            // moving end to start
            // start checking as of previous index found
            for n in (0...previousGPXTrackPointIndex).reversed() {
                
                if checkOnTrack(n) {
                    
                    return true
                    
                } else {
                    
                    for n in (previousGPXTrackPointIndex...(trackPointDistances.count - 1)).reversed() {
                        
                        if checkOnTrack(n) {
                            
                            return true
                            
                        }
                        
                    }
                    
                }
                
            }
            
        }
        
        return false
        
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
            
            // there's been no move, no change in distance label
            return currentDistanceToDestination
            
        }
        
        // case where current gpxtrackpointindex increased
        if currentGPXTrackPointIndex > previousGPXTrackPointIndex {
            
            // possibly moving from start to end
            if subsequentTrackPointsInSameDirection == amountOfTrackPointsToDetermineDirection {
                
                // reached amountOfTrackPointsToDetermineDirection to determine the moving direction
                movesStartToEnd = true
                
            } else {
                
                // did not reach amountOfTrackPointsToDetermineDirection to determine the moving direction
                // increase the value
                subsequentTrackPointsInSameDirection += 1
                
                // possibly user changed direction, return current distance
                return currentDistanceToDestination
                
            }
            
        }
        
        // case where current gpxtrackpointindex decreased
        if currentGPXTrackPointIndex < previousGPXTrackPointIndex {
            
            // possibly moving from end to start
            // this is the case of subsequentTrackPointsInSameDirection equals negative value for amountOfTrackPointsToDetermineDirection
            if subsequentTrackPointsInSameDirection == -amountOfTrackPointsToDetermineDirection {
                
                // reached amountOfTrackPointsToDetermineDirection to determine the moving direction
                movesStartToEnd = false
                
            } else {
                
                // did not reach amountOfTrackPointsToDetermineDirection to determine the moving direction
                // increase the value
                subsequentTrackPointsInSameDirection -= 1
                
                // possibly user changed direction, return current distance
                return currentDistanceToDestination
                
            }
            
        }

        if movesStartToEnd {
            
            return session.distance - currentGPXTrackPointDistanceFromStart
            
        } else {
            
            return -currentGPXTrackPointDistanceFromStart
            
        }

    }

}
