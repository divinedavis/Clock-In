import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            if auth.isAdmin {
                AdminView()
                    .tabItem { Label("Users", systemImage: "person.3.fill") }
                    .tag(0)
                AdminJobsView()
                    .tabItem { Label("Jobs", systemImage: "briefcase.fill") }
                    .tag(1)
                CalendarView()
                    .tabItem { Label("Calendar", systemImage: "calendar") }
                    .tag(2)
                MessagesView()
                    .tabItem { Label("Messages", systemImage: "bubble.left.and.bubble.right.fill") }
                    .tag(3)
            } else {
                ClockView()
                    .tabItem { Label("Clock", systemImage: "clock.fill") }
                    .tag(0)
                JobsView()
                    .tabItem { Label("Jobs", systemImage: "briefcase.fill") }
                    .tag(1)
                CalendarView()
                    .tabItem { Label("Calendar", systemImage: "calendar") }
                    .tag(2)
                MessagesView()
                    .tabItem { Label("Messages", systemImage: "bubble.left.and.bubble.right.fill") }
                    .tag(3)
            }
            AccountView()
                .tabItem { Label("Account", systemImage: "person.circle") }
                .tag(4)
        }
        #if DEBUG
        .onAppear { applyScreenshotSelectionIfNeeded() }
        #endif
    }

    #if DEBUG
    // Marketing screenshot support (DEBUG-only, used to capture App Store screenshots). See ScreenshotMode.
    private func applyScreenshotSelectionIfNeeded() {
        switch ScreenshotMode.screen {
        case "jobs": selection = 1
        case "account": selection = 4
        default: break
        }
    }
    #endif
}
