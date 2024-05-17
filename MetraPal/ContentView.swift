//
//  ContentView.swift
//  MetraPal
//
//  Created by Yaseen Mustapha on 5/5/24.
//

import SwiftUI
import MapKit
import Snap

enum MetraLine: String, Codable, CaseIterable, Identifiable {
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
    let routeId: MetraLine
}


struct PositionDetails: Codable {
    let latitude: Double
    let longitude: Double
    let bearing: Int
}

struct ContentView: View {
    @State private var drawerSize: AppleMapsSnapState = .medium
    @State private var trainPositions: [TrainPosition] = []
    @State private var selectedMetraLine: MetraLine = .UPW
    
    let coordinate = CLLocationCoordinate2D(latitude: 41.8781, longitude: -88)
    
    private var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.6, longitudeDelta: 0.6)
        )
    }
    
    var body: some View {
        
        ZStack {
            Map(position: .constant(.region(region))) {
                ForEach(filteredTrainPositions) { trainPosition in
                    Annotation(trainPosition.id, coordinate: CLLocationCoordinate2D(latitude: trainPosition.vehicle.position.latitude, longitude: trainPosition.vehicle.position.longitude)) {
                        VStack{
                            Text(trainPosition.id)
                            Text("🚆")
                                .font(.title)
                        }
                    }
                }
            }
            
            SnapDrawer(state: $drawerSize, large: .paddingToTop(12), medium: .fraction(0.58), tiny: .height(150), allowInvisible: false) { state in
                VStack {
                    Picker("Metra Line", selection: $selectedMetraLine) {
                        ForEach(MetraLine.allCases) { metraLine in
                            Text(metraLine.rawValue).tag(metraLine.rawValue)
                        }
                    }
                    
                    List(filteredTrainPositions, id: \.id) { trainPosition in
                        VStack(alignment: .leading) {
                            Text("Metra Line: \(trainPosition.vehicle.trip.routeId.rawValue)")
                                .font(.title3)
                            Text("Train ID: \(trainPosition.id)")
                            Text("Latitude: \(trainPosition.vehicle.position.latitude)")
                            Text("Longitude: \(trainPosition.vehicle.position.longitude)")
                            Text("Bearing: \(trainPosition.vehicle.position.bearing)")
                        }.listRowBackground(Color.clear)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        }.onAppear(perform: {
            fetchData()
        })
    }
    
    var filteredTrainPositions: [TrainPosition] {
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
    
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
