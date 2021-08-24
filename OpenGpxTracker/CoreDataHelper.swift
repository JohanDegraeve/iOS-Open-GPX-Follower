//
//  CoreDataHelper.swift
//  OpenGpxFollower
//
//    Based on Open GPX Tracker. Orignal source created by Vincent on 9/4/19.
//

import UIKit
import CoreData
import CoreGPX

/// Core Data implementation. As all Core Data related logic is contained here, I considered it as a helper.
///
/// Implementation learnt / inspired
/// from 4 part series:
/// https://marcosantadev.com/coredata_crud_concurrency_swift_1/
///
class CoreDataHelper {
    
    // MARK: IDs
    // ids to keep track of object's sequence
    
    /// for waypoints
    var waypointId = Int64()
    /// for trackpoints
    var trackpointId = Int64()
    
    /// id to seperate trackpoints in different tracksegements
    var tracksegmentId = Int64()
    
    var isContinued = false
    var lastTracksegmentId = Int64()
    
    // MARK: Other Declarations
    
    /// app delegate.
    // swiftlint:disable force_cast
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    // arrays for handling retrieval of data when needed.
    
    // recovered tracksegments
    var tracksegments = [GPXTrackSegment]()
    
    // recovered current segment
    var currentSegment = GPXTrackSegment()
    
    // recovered waypoints, inclusive of waypoints from previous file if file is loaded on recovery.
    var waypoints = [GPXWaypoint]()
    
    // last file name of the recovered file, if the recovered file was a continuation.
    var lastFileName = String()
    
    // MARK: Add to Core Data
    
    /// Adds the last file name to Core Data
    ///
    /// - Parameters:
    ///     - lastFileName: Last file name of the previously logged GPX file.
    ///
    func add(toCoreData lastFileName: String, willContinueAfterSave willContinue: Bool) {

        let childManagedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        // Creates the link between child and parent
        childManagedObjectContext.parent = appDelegate.managedObjectContext
        
        childManagedObjectContext.perform {
            let root = NSEntityDescription.insertNewObject(forEntityName: "CDRoot", into: childManagedObjectContext) as! CDRoot
            
            root.lastFileName = lastFileName
            root.continuedAfterSave = willContinue
            root.lastTrackSegmentId = self.tracksegmentId
            
            do {
                try childManagedObjectContext.save()
                self.appDelegate.managedObjectContext.performAndWait {
                    do {
                        // Saves the data from the child to the main context to be stored properly
                        try self.appDelegate.managedObjectContext.save()
                    } catch {
                        print("Failure to save parent context when adding last file name: \(error)")
                    }
                }
            } catch {
                print("Failure to save child context when adding last file name: \(error)")
            }
        }
    }
    
    /// Adds a trackpoint to Core Data
    ///
    /// A track segment ID should also be provided, such that trackpoints would be seperated in their track segments when recovered.
    /// - Parameters:
    ///     - trackpoint: the trackpoint meant to be added to Core Data
    ///     - Id: track segment ID that the trackpoint originally was in.
    ///
    func add(toCoreData trackpoint: GPXTrackPoint, withTrackSegmentID Id: Int) {
        let childManagedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        // Creates the link between child and parent
        childManagedObjectContext.parent = appDelegate.managedObjectContext
        
        childManagedObjectContext.perform {
            print("Core Data Helper: Add trackpoint with id: \(self.trackpointId)")
            // swiftlint:disable force_cast
            let pt = NSEntityDescription.insertNewObject(forEntityName: "CDTrackpoint", into: childManagedObjectContext) as! CDTrackpoint
            
            guard let elevation = trackpoint.elevation else { return }
            guard let latitude = trackpoint.latitude   else { return }
            guard let longitude = trackpoint.longitude else { return }
            
            pt.elevation = elevation
            pt.latitude = latitude
            pt.longitude = longitude
            pt.time = trackpoint.time
            pt.trackpointId = self.trackpointId
            pt.trackSegmentId = Int64(Id)
            
            // Serialization of trackpoint
            do {
                let serialized = try JSONEncoder().encode(trackpoint)
                pt.serialized = serialized
            } catch {
                print("Core Data Helper: serialization error when adding trackpoint: \(error)")
            }
            
            self.trackpointId += 1
            
            do {
                try childManagedObjectContext.save()
                self.appDelegate.managedObjectContext.performAndWait {
                    do {
                        // Saves the data from the child to the main context to be stored properly
                        try self.appDelegate.managedObjectContext.save()
                    } catch {
                        print("Failure to save parent context when adding trackpoint: \(error)")
                    }
                }
            } catch {
                print("Failure to save child context when adding trackpoint: \(error)")
            }
        }
    }
    
