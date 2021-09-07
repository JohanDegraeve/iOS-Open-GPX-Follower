import Foundation

/// for use in NSLog
fileprivate let tracePrefix = "GPXFollower-NSLog"

/// maximum size of one trace file, in MB. If size is larger, files will rotate, ie all trace files will be renamed, from xdriptrace.2.log to xdriptrace.3.log, from xdriptrace.1.log to xdriptrace.2.log, from xdriptrace.0.log to xdriptrace.1.log,
fileprivate let maximumFileSizeInMB: UInt64 = 3

/// - will be used as filename to store traces on disk, and attachment file name when sending trace via e-mail
/// - filename will be extended with digit, eg xdriptrace.0.log, or xdriptrace.1.log - the actual trace file is always xdriptrace.0.log
fileprivate let traceFileNameToUse = "gpxfollowertrace"

/// timestamp format for nslog
fileprivate let dateFormatNSLog = "y-MM-dd HH:mm:ss.SSSS"

/// maximum amount of trace files to hold. When rotating, and if value is 3, then tracefile xdriptrace.2.log will be deleted
fileprivate let maximumAmountOfTraceFiles = 3

/// application version
fileprivate var applicationVersion:String = {
    
    if let dictionary = Bundle.main.infoDictionary {
        
        if let version = dictionary["CFBundleShortVersionString"] as? String  {
            return version
        }
    }
    
    return "unknown"
    
}()

/// build number
fileprivate var buildNumber:String = {
    
    if let dictionary = Bundle.main.infoDictionary {
        
        if let buildnumber = dictionary["CFBundleVersion"] as? String  {
            return buildnumber
        }
        
    }
    
    return "unknown"
    
}()

/// dateformatter for nslog
fileprivate let dateFormatterNSLog: DateFormatter = {
    
    let dateFormatter = DateFormatter()
    
    dateFormatter.dateFormat = dateFormatNSLog
    
    return dateFormatter
    
}()

/// trace file currently in use, in case tracing needs to be stored on file
fileprivate var traceFileName:URL?

/// used during development
func debuglogging(_ logtext:String) {
    print("\(logtext)")
}

/// finds the path to where xdrip can save files
fileprivate func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
}

/// function to be used for logging, takes same parameters as os_log but in a next phase also NSLog can be added, or writing to disk to send later via e-mail ..
/// - message : the text, same format as in os_log with %{private} and %{public} to either keep variables private or public , for NSLog, only 3 String formatters are suppored "@" for String, "d" for Int, "f" for double.
/// - args : optional list of parameters that will be used. MAXIMUM 10 !
///
/// Example
func trace(_ message: StaticString, _ args: CVarArg...) {
    
    // initialize traceFileName if needed
    if traceFileName ==  nil {
        traceFileName = getDocumentsDirectory().appendingPathComponent(traceFileNameToUse + ".0.log")
    }
    guard let traceFileName = traceFileName else {return}
    
    // calculate string to log, replacing arguments
    
    var argumentsCounter: Int = 0
    
    var actualMessage = message.description
    
    // try to find the publicMark as long as argumentsCounter is less than the number of arguments
    while argumentsCounter < args.count {
        
        // mark to replace
        let publicMark = "%{public}"
        
        // get array of indexes of location of publicMark
        let indexesOfPublicMark = actualMessage.indexes(of: "%{public}")
        
        if indexesOfPublicMark.count > 0 {
            
            // range starts from first character until just before the publicMark
            let startOfMessageRange = actualMessage.startIndex..<indexesOfPublicMark[0]
            // text as String, until just before the publicMark
            let startOfMessage = String(actualMessage[startOfMessageRange])
            
            // range starts from just after the publicMark till the end
            var endOfMessageRange = actualMessage.index(indexesOfPublicMark[0], offsetBy: publicMark.count)..<actualMessage.endIndex
            // text as String, from just after the publicMark till the end
            var endOfMessage = String(actualMessage[endOfMessageRange])
            
            // no start looking for String Format Specifiers
            // possible formatting see https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFStrings/formatSpecifiers.html#//apple_ref/doc/uid/TP40004265
            // not doing them all
            
            if endOfMessage.starts(with: "@") {
                let indexOfAt = endOfMessage.indexes(of: "@")
                endOfMessageRange = endOfMessage.index(after: indexOfAt[0])..<endOfMessage.endIndex
                endOfMessage = String(endOfMessage[endOfMessageRange])
                if let argValue = args[argumentsCounter] as? String {
                    endOfMessage = argValue + endOfMessage
                }
            } else if endOfMessage.starts(with: "d") || endOfMessage.starts(with: "D") {
                let indexOfAt = endOfMessage.indexes(of: "d", options: [NSString.CompareOptions.caseInsensitive])
                endOfMessageRange = endOfMessage.index(after: indexOfAt[0])..<endOfMessage.endIndex
                endOfMessage = String(endOfMessage[endOfMessageRange])
                if let argValue = args[argumentsCounter] as? Int {
                    endOfMessage = argValue.description + endOfMessage
                }
            } else if endOfMessage.starts(with: "f") || endOfMessage.starts(with: "F") {
                let indexOfAt = endOfMessage.indexes(of: "f", options: [NSString.CompareOptions.caseInsensitive])
                endOfMessageRange = endOfMessage.index(after: indexOfAt[0])..<endOfMessage.endIndex
                endOfMessage = String(endOfMessage[endOfMessageRange])
                if let argValue = args[argumentsCounter] as? Double {
                    endOfMessage = argValue.description + endOfMessage
                }
            }
            
            actualMessage = startOfMessage + endOfMessage
            
        } else {
            // there's no more occurrences of the publicMark, no need to continue
            break
        }
        
        argumentsCounter += 1
        
    }
    
    // create timeStamp to use in NSLog and tracefile
    let timeStamp = dateFormatterNSLog.string(from: Date())
    
    // nslog
    NSLog("%@", tracePrefix + " " + timeStamp + " " + applicationVersion + " " + buildNumber + " " + actualMessage)
    
    // write trace to file
    do {
        
        let textToWrite = timeStamp + " " + applicationVersion + " " + buildNumber + " " + actualMessage + "\n"
        
        if let fileHandle = FileHandle(forWritingAtPath: traceFileName.path) {
            
            // file already exists, go to end of file and append text
            fileHandle.seekToEndOfFile()
            fileHandle.write(textToWrite.data(using: .utf8)!)
            
        } else {
            
            // file doesn't exist yet
            try textToWrite.write(to: traceFileName, atomically: true, encoding: String.Encoding.utf8)
            
        }
        
    } catch {
        NSLog("%@", tracePrefix + " " + dateFormatterNSLog.string(from: Date()) + " write trace to file failed")
    }
    
    // check if tracefile has reached limit size and if yes rotate the files
    if traceFileName.fileSize > maximumFileSizeInMB * 1024 * 1024 {
        
        rotateTraceFiles()
        
    }
    
}

