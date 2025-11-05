# Wispr Dictation Tool - Windows Installation Guide

## ⚙️ Your System Specs
- **CPU:** AMD Ryzen 9 9950X (Excellent! 16 cores)
- **RAM:** 64GB (Perfect for any model size)
- **GPU:** AMD Radeon RX 7800 XT (Great GPU)
- **Python:** ✅ Already installed (Anaconda)

**You have high-end hardware!** We'll start with lightweight models, but you can easily upgrade to larger ones later for even better accuracy.

---

## 📋 What We'll Install

1. **Ollama** - Local LLM server (for text refinement)
2. **Python packages** - faster-whisper, audio libraries, system integration
3. **Models** - Lightweight Whisper and LLM models
4. **Basic scripts** - Testing pipeline

**Total install time:** ~15-20 minutes
**Download size:** ~4-5 GB (models)

---

## Step 1: Install Ollama (5 minutes)

### 1.1 Download Ollama for Windows

1. Open your browser and go to: **https://ollama.com/download/windows**
2. Click **"Download for Windows"**
3. Run the installer (`OllamaSetup.exe`)
4. Follow the installation wizard (use default settings)
5. Ollama will automatically start and run in the background

### 1.2 Verify Ollama is Running

1. Open **PowerShell** or **Command Prompt**
2. Type and press Enter:
   ```powershell
   ollama --version
   ```
3. You should see something like: `ollama version 0.x.x`

✅ **Checkpoint:** Ollama is installed and running!

---

## Step 2: Create Python Environment (2 minutes)

### 2.1 Open Anaconda Prompt

1. Press **Windows Key**
2. Type **"Anaconda Prompt"**
3. Click on it to open

### 2.2 Create New Environment

In the Anaconda Prompt, run these commands one by one:

```bash
# Create new environment named 'wispr' with Python 3.11
conda create -n wispr python=3.11 -y

# Activate the environment
conda activate wispr
```

You should now see `(wispr)` at the beginning of your prompt line.

✅ **Checkpoint:** Virtual environment created and activated!

---

## Step 3: Install Python Packages (5 minutes)

### 3.1 Install Core Dependencies

**Still in Anaconda Prompt with (wispr) active**, run:

```bash
# Audio and ML libraries
pip install faster-whisper sounddevice numpy scipy

# System integration
pip install pyperclip pynput keyboard

# LLM client
pip install requests

# Utilities
pip install pyyaml python-dotenv
```

This will download and install all necessary packages (~500MB).

### 3.2 Verify Installation

Test that faster-whisper is installed:

```bash
python -c "import faster_whisper; print('faster-whisper:', faster_whisper.__version__)"
```

You should see version number printed.

✅ **Checkpoint:** All Python packages installed!

---

## Step 4: Download Models (5-10 minutes)

### 4.1 Download Whisper Model (Lightweight)

The Whisper model downloads automatically on first use, but let's verify it works:

```bash
python -c "from faster_whisper import WhisperModel; print('Downloading model...'); model = WhisperModel('base', device='cpu'); print('Model ready!')"
```

This will download the **base** Whisper model (~140MB). It may take 2-5 minutes depending on your internet speed.

**Available model sizes:**
- `tiny` - ~40MB, fastest, decent accuracy
- `base` - ~140MB, **good balance** ← we're using this
- `small` - ~460MB, better accuracy
- `medium` - ~1.5GB, high accuracy
- `large-v2` - ~3GB, best accuracy

You can upgrade later by just changing `'base'` to `'small'` or `'medium'`.

### 4.2 Download LLM Model (Lightweight)

Still in Anaconda Prompt:

```bash
# Go back to regular command prompt (or open a new one)
ollama pull phi3:mini
```

This downloads **Phi-3 Mini** (~2.3GB) - Microsoft's lightweight but powerful model.

**Alternative lightweight models you can try:**
- `ollama pull llama3.2:3b` - Meta's LLaMA 3.2 (2GB)
- `ollama pull gemma2:2b` - Google's Gemma (1.6GB)

For better quality (you have the RAM!):
- `ollama pull mistral:7b-instruct` - Better quality (4.5GB)
- `ollama pull llama3.2:8b` - Even better (8GB)

### 4.3 Test Ollama Model

```bash
ollama run phi3:mini "Fix this text: hello wrld how r u"
```

You should see corrected output: "Hello world, how are you?"

Type `/bye` to exit the chat.

✅ **Checkpoint:** All models downloaded and working!

---

## Step 5: Create Project Structure (2 minutes)

### 5.1 Create Project Directory

In Anaconda Prompt (with `wispr` environment active):

