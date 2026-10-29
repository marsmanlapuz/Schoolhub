# 🎓 SchoolHub - Campus Essentials Mobile & Web App

SchoolHub is a cross-platform application built with **Flutter** for students and educational institutions to browse, manage, and order school supplies with integrated **Xendit** payment WebView integration.

## 🚀 Key Features

* **Product Catalog & Details**: Browse supplies with live pricing, dynamic stock indicators, and images.
* **Shopping Cart & Checkout**: Interactive item management with total calculation.
* **Xendit Payment Integration**: Native WebView integration supporting multi-channel payments (E-Wallets, Cards, Over-the-Counter, QR Ph).
* **Order Tracking History**: View previous orders with real-time status badges (`PAID`).

## 🛠️ Tech Stack & Prerequisites

* **Framework**: [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.x or higher)
* **Language**: Dart
* **Backend / Services**: Firebase (Authentication / Firestore / Options)
* **Payment Gateway**: Xendit API & In-App WebView
* **Target Platforms**: Web (Chrome), Android, iOS

## 📂 Project Structure

```text
school_hub/
├── android/                 # Android native project files
├── ios/                     # iOS native project files
├── lib/                     # Dart source code
│   ├── models/              # Product & Order data models (e.g., product_model.dart)
│   ├── screens/             # App screens
│   │   ├── orders_screen.dart
│   │   ├── product_list_screen.dart
│   │   └── xendit_webview_screen.dart
│   ├── services/            # API & Payment service handlers
│   ├── firebase_options.dart # Firebase configuration
│   └── main.dart            # Main app entry point
└── pubspec.yaml             # Flutter dependencies & assets config
```

## ⚙️ Setup & Installation

### 1. Prerequisites
Ensure you have Flutter and Dart installed and added to your system PATH:
```bash
flutter doctor
```

### 2. Clone the Repository
```bash
git clone https://github.com/your-username/school_hub.git
cd school_hub
```

### 3. Install Dependencies
Get all required packages listed in `pubspec.yaml`:
```bash
flutter pub get
```

## 🏃 Running the Project

### Run on Chrome (Web)
```bash
flutter run -d chrome
```

### Run on Mobile (Android Emulator / Device)
```bash
flutter run
```

---

## 🛠️ Build & Deployment

* **Web Build**:
  ```bash
  flutter build web
  ```
* **Android APK**:
  ```bash
  flutter build apk --release
  ```