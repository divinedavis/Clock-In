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
                AdminFormsView()
                    .tabItem { Label("Forms", systemImage: "doc.text.fill") }
            } else {
                ClockView()
                    .tabItem { Label("Clock", systemImage: "clock.fill") }
                JobsView()
                    .tabItem { Label("Jobs", systemImage: "briefcase.fill") }
                CalendarView()
                    .tabItem { Label("Calendar", systemImage: "calendar") }
                FormsView()
                    .tabItem { Label("Forms", systemImage: "doc.text.fill") }
            }
            AccountView()
                .tabItem { Label("Account", systemImage: "person.circle") }
        }
    }
}
