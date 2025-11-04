# Wispr-Style Dictation Tool – Full Implementation Plan

## 🧩 Overview
You’ll build a **two-stage pipeline**, just like Wispr Flow:

1. **Speech-to-Text (STT):** Local voice transcription in English and Polish → raw text.  
2. **Text Refinement (LLM):** Feed the raw text into Gemini CLI → get polished, formatted, grammar-corrected text.  

Optionally, a **third stage** can paste that text into the active window or clipboard.

Everything runs locally (except Gemini’s call), so you stay privacy-friendly and token-free.

---

## 🏗️ Stage 0: Environment Preparation

### 🖥️ System Requirements
- Linux host (Debian ideal).  
- Installed:  
  - `bash`, `git`, `curl`, `jq`  
  - `sox` or `ffmpeg` for audio capture  
  - `python3` + `pip`  
  - `whisper.cpp` (for local STT)  
  - `Gemini CLI`  

### 🎙️ Optional Tools
- `xclip` or `wl-copy` → copy output to clipboard  
- `xdotool` → simulate keyboard typing  
- `tmux` → run background service  

---

## ⚙️ Stage 1: Audio Capture + Transcription

### 📦 Tool: **whisper.cpp**
Reason: it’s light, offline, supports English + Polish, and can run on CPU/GPU.

```bash
git clone https://github.com/ggerganov/whisper.cpp
cd whisper.cpp
make
```

Download model:
```bash
./models/download-ggml-model.sh base
```

Record and transcribe:
```bash
arecord -f cd -t wav -d 10 -r 16000 input.wav
./main -m models/ggml-base.bin -f input.wav -l pl -otxt
```

Output → `input.wav.txt`

---

## 🧠 Stage 2: Gemini CLI Post-Processing

### 🔧 Create custom command file (e.g., `commands/dictate.txt`)
```
You are a writing assistant. Take raw transcription text that may contain errors or missing punctuation.
Correct grammar, punctuation, and casing.
Preserve the language (English or Polish) and do not translate.
If user uses both languages, maintain mixed-language structure.
Output only the corrected text.
```

### 💬 Example CLI call
```bash
gemini --model=gemini-1.5-pro --command=commands/dictate.txt --input=input.wav.txt --output=output.txt
```
or pipe it directly:
```bash
cat input.wav.txt | gemini --command=commands/dictate.txt > output.txt
```

---

## 🧩 Stage 3: Output Delivery

### Clipboard
```bash
xclip -sel clip < output.txt
```

### Type Directly
```bash
xdotool type --clearmodifiers "$(cat output.txt)"
```

You can combine this into one script so when you press a hotkey, it:
- Records audio  
- Transcribes  
- Sends to Gemini for refinement  
- Pastes result into current app  

---

## 🪄 Stage 4: Wrap Everything Into One Script

`dictate.sh` example:

```bash
#!/bin/bash
TMP_AUDIO="/tmp/input.wav"
TMP_TEXT="/tmp/input.txt"
TMP_OUT="/tmp/output.txt"

# record voice (adjust duration or detect silence)
arecord -f cd -t wav -d 10 -r 16000 "$TMP_AUDIO"

# transcribe
cd ~/whisper.cpp
./main -m models/ggml-base.bin -f "$TMP_AUDIO" -l auto -otxt
mv "$TMP_AUDIO.txt" "$TMP_TEXT"

# send to Gemini for correction
gemini --command=~/commands/dictate.txt --input="$TMP_TEXT" --output="$TMP_OUT"

# copy or type output
xclip -sel clip < "$TMP_OUT"
# optional: xdotool type --clearmodifiers "$(cat $TMP_OUT)"
```

Make executable:
```bash
chmod +x dictate.sh
```

Bind to a global hotkey (e.g., `Ctrl+Alt+Space`).

---

## 🚀 Optional Improvements

| Feature | Description |
|----------|--------------|
| **Silence detection** | Use `sox` or `ffmpeg` VAD to auto-stop recording. |
| **Continuous mode** | Run a loop to listen for keypress → record → process. |
| **Language auto-switch** | Use Whisper’s `-l auto`, or detect language and adjust prompt dynamically. |
| **Daemon mode** | Convert script to systemd service or background listener. |
| **Command extensions** | Add `commands/polish.txt`, `commands/email.txt`, `commands/code.txt` for context-specific tone. |

---

## ✅ Final Result

Pipeline:
🎙️ **Voice → (arecord/sox)**  
→ 🧩 **Whisper.cpp (offline STT)**  
→ 🧠 **Gemini CLI (grammar/format polish)**  
→ 📋 **Clipboard or active window**
