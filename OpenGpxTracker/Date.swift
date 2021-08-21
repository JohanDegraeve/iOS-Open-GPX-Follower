//
//  Date.swift
//  OpenGpxTracker
//
//  Created by Johan Degraeve on 20/08/2021.
//

import Foundation

extension Date {
    
    //source https://freakycoder.com/ios-notes-22-how-to-get-current-time-as-timestamp-fa8a0d422879
    /// extension to Date class
    /// - returns:
    ///     time since 1 Jan 1970 in ms, can be negative if Date is before 1 Jan 1970
    func toMillisecondsAsDouble() -> Double {
        return Double(self.timeIntervalSince1970 * 1000)
    }

    /// date to string, with date and time as specified by one of the values in DateFormatter.Style
    func toString(timeStyle: DateFormatter.Style, dateStyle: DateFormatter.Style) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = timeStyle
        dateFormatter.dateStyle = dateStyle
        return dateFormatter.string(from: self)
    }

}
