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

---

## 🎨 Design Evolution & Functionality

This section details the initial conceptual design and systemic functionality of **Focus Sphere**, bridging the 'Connected Environment' sensor data with a narrative-driven user experience.

### Conceptual Storyboard (Design Evolution)

The image below displays the theoretical storyboard that guided the gamified narrative flow. It maps out the key visual states and user interactions:

* **Optimal Focus**: The core narrative centers on 'Charging the Focus Planet' with professional, breathing cyan UI.
* **Energy Crisis**: Utilizing device sensors, if the environment becomes suboptimal (dim/loud), the UI **immediately transitions** to a flashing red 'CRISIS' state. This visual feedback loop directly connects the physical world to the gamified digital narrative.
* **Data Closure**: The flow concludes with a permanent, cloud-synced record, accessible via interactive fl_chart details.

| Storyboard & Use Cases Conceptual Board |
| :---: |
| ![Storyboard & Use Cases Concept](https://github.com/user-attachments/assets/33dfec64-f79c-45c6-9776-ea6a3b984b11)|

### Functional Use Case Diagram (System Interactions)

The right half of the conceptual board above outlines the UML-style functional use cases, demonstrating the complex interactions between the **Actor (User, Physical Sensors, Firebase)** and the **System**:

* **Actors**: Clearly defined User, Physical Sensors (Light/Sound), and Firebase Cloud Firestore actors.
* **Core Systems**: Focuses on interactions with core modules: Sensor Monitoring (connected environment), Pomodoro Loop, and Cloud API services.
* **Key Cloud Use Cases**: Specifically demonstrates user capability to 'Upload Session Report to Cloud' and 'Delete Cloud History', satisfying all requirements for robust API and service integration (Firebase).

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
