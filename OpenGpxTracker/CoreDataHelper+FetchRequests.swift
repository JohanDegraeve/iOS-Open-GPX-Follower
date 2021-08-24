//
//  CoreDataHelper+FetchRequests.swift
//  OpenGpxFollower
//
//    Based on Open GPX Tracker. Orignal source created by Vincent Neo on 1/8/20.
//

import CoreData
import CoreGPX

extension CoreDataHelper {
    
    func rootFetchRequest() -> NSAsynchronousFetchRequest<CDRoot> {
        let rootFetchRequest = NSFetchRequest<CDRoot>(entityName: "CDRoot")
        let asyncRootFetchRequest = NSAsynchronousFetchRequest(fetchRequest: rootFetchRequest) { asynchronousFetchResult in
            guard let rootResults = asynchronousFetchResult.finalResult else { return }
            
            DispatchQueue.main.async {
                guard let objectID = rootResults.last?.objectID else { self.lastFileName = ""; return }
                guard let safePoint = self.appDelegate.managedObjectContext.object(with: objectID) as? CDRoot else { self.lastFileName = ""; return }
                self.lastFileName = safePoint.lastFileName ?? ""
                self.lastTracksegmentId = safePoint.lastTrackSegmentId
                self.isContinued = safePoint.continuedAfterSave
            }
        }
        return asyncRootFetchRequest
    }

    func trackPointFetchRequest() -> NSAsynchronousFetchRequest<CDTrackpoint> {
        // Creates a fetch request
        let trkptFetchRequest = NSFetchRequest<CDTrackpoint>(entityName: "CDTrackpoint")
        // Ensure that fetched data is ordered
        let sortTrkpt = NSSortDescriptor(key: "trackpointId", ascending: true)
        trkptFetchRequest.sortDescriptors = [sortTrkpt]
        
        // Creates `asynchronousFetchRequest` with the fetch request and the completion closure
        let asynchronousTrackPointFetchRequest = NSAsynchronousFetchRequest(fetchRequest: trkptFetchRequest) { asynchronousFetchResult in
            
            print("Core Data Helper: fetching recoverable trackpoints from Core Data")
            
            guard let trackPointResults = asynchronousFetchResult.finalResult else { return }
            // Dispatches to use the data in the main queue
            DispatchQueue.main.async {
                self.tracksegmentId = trackPointResults.first?.trackSegmentId ?? 0
                
                for result in trackPointResults {
                    let objectID = result.objectID
                    
                    // thread safe
                    guard let safePoint = self.appDelegate.managedObjectContext.object(with: objectID) as? CDTrackpoint else { continue }
                    
                    if self.tracksegmentId != safePoint.trackSegmentId {
                        if self.currentSegment.trackpoints.count > 0 {
                            self.tracksegments.append(self.currentSegment)
                            self.currentSegment = GPXTrackSegment()
                        }
                        
                        self.tracksegmentId = safePoint.trackSegmentId
                    }
                    
                    let pt = GPXTrackPoint(latitude: safePoint.latitude, longitude: safePoint.longitude)
                    
                    pt.time = safePoint.time
                    pt.elevation = safePoint.elevation
                    
                    self.currentSegment.trackpoints.append(pt)
                    
                }
                self.trackpointId = trackPointResults.last?.trackpointId ?? Int64()
                self.tracksegments.append(self.currentSegment)
            }
        }
        
        return asynchronousTrackPointFetchRequest
    }
    
}
