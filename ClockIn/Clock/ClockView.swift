import SwiftUI
import CoreLocation

struct ClockView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var vm = ClockViewModel()
    @StateObject private var location = LocationManager()
    @State private var now = Date()

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            SkyGradient(date: now)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 8)
                AnalogClock(now: now, activeEntry: vm.activeEntry)
                    .aspectRatio(1, contentMode: .fit)
                    .padding(.horizontal, 28)
                    .contentShape(Circle())
                    .onTapGesture { tap() }
                    .overlay(alignment: .center) {
                        if vm.isWorking {
                            Circle()
                                .fill(.black.opacity(0.25))
                                .overlay(ProgressView().tint(.white).scaleEffect(1.4))
                                .padding(28)
                        }
                    }
                    .animation(.easeInOut, value: vm.isClockedIn)
                Spacer(minLength: 8)
                footer
            }
            .padding(.vertical, 24)
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .onReceive(tick) { now = $0 }
        .task {
            location.requestPermissionIfNeeded()
            await vm.loadOpenEntry()
        }
        .alert("Error", isPresented: .constant(vm.errorMessage != nil), presenting: vm.errorMessage) { _ in
            Button("OK") { vm.errorMessage = nil }
        } message: { Text($0) }
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text(now, format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute(.twoDigits))
                .font(.system(size: 64, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(headerSubtitle)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var headerSubtitle: String {
        if let entry = vm.activeEntry {
            let started = entry.clockInAt.formatted(date: .omitted, time: .shortened)
            return "Clocked in since \(started)"
        }
        return "Today"
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text(vm.isClockedIn ? "Tap clock to clock out" : "Tap clock to clock in")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
            if let loc = location.lastLocation {
                Text(String(format: "%.4f, %.4f", loc.coordinate.latitude, loc.coordinate.longitude))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
            }
            Text(permissionLabel)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.bottom, 8)
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
        guard !vm.isWorking else { return }
        Task {
            let loc = try? await location.currentLocation()
            if vm.isClockedIn {
                await vm.clockOut(location: loc)
            } else {
                await vm.clockIn(location: loc)
            }
        }
    }
}

// MARK: - Sky gradient that shifts with time of day

private struct SkyGradient: View {
    let date: Date

    var body: some View {
        LinearGradient(colors: [topColor, bottomColor], startPoint: .top, endPoint: .bottom)
    }

    private var hourFraction: Double {
        let cal = Calendar.current
        let h = Double(cal.component(.hour, from: date))
        let m = Double(cal.component(.minute, from: date))
        return h + m / 60.0
    }

    private var topColor: Color {
        interp(palette: topPalette, at: hourFraction)
    }

    private var bottomColor: Color {
        interp(palette: bottomPalette, at: hourFraction)
    }

    // Key anchor points around the 24h clock (hour → color).
    private var topPalette: [(Double, Color)] {
        [
            (0,  Color(red: 0.04, green: 0.05, blue: 0.14)),
            (5,  Color(red: 0.15, green: 0.10, blue: 0.32)),
            (7,  Color(red: 0.95, green: 0.55, blue: 0.40)),
            (12, Color(red: 0.30, green: 0.55, blue: 0.85)),
            (17, Color(red: 0.85, green: 0.40, blue: 0.30)),
            (19, Color(red: 0.55, green: 0.18, blue: 0.22)),
            (22, Color(red: 0.09, green: 0.07, blue: 0.18)),
            (24, Color(red: 0.04, green: 0.05, blue: 0.14)),
        ]
    }

    private var bottomPalette: [(Double, Color)] {
        [
            (0,  Color(red: 0.02, green: 0.02, blue: 0.08)),
            (5,  Color(red: 0.25, green: 0.12, blue: 0.32)),
            (7,  Color(red: 0.55, green: 0.25, blue: 0.45)),
            (12, Color(red: 0.10, green: 0.25, blue: 0.50)),
            (17, Color(red: 0.45, green: 0.15, blue: 0.25)),
            (19, Color(red: 0.28, green: 0.08, blue: 0.18)),
            (22, Color(red: 0.03, green: 0.03, blue: 0.10)),
            (24, Color(red: 0.02, green: 0.02, blue: 0.08)),
        ]
    }

