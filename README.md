<div align="center">

# ⚡ CIPHER! (v1.0)
### The Fast-Paced, Neo-Brutalist Party Charades Engine Powered by AIVCO AI

[![Download APK](https://img.shields.io/badge/📲_Download_APK-Cipher--v1.0.apk-BAFF29?style=for-the-badge&labelColor=000000)](releases/Cipher-v1.0.apk)
[![Latest Release](https://img.shields.io/badge/GitHub_Release-v1.0-FFD700?style=for-the-badge&logo=github&logoColor=black)](../../releases/latest)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://android.com)

<p align="center">
  <b>Hold the phone to your forehead. Tilt down when you get it right. Tilt up to pass.</b><br/>
  Never run out of cards again—synthesize encrypted, zero-spoiler custom decks on <i>any</i> topic in seconds with <b>AIVCO AI</b>.
</p>

### 📥 [Click Here to Download `Cipher-v1.0.apk` Directly](releases/Cipher-v1.0.apk)
*(Or grab it from the [GitHub Releases](../../releases) page!)*

</div>

---

## 🎯 Overview

**Cipher!** reimagines classic forehead charades with an uncompromising **Neo-Brutalist arcade UI**, responsive physical motion controls, and real-time generative AI. 

Instead of locking players behind static wordlists, **Cipher!** integrates the **AIVCO AI Engine** to turn any prompt—from *"90s Rock Bands"* and *"Premier League Clubs"* to *"Nepali Pop Culture"* or *"Sci-Fi Movies"*—into a balanced, spoiler-encrypted party deck tailored to your exact group size and difficulty vibe.

---

## 📦 Quick Install (Android)

1. Download **[`Cipher-v1.0.apk`](releases/Cipher-v1.0.apk)** directly onto your Android phone.
2. Open the downloaded file (allow *"Install from Unknown Sources"* if prompted by Android).
3. Launch **Cipher!**, pick a deck or generate one with **AIVCO AI**, and start playing!

---

## ✨ Key Features

* 🧠 **AIVCO AI Deck Synthesis:** Generate custom decks on any conceivable topic in seconds. Built with strict entity-only guardrails to ensure every card is a pure, actable noun, person, or title.
* 🛡️ **Zero-Spoiler Encryption Guarantee:** AI-generated decks are obfuscated and saved directly into your local library. The player holding the phone during generation never sees the wordlist beforehand. Editing a locked deck requires clearing an explicit Spoiler Guard prompt.
* 📳 **60fps Accelerometer & Gyro Controls:** Hold the phone in landscape against your forehead:
  * **Tilt Down (↓):** Mark card as **CORRECT** (triggers haptic feedback + audio chime).
  * **Tilt Up (↑):** **PASS / SKIP** tough cards immediately.
* 👥 **Dynamic Player Scaling (2P – 6P):** Automatically scales deck density and card generation targets (`~40` to `~120+` cards) based on your active party size (`2P`, `3P`, `4P`, `5P`, `6P`).
* 🎚️ **3 Distinct Vibe & Difficulty Modes:**
  * 🌱 **Casual:** Popular, everyday, and universally relatable hits.
  * 🎉 **Party:** Fast-paced crowd-pleasers built for high-energy rooms.
  * 🔥 **Hardcore:** Deep-cut trivia and niche entities for true superfans.
* 🛠️ **Custom Deck Studio:** Build, edit, add, or prune cards manually with bulk comma-separated pasting and instant local persistence.

---

## 🏗️ Tech Stack

* **Framework:** Flutter (Dart 3)
* **AI Synthesis:** AIVCO AI Engine (LLaMA 3.3 70B JSON Mode)
* **Motion Sensors:** `sensors_plus` (Accelerometer & Gyroscope)
* **Storage & Security:** `shared_preferences` + Zero-Spoiler Local Cipher Encoding

---

## 🛠️ Build From Source

```bash
git clone https://github.com/parikshit-koirala/cipher.git
cd cipher
flutter pub get
flutter run
```
