import SwiftUI
import CoreLocation

struct ClockView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var vm = ClockViewModel()
    @StateObject private var location = LocationManager()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                statusHeader
                Spacer()
                bigButton
                Spacer()
                locationFooter
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .navigationTitle("Clock In")
            .task {
                location.requestPermissionIfNeeded()
                await vm.loadOpenEntry()
            }
            .onReceive(timer) { vm.now = $0 }
            .alert("Error", isPresented: .constant(vm.errorMessage != nil), presenting: vm.errorMessage) { _ in
                Button("OK") { vm.errorMessage = nil }
            } message: { Text($0) }
        }
    }

    private var statusHeader: some View {
        VStack(spacing: 8) {
            Text(vm.isClockedIn ? "Clocked In" : "Clocked Out")
                .font(.headline)
                .foregroundColor(vm.isClockedIn ? .green : .secondary)
            Text(vm.elapsedString)
                .font(.system(size: 56, weight: .semibold, design: .rounded))
                .monospacedDigit()
            if let start = vm.activeEntry?.clockInAt {
                Text("Since \(start.formatted(date: .omitted, time: .shortened))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var bigButton: some View {
        Button(action: tap) {
            ZStack {
                Circle()
                    .fill(vm.isClockedIn ? Color.green : Color.accentColor)
                    .shadow(color: (vm.isClockedIn ? Color.green : Color.accentColor).opacity(0.4), radius: 20, y: 8)
                VStack(spacing: 6) {
                    if vm.isWorking {
                        ProgressView().tint(.white).scaleEffect(1.4)
                    } else {
                        Image(systemName: vm.isClockedIn ? "stop.fill" : "play.fill")
                            .font(.system(size: 48, weight: .bold))
                        Text(vm.isClockedIn ? "Clock Out" : "Clock In")
                            .font(.title2.weight(.semibold))
                    }
                }
                .foregroundStyle(.white)
            }
            .frame(width: 240, height: 240)
        }
        .disabled(vm.isWorking)
        .animation(.easeInOut, value: vm.isClockedIn)
    }

    private var locationFooter: some View {
        VStack(spacing: 4) {
            if let loc = location.lastLocation {
                Text(String(format: "%.4f, %.4f", loc.coordinate.latitude, loc.coordinate.longitude))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(permissionLabel)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var permissionLabel: String {
        switch location.authorization {
        case .notDetermined: return "Location permission pending"
        case .restricted, .denied: return "Location access denied — enable in Settings"
        case .authorizedWhenInUse, .authorizedAlways: return "Location access granted"
        @unknown default: return ""
        }
    }

    private func tap() {
        Task {
            let loc = try? await location.currentLocation()
            if vm.isClockedIn {
                await vm.clockOut(location: loc)
            } else {
                guard let userIdString = try? await SupabaseManager.shared.auth.session.user.id.uuidString,
                      let userId = UUID(uuidString: userIdString) else {
                    vm.errorMessage = "Not signed in."
                    return
                }
                await vm.clockIn(userId: userId, location: loc)
            }
        }
    }
}