    private func interp(palette: [(Double, Color)], at x: Double) -> Color {
        guard let first = palette.first, let last = palette.last else { return .black }
        if x <= first.0 { return first.1 }
        if x >= last.0 { return last.1 }
        for i in 0..<(palette.count - 1) {
            let (x0, c0) = palette[i]
            let (x1, c1) = palette[i + 1]
            if x >= x0 && x <= x1 {
                let t = (x - x0) / (x1 - x0)
                return c0.lerp(to: c1, t: t)
            }
        }
        return last.1
    }
}

private extension Color {
    func lerp(to other: Color, t: Double) -> Color {
        let a = NSUIColor(self).rgba
        let b = NSUIColor(other).rgba
        return Color(
            red: a.r + (b.r - a.r) * t,
            green: a.g + (b.g - a.g) * t,
            blue: a.b + (b.b - a.b) * t,
            opacity: a.a + (b.a - a.a) * t
        )
    }
}

#if canImport(UIKit)
import UIKit
private typealias NSUIColor = UIColor
private extension UIColor {
    var rgba: (r: Double, g: Double, b: Double, a: Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }
}
#endif

// MARK: - Analog clock face

private struct AnalogClock: View {
    let now: Date
    let activeEntry: TimeEntry?

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let r = side / 2
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)

                // Hour numbers
                ForEach(1...12, id: \.self) { n in
                    Text("\(n)")
                        .font(.system(size: r * 0.11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .position(pointOnCircle(angleDeg: Double(n) * 30 - 90, radius: r * 0.82, center: center))
                }

                // Minute ticks
                ForEach(0..<60, id: \.self) { i in
                    Rectangle()
                        .fill(Color.white.opacity(i % 5 == 0 ? 0.8 : 0.3))
                        .frame(width: i % 5 == 0 ? 2 : 1, height: i % 5 == 0 ? r * 0.04 : r * 0.02)
                        .offset(y: -r * 0.94)
                        .rotationEffect(.degrees(Double(i) * 6))
                        .position(center)
                }

                // Hour hand
                ClockHand(
                    angleDegrees: hourAngle,
                    length: r * 0.5,
                    thickness: r * 0.055,
                    color: .white,
                    label: activeEntry != nil ? "Clocked In" : nil,
                    center: center
                )

                // Minute hand
                ClockHand(
                    angleDegrees: minuteAngle,
                    length: r * 0.78,
                    thickness: r * 0.035,
                    color: .white.opacity(0.9),
                    label: activeEntry.map { shortTime($0.clockInAt) },
                    center: center
                )

                // Center hub
                Circle()
                    .fill(Color.white)
                    .frame(width: r * 0.08, height: r * 0.08)
                    .position(center)
                Circle()
                    .fill(Color.black.opacity(0.35))
                    .frame(width: r * 0.03, height: r * 0.03)
                    .position(center)
            }
        }
    }

    private var hourAngle: Double {
        let cal = Calendar.current
        let h = Double(cal.component(.hour, from: now) % 12)
        let m = Double(cal.component(.minute, from: now))
        let s = Double(cal.component(.second, from: now))
        return (h + m / 60 + s / 3600) * 30 - 90
    }

    private var minuteAngle: Double {
        let cal = Calendar.current
        let m = Double(cal.component(.minute, from: now))
        let s = Double(cal.component(.second, from: now))
        return (m + s / 60) * 6 - 90
    }

    private func shortTime(_ d: Date) -> String {
        d.formatted(date: .omitted, time: .shortened)
    }

    private func pointOnCircle(angleDeg: Double, radius: Double, center: CGPoint) -> CGPoint {
        let rad = angleDeg * .pi / 180
        return CGPoint(x: center.x + cos(rad) * radius, y: center.y + sin(rad) * radius)
    }
}

private struct ClockHand: View {
    let angleDegrees: Double
    let length: Double
    let thickness: Double
    let color: Color
    let label: String?
    let center: CGPoint

    var body: some View {
        ZStack {
            // The rod
            Capsule()
                .fill(color)
                .frame(width: thickness, height: length)
                .offset(y: -length / 2)
                .rotationEffect(.degrees(angleDegrees + 90))
                .position(center)

            // Optional label along the hand (like the reference "around the clock")
            if let label, !label.isEmpty {
                Capsule()
                    .fill(Color.white)
                    .overlay(
                        Text(label)
                            .font(.system(size: max(10, thickness * 2.2), weight: .semibold, design: .rounded))
                            .foregroundStyle(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 8)
                    )
                    .frame(width: length * 0.7, height: thickness * 3)
                    .offset(y: -length * 0.55)
                    .rotationEffect(.degrees(angleDegrees + 90))
                    .position(center)
            }
        }
    }
}
