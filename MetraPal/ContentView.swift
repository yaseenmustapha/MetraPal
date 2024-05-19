//
//  ContentView.swift
//  MetraPal
//
//  Created by Yaseen Mustapha on 5/5/24.
//

import SwiftUI
import MapKit
import Snap

struct ShapePoint: Codable {
    let shapeId: String
    let shapePtLat: Double
    let shapePtLon: Double
    let shapePtSequence: Int
}

// extend Color struct to accept hex values
extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

enum MetraLine: String, Codable, CaseIterable, Identifiable {
    case All = "All Metra Lines"
    case ME = "ME"
    case RI = "RI"
    case SWS = "SWS"
    case HC = "HC"
    case BNSF = "BNSF"
    case UPW = "UP-W"
    case MDW = "MD-W"
    case UPNW = "UP-NW"
    case NCS = "NCS"
    case MDN = "MD-N"
    case UPN = "UP-N"
    
    var id: Self { self }
    
    var color: Color {
        switch self {
        case .All:
            return .blue
        case .ME:
            return Color(hex: 0xFF4E00)
        case .RI:
            return Color(hex: 0xE1261D)
        case .SWS:
            return Color(hex: 0x005EB9)
        case .HC:
            return Color(hex: 0x8B1E41)
        case .BNSF:
            return Color(hex: 0x3DAF2C)
        case .UPW:
            return Color(hex: 0xFFB2B9)
        case .MDW:
            return Color(hex: 0xF4B24A)
        case .UPNW:
            return Color(hex: 0xFEDE02)
        case .NCS:
            return Color(hex: 0x62319F)
        case .MDN:
            return Color(hex: 0xE97200)
        case .UPN:
            return Color(hex: 0x0D5200)
        }
    }
}

struct Station: Codable, Identifiable {
    var id: String { stopId }
    let stopId: String
    let stopName: String
    let stopDesc: String
    let stopLat: Double
    let stopLon: Double
    let zoneId: Int
    let stopUrl: String
    let wheelchairBoarding: Int
}

struct StopTime: Codable, Identifiable {
    var id: Int { stopSequence }
    let tripId: String
    let arrivalTime: String
    let departureTime: String
    let stopId: String
    let stopSequence: Int
    let pickupType: Int
    let dropOffType: Int
    let centerBoarding: Int
    let southBoarding: Int
    let bikesAllowed: Int
    let notice: Int
}


struct TrainPosition: Codable, Identifiable {
    let id: String
    let vehicle: VehicleDetails
}

struct VehicleDetails: Codable {
    let trip: TripDetails
    let position: PositionDetails
}

struct TripDetails: Codable {
    let tripId: String
    let routeId: MetraLine
}


struct PositionDetails: Codable {
    let latitude: Double
    let longitude: Double
    let bearing: Int
}

struct ContentView: View {
    @State private var position: MapCameraPosition = .automatic
    
    @State private var shapePoints: [String: [CLLocationCoordinate2D]] = [:]
    
    @StateObject private var viewModel = ContentViewModel()
    @State private var drawerSize: AppleMapsSnapState = .medium
    @State private var refetchTimer: Timer? = nil
    @State private var stations: [Station] = []
    @State private var trainPositions: [TrainPosition] = []
    @State private var selectedMetraLine: MetraLine = .All
    @State private var selectedTripId: String? = nil
    @State private var selectedTripStopTimes: [StopTime] = []
    
