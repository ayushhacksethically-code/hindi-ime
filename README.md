# Hindi IME — Hinglish to Devanagari

A fast, offline-first Hinglish → Devanagari transliteration system for Linux, built on Nim + Fcitx5 + Rime.

## Why This Exists

Linux mein koi badhiya sa version nahi mil raha tha. Har cheez mein 
strict rules the jo ki Hinglish type karne walo ke liye problem tha.

## Features

- ✅ **Natural Hinglish input** — not formal transliteration
- ✅ **Offline-first** — works without internet
- ✅ **Zero-latency** — rule engine, no background daemon
- ✅ **Hybrid intelligence** — rules → dict → fuzzy → API
- ✅ **195,913 entries** (88,000+ unique words)
- ✅ **91% accuracy** (daily test)
- ✅ **730+ curated Hinglish words**
- ✅ **Hindi WordNet** (40k+ entries)
- ✅ **Multi-language ready** — architecture supports Tamil, Telugu, Bengali
- ✅ **Rime + Fcitx5 integration**
- ✅ **Optional Google API fallback** (runtime config, OFF by default)

## Recent Updates

- 195,913 entries (88,000+ unique words)
- 91% accuracy (daily test)
- WhatsApp conversation words (200+)
- Ordinal numbers 1-100
- Question words (koun, kaha, kaise)
- Matra handling fix (pyari, karti, gadiyan)
- Smart English passthrough (office, whatsapp)
- User choice respected (no forced defaults)

## Project Stats

- **Total entries**: 195,913
- **Unique words**: 88,144
- **Unique Hinglish keys**: 177,472
- **Accuracy**: 91% (daily test)
- **Dictionary size**: 6.8 MB
- **Commits**: 17
- **Built in**: 5 days

## Quick Start

### Prerequisites

- Nim 2.0+
- Fcitx5 with Rime
- Linux (X11 or Wayland)

### Install

```bash
git clone https://github.com/ayushhacksethically-code/hindi-ime
cd hindi-ime
./scripts/install.sh
```

### Manual Build

```bash
nim c -d:release src/compile_rime_hindi.nim
nim c -d:release src/build_rime_dict.nim
./src/compile_rime_hindi
fcitx5 -r -d
```

Then select **hindi_ai** in Fcitx5.

### Dictionary Coverage

The repository includes a pre-generated Rime dictionary (`rime/hindi_ai.dict.yaml`, ~6.8 MB) covering 195,913 entries (88,000+ unique words) derived from Hindi WordNet (IIT Bombay, GPL) plus curated Hinglish vocabulary.

For **regenerating** from source, place `wordnet_hindi_dict.bin` (6 MB) in `~/.local/share/hindi-ime/` and run:

```bash
./scripts/build_dict.sh
```

Run `./scripts/fetch_wordnet.sh` for setup instructions.

## Installation Notes

This installer does NOT change your system's default keyboard 
or input method. Your existing setup remains untouched.

To use Hindi IME:
1. Ensure Fcitx5 has Rime added as an input method
2. Switch to Rime via Ctrl+Space
3. Select 'hindi_ai' schema

To make Hindi your default:
- Manually configure in Fcitx5 settings
- Or set in ~/.config/fcitx5/profile

We believe in user choice — no forced defaults.

## Usage

Type Hinglish, get Devanagari:

| You type | You get |
|----------|---------|
| `samasya` | समस्या |
| `namaste` | नमस्ते |
| `nhi` | नहीं |
| `aaplog` | आपलोग |
| `karta` | करता |
| `vaishe` | वैसे |
| `koun` | कौन |
| `pyari` | प्यारी |
| `office` | office |
| `hlo` | हैलो |
| `chaturbhuj` | चतुर्भुज |
| `samasyaen` | समस्याएँ |

Spacebar commits the candidate + inserts a space in one go.

## Bhai, test karo!

Ye IME ready hai, lekin akela test karna mushkil hai.

Tu test kar, galti bata.

Kaise:
1. Install kar
2. Roz ke messages type kar
3. Jo galat aaye, GitHub issue kholo

Galti format:
```text
Input: jaan
Output: जाआँच
Expected: जान
Type: Informal
```

Chalo, duniya ko Hindi typing better banate hain! 🇮🇳

## Architecture

```
Input (Hinglish)
    ↓
Rule Engine
    ↓
Common Dict (730+)
    ↓
WordNet Hindi (40k+)
    ↓
Inflections (145k+)
    ↓
Fuzzy Match
    ↓
Google API (optional)
    ↓
Output (Devanagari)
```

## Google API (Optional)

The Google API fallback is **disabled by default**. The core system works fully offline without it.

⚠️ **Warning**: Uses an **UNOFFICIAL** Google endpoint. Not documented, not supported by Google. May break anytime.

### Enable via environment variable

```bash
export HINDI_IME_GOOGLE_API=1
```

### Enable via config file

```bash
mkdir -p ~/.config/hindi-ime
echo '{"google_api": true}' > ~/.config/hindi-ime/config.json
```

### Priority

Environment variable > Config file > Default (off)

## Data Sources

- Common high-frequency Hinglish vocabulary (curated)
- Hindi WordNet (IIT Bombay, GPL license)
- Conversational corpus (anonymized, aggregated)
- Academic & technical terms
- WhatsApp conversation corpus (anonymized)

## Project Structure

```
hindi-ime/
├── src/                Nim source code
│   ├── hindi_live_ime.nim
│   ├── hindi_predictive_keyboard.nim
│   ├── compile_rime_hindi.nim
│   ├── build_rime_dict.nim
│   └── google_transliterate_nim.nim
├── data/               Common dict + mappings
├── rime/               Rime schema files
├── scripts/            Install/build scripts
└── docs/               Additional docs
```

## Credits

- **Concept, direction, testing**: Ayush Singh
- **AI assistance**: Gemini (Google) + DeepSeek
- **Built with**: Nim, Rime, Fcitx5
- **Dictionary**: Hindi WordNet (IIT Bombay, GPL)
- **Inspiration**: Google Input Tools (2009-2018)

## License

GPL-3.0 — see [LICENSE](LICENSE)

Licensed under GPL-3.0 because dictionary data is derived from Hindi WordNet (IIT Bombay, GPL).

## Contributing

Pull requests welcome! Especially for:

- More common Hinglish words
- Regional variations
- Other Indic languages (Tamil, Telugu, Bengali)
- Bug fixes

Open an issue first for major changes.
