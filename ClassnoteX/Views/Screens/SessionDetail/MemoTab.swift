import SwiftUI
import PhotosUI
import UIKit

struct MemoTab: View {
    @Binding var session: Session
    let onSaveMemo: (String) -> Void
    let onAddPhoto: (UIImage) -> Void
    let isPhotoUploading: Bool

    @State private var memoText: String = ""
    @State private var isDirty = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var pendingSaveTask: Task<Void, Never>?
    @FocusState private var isMemoFocused: Bool

    var body: some View {
        TabContentWrapper {
            VStack(spacing: Tokens.Spacing.lg) {
                memoSection
                photosSection
            }
        }
        .onAppear {
            memoText = session.memoText ?? ""
        }
        .onChange(of: session.memoText) { _, newValue in
            guard !isDirty else { return }
            memoText = newValue ?? ""
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(image: $capturedImage)
                .ignoresSafeArea()
        }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                do {
                    if let data = try await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        onAddPhoto(image)
                    }
                } catch {
                    print("Failed to load photo: \(error)")
                }
                await MainActor.run {
                    photoItem = nil
                }
            }
        }
        .onChange(of: capturedImage) { _, newValue in
            guard let image = newValue else { return }
            onAddPhoto(image)
            capturedImage = nil
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") {
                    saveMemo()
                    isMemoFocused = false
                }
                .disabled(!isDirty)
            }
        }
        .onDisappear {
            if isDirty {
                saveMemo()
            }
        }
    }

    // MARK: - Memo Section

    private var memoSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            sectionHeader(title: "メモ", icon: "note.text")

            ContentCard {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $memoText)
                        .frame(minHeight: 160)
                        .hideScrollContentBackground()
                        .focused($isMemoFocused)
                        .foregroundStyle(Tokens.Color.textPrimary)
                        .font(Tokens.Typography.body())
                        .onChange(of: memoText) { _, _ in
                            isDirty = true
                            scheduleAutosave()
                        }

                    if memoText.isEmpty {
                        Text("メモを入力…")
                            .font(Tokens.Typography.body())
                            .foregroundStyle(Tokens.Color.textTertiary)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                }
            }

            saveStatusRow
        }
    }

    private var saveStatusRow: some View {
        HStack(spacing: Tokens.Spacing.xs) {
            if isDirty {
                Circle()
                    .fill(Tokens.Color.accent)
                    .frame(width: 6, height: 6)
                Text("未保存")
                    .font(Tokens.Typography.caption())
                    .foregroundStyle(Tokens.Color.textSecondary)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(Tokens.Typography.caption())
                    .foregroundStyle(Tokens.Color.accent)
                Text("保存済み")
                    .font(Tokens.Typography.caption())
                    .foregroundStyle(Tokens.Color.textSecondary)
            }

            Spacer()

            SecondaryActionButton(
                "今すぐ保存",
                icon: "arrow.up.circle",
                isDisabled: !isDirty
            ) {
                saveMemo()
            }
        }
    }

    // MARK: - Photos Section

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            sectionHeader(title: "写真", icon: "photo.on.rectangle")

            if let photos = session.photos, !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Tokens.Spacing.sm) {
                        addPhotoButton
                        ForEach(photos) { photo in
                            photoThumbnail(photo)
                        }
                    }
                }
            } else {
                addPhotoButton
            }

            photoActionButtons
        }
    }

    private var addPhotoButton: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            ZStack {
                RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                    .fill(Tokens.Color.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                            .foregroundStyle(Tokens.Color.border)
                    )

                VStack(spacing: Tokens.Spacing.xxs) {
                    if isPhotoUploading {
                        ProgressView()
                    } else {
                        Image(systemName: "plus")
                            .font(Tokens.Typography.iconMedium())
                            .foregroundStyle(Tokens.Color.accent)
                    }
                    Text(isPhotoUploading ? "アップロード中…" : "追加")
                        .font(Tokens.Typography.caption())
                        .foregroundStyle(Tokens.Color.textSecondary)
                }
            }
            .frame(width: 88, height: 88)
        }
        .buttonStyle(.plain)
        .disabled(isPhotoUploading)
    }

    private func photoThumbnail(_ photo: PhotoRef) -> some View {
        AsyncImage(url: photo.url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                Image(systemName: "photo")
                    .foregroundStyle(Tokens.Color.textTertiary)
            case .empty:
                ProgressView()
            @unknown default:
                EmptyView()
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
        )
    }

    private var photoActionButtons: some View {
        HStack(spacing: Tokens.Spacing.md) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("写真を選択", systemImage: "photo")
                    .font(Tokens.Typography.caption())
                    .foregroundStyle(Tokens.Color.accent)
            }
            .buttonStyle(.plain)
            .disabled(isPhotoUploading)

            Button {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showCamera = true
                }
            } label: {
                Label("カメラで撮影", systemImage: "camera")
                    .font(Tokens.Typography.caption())
                    .foregroundStyle(Tokens.Color.accent)
            }
            .buttonStyle(.plain)
            .disabled(isPhotoUploading)

            Spacer()
        }
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: Tokens.Spacing.xs) {
            Image(systemName: icon)
                .font(Tokens.Typography.caption())
                .foregroundStyle(Tokens.Color.textSecondary)
            Text(title)
                .font(Tokens.Typography.sectionTitle())
                .foregroundStyle(Tokens.Color.textPrimary)
        }
    }

    private func saveMemo() {
        onSaveMemo(memoText)
        isDirty = false
    }

    private func scheduleAutosave() {
        pendingSaveTask?.cancel()
        pendingSaveTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                if isDirty {
                    saveMemo()
                }
            }
        }
    }
}

// MARK: - View Extensions

private extension View {
    @ViewBuilder
    func hideScrollContentBackground() -> some View {
        if #available(iOS 16.0, *) {
            scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}

// MARK: - Camera Picker

private struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) private var presentationMode
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.cameraCaptureMode = .photo
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
