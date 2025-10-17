//
//  GardenCommunityApp.swift
//  CommunityGarden
//
//  Created by ChatGPT GPT-5 on 2025-10-17.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseStorage
import PhotosUI
import Combine

// MARK: - Firebase Setup
@main
struct GardenCommunityApp: App {
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(FirestoreManager())
        }
    }
}

// MARK: - Firestore Manager
class FirestoreManager: ObservableObject {
    @Published var tasks: [GardenTask] = []
    @Published var plants: [Plant] = []
    @Published var events: [GardenEvent] = []
    @Published var donations: [Donation] = []
    
    private var db = Firestore.firestore()
    
    init() {
        fetchTasks()
        fetchPlants()
        fetchEvents()
        fetchDonations()
    }
    
    // Volunteer Tasks
    func fetchTasks() {
        db.collection("tasks").addSnapshotListener { snap, err in
            guard let docs = snap?.documents else { return }
            self.tasks = docs.compactMap { doc in
                let d = doc.data()
                return GardenTask(
                    id: doc.documentID,
                    title: d["title"] as? String ?? "",
                    assignedTo: d["assignedTo"] as? String ?? "",
                    date: (d["date"] as? Timestamp)?.dateValue() ?? Date(),
                    completed: d["completed"] as? Bool ?? false
                )
            }
        }
    }
    
    func addTask(title: String, assignedTo: String, date: Date) {
        db.collection("tasks").addDocument(data: [
            "title": title,
            "assignedTo": assignedTo,
            "date": date,
            "completed": false
        ])
    }
    
    func updateTask(_ task: GardenTask) {
        db.collection("tasks").document(task.id).updateData(["completed": !task.completed])
    }
    
    func deleteTask(_ task: GardenTask) {
        db.collection("tasks").document(task.id).delete()
    }
    
    // Plants
    func fetchPlants() {
        db.collection("plants").addSnapshotListener { snap, _ in
            guard let docs = snap?.documents else { return }
            self.plants = docs.compactMap { doc in
                let d = doc.data()
                return Plant(
                    id: doc.documentID,
                    name: d["name"] as? String ?? "",
                    growthStage: d["growthStage"] as? String ?? "",
                    lastWatered: (d["lastWatered"] as? Timestamp)?.dateValue() ?? Date()
                )
            }
        }
    }
    
    // Events
    func fetchEvents() {
        db.collection("events").addSnapshotListener { snap, _ in
            guard let docs = snap?.documents else { return }
            self.events = docs.compactMap { doc in
                let d = doc.data()
                return GardenEvent(
                    id: doc.documentID,
                    title: d["title"] as? String ?? "",
                    description: d["description"] as? String ?? "",
                    date: (d["date"] as? Timestamp)?.dateValue() ?? Date(),
                    imagePath: d["imagePath"] as? String
                )
            }
        }
    }
    
    // Donations
    func fetchDonations() {
        db.collection("donations").addSnapshotListener { snap, _ in
            guard let docs = snap?.documents else { return }
            self.donations = docs.compactMap { doc in
                let d = doc.data()
                return Donation(
                    id: doc.documentID,
                    donorName: d["donorName"] as? String ?? "",
                    item: d["item"] as? String ?? "",
                    quantity: d["quantity"] as? Int ?? 0
                )
            }
        }
    }
}

// MARK: - Storage Manager
class StorageManager {
    static let shared = StorageManager()
    private let storage = Storage.storage()
    
    func uploadImage(_ data: Data, path: String, completion: @escaping (Result<String, Error>) -> Void) {
        let ref = storage.reference().child(path)
        ref.putData(data, metadata: nil) { _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            ref.downloadURL { url, error in
                if let url = url {
                    completion(.success(url.absoluteString))
                } else if let error = error {
                    completion(.failure(error))
                }
            }
        }
    }
}

// MARK: - Models
struct GardenTask: Identifiable {
    let id: String
    let title: String
    let assignedTo: String
    let date: Date
    let completed: Bool
}

struct Plant: Identifiable {
    let id: String
    let name: String
    let growthStage: String
    let lastWatered: Date
}

struct GardenEvent: Identifiable {
    let id: String
    let title: String
    let description: String
    let date: Date
    let imagePath: String?
}

struct Donation: Identifiable {
    let id: String
    let donorName: String
    let item: String
    let quantity: Int
}

// MARK: - Main Content View
struct ContentView: View {
    var body: some View {
        TabView {
            TasksView()
                .tabItem { Label("Volunteers", systemImage: "person.3.fill") }
            PlantsView()
                .tabItem { Label("Plants", systemImage: "leaf.fill") }
            UpdatesView()
                .tabItem { Label("Updates", systemImage: "photo.on.rectangle") }
            DonationsView()
                .tabItem { Label("Donations", systemImage: "gift.fill") }
        }
    }
}

// MARK: - TasksView
struct TasksView: View {
    @EnvironmentObject var firestore: FirestoreManager
    @State private var title = ""
    @State private var assignedTo = ""
    @State private var date = Date()
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(firestore.tasks) { task in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(task.title).font(.headline)
                                Text("Assigned to: \(task.assignedTo)").font(.subheadline)
                                Text(task.date.formatted(date: .abbreviated, time: .omitted)).font(.caption)
                            }
                            Spacer()
                            Button {
                                firestore.updateTask(task)
                            } label: {
                                Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .onDelete { indexSet in
                        indexSet.map { firestore.tasks[$0] }.forEach(firestore.deleteTask)
                    }
                }
                
