import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        TabView {
            ClockView()
                .tabItem { Label("Clock", systemImage: "clock.fill") }
            HistoryView()
                .tabItem { Label("History", systemImage: "calendar") }
            if auth.isAdmin {
                AdminView()
                    .tabItem { Label("Admin", systemImage: "person.3.fill") }
            }
            AccountView()
                .tabItem { Label("Account", systemImage: "person.circle") }
        }
    }
}
