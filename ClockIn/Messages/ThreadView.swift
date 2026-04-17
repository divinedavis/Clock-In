import SwiftUI

struct ThreadView: View {
    let partnerId: UUID
    let partnerEmail: String
    var onClose: () async -> Void

    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var vm = ThreadViewModel()
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(vm.messages) { msg in
                            MessageBubble(message: msg, isMine: msg.senderId == auth.userId)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: vm.messages.count) { _, _ in
                    if let lastId = vm.messages.last?.id {
                        withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Message", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(draft.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : .accentColor)
                }
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            .background(.bar)
        }
        .navigationTitle(partnerEmail)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard let me = auth.userId else { return }
            await vm.load(partnerId: partnerId, me: me)
            await vm.markRead(partnerId: partnerId, me: me)
        }
        .onDisappear {
            Task { await onClose() }
        }
    }

    private func send() async {
        let body = draft.trimmingCharacters(in: .whitespaces)
        guard !body.isEmpty else { return }
        draft = ""
        await vm.send(to: partnerId, body: body)
    }
}

private struct MessageBubble: View {
    let message: Message
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }
            VStack(alignment: .trailing, spacing: 2) {
                Text(message.body)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(isMine ? Color.accentColor : Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 16))
                    .foregroundColor(isMine ? .white : .primary)
                HStack(spacing: 4) {
                    Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if isMine, message.readAt != nil {
                        Text("· Read")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if !isMine { Spacer(minLength: 40) }
        }
    }
}
