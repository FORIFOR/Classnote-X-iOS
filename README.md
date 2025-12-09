# ClassnoteX - AI-Powered Voice Recorder & Note Assistant

ClassnoteX is an advanced iOS application designed to transform how you record and review lectures and meetings. Utilizing a hybrid approach of on-device processing and cloud-based AI, it provides real-time transcription, speaker diarization, and intelligent summarization.

## Key Features

*   **🎙️ Smart Recording**: High-quality audio recording with auto-silence skipping and VAD (Voice Activity Detection).
*   **👥 Talker Diarization (On-Device)**: Identifies and separates different speakers locally using `sherpa-onnx` and `pyannote` models, ensuring privacy and speed.
*   **📝 Real-time Transcription**: accurate speech-to-text powered by SFSpeechRecognizer and cloud fallbacks.
*   **🧠 AI Summarization**:
    *   **Lecture Mode**: Extracts key points, generates review quizzes, and creates structured lecture notes.
    *   **Meeting Mode**: Identifies decisions, action items (ToDo), and generates meeting minutes.
*   **🏷️ Visual Timeline**:
    *   YouTube-style chapter markers.
    *   Speaker-coded waveforms and transcript bubbles.
    *   AI-generated tags for "Decisions", "Tasks", "Important", etc.
*   **🔄 Cloud Sync**: Seamlessly syncs sessions and notes via Firebase and Cloud Run backend.

## Tech Stack

*   **Language**: Swift 5.9+ (SwiftUI)
*   **Architecture**: MVVM with Concurrency (async/await)
*   **Audio Engine**: AVFoundation, AudioToolbox
*   **Local AI**: `sherpa-onnx` (ONNX Runtime) for Speaker Diarization & VAD
*   **Backend**: 
    *   Google Cloud Run (API)
    *   Firebase Authentication (Google Sign-In, Email/Password)
    *   Firestore (Metadata storage)
    *   Google Cloud Storage (Audio files)

## Requirements

*   **iOS**: 16.0+
*   **Xcode**: 15.0+
*   **CocoaPods / Swift Package Manager**

## Setup & Installation

1.  **Clone the repository**
    ```bash
    git clone https://github.com/FORIFOR/Classnote-X-iOS.git
    cd ClassnoteX
    ```

2.  **Install Dependencies**
    *   The project uses Swift Package Manager. Xcode should automatically resolve dependencies upon opening the project.
    *   **Note**: Ensure `sherpa-onnx` and related packages are fetched.

3.  **Configuration**
    *   **GoogleService-Info.plist**: You need to add your own Firebase configuration file to the `ClassnoteX/` root directory.
    *   **API Configuration**: Update the backend URL in `AppModel.swift` or `ClassnoteAPIClient.swift` if you are deploying your own backend.
        ```swift
        // Example in AppModel.swift
        self.baseURLString = "https://your-cloud-run-url.app"
        ```

4.  **Local Models (Diarization)**
    *   The app requires ONNX models for local speaker diarization.
    *   Ensure the following files are included in the app bundle (Copy Bundle Resources):
        *   `sherpa-onnx-pyannote-segmentation-3-0.onnx`
        *   `3dspeaker_speech_eres2net_base_sv_zh-cn_3dspeaker_16k.onnx`
        *   `silero_vad.onnx`
    *   These are usually located in `ClassnoteX/Models/Diarization/`.

5.  **Build & Run**
    *   Select your target simulator or device (Real device recommended for microphone features).
    *   Run (`Cmd + R`).

## Usage

1.  **Home Tab**: View recent sessions and quick stats. Tap the big card to start recording.
2.  **Recording**: Select "Lecture" or "Meeting" mode. Recording starts immediately.
    *   Use the "Memo" bar to add timestamped notes during recording.
3.  **Session Detail**:
    *   **Playback**: Listen to audio with a visual waveform.
    *   **Transcript**: View speaker-separated text. Edit speaker names.
    *   **Summary**: View AI-generated summaries, quizzes, and tasks.

## License

This project is proprietary software.
Copyright © 2024 ClassnoteX Team. All rights reserved.
