import SwiftUI

struct MessagesView: View {
    @StateObject private var vm = MessagesViewModel()
    @State private var showCompose = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.conversations.isEmpty {
                    ProgressView()
                } else if vm.conversations.isEmpty {
                    ContentUnavailableView(
                        "No messages",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Tap + to start a conversation.")
                    )
                } else {
                    List(vm.conversations) { convo in
                        NavigationLink {
                            ThreadView(partnerId: convo.partnerId, partnerEmail: convo.partnerEmail) {
                                await vm.load()
                            }
                        } label: {
                            ConversationRow(convo: convo)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCompose = true } label: { Image(systemName: "square.and.pencil") }
                }
            }
            .sheet(isPresented: $showCompose) {
                NewMessageSheet { await vm.load() }
            }
            .task { await vm.load() }
            .refreshable { await vm.load() }
        }
    }
}

private struct ConversationRow: View {
    let convo: Conversation

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.15)).frame(width: 42, height: 42)
                Text(convo.partnerEmail.prefix(1).uppercased())
                    .font(.headline)
                    .foregroundColor(.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(convo.partnerEmail)
                        .font(.subheadline.weight(convo.unreadCount > 0 ? .bold : .semibold))
                    Spacer()
                    Text(convo.lastAt.formatted(.relative(presentation: .numeric)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(convo.lastBody)
                    .font(.footnote)
                    .foregroundStyle(convo.unreadCount > 0 ? .primary : .secondary)
                    .lineLimit(1)
            }
            if convo.unreadCount > 0 {
                Text("\(convo.unreadCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color.accentColor, in: Capsule())
            }
        }
        .padding(.vertical, 2)
    }
}
