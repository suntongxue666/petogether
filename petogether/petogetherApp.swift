//
//  petogetherApp.swift
//  petogether
//
//  Created by Sun1 on 2025/10/23.
//

import SwiftUI
import SwiftData

@main
struct petogetherApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PhotoRecord.self,
            SceneCategory.self,
            SceneSubcategory.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
