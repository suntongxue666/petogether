//
//  ContentView.swift
//  petogether
//
//  Created by Sun1 on 2025/10/23.
//

import SwiftUI
import SwiftData
import StoreKit

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }
            
            HistoryView()
                .tabItem {
                    Image(systemName: "clock")
                    Text("History")
                }
            
            MyView()
                .tabItem {
                    Image(systemName: "person")
                    Text("My")
                }
        }
    }
}

#Preview {
    ContentView()
}