    var body: some View {
        ZStack {
            Map(position: $position) {
                // Draw shape points for all shape IDs:
                if selectedMetraLine == .All {
                    ForEach(MetraLine.allCases, id: \.self) { metraLine in
                        ForEach(shapePoints.keys.sorted(), id: \.self) { shapeId in
                            if shapeId.hasPrefix(metraLine.rawValue) {
                                MapPolyline(coordinates: shapePoints[shapeId] ?? [])
                                    .stroke(metraLine.color, lineWidth: 3)
                            }
                        }
                    }
                }
                
                // Only way to get the metra line is from the URL after the 5th "/" BUT it might not always be there (for CUS and OTC stations only)
                ForEach(stations) { station in
                    if selectedMetraLine == .All || station.stopUrl.split(separator: "/").count < 5 || station.stopUrl.split(separator: "/")[4] == selectedMetraLine.rawValue {
                        Annotation(station.stopId, coordinate: CLLocationCoordinate2D(latitude: station.stopLat, longitude: station.stopLon)) {
                            // Draw a small circle for each station
                            ZStack {
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 5, height: 5)
                                    .opacity(0.7)
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 3, height: 3)
                                    .opacity(0.7)
                            }
                        }.annotationTitles(Visibility.hidden)
                    }
                }
                
                
                // Draw all lines for the selected metra line
                // selectedMetraLine should be the prefix of the shape ID. Ex: "UP-W_IB_1" and "UP-W_OB_1" are shape IDs for the UP-W line
                ForEach(shapePoints.keys.sorted(), id: \.self) { shapeId in
                    if shapeId.hasPrefix(selectedMetraLine.rawValue) {
                        MapPolyline(coordinates: shapePoints[shapeId] ?? [])
                            .stroke(selectedMetraLine.color, lineWidth: 4)
                    }
                }
                
                // Draw all train annotations for the selected metra line
                ForEach(filteredTrainPositions) { trainPosition in
                    Annotation(trainPosition.id, coordinate: CLLocationCoordinate2D(latitude: trainPosition.vehicle.position.latitude, longitude: trainPosition.vehicle.position.longitude)) {
                        ZStack {
                            Text("🚆")
                                .font(.title)
                            
                            // small font size
                            Text(trainPosition.id)
                                .font(.system(size: 9))
                                .offset(y: -3)
                                
                            
                            Image(systemName: "arrow.up")
                                .rotationEffect(.degrees(Double(trainPosition.vehicle.position.bearing)))
                                .offset(x: offsetForBearing(bearing: trainPosition.vehicle.position.bearing).x, y: offsetForBearing(bearing: trainPosition.vehicle.position.bearing).y)
                        }
                    }.annotationTitles(Visibility.hidden)
                }
                
                UserAnnotation()
            }
            .safeAreaInset(edge: .bottom) {
                // push bottom of map up
                VStack {}.padding(.top, 260)
            }
            .safeAreaInset(edge: .top) {
                // push controls down
                VStack {}.padding(.top, 20)
            }
            .onChange(of: selectedMetraLine) {
                position = .automatic
            }
            .onAppear {
                viewModel.checkIfLocationServicesIsEnabled()
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            
            SnapDrawer(state: $drawerSize, large: .paddingToTop(12), medium: .fraction(0.58), tiny: .height(150), allowInvisible: false) { state in
                VStack {
                    if (selectedTripId != nil) {
                        ZStack{
                            HStack{
                                Button(action: {
                                    selectedTripId = nil
                                    position = .automatic
                                }) {
                                    Image(systemName: "chevron.left")
                                    Text("Back")
                                }
                                .padding(.leading, 10)
                                Spacer()
                            }
                            
                            HStack{
                                Text(selectedTripId!)
                            }
                        }
                        
                        List(selectedTripStopTimes, id: \.id) { stopTime in
                            VStack(alignment: .leading) {
                                Text(stopTime.stopId)
                                    .font(.title3)
                                Text("Stop Sequence: \(stopTime.stopSequence)")
                                Text("Arrival Time: \(formatTime(time: stopTime.arrivalTime))")
                            }
                            .listRowBackground(Color.clear)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        
                    } else {
                        Picker("Metra Line", selection: $selectedMetraLine) {
                            ForEach(MetraLine.allCases) { metraLine in
                                Text(metraLine.rawValue).tag(metraLine.rawValue)
                            }
                        }
                        
                        if (filteredTrainPositions.isEmpty) {
                            Spacer()
                            Text("No trains found for the \(selectedMetraLine.rawValue) metra line")
                            Spacer()
                        } else {
                            List(filteredTrainPositions, id: \.id) { trainPosition in
                                VStack(alignment: .leading) {
                                    if (selectedMetraLine == .All) {
                                        Text("Metra Line: \(trainPosition.vehicle.trip.routeId.rawValue)")
                                            .font(.title3)
                                    }
                                    Text("Train #\(trainPosition.id)")
                                        .font(.title3)
                                    Text("Latitude: \(trainPosition.vehicle.position.latitude)")
                                    Text("Longitude: \(trainPosition.vehicle.position.longitude)")
                                    Text("Bearing: \(trainPosition.vehicle.position.bearing)")
                                }
                                .listRowBackground(Color.clear)
                                .onTapGesture {
                                    selectedTripId = trainPosition.vehicle.trip.tripId
                                    fetchStopTimes(tripId: trainPosition.vehicle.trip.tripId)
                                    position = .region(
                                        MKCoordinateRegion(
                                            center: CLLocationCoordinate2D(latitude: trainPosition.vehicle.position.latitude, longitude: trainPosition.vehicle.position.longitude),
                                            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
                                    )
                                }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                        }
                        
                    }
                    
                }
            }
        }.onAppear(perform: {
            fetchData()
            fetchShapePoints()
            fetchStations()
            startRefetchTimer()
        })
        .onDisappear(perform: {
            stopRefetchTimer()
        })
    }
    
    func offsetForBearing(bearing: Int) -> CGPoint {
        let offset: CGFloat = 20
        let x = offset * CGFloat(sin(Double(bearing) * Double.pi / 180))
        let y = offset * CGFloat(cos(Double(bearing) * Double.pi / 180))
        return CGPoint(x: x, y: -y)
    }
    
    func startRefetchTimer() {
        refetchTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            fetchData()
        }
    }
    
    func stopRefetchTimer() {
        refetchTimer?.invalidate()
        refetchTimer = nil
    }
    
    var filteredTrainPositions: [TrainPosition] {
        if selectedMetraLine == .All {
            return trainPositions
        }
        return trainPositions.filter { $0.vehicle.trip.routeId == selectedMetraLine }
    }
    
    func fetchData() {
        guard let url = URL(string: "https://gtfsapi.metrarail.com/gtfs/positions") else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let username = "24adf46e6f327dfbf5510fa8eb4bd625"
        let password = "475115b80ded9d9944b0f0d50a3e6835"
        let loginString = "\(username):\(password)"
        let loginData = loginString.data(using: .utf8)!
        let base64LoginString = loginData.base64EncodedString()
        
        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching data: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("No data received")
                return
            }
            
            do {
                let jsonString = String(data: data, encoding: .utf8) ?? "Data not in UTF-8 format"
                print("JSON Data: \(jsonString)")
                
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let trainPositions = try decoder.decode([TrainPosition].self, from: data)
                DispatchQueue.main.async {
                    self.trainPositions = trainPositions
                }
            } catch {
                print("Error decoding JSON: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    // fetch the metra stations
    func fetchStations() {
        guard let url = URL(string: "https://gtfsapi.metrarail.com/gtfs/schedule/stops") else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let username = "24adf46e6f327dfbf5510fa8eb4bd625"
        let password = "475115b80ded9d9944b0f0d50a3e6835"
        let loginString = "\(username):\(password)"
        let loginData = loginString.data(using: .utf8)!
        let base64LoginString = loginData.base64EncodedString()
        
        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching data: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("No data received")
                return
            }
            
            do {
                let jsonString = String(data: data, encoding: .utf8) ?? "Data not in UTF-8 format"
                print("JSON Data: \(jsonString)")
                
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let stations = try decoder.decode([Station].self, from: data)
                DispatchQueue.main.async {
                    self.stations = stations
                }
            } catch {
                print("Error decoding JSON: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    
    // fetch stop times for given trip id
    func fetchStopTimes(tripId: String) {
        guard let url = URL(string: "https://gtfsapi.metrarail.com/gtfs/schedule/stop_times/\(tripId)") else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let username = "24adf46e6f327dfbf5510fa8eb4bd625"
        let password = "475115b80ded9d9944b0f0d50a3e6835"
        let loginString = "\(username):\(password)"
        let loginData = loginString.data(using: .utf8)!
        let base64LoginString = loginData.base64EncodedString()
        
        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching data: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("No data received")
                return
            }
            
            do {
                let jsonString = String(data: data, encoding: .utf8) ?? "Data not in UTF-8 format"
                print("JSON Data: \(jsonString)")
                
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let stopTimes = try decoder.decode([StopTime].self, from: data)
                DispatchQueue.main.async {
                    self.selectedTripStopTimes = stopTimes
                }
            } catch {
                print("Error decoding JSON: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    func fetchShapePoints() {
        guard let url = URL(string: "https://gtfsapi.metrarail.com/gtfs/schedule/shapes") else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let username = "24adf46e6f327dfbf5510fa8eb4bd625"
        let password = "475115b80ded9d9944b0f0d50a3e6835"
        let loginString = "\(username):\(password)"
        let loginData = loginString.data(using: .utf8)!
        let base64LoginString = loginData.base64EncodedString()
        
        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching data: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("No data received")
                return
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let shapePoints = try decoder.decode([ShapePoint].self, from: data)
                
                // Group shape points by shapeId
                let groupedShapePoints = Dictionary(grouping: shapePoints, by: { $0.shapeId })
                
                // Convert grouped shape points to CLLocationCoordinate2D arrays
                var coordinatesByShapeId: [String: [CLLocationCoordinate2D]] = [:]
                for (shapeId, points) in groupedShapePoints {
                    let coordinates = points.map { CLLocationCoordinate2D(latitude: $0.shapePtLat, longitude: $0.shapePtLon) }
                    coordinatesByShapeId[shapeId] = coordinates
                }
                
                DispatchQueue.main.async {
                    self.shapePoints = coordinatesByShapeId
                }
            } catch {
                print("Error decoding shape JSON: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    func formatTime(time: String) -> String {
        // check if time is in 24 hour format (sometimes API gives something like 25:00:00)
        if time.count == 8 {
            return "Invalid time format"
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        let date = dateFormatter.date(from: time)
        
        dateFormatter.dateFormat = "h:mm a"
        return dateFormatter.string(from: date!)
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

final class ContentViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    var locationManager: CLLocationManager?
    
    func checkIfLocationServicesIsEnabled() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager = CLLocationManager()
            locationManager!.delegate = self
        } else {
            print("Show an alert letting them know this is off and to go turn it on.")
        }
    }
    
    private func checkLocationAuthorization() {
        guard let locationManager = locationManager else { return }
        
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted:
            print("Your location is restricted likely due to parental controls.")
        case .denied:
            print("You have denied location access. Go into your settings to change it.")
        case .authorizedAlways, .authorizedWhenInUse:
            break
        @unknown default:
            break
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationAuthorization()
    }
}
