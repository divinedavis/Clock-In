import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ClockView()
                .tabItem { Label("Clock", systemImage: "clock.fill") }
            HistoryView()
                .tabItem { Label("History", systemImage: "calendar") }
            AccountView()
                .tabItem { Label("Account", systemImage: "person.circle") }
        }
    }
}
