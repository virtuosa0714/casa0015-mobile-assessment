# Focus Sphere 🌍⏱️

Welcome to **Focus Sphere**, a gamified Pomodoro productivity application developed for the **CASA0015 - Mobile Systems & Interactions** module. 

Focus Sphere goes beyond traditional time management by intelligently monitoring your physical surroundings. By utilizing your device's onboard sensors (Light and Microphone), the app ensures you are studying in an optimal environment, bridging the gap between digital focus and the physical **Connected Environment**.

## 📱 About The App

**Tagline**: *Monitor. Focus. Connect.*

Focus Sphere gamifies your study sessions. Your goal is to "charge the Focus Planet Core" by maintaining focus. However, if the environment becomes too loud (>60 dB) or too dim (<300 Lux), an "Energy Crisis" is triggered, visually prompting you to improve your surroundings. 

### ✨ Key Features
* **Gamified Pomodoro Timer**: Custom-painted UI with breathing and rotation animations that react to your current state and environmental health.
* **Real-time Environmental Monitoring**: Uses device light sensors and microphones to constantly track Lux and dB levels.
* **Cloud Session History**: Seamlessly integrates with **Firebase Cloud Firestore** to upload and store your study reports.
* **Data Visualization**: Detailed, interactive line charts built with `fl_chart` to review the environmental data of past cloud sessions.

### 🖼️ Screenshots & Demo
> **Note to user:** Add your image/video links below. You can drag and drop images directly into GitHub's editor to get the links.

#### Core Experience
| Splash Screen | Main Timer (Optimal) | Energy Crisis Warning |
| :---: | :---: | :---: |
| ![Splash](https://github.com/user-attachments/assets/68856144-c97e-4c5b-8d9d-536ae61d19a1)| ![Main UI](https://github.com/user-attachments/assets/467a1ae9-6688-4821-b9f9-5bc0d07d99d1)| ![Warning UI](https://github.com/user-attachments/assets/3cd96826-d174-42af-8b28-0dc00327edfd)|

#### Settings & Cloud Data
| Settings Panel | Cloud History | Session Chart Detail |
| :---: | :---: | :---: |
| ![Settings](https://github.com/user-attachments/assets/6fa8cd39-3314-493c-9bc0-62e3c7935a85)| ![Cloud History](https://github.com/user-attachments/assets/be6b8bc0-bfa7-485d-be27-b600b697afb8)| ![Chart Detail](https://github.com/user-attachments/assets/a2964f7a-e537-4504-a108-37e9448b80de)|

🎥 **[Watch the full presentation & demo video here](https://youtube.com/shorts/Byi8CcJfj7c)**

🌐 **[Visit the Promotional Landing Page (GitHub Pages)](https://github.com/virtuosa0714/casa0015-mobile-assessment)**

---

## 🛠️ Built With (Frameworks & Plugins)

This application is built entirely in **Flutter** & **Dart**.

* [Flutter](https://flutter.dev/) - UI Toolkit
* [Firebase Core & Cloud Firestore](https://firebase.google.com/docs/firestore) - Cloud Database & API
* [fl_chart](https://pub.dev/packages/fl_chart) - Advanced Data Visualization
* [light](https://pub.dev/packages/light) - Ambient Light Sensor Plugin
* [noise_meter](https://pub.dev/packages/noise_meter) - Audio/Noise Level Plugin
* [permission_handler](https://pub.dev/packages/permission_handler) - Cross-platform permission management

---

## ⚙️ How To Install & Run

Follow these instructions to get a copy of the project up and running on your local machine for development and testing purposes.

### Prerequisites
* Flutter SDK (Version 3.16 or higher recommended)
* Android Studio or VS Code with Flutter extensions
* A physical Android/iOS device is **highly recommended** as emulators do not support real-time light/noise sensor inputs.

### Installation

1. **Clone the repository**
   git clone https://github.com/virtuosa0714/casa0015-mobile-assessment

2.**Navigate to the project directory**
   cd app

3.**Install Dependencies**
   flutter pub get

4.**Firebase Configuration (Important⚠️)**
   Because this app uses Firebase Firestore for cloud syncing, you must have a valid google-services.json file.
Place your google-services.json file inside the android/app/ directory.

5.**Run the Application**
   flutter run
