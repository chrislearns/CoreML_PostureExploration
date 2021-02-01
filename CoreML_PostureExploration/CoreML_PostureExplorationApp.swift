//
//  CoreML_PostureExplorationApp.swift
//  CoreML_PostureExploration
//
//  Created by Christopher Guirguis on 2/1/21.
//

import SwiftUI

@main
struct CoreML_PostureExplorationApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
