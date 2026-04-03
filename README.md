# 🎵 MSST & WebUI - One-Click Portable Installer 🚀

Welcome! This repository provides **fully automated and portable** installers for two powerful AI-based music source separation tools (vocal removal, stems splitting, etc.). 

No Python, Conda, or driver configuration knowledge required. The script handles the heavy lifting for you! 😎

---

## 🌟 What's Included?

1.  **Music-Source-Separation-Training (ZFTurbo)** – Advanced engine for training and inference of separation models.
2.  **MSST-WebUI (SUC-DriverOld)** – A clean, user-friendly browser interface (WebUI) for the models.

---

## 🔥 Why use these scripts?

* **Fully Portable:** Creates a local environment inside the project folder. No system-wide clutter! 🧹
* **Smart CUDA Detection:** Automatically detects your GPU and installs the correct PyTorch version (Full support for **RTX 50-series** and CUDA 12.8! 🏎️💨).
* **Zero Config:** Automatically downloads and sets up Miniconda, Git, and all necessary dependencies.
* **Ready-to-Run:** Generates a `run-gui.bat` launcher so you can start the app with a single click after installation.

---

## 🛠️ Quick Start (1-2-3 Guide)

1.  **Download** this repository (or copy the `.bat` files to the folder where you want the programs installed).
2.  **Run** the chosen installer:
    * `install.bat` – for the wxPython GUI version.
    * `install_WebUI.bat` – for the Web browser version.
3.  **Wait** – the script will download everything. Once finished, it will display the total installation time. ⏱️

---

## 🖥️ Requirements

* **OS:** Windows 10/11 (64-bit).
* **GPU:** NVIDIA GPU is highly recommended for speed, but the script will automatically fallback to **CPU mode** if no GPU is detected! 💻
* **Disk Space:** Approx. 5-10 GB (for the environment and AI models).

---

### 📂 Folder Structure After Install

Once the installation is finished, your directory will be organized as follows:

```text
📂 Your_Project_Folder
┃
┣━━ 📄 install.bat          <-- The installer you ran
┃
┗━━ 📂 Music-Source-Separation-Training
    ┃
    ┣━━ 📂 env                     <-- Your isolated Python environment 🐍
    ┣━━ 📄 gui-wx.py               <-- Main GUI script (Auto-relocated)
    ┗━━ 🚀 run-gui.bat             <-- DOUBLE CLICK THIS TO START!
```
---

## 📜 Credits

Huge thanks to the creators of the original tools:
* [ZFTurbo](https://github.com/ZFTurbo/Music-Source-Separation-Training) – For the engine and models.
* [SUC-DriverOld](https://github.com/SUC-DriverOld/MSST-WebUI) – For the excellent WebUI.