```bash
# Navigate to where you want the project
cd C:\Users\YourUsername\Documents

# Create project folder
mkdir wispr-dictation-tool
cd wispr-dictation-tool

# Create folder structure
mkdir src
mkdir src\audio
mkdir src\stt
mkdir src\llm
mkdir src\system
mkdir models
mkdir temp
```

### 5.2 Create Configuration File

Create a file named `config.yaml` in the `wispr-dictation-tool` folder:

**config.yaml:**
```yaml
# Wispr Dictation Tool Configuration

# Audio Settings
audio:
  sample_rate: 16000
  channels: 1
  silence_threshold: 0.01
  silence_duration: 1.5  # seconds of silence to stop recording
  max_duration: 60  # maximum recording duration in seconds

# Speech-to-Text Settings
stt:
  model_size: "base"  # tiny, base, small, medium, large-v2
  device: "cpu"  # cpu or cuda (for GPU)
  compute_type: "int8"  # int8, float16, float32
  language: "auto"  # auto, en, pl

# LLM Settings
llm:
  provider: "ollama"
  model: "phi3:mini"
  base_url: "http://localhost:11434"
  temperature: 0.3
  max_tokens: 500

# Hotkey Settings
hotkey:
  trigger: "ctrl+alt+d"  # Press this to start recording
  mode: "push_to_talk"  # push_to_talk or toggle

# Output Settings
output:
  method: "clipboard"  # clipboard or type
  notification: true
  save_history: false

# Paths
paths:
  temp_audio: "temp/recording.wav"
  temp_transcript: "temp/transcript.txt"
  temp_refined: "temp/refined.txt"
```

✅ **Checkpoint:** Project structure created!

---

## Step 6: Create Basic Testing Scripts (5 minutes)

### 6.1 Test Audio Capture

Create `test_audio.py` in the `wispr-dictation-tool` folder:

```python
"""Test audio recording"""
import sounddevice as sd
import numpy as np
import scipy.io.wavfile as wavfile
import os

print("Testing audio capture...")
print("Available audio devices:")
print(sd.query_devices())

# Settings
duration = 5  # seconds
sample_rate = 16000

print(f"\nRecording for {duration} seconds...")
print("Speak now!")

# Record audio
audio = sd.rec(int(duration * sample_rate),
               samplerate=sample_rate,
               channels=1,
               dtype=np.int16)
sd.wait()

print("Recording finished!")

# Save to file
os.makedirs("temp", exist_ok=True)
output_file = "temp/test_audio.wav"
wavfile.write(output_file, sample_rate, audio)

print(f"Audio saved to: {output_file}")
print(f"File size: {os.path.getsize(output_file) / 1024:.2f} KB")
print("\n✅ Audio capture test successful!")
```

**Run it:**
```bash
python test_audio.py
```

Speak for 5 seconds when prompted. You should see "Audio capture test successful!"

---

### 6.2 Test Speech-to-Text

Create `test_stt.py`:

```python
"""Test speech-to-text with faster-whisper"""
from faster_whisper import WhisperModel
import os
import time

print("Loading Whisper model...")
model = WhisperModel("base", device="cpu", compute_type="int8")
print("Model loaded!\n")

# Check if test audio exists
audio_file = "temp/test_audio.wav"
if not os.path.exists(audio_file):
    print(f"❌ Audio file not found: {audio_file}")
    print("Please run test_audio.py first!")
    exit(1)

print(f"Transcribing: {audio_file}")
start_time = time.time()

# Transcribe
segments, info = model.transcribe(audio_file, language="auto")

# Collect text
text = " ".join([segment.text for segment in segments])

elapsed = time.time() - start_time

print(f"\n📝 Transcription Result:")
print("=" * 60)
print(text)
print("=" * 60)
print(f"\n⏱️  Time taken: {elapsed:.2f} seconds")
print(f"🌍 Detected language: {info.language}")
print(f"📊 Probability: {info.language_probability:.2%}")
print("\n✅ Speech-to-text test successful!")

# Save transcript
output_file = "temp/test_transcript.txt"
with open(output_file, "w", encoding="utf-8") as f:
    f.write(text)
print(f"💾 Transcript saved to: {output_file}")
```

**Run it:**
```bash
python test_stt.py
```

You should see your spoken words transcribed!

---

### 6.3 Test LLM Refinement

Create `test_llm.py`:

```python
"""Test LLM text refinement with Ollama"""
import requests
import json
import os
import time

print("Testing Ollama LLM refinement...\n")

# Read the transcript
transcript_file = "temp/test_transcript.txt"
if not os.path.exists(transcript_file):
    print(f"❌ Transcript not found: {transcript_file}")
    print("Please run test_stt.py first!")
    exit(1)

with open(transcript_file, "r", encoding="utf-8") as f:
    raw_text = f.read()

print("📝 Raw transcript:")
print("=" * 60)
print(raw_text)
print("=" * 60)

# Create refinement prompt
prompt = f"""You are a writing assistant. Take the following transcribed text and:
1. Correct any grammar mistakes
2. Add proper punctuation
3. Fix capitalization
4. Make it natural and readable
5. Keep the same language (don't translate)
6. Output ONLY the corrected text, nothing else

Raw transcript:
{raw_text}

Corrected text:"""

print("\n🤖 Sending to Ollama for refinement...")
start_time = time.time()

# Call Ollama API
response = requests.post(
    "http://localhost:11434/api/generate",
    json={
        "model": "phi3:mini",
        "prompt": prompt,
        "stream": False,
        "options": {
            "temperature": 0.3,
            "num_predict": 500
        }
    },
    timeout=30
)

elapsed = time.time() - start_time

if response.status_code == 200:
    result = response.json()
    refined_text = result["response"].strip()

    print("\n✨ Refined text:")
    print("=" * 60)
    print(refined_text)
    print("=" * 60)
    print(f"\n⏱️  Time taken: {elapsed:.2f} seconds")

    # Save refined text
    output_file = "temp/test_refined.txt"
    with open(output_file, "w", encoding="utf-8") as f:
        f.write(refined_text)

    print(f"💾 Refined text saved to: {output_file}")
    print("\n✅ LLM refinement test successful!")
else:
    print(f"❌ Error: {response.status_code}")
    print(response.text)
```

**Run it:**
```bash
python test_llm.py
```

You should see your transcript refined with proper grammar and punctuation!

---

### 6.4 Test Clipboard

Create `test_clipboard.py`:

```python
"""Test clipboard functionality"""
import pyperclip
import os

print("Testing clipboard...\n")

# Read refined text
refined_file = "temp/test_refined.txt"
if not os.path.exists(refined_file):
    print(f"❌ Refined text not found: {refined_file}")
    print("Please run test_llm.py first!")
    exit(1)

with open(refined_file, "r", encoding="utf-8") as f:
    text = f.read()

print("📋 Copying to clipboard:")
print("=" * 60)
print(text)
print("=" * 60)

# Copy to clipboard
pyperclip.copy(text)

print("\n✅ Text copied to clipboard!")
print("\nTry pasting (Ctrl+V) in any application to verify.")

# Verify
clipboard_content = pyperclip.paste()
if clipboard_content == text:
    print("✅ Clipboard verification successful!")
else:
    print("⚠️  Warning: Clipboard content doesn't match")
```

**Run it:**
```bash
python test_clipboard.py
```

Now try pasting (Ctrl+V) in Notepad or any app - you should see your refined text!

---

## Step 7: Test Full Pipeline (2 minutes)

Create `test_full_pipeline.py`:

```python
"""Test complete dictation pipeline"""
import sounddevice as sd
import numpy as np
import scipy.io.wavfile as wavfile
from faster_whisper import WhisperModel
import requests
import pyperclip
import os
import time

print("=" * 70)
print("WISPR DICTATION TOOL - FULL PIPELINE TEST")
print("=" * 70)

# Configuration
DURATION = 10  # seconds
SAMPLE_RATE = 16000
TEMP_AUDIO = "temp/pipeline_audio.wav"
OLLAMA_MODEL = "phi3:mini"

os.makedirs("temp", exist_ok=True)

# Step 1: Record Audio
print("\n[1/4] 🎙️  Recording audio...")
print(f"Speak for {DURATION} seconds starting NOW:")
print("-" * 70)

audio = sd.rec(int(DURATION * SAMPLE_RATE),
               samplerate=SAMPLE_RATE,
               channels=1,
               dtype=np.int16)
sd.wait()

wavfile.write(TEMP_AUDIO, SAMPLE_RATE, audio)
print("✅ Recording complete!")

# Step 2: Transcribe
print("\n[2/4] 📝 Transcribing...")
start_stt = time.time()

model = WhisperModel("base", device="cpu", compute_type="int8")
segments, info = model.transcribe(TEMP_AUDIO, language="auto")
raw_text = " ".join([segment.text for segment in segments])

stt_time = time.time() - start_stt

print(f"✅ Transcription complete! ({stt_time:.2f}s)")
print(f"   Language: {info.language} ({info.language_probability:.0%} confidence)")
print(f"   Raw text: {raw_text[:80]}...")

# Step 3: Refine with LLM
print("\n[3/4] ✨ Refining text...")
start_llm = time.time()

prompt = f"""You are a writing assistant. Correct the following transcribed text:
- Fix grammar and spelling
- Add proper punctuation
- Improve capitalization
- Keep the original language
- Output only the corrected text

Text: {raw_text}

Corrected:"""

response = requests.post(
    "http://localhost:11434/api/generate",
    json={
        "model": OLLAMA_MODEL,
        "prompt": prompt,
        "stream": False,
        "options": {"temperature": 0.3}
    },
    timeout=30
)

refined_text = response.json()["response"].strip()
llm_time = time.time() - start_llm

print(f"✅ Refinement complete! ({llm_time:.2f}s)")

# Step 4: Copy to Clipboard
print("\n[4/4] 📋 Copying to clipboard...")
pyperclip.copy(refined_text)
print("✅ Copied!")

# Results
print("\n" + "=" * 70)
print("RESULTS")
print("=" * 70)
print(f"\n📝 Original transcript:\n   {raw_text}\n")
print(f"✨ Refined text:\n   {refined_text}\n")
print("=" * 70)
print(f"⏱️  Total time: {stt_time + llm_time:.2f}s (STT: {stt_time:.1f}s + LLM: {llm_time:.1f}s)")
print(f"📋 Text is now in your clipboard - try pasting it!")
print("=" * 70)
print("\n✅ FULL PIPELINE TEST SUCCESSFUL! 🎉")
```

