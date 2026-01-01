import SwiftUI

// MARK: - Username Setup View

/// Username setup screen shown after first sign-in.
/// Username is required for sharing and cannot be changed after set.
struct UsernameSetupView: View {
    @State private var username: String = ""
    @State private var status: AvailabilityStatus = .idle
    @State private var checkTask: Task<Void, Never>?
    @State private var isSubmitting: Bool = false

    var onComplete: (User) -> Void

    var body: some View {
        ZStack {
            Tokens.Color.background.ignoresSafeArea()

            VStack(spacing: Tokens.Spacing.xl) {
                Spacer()

                // Header
                VStack(spacing: Tokens.Spacing.sm) {
                    AppText("ユーザーネームを設定", style: .screenTitle, color: Tokens.Color.textPrimary)

                    Text("共有時に相手に表示される名前です。\n一度設定すると変更できません。")
                        .font(Tokens.Typography.body())
                        .foregroundStyle(Tokens.Color.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Input field
                VStack(spacing: Tokens.Spacing.sm) {
                    HStack(spacing: 0) {
                        Text("@")
                            .font(Tokens.Typography.body())
                            .foregroundStyle(Tokens.Color.textSecondary)
                            .padding(.leading, Tokens.Spacing.md)

                        TextField("username", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .font(Tokens.Typography.body())
                            .foregroundStyle(Tokens.Color.textPrimary)
                            .padding(.vertical, Tokens.Spacing.md)
                            .padding(.trailing, Tokens.Spacing.md)
                            .onChange(of: username) { _, _ in
                                scheduleAvailabilityCheck()
                            }
                    }
                    .background(Tokens.Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous)
                            .stroke(borderColor, lineWidth: Tokens.Border.thin)
                    )

                    // Status message
                    HStack(spacing: Tokens.Spacing.xxs) {
                        if let message = status.message {
                            if status == .checking {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else if status == .available {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Tokens.Color.accent)
                            } else if status.isError {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Tokens.Color.destructive)
                            }

                            Text(message)
                                .font(Tokens.Typography.caption())
                                .foregroundStyle(status.isError ? Tokens.Color.destructive : Tokens.Color.textSecondary)
                        }
                        Spacer()
                    }
                    .frame(height: 20)

                    // Format hint
                    Text("3〜15文字 / 英小文字・数字・_・. / 先頭は英字推奨")
                        .font(Tokens.Typography.caption())
                        .foregroundStyle(Tokens.Color.textSecondary)
                }
                .padding(.horizontal, Tokens.Spacing.lg)

                Spacer()

                // Submit button
                Button {
                    Haptics.medium()
                    submit()
                } label: {
                    HStack(spacing: Tokens.Spacing.xxs) {
                        if isSubmitting {
                            ProgressView()
                                .tint(Tokens.Color.surface)
                        }
                        Text(isSubmitting ? "設定中..." : "確定する（変更不可）")
                            .font(Tokens.Typography.button())
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: Tokens.Sizing.buttonHeight)
                    .background(
                        RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous)
                            .fill(canSubmit ? AnyShapeStyle(Tokens.Gradients.ai) : AnyShapeStyle(Tokens.Color.border))
                    )
                    .foregroundStyle(canSubmit ? Tokens.Color.surface : Tokens.Color.textSecondary)
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit || isSubmitting)
                .padding(.horizontal, Tokens.Spacing.screenHorizontal)
                .padding(.bottom, Tokens.Spacing.xl)
            }
        }
        .cappedDynamicType()
    }

    // MARK: - Computed Properties

    private var canSubmit: Bool {
        status == .available
    }

    private var borderColor: Color {
        if status.isError {
            return Tokens.Color.destructive
        } else if status == .available {
            return Tokens.Color.accent
        }
        return Tokens.Color.border
    }

    // MARK: - Availability Check

    private func scheduleAvailabilityCheck() {
        checkTask?.cancel()
        let candidate = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !candidate.isEmpty else {
            status = .idle
            return
        }

        // First validate format
        guard validateFormat(candidate) else { return }

        checkTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000) // 400ms debounce
            if Task.isCancelled { return }
            await checkAvailability(candidate)
        }
    }

    @MainActor
    private func checkAvailability(_ candidate: String) async {
        status = .checking

        do {
            // Try to lookup user - if found, username is taken
            _ = try await APIClient.shared.lookupUser(username: candidate)
            // If we get here, user exists = taken
            status = .unavailable
        } catch let error as APIError {
            switch error {
            case .notFound:
                // 404 = username not taken = available
                status = .available
            default:
                status = .error("確認に失敗しました")
            }
        } catch {
            status = .error("確認に失敗しました")
        }
    }

    // MARK: - Submit

    private func submit() {
        let candidate = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard validateFormat(candidate), status == .available else { return }

        isSubmitting = true

        Task {
            do {
                let user = try await APIClient.shared.setUsername(candidate)
                await MainActor.run {
                    isSubmitting = false
                    Haptics.success()
                    onComplete(user)
                }
            } catch let error as APIError {
                await MainActor.run {
                    switch error {
                    case .usernameTaken:
                        status = .unavailable
                    case .usernameAlreadySet:
                        status = .error("既に設定済みです")
                    default:
                        status = .error("設定に失敗しました")
                    }
                    isSubmitting = false
                    Haptics.error()
                }
            } catch {
                await MainActor.run {
                    status = .error("設定に失敗しました")
                    isSubmitting = false
                    Haptics.error()
                }
            }
        }
    }

    // MARK: - Validation

    private func validateFormat(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Check regex pattern: 3-15 chars, [a-z0-9_.]
        let regex = "^[a-z0-9_.]{3,15}$"
        if normalized.range(of: regex, options: .regularExpression) == nil {
            if normalized.count < 3 {
                status = .error("3文字以上必要です")
            } else if normalized.count > 15 {
                status = .error("15文字以下にしてください")
            } else {
                status = .error("使用できない文字が含まれています")
            }
            return false
        }

        // Recommend starting with a letter
        if normalized.first?.isNumber == true {
            status = .error("先頭は英字を推奨します")
            return false
        }

        return true
    }
}

// MARK: - Availability Status

private enum AvailabilityStatus: Equatable {
    case idle
    case checking
    case available
    case unavailable
    case error(String)

    var message: String? {
        switch self {
        case .idle: return nil
        case .checking: return "確認中..."
        case .available: return "使用可能"
        case .unavailable: return "既に使われています"
        case .error(let text): return text
        }
    }

    var isError: Bool {
        switch self {
        case .unavailable, .error:
            return true
        default:
            return false
        }
    }
}

// MARK: - Preview
