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
                CalendarView()
                    .tabItem { Label("Calendar", systemImage: "calendar") }
                MessagesView()
                    .tabItem { Label("Messages", systemImage: "bubble.left.and.bubble.right.fill") }
            } else {
                ClockView()
                    .tabItem { Label("Clock", systemImage: "clock.fill") }
                JobsView()
                    .tabItem { Label("Jobs", systemImage: "briefcase.fill") }
                CalendarView()
                    .tabItem { Label("Calendar", systemImage: "calendar") }
                MessagesView()
                    .tabItem { Label("Messages", systemImage: "bubble.left.and.bubble.right.fill") }
            }
            AccountView()
                .tabItem { Label("Account", systemImage: "person.circle") }
        }
    }
}
