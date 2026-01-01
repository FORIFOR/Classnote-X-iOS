import SwiftUI
import UIKit

struct ShareSheet: View {
    let sessionId: String
    let memberCount: Int
    let members: [SessionMember]

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var shareCoordinator: ShareCoordinator

    @State private var shareLink: String?
    @State private var isCreatingLink = false
    @State private var targetUsername = ""
    @State private var isInviting = false
    @State private var selectedRole: ShareRole = .viewer
    @State private var toast: ToastMessage?
    @State private var showShareActivity = false

    init(sessionId: String, memberCount: Int, members: [SessionMember] = []) {
        self.sessionId = sessionId
        self.memberCount = memberCount
        self.members = members
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Tokens.Spacing.lg) {
                    headerSection
                    shareLinkSection
                    inviteByUsernameSection
                    if !members.isEmpty {
                        membersSection
                    }
                }
                .padding(Tokens.Spacing.screenHorizontal)
                .padding(.bottom, Tokens.Spacing.xl)
            }
            .background(Tokens.Color.background)
            .navigationTitle("共有")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showShareActivity) {
            if let shareLink {
                ActivityView(activityItems: [shareLink])
            }
        }
        .overlay(alignment: .top) {
            if let toast {
                ToastView(message: toast)
                    .padding(.top, Tokens.Spacing.md)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: toast != nil)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: Tokens.Spacing.xs) {
            Image(systemName: "person.2.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(Tokens.Gradients.ai)

            Text("セッションを共有")
                .font(Tokens.Typography.sectionTitle())
                .foregroundStyle(Tokens.Color.textPrimary)

            Text("リンクを送信するか、ユーザー名で招待できます")
                .font(Tokens.Typography.caption())
                .foregroundStyle(Tokens.Color.textSecondary)
                .multilineTextAlignment(.center)

            if memberCount > 0 {
                HStack(spacing: Tokens.Spacing.xxs) {
                    Image(systemName: "person.2.fill")
                        .font(Tokens.Typography.caption())
                    Text("\(memberCount)人が参加中")
                        .font(Tokens.Typography.caption())
                }
                .foregroundStyle(Tokens.Color.accent)
                .padding(.top, Tokens.Spacing.xxs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Spacing.md)
    }

    // MARK: - Share Link Section

    private var shareLinkSection: some View {
        ContentCard {
            VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                HStack(spacing: Tokens.Spacing.xs) {
                    Image(systemName: "link")
                        .font(Tokens.Typography.iconMedium())
                        .foregroundStyle(Tokens.Color.accent)
                    Text("共有リンク")
                        .font(Tokens.Typography.sectionTitle())
                        .foregroundStyle(Tokens.Color.textPrimary)
                }

                if let shareLink {
                    VStack(spacing: Tokens.Spacing.sm) {
                        HStack(spacing: Tokens.Spacing.sm) {
                            Text(shareLink)
                                .font(Tokens.Typography.caption())
                                .foregroundStyle(Tokens.Color.textSecondary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button {
                                copyToClipboard(shareLink)
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(Tokens.Typography.caption())
                                    .foregroundStyle(Tokens.Color.accent)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(Tokens.Spacing.sm)
                        .background(Tokens.Color.background)
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous))

                        HStack(spacing: Tokens.Spacing.sm) {
                            Button {
                                showShareActivity = true
                            } label: {
                                HStack(spacing: Tokens.Spacing.xxs) {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("送信")
                                }
                                .font(Tokens.Typography.button())
                                .foregroundStyle(Tokens.Color.surface)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Tokens.Color.textPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            Button {
                                createShareLink()
                            } label: {
                                HStack(spacing: Tokens.Spacing.xxs) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("再作成")
                                }
                                .font(Tokens.Typography.button())
                                .foregroundStyle(Tokens.Color.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Tokens.Color.surface)
                                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous)
                                        .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    Text("リンクを作成して簡単に共有できます")
                        .font(Tokens.Typography.caption())
                        .foregroundStyle(Tokens.Color.textSecondary)

                    Button {
                        createShareLink()
                    } label: {
                        HStack(spacing: Tokens.Spacing.xs) {
                            if isCreatingLink {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(Tokens.Color.surface)
                            } else {
                                Image(systemName: "link.badge.plus")
                            }
                            Text(isCreatingLink ? "作成中…" : "リンクを作成")
                        }
                        .font(Tokens.Typography.button())
                        .foregroundStyle(Tokens.Color.surface)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Tokens.Color.accent)
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isCreatingLink)
                }
            }
        }
    }

    // MARK: - Invite by Username Section

    private var inviteByUsernameSection: some View {
        ContentCard {
            VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                HStack(spacing: Tokens.Spacing.xs) {
                    Image(systemName: "at")
                        .font(Tokens.Typography.iconMedium())
                        .foregroundStyle(Tokens.Color.accent)
                    Text("ユーザー名で招待")
                        .font(Tokens.Typography.sectionTitle())
                        .foregroundStyle(Tokens.Color.textPrimary)
                }

                Text("相手のユーザー名を入力して直接招待できます")
                    .font(Tokens.Typography.caption())
                    .foregroundStyle(Tokens.Color.textSecondary)

                HStack(spacing: Tokens.Spacing.sm) {
                    HStack(spacing: Tokens.Spacing.xxs) {
                        Text("@")
                            .font(Tokens.Typography.body())
                            .foregroundStyle(Tokens.Color.textTertiary)
                        TextField("username", text: $targetUsername)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .font(Tokens.Typography.body())
                    }
                    .padding(.horizontal, Tokens.Spacing.sm)
                    .frame(height: 44)
                    .background(Tokens.Color.background)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous)
                            .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
                    )

                    Button {
                        inviteByUsername()
                    } label: {
                        if isInviting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(Tokens.Color.surface)
                        } else {
                            Text("招待")
                        }
                    }
                    .font(Tokens.Typography.button())
                    .foregroundStyle(Tokens.Color.surface)
                    .frame(width: 72, height: 44)
                    .background(canInvite ? Tokens.Color.textPrimary : Tokens.Color.border)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous))
                    .buttonStyle(.plain)
                    .disabled(!canInvite)
                }

                // Role selector
                VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                    Text("権限")
                        .font(Tokens.Typography.caption())
                        .foregroundStyle(Tokens.Color.textSecondary)

                    HStack(spacing: Tokens.Spacing.xs) {
                        ForEach(ShareRole.allCases, id: \.self) { role in
                            RoleChip(
                                role: role,
                                isSelected: selectedRole == role
                            ) {
                                selectedRole = role
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Members Section

    private var membersSection: some View {
        ContentCard {
            VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                HStack(spacing: Tokens.Spacing.xs) {
                    Image(systemName: "person.2")
                        .font(Tokens.Typography.iconMedium())
                        .foregroundStyle(Tokens.Color.accent)
                    Text("参加メンバー")
                        .font(Tokens.Typography.sectionTitle())
                        .foregroundStyle(Tokens.Color.textPrimary)
                    Spacer()
                    Text("\(members.count)人")
                        .font(Tokens.Typography.caption())
                        .foregroundStyle(Tokens.Color.textSecondary)
                }

                VStack(spacing: 0) {
                    ForEach(sortedMembers) { member in
                        MemberRow(member: member)
                        if member.id != sortedMembers.last?.id {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
            }
        }
    }

    private var sortedMembers: [SessionMember] {
        members.sorted { lhs, rhs in
            if lhs.role == rhs.role { return lhs.username < rhs.username }
            return lhs.role == .owner
        }
    }

    private var canInvite: Bool {
        !isInviting && !targetUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    private func createShareLink() {
        guard !isCreatingLink else { return }
        isCreatingLink = true

        Task {
            do {
                let response = try await APIClient.shared.createShareLink(sessionId: sessionId)
                await MainActor.run {
                    shareLink = response.url
                    showToast(.success("リンクを作成しました"))
                }
            } catch {
                await MainActor.run {
                    showToast(.error("作成に失敗しました"))
                }
            }
            await MainActor.run {
                isCreatingLink = false
            }
        }
    }

    private func inviteByUsername() {
        guard canInvite else { return }
        isInviting = true

        let trimmed = targetUsername.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalized = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed

        Task {
            do {
                let user = try await APIClient.shared.lookupUser(username: normalized)
                _ = try await APIClient.shared.inviteSessionMember(
                    sessionId: sessionId,
                    userId: user.uid,
                    role: selectedRole
                )
                await MainActor.run {
                    showToast(.success("@\(normalized) を招待しました"))
                    targetUsername = ""
                }
            } catch let error as APIError {
                await MainActor.run {
                    switch error {
                    case .notFound:
                        showToast(.error("ユーザーが見つかりません"))
                    default:
                        showToast(.error("招待に失敗しました"))
                    }
                }
            } catch {
                await MainActor.run {
                    showToast(.error("招待に失敗しました"))
                }
            }
            await MainActor.run {
                isInviting = false
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        Haptics.success()
        showToast(.success("コピーしました"))
    }

    private func showToast(_ message: ToastMessage) {
        toast = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if toast == message {
                toast = nil
            }
        }
    }
}

// MARK: - Role Chip

private struct RoleChip: View {
    let role: ShareRole
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Spacing.xxs) {
                Image(systemName: role.icon)
                    .font(Tokens.Typography.caption())
                Text(role.rawValue)
                    .font(Tokens.Typography.caption())
            }
            .foregroundStyle(isSelected ? Tokens.Color.surface : Tokens.Color.textSecondary)
            .padding(.horizontal, Tokens.Spacing.sm)
            .padding(.vertical, Tokens.Spacing.xs)
            .background(isSelected ? Tokens.Color.accent : Tokens.Color.background)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Tokens.Color.border, lineWidth: Tokens.Border.thin)
            )
        }
        .buttonStyle(.plain)
    }
}

private extension ShareRole {
    var icon: String {
        switch self {
        case .viewer: return "eye"
        case .editor: return "pencil"
        }
    }
}

// MARK: - Member Row

private struct MemberRow: View {
    let member: SessionMember

    private var roleDisplayText: String {
        switch member.role {
        case .owner: return "オーナー"
        case .viewer: return "閲覧者"
        }
    }

    var body: some View {
        HStack(spacing: Tokens.Spacing.sm) {
            Circle()
                .fill(Tokens.Color.background)
                .frame(width: 36, height: 36)
                .overlay(
                    Text(member.initials)
                        .font(Tokens.Typography.caption())
                        .foregroundStyle(Tokens.Color.textSecondary)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("@\(member.username)")
                    .font(Tokens.Typography.body())
                    .foregroundStyle(Tokens.Color.textPrimary)

                Text(roleDisplayText)
                    .font(Tokens.Typography.caption())
                    .foregroundStyle(Tokens.Color.textSecondary)
            }

            Spacer()

            if member.role == .owner {
                Image(systemName: "crown.fill")
                    .font(Tokens.Typography.caption())
                    .foregroundStyle(Tokens.Color.accent)
            }
        }
        .padding(.vertical, Tokens.Spacing.sm)
    }
}

// MARK: - Toast

private enum ToastMessage: Equatable {
    case success(String)
    case error(String)

    var message: String {
        switch self {
        case .success(let msg), .error(let msg):
            return msg
        }
    }

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: return Tokens.Color.accent
        case .error: return Tokens.Color.destructive
        }
    }
}

private struct ToastView: View {
    let message: ToastMessage

    var body: some View {
        HStack(spacing: Tokens.Spacing.xs) {
            Image(systemName: message.icon)
                .foregroundStyle(message.color)
            Text(message.message)
                .font(Tokens.Typography.caption())
                .foregroundStyle(Tokens.Color.textPrimary)
        }
        .padding(.horizontal, Tokens.Spacing.md)
        .padding(.vertical, Tokens.Spacing.sm)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous)
                .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Activity View

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        controller.excludedActivityTypes = excludedActivityTypes
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
