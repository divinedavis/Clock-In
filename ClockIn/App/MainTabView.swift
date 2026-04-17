import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        TabView {
            if auth.isAdmin {
                AdminView()
                    .tabItem { Label("Users", systemImage: "person.3.fill") }
                AdminJobsView()
                    .tabItem { Label("Jobs", systemImage: "briefcase.fill") }
            } else {
                ClockView()
                    .tabItem { Label("Clock", systemImage: "clock.fill") }
                JobsView()
                    .tabItem { Label("Jobs", systemImage: "briefcase.fill") }
                HistoryView()
                    .tabItem { Label("History", systemImage: "calendar") }
            }
            AccountView()
                .tabItem { Label("Account", systemImage: "person.circle") }
        }
    }
}