    /// Adds a waypoint to Core Data
    ///
    /// - Parameters:
    ///     - waypoint: the waypoint meant to be added to Core Data
    ///
    func add(toCoreData waypoint: GPXWaypoint) {
        let waypointChildManagedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        // Creates the link between child and parent
        waypointChildManagedObjectContext.parent = appDelegate.managedObjectContext
        
        waypointChildManagedObjectContext.perform {
            print("Core Data Helper: Add waypoint with id: \(self.waypointId)")
            // swiftlint:disable force_cast
            let pt = NSEntityDescription.insertNewObject(forEntityName: "CDWaypoint", into: waypointChildManagedObjectContext) as! CDWaypoint
            
            guard let latitude = waypoint.latitude   else { return }
            guard let longitude = waypoint.longitude else { return }
            
            if let elevation = waypoint.elevation {
                pt.elevation = elevation
            } else {
                pt.elevation = .greatestFiniteMagnitude
            }
            
            pt.name = waypoint.name
            pt.desc = waypoint.desc
            pt.latitude = latitude
            pt.longitude = longitude
            pt.time = waypoint.time
            pt.waypointId = self.waypointId
            
            // Serialization of trackpoint
            do {
                let serialized = try JSONEncoder().encode(waypoint)
                pt.serialized = serialized
            } catch {
                print("Core Data Helper: serialization error when adding waypoint: \(error)")
            }
            
            self.waypointId += 1
            
            do {
                try waypointChildManagedObjectContext.save()
                self.appDelegate.managedObjectContext.performAndWait {
                    do {
                        // Saves the data from the child to the main context to be stored properly
                        try self.appDelegate.managedObjectContext.save()
                    } catch {
                        print("Failure to save parent context when adding waypoint: \(error)")
                    }
                }
            } catch {
                print("Failure to save parent context when adding waypoint: \(error)")
            }
        }
    }
    
    // MARK: Update Core Data
    
    /// Updates a previously added waypoint to Core Data
    ///
    /// The waypoint at the given index will be updated accordingly.
    /// - Parameters:
    ///     - updatedWaypoint: the waypoint meant to replace a already added, Core Data waypoint.
    ///     - index: the waypoint that is meant to be replaced/updated to newer data.
    ///
    func update(toCoreData updatedWaypoint: GPXWaypoint, from index: Int) {
        let privateManagedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateManagedObjectContext.parent = appDelegate.managedObjectContext
        // Creates a fetch request
        let wptFetchRequest = NSFetchRequest<CDWaypoint>(entityName: "CDWaypoint")
        
        let asynchronousWaypointFetchRequest = NSAsynchronousFetchRequest(fetchRequest: wptFetchRequest) { asynchronousFetchResult in
            
            print("Core Data Helper: updating waypoint in Core Data")
            
            // Retrieves an array of points from Core Data
            guard let waypointResults = asynchronousFetchResult.finalResult else { return }
            
            privateManagedObjectContext.perform {
                let objectID = waypointResults[index].objectID
                guard let pt = self.appDelegate.managedObjectContext.object(with: objectID) as? CDWaypoint else { return }
                
                guard let latitude = updatedWaypoint.latitude   else { return }
                guard let longitude = updatedWaypoint.longitude else { return }
                
                if let elevation = updatedWaypoint.elevation {
                    pt.elevation = elevation
                } else {
                    pt.elevation = .greatestFiniteMagnitude
                }
                
                pt.name = updatedWaypoint.name
                pt.desc = updatedWaypoint.desc
                pt.latitude = latitude
                pt.longitude = longitude
                
                do {
                    try privateManagedObjectContext.save()
                    self.appDelegate.managedObjectContext.performAndWait {
                        do {
                            // Saves the changes from the child to the main context to be applied properly
                            try self.appDelegate.managedObjectContext.save()
                        } catch {
                            print("Failure to update and save waypoint to parent context: \(error)")
                        }
                    }
                } catch {
                    print("Failure to update and save waypoint to context at child context: \(error)")
                }
            }
            
        }
        
        do {
            try privateManagedObjectContext.execute(asynchronousWaypointFetchRequest)
        } catch {
            print("NSAsynchronousFetchRequest (for finding updatable waypoint) error: \(error)")
        }
    }
    
    /// Delete all objects of entity given as parameter in Core Data.
    func coreDataDeleteAll<T: NSManagedObject>(of type: T.Type) {
        
        print("Core Data Helper: Batch Delete \(T.self) from Core Data")

        if #available(iOS 10.0, *) {
            modernBatchDelete(of: T.self)
        } else { // for pre iOS 9 (less efficient, load in memory before removal)
            legacyBatchDelete(of: T.self)
        }
    }
    
    // MARK: Reset & Clear
    
    /// Resets trackpoints and waypoints Id
    ///
    /// the Id is to ensure that when retrieving the entities, the order remains.
    /// This is important to ensure that the resulting recovery file has the correct order.
    func resetIds() {
        self.trackpointId = 0
        self.waypointId = 0
        self.tracksegmentId = 0
        
    }
    
    /// Clear all arrays and current segment after recovery.
    func clearObjects() {
        self.tracksegments = []
        self.waypoints = []
        self.currentSegment = GPXTrackSegment()
    }
    
    func clearAllExceptWaypoints() {
        // once file recovery is completed, Core Data stored items are deleted.
        self.coreDataDeleteAll(of: CDTrackpoint.self)
        
        // once file recovery is completed, arrays are cleared.
        self.tracksegments = []
        
        // current segment should be 'reset' as well
        self.currentSegment = GPXTrackSegment()
        
        // reset order sorting ids
        self.trackpointId = 0
        self.tracksegmentId = 0
    }
    
    /// clears all
    func clearAll() {
        // once file recovery is completed, Core Data stored items are deleted.
        self.coreDataDeleteAll(of: CDTrackpoint.self)
        self.coreDataDeleteAll(of: CDWaypoint.self)
        
        // once file recovery is completed, arrays are cleared.
        self.clearObjects()
        
        // current segment should be 'reset' as well
        self.currentSegment = GPXTrackSegment()
        
        // reset order sorting ids
        self.resetIds()
        
    }
    
}
