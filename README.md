<div align="center">

# ⚡ CIPHER! (v1.0)
### The Fast-Paced, Neo-Brutalist Party Charades Engine Powered by AIVCO AI

<br/>

<!-- BIG DIRECT ONE-CLICK INSTALL BUTTON -->
<a href="releases/Cipher-v1.0.apk?raw=true">
  <img src="https://img.shields.io/badge/⚡_INSTALL_NOW-DOWNLOAD_APK-BAFF29?style=for-the-badge&labelColor=000000&logo=android&logoColor=white" height="52" alt="Install Now"/>
</a>

<br/><br/>

[![APK File](https://img.shields.io/badge/Download-Cipher--v1.0.apk-00E5FF?style=for-the-badge&logo=android&logoColor=black)](releases/Cipher-v1.0.apk?raw=true)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![AIVCO AI](https://img.shields.io/badge/AI_Engine-AIVCO_AI-BAFF29?style=for-the-badge&labelColor=000000)](https://github.com/parikshit-koirala)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://android.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-FFD700?style=for-the-badge)](LICENSE)

<p align="center">
  <b>Hold the phone to your forehead. Tilt down when you get it right. Tilt up to pass.</b><br/>
  Never run out of cards again—synthesize encrypted, zero-spoiler custom decks on <i>any</i> topic in seconds with <b>AIVCO AI</b>.
</p>

<p align="center">
  📲 <b>Direct File Link:</b> <a href="releases/Cipher-v1.0.apk?raw=true"><b>Click here if download doesn't start automatically</b></a>
</p>

</div>

---

## 🎯 Overview

**Cipher!** reimagines classic forehead charades with an uncompromising **Neo-Brutalist arcade UI**, responsive physical motion controls, and real-time generative AI. 

Instead of locking players behind static wordlists or paywalled expansion packs, **Cipher!** integrates the **AIVCO AI Engine** to turn any prompt—from *"90s Rock Bands"* and *"Premier League Clubs"* to *"Nepali Pop Culture"* or *"Sci-Fi Movies"*—into a balanced, spoiler-encrypted party deck tailored to your exact group size and difficulty vibe.

---

## 📦 Quick Install (Android)

1. Tap the **[⚡ INSTALL NOW](releases/Cipher-v1.0.apk?raw=true)** button above to download `Cipher-v1.0.apk` directly to your phone.
2. Open the downloaded file from your notifications or file manager (allow *"Install from Unknown Sources"* if prompted).
3. Launch **Cipher!**, pick a deck or generate one with **AIVCO AI**, and start playing!

---

## ✨ Key Features

- 🧠 **AIVCO AI Deck Synthesis:** Generate custom decks on any conceivable topic in under 3 seconds. Built with strict entity-only guardrails to ensure every card is a pure, actable noun, person, or title—zero filler or repetitive suffixes.
- 🛡️ **Zero-Spoiler Encryption Guarantee:** AI-generated decks are obfuscated and saved directly into your local library. The player holding the phone during generation never sees the wordlist beforehand. Editing a locked deck requires clearing an explicit Spoiler Guard prompt.
- 📳 **60fps Accelerometer & Gyro Controls:** Hold the phone in landscape against your forehead:
  * **Tilt Down (↓):** Mark card as **CORRECT** (triggers haptic feedback + audio chime).
  * **Tilt Up (↑):** **PASS / SKIP** tough cards immediately.
- 👥 **Dynamic Player Scaling (2P – 6P):** Automatically scales deck density and card generation targets (`~40` to `~120+` cards) based on your active party size (`2P`, `3P`, `4P`, `5P`, `6P`) so no card repeats mid-session.
- 🎚️ **3 Distinct Vibe & Difficulty Modes:**
  * 🌱 **Casual:** Popular, everyday, and universally relatable hits.
  * 🎉 **Party:** Fast-paced crowd-pleasers built for high-energy rooms.
  * 🔥 **Hardcore:** Deep-cut trivia and niche entities for true superfans.
- 🛠️ **Custom Deck Studio:** Build, edit, add, or prune cards manually with bulk comma-separated pasting and instant local persistence.
- 🎨 **High-Contrast Neo-Brutalist Design:** Tactile offset hard shadows, thick ink borders, electric cobalt & acid-lime palettes, and punchy typography readable from across a crowded room.

---

## 📸 Screenshots

<div align="center">
  <table>
    <tr>
      <td align="center"><b>Home & Deck Library</b></td>
      <td align="center"><b>AIVCO AI Generator</b></td>
      <td align="center"><b>Deck Studio & Spoiler Lock</b></td>
      <td align="center"><b>Forehead Gameplay</b></td>
    </tr>
    <tr>
      <td><img src="assets/screenshots/home.jpg" width="200" alt="Home Screen"/></td>
      <td><img src="assets/screenshots/ai_generator.jpg" width="200" alt="AI Generator"/></td>
      <td><img src="assets/screenshots/edit_deck.jpg" width="200" alt="Edit Deck"/></td>
      <td><img src="assets/screenshots/gameplay.jpg" width="200" alt="Gameplay"/></td>
    </tr>
  </table>
  <p><i>(Tip: Add screenshots to <code>assets/screenshots/</code> to populate this gallery!)</i></p>
</div>

---

## 🏗️ Architecture & Tech Stack

| Layer | Technology | Purpose |
| :--- | :--- | :--- |
| **Framework** | Flutter (Dart 3) | Cross-platform UI & high-frame-rate animations |
| **AI Synthesis** | AIVCO AI Engine (LLaMA 3.3 70B JSON Mode) | Structured JSON entity extraction & custom deck generation |
| **Motion Sensors** | `sensors_plus` | Real-time accelerometer & gyroscope tilt detection |
| **Local Storage** | `shared_preferences` + Cipher Encoding | Persistent custom decks & Zero-Spoiler payload obfuscation |
| **Networking** | `http` | Low-latency REST calls with strict JSON schema validation |

### Project Structure

```text
lib/
├── main.dart                      # App entry point, theme & orientation locks
├── models/
│   └── deck_model.dart            # Deck & card serialization + encryption flags
├── services/
│   ├── groq_deck_service.dart     # AIVCO AI synthesis, JSON parsing & sanitization
│   └── storage_service.dart       # Local persistence & zero-spoiler cipher logic
├── screens/
│   ├── home_screen.dart           # Main arcade hub & category browser
│   ├── ai_deck_generator_screen.dart # Parameterized AIVCO AI prompt studio
│   ├── edit_deck_screen.dart      # Spoiler-guarded card manager
│   ├── gameplay_screen.dart       # Landscape sensor-driven charades loop
│   └── results_screen.dart        # Post-round scoreboard & card breakdown
└── widgets/                       # Neo-brutalist buttons, chips & hard-shadow cards
