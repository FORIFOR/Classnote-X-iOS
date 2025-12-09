import SwiftUI

struct HelpView: View {
    var body: some View {
        List {
            Section {
                faqItem(
                    question: "マイクを許可するには？",
                    answer: "「設定」アプリ → プライバシーとセキュリティ → マイク から本アプリを有効にしてください。",
                    icon: "mic.fill"
                )
                
                faqItem(
                    question: "Ollamaの起動確認方法は？",
                    answer: "ターミナルで `ollama list` を実行し、サービスが稼働していることを確認してください。",
                    icon: "terminal.fill"
                )
                
                faqItem(
                    question: "ポートが競合している場合は？",
                    answer: "FastAPIバックエンドが8000番ポートで待ち受けていることを確認してください。",
                    icon: "network"
                )
            } header: {
                Label("よくある質問", systemImage: "questionmark.circle.fill")
            }
            
            Section {
                troubleItem(
                    title: "WebSocket接続エラー",
                    solution: "バックエンドURLとトークンを確認し、VPNやファイアウォールを一時的に無効にしてください。",
                    icon: "wifi.exclamationmark"
                )
                
                troubleItem(
                    title: "ASR/話者分離モデルの読み込み",
                    solution: "/api/health/models エンドポイントが ready を返すまでお待ちください。",
                    icon: "cpu"
                )
                
                troubleItem(
                    title: "録音が送信されない",
                    solution: "録音開始後にメーターが反応することを確認し、マイク入力を有効化してください。",
                    icon: "waveform.slash"
                )
            } header: {
                Label("トラブルシューティング", systemImage: "wrench.and.screwdriver.fill")
            }
            
            Section {
                Link(destination: URL(string: "mailto:support@example.com")!) {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(AppColors.primaryBlue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("サポートに連絡")
                                .font(.body)
                                .foregroundStyle(.primary)
                            
                            Text("support@example.com")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.forward")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            } header: {
                Text("サポート")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("ヘルプ")
    }
    
    private func faqItem(question: String, answer: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(AppColors.primaryBlue)
                    .frame(width: 24)
                
                Text(question)
                    .font(.subheadline.weight(.semibold))
            }
            
            Text(answer)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.leading, 34)
        }
        .padding(.vertical, 6)
    }
    
    private func troubleItem(title: String, solution: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(AppColors.warning)
                    .frame(width: 24)
                
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            
            Text(solution)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.leading, 34)
        }
        .padding(.vertical, 6)
    }
}