**Run it:**
```bash
python test_full_pipeline.py
```

This tests the entire workflow:
1. Records 10 seconds of audio
2. Transcribes it with Whisper
3. Refines it with Ollama
4. Copies to clipboard

Speak clearly for 10 seconds when prompted, then wait for processing. The refined text will be in your clipboard!

---

## 🎯 Quick Start Checklist

Use this to verify everything is working:

```bash
# Activate environment
conda activate wispr

# Test 1: Audio
python test_audio.py
# ✅ Should record 5 seconds and save temp/test_audio.wav

# Test 2: Transcription
python test_stt.py
# ✅ Should transcribe your audio to text

# Test 3: LLM Refinement
python test_llm.py
# ✅ Should refine the transcript with proper grammar

# Test 4: Clipboard
python test_clipboard.py
# ✅ Should copy refined text to clipboard

# Test 5: Full Pipeline
python test_full_pipeline.py
# ✅ Should run complete workflow end-to-end
```

---

## 🎓 What You've Accomplished

✅ **Ollama installed** - Local LLM server running
✅ **Python environment** - All libraries installed
✅ **Models downloaded** - Whisper (base) + Phi-3 (mini)
✅ **Audio working** - Can record your voice
✅ **STT working** - Can transcribe speech to text
✅ **LLM working** - Can refine text with proper grammar
✅ **Clipboard working** - Can paste into any app
✅ **Full pipeline tested** - Everything works together!

---

## 🚀 Next Steps

Now that everything is installed and tested, you have a few options:

### Option 1: Add Hotkey Activation
- Make it run in the background
- Press Ctrl+Alt+D to activate
- Automatic recording and pasting

### Option 2: Improve Models
Your hardware can handle bigger models:
```bash
# Upgrade Whisper (better accuracy)
# Change 'base' to 'small' in the scripts

# Upgrade LLM (better refinement)
ollama pull mistral:7b-instruct
# Change 'phi3:mini' to 'mistral:7b-instruct' in scripts
```

### Option 3: Build GUI
- System tray icon
- Settings window
- Visual feedback during recording

### Option 4: Add Voice Activity Detection
- Auto-stop when you stop talking
- No need to wait for fixed duration

---

## 🆘 Troubleshooting

### "No audio devices found"
- Check microphone is connected and enabled in Windows Settings
- Try: `python -c "import sounddevice as sd; print(sd.query_devices())"`

### "Ollama connection refused"
- Make sure Ollama is running
- Check system tray for Ollama icon
- Try: `ollama list` in command prompt

### "Model not found"
- Run: `ollama pull phi3:mini`
- Verify: `ollama list`

### "Permission denied" errors
- Run Anaconda Prompt as Administrator
- Check antivirus isn't blocking Python

### Slow performance
- First run is always slower (model loading)
- Subsequent runs should be faster
- With your specs, expect ~3-5 seconds total

---

## 📞 Getting Help

If you encounter issues:
1. Check the error message carefully
2. Make sure `conda activate wispr` is run
3. Verify Ollama is running: `ollama --version`
4. Test components individually (test_audio.py, etc.)

---

## 🎉 Congratulations!

You now have a working dictation tool! Try the full pipeline test and see your spoken words automatically refined and copied to your clipboard.

**What you can do right now:**
1. Run `python test_full_pipeline.py`
2. Speak for 10 seconds
3. Wait for processing (~5 seconds)
4. Paste (Ctrl+V) into any application
5. See your perfectly formatted text!

Enjoy your new dictation tool! 🎤✨