fileprivate func rotateTraceFiles() {
    
    // assign fileManager
    let fileManager = FileManager.default
    
    // first check if last trace file exists
    let lastFile = getDocumentsDirectory().appendingPathComponent(traceFileNameToUse + "." + (maximumAmountOfTraceFiles - 1).description + ".log")
    if FileHandle(forWritingAtPath: lastFile.path) != nil {
        
        do {
            try fileManager.removeItem(at: lastFile)
        } catch {
            debuglogging("failed to delete file " + lastFile.absoluteString)
        }
        
    }
    
    // now rename trace files if they exist,
    for indexFrom0ToMax in 0...(maximumAmountOfTraceFiles - 2) {
        
        let index = (maximumAmountOfTraceFiles - 2) - indexFrom0ToMax
        
        let file = getDocumentsDirectory().appendingPathComponent(traceFileNameToUse + "." + index.description + ".log")
        let newFile = getDocumentsDirectory().appendingPathComponent(traceFileNameToUse + "." + (index + 1).description + ".log")
        
        if FileHandle(forWritingAtPath: file.path) != nil {
            
            do {
                try fileManager.moveItem(at: file, to: newFile)
            } catch {
                debuglogging("failed to rename file " + lastFile.absoluteString)
            }
            
        }
    }
    
    // now set tracefilename to nil, it will be reassigned to correct name, ie the one with index 0, at next usage
    traceFileName = nil
    
}

class Trace {
    
    // MARK: - private properties
    
    private static let paragraphSeperator = "\n\n===================================================\n\n"
    
    // MARK: - public static functions
    
    /// returns tuple, first type is an array of Data, each element is a tracefile converted to Data, second type is String, each element is the name of the tracefile
    static func getTraceFilesInData() -> ([Data], [String]) {
        
        var traceFilesInData = [Data]()
        var traceFileNames = [String]()
        
        for index in 0..<maximumAmountOfTraceFiles {
            
            let filename = traceFileNameToUse + "." + index.description + ".log"
            
            let file = getDocumentsDirectory().appendingPathComponent(filename)
            
            if FileHandle(forWritingAtPath: file.path) != nil {
                
                do {
                    // create traceFile info as data
                    let fileData = try Data(contentsOf: file)
                    traceFilesInData.append(fileData)
                    traceFileNames.append(filename)
                } catch {
                    debuglogging("failed to create data from  " + filename)
                }
                
            }
        }
        
        return (traceFilesInData, traceFileNames)
        
    }
    
}
