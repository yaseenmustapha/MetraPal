//
//  Utilities.swift
//  MetraPal
//
//  Created by Yaseen Mustapha on 5/19/24.
//

import Foundation

import Foundation

class Utilities {
    static func formatTime(time: String) -> String {
        // check if time is in 24 hour format (sometimes API gives something like 25:00:00 which is not a valid 24hr time)
        if time.split(separator: ":")[0] > "24" {
            return "Invalid Time"
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        guard let date = dateFormatter.date(from: time) else {
            return "Invalid Time"
        }
        
        dateFormatter.dateFormat = "h:mm a"
        return dateFormatter.string(from: date)
    }
    
    // calculate number of minutes between now and a given time
    static func minutesUntil(time: String) -> Int {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        guard let date = dateFormatter.date(from: time) else {
            return -1
        }
        
        let now = Date()
        let calendar = Calendar.current
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: date)
        
        let nowMinutes = nowComponents.hour! * 60 + nowComponents.minute!
        let timeMinutes = timeComponents.hour! * 60 + timeComponents.minute!
        
        return timeMinutes - nowMinutes
    }
    
    // use the minutesUtil function to create a string that says how many minutes until a given time (ex: "in 5 minutes", "Now" (for 0 min), "5 minutes ago")
    static func timeUntil(time: String) -> String {
        let minutes = minutesUntil(time: time)
        
        if minutes == 0 {
            return "Now"
        } else if minutes < 0 {
            return "\(minutes * -1) minute\(minutes == -1 ? "" : "s") ago"
        } else {
            return "in \(minutes) minute\(minutes == 1 ? "" : "s")"
        }
    }
    
    // check if a given time is in the past
    // check if a given time is in the past
    static func isPast(time: String) -> Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        guard let timeDate = dateFormatter.date(from: time) else {
            return false
        }
        
        let now = Date()
        let calendar = Calendar.current
        let nowComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
        var timeComponents = calendar.dateComponents([.hour, .minute, .second], from: timeDate)
        timeComponents.year = nowComponents.year
        timeComponents.month = nowComponents.month
        timeComponents.day = nowComponents.day
        
        guard let fullDate = calendar.date(from: timeComponents) else {
            return false
        }
        
        return fullDate < now
    }
}