                Divider().padding()
                
                VStack {
                    TextField("Task title", text: $title)
                        .textFieldStyle(.roundedBorder)
                    TextField("Assigned to", text: $assignedTo)
                        .textFieldStyle(.roundedBorder)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    
                    Button("Add Task") {
                        firestore.addTask(title: title, assignedTo: assignedTo, date: date)
                        title = ""
                        assignedTo = ""
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .navigationTitle("Volunteer Schedule")
        }
    }
}

// MARK: - PlantsView
struct PlantsView: View {
    @EnvironmentObject var firestore: FirestoreManager
    @State private var newPlantName = ""
    @State private var stage = ""
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(firestore.plants) { plant in
                        VStack(alignment: .leading) {
                            Text(plant.name).font(.headline)
                            Text("Stage: \(plant.growthStage)")
                            Text("Last watered: \(plant.lastWatered.formatted(date:.abbreviated, time:.omitted))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                VStack(spacing: 8) {
                    TextField("Plant name", text: $newPlantName)
                        .textFieldStyle(.roundedBorder)
                    TextField("Growth stage", text: $stage)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Add Plant") {
                        guard !newPlantName.isEmpty else { return }
                        let data: [String: Any] = [
                            "name": newPlantName,
                            "growthStage": stage,
                            "lastWatered": Date()
                        ]
                        Firestore.firestore().collection("plants").addDocument(data: data)
                        newPlantName = ""
                        stage = ""
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .navigationTitle("Plant Tracker")
        }
    }
}

// MARK: - UpdatesView
struct UpdatesView: View {
    @EnvironmentObject var firestore: FirestoreManager
    @State private var newTitle = ""
    @State private var newDesc = ""
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var uploading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack {
                    ForEach(firestore.events) { ev in
                        VStack(alignment: .leading) {
                            HStack {
                                if let path = ev.imagePath, let url = URL(string: path) {
                                    AsyncImage(url: url) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        ProgressView()
                                    }
                                    .frame(width: 60, height: 60)
                                    .clipped()
                                    .cornerRadius(6)
                                }
                                VStack(alignment: .leading) {
                                    Text(ev.title).font(.headline)
                                    Text(ev.date.formatted(date:.abbreviated, time:.omitted))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Text(ev.description).padding(.leading, 4)
                        }
                        .padding()
                        Divider()
                    }
                }
                
                Divider().padding(.vertical)
                
                Group {
                    TextField("Event title", text: $newTitle)
                        .textFieldStyle(.roundedBorder)
                    TextField("Description", text: $newDesc)
                        .textFieldStyle(.roundedBorder)
                    
                    PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                        Label("Select Photo", systemImage: "photo")
                    }
                    .onChange(of: selectedItem) { oldValue, newValue in
                        Task {
                            if let item = newValue, let data = try? await item.loadTransferable(type: Data.self) {
                                selectedImageData = data
                            }
                        }
                    }
                    
                    Button(uploading ? "Uploading..." : "Create Event") {
                        guard !uploading else { return }
                        uploading = true
                        
                        let id = UUID().uuidString
                        if let data = selectedImageData {
                            let path = "events/\(id).jpg"
                            StorageManager.shared.uploadImage(data, path: path) { result in
                                switch result {
                                case .success(let urlString):
                                    addEvent(imagePath: urlString)
                                case .failure(let err):
                                    print("Upload error:", err.localizedDescription)
                                }
                                uploading = false
                            }
                        } else {
                            addEvent(imagePath: nil)
                            uploading = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 6)
                }
                .padding()
            }
            .navigationTitle("Garden Updates")
        }
    }
    
    private func addEvent(imagePath: String?) {
        let data: [String: Any] = [
            "title": newTitle,
            "description": newDesc,
            "date": Date(),
            "imagePath": imagePath as Any
        ]
        Firestore.firestore().collection("events").addDocument(data: data)
        newTitle = ""
        newDesc = ""
        selectedImageData = nil
        selectedItem = nil
    }
}

// MARK: - DonationsView
struct DonationsView: View {
    @EnvironmentObject var firestore: FirestoreManager
    @State private var donor = ""
    @State private var item = ""
    @State private var quantity = ""
    
    var body: some View {
        NavigationView {
            VStack {
                List(firestore.donations) { donation in
                    VStack(alignment: .leading) {
                        Text("\(donation.item) — \(donation.quantity)")
                            .font(.headline)
                        Text("Donated by \(donation.donorName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(spacing: 8) {
                    TextField("Donor Name", text: $donor)
                        .textFieldStyle(.roundedBorder)
                    TextField("Item", text: $item)
                        .textFieldStyle(.roundedBorder)
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Add Donation") {
                        guard let qty = Int(quantity), !donor.isEmpty, !item.isEmpty else { return }
                        let data: [String: Any] = [
                            "donorName": donor,
                            "item": item,
                            "quantity": qty
                        ]
                        Firestore.firestore().collection("donations").addDocument(data: data)
                        donor = ""
                        item = ""
                        quantity = ""
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .navigationTitle("Donations")
        }
    }
}

//raa
