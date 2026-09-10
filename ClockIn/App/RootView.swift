import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        Group {
            switch auth.state {
            case .loading:
                ProgressView().controlSize(.large)
            case .signedOut:
                AuthView()
            case .signedIn:
                #if DEBUG
                if let screen = ScreenshotMode.screen, screen == "historyWeek" || screen == "historyMonth" {
                    HistoryView(initialRange: screen == "historyMonth" ? .month : .week)
                } else {
                    MainTabView()
                }
                #else
                MainTabView()
                #endif
            }
        }
    }
}
