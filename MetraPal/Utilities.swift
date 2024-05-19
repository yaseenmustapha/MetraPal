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
}
