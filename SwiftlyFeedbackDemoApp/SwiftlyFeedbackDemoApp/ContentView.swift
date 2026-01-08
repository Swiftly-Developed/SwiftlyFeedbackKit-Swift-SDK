//
//  ContentView.swift
//  SwiftlyFeedbackDemoApp
//
//  Created by Ben Van Aken on 03/01/2026.
//

import SwiftUI
import SwiftlyFeedbackKit

struct ContentView: View {
    var settings: AppSettings

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            List {
                NavigationLink {
                    HomeView()
                } label: {
                    Label("Home", systemImage: "house.fill")
                }

                NavigationLink {
                    FeedbackListView()
                } label: {
                    Label("Feedback", systemImage: "bubble.left.and.bubble.right.fill")
                }

                NavigationLink {
                    ConfigurationView(settings: settings)
                } label: {
                    Label("Settings", systemImage: "gearshape.fill")
                }
            }
            .navigationTitle("Feedback Kit")
        } detail: {
            HomeView()
        }
        #else
        TabView {
            Tab("Home", systemImage: "house.fill") {
                NavigationStack {
                    HomeView()
                }
            }

            Tab("Feedback", systemImage: "bubble.left.and.bubble.right.fill") {
                FeedbackListView()
            }

            Tab("Settings", systemImage: "gearshape.fill") {
                NavigationStack {
                    ConfigurationView(settings: settings)
                }
            }
        }
        #endif
    }
}

#Preview {
    ContentView(settings: AppSettings())
}
