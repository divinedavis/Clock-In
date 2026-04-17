import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        TabView {
            if auth.isAdmin {
                AdminView()
                    .tabItem { Label("Admin", systemImage: "person.3.fill") }
            } else {
                ClockView()
                    .tabItem { Label("Clock", systemImage: "clock.fill") }
                HistoryView()
                    .tabItem { Label("History", systemImage: "calendar") }
            }
            AccountView()
                .tabItem { Label("Account", systemImage: "person.circle") }
        }
    }
}
