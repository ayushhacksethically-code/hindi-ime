# Hindi IME — Hinglish to Devanagari

A fast, offline-first Hinglish → Devanagari transliteration system for Linux, built on Nim + Fcitx5 + Rime.

## Why This Exists

- **Google Input Tools for Windows is dead** (discontinued 2018)
- Existing Linux IMEs don't understand **real Hinglish** (`samasya`, `nhi`, `aaplog`, `vaishe`) — they expect formal transliteration (`samasyA`, `nahI`)
- Linux IME ecosystem is fragmented and complex

This project fills that gap.

## Features

- ✅ **Natural Hinglish input** — not formal transliteration
- ✅ **Offline-first** — works without internet
- ✅ **Zero-latency** — rule engine, no background daemon
- ✅ **Hybrid intelligence** — rules → dict → fuzzy → API
- ✅ **730+ curated words** + Hindi WordNet (40k+ entries)
- ✅ **Multi-language ready** — architecture supports Tamil, Telugu, Bengali
- ✅ **Rime + Fcitx5 integration**
- ✅ **Optional Google API fallback** (runtime config, OFF by default)

## Demo

![Demo](docs/demo.gif)

*(Demo GIF coming soon — replace this line with a real demo)*

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

The repository includes a pre-generated Rime dictionary (`rime/hindi_ai.dict.yaml`, ~2.6 MB) covering 40,000+ words derived from Hindi WordNet (IIT Bombay, GPL) plus curated Hinglish vocabulary.

For **regenerating** from source, place `wordnet_hindi_dict.bin` (6 MB) in `~/.local/share/hindi-ime/` and run:

```bash
./scripts/build_dict.sh
```

Run `./scripts/fetch_wordnet.sh` for setup instructions.

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

Spacebar commits the candidate + inserts a space in one go.

## Architecture

```
Input (Hinglish)
    ↓
┌─────────────────────────┐
│  Rule Engine            │  ← phonetic rules
│  transliterateSingleWord│
└─────────────────────────┘
    ↓ (no match)
┌─────────────────────────┐
│  Common Dict (730+)     │  ← curated Hinglish
└─────────────────────────┘
    ↓ (no match)
┌─────────────────────────┐
│  WordNet Hindi (40k+)   │  ← HWNB binary
└─────────────────────────┘
    ↓ (no match)
┌─────────────────────────┐
│  Fuzzy Match            │  ← edit distance
└─────────────────────────┘
    ↓ (no match)
┌─────────────────────────┐
│  Google API (optional)  │  ← runtime config
└─────────────────────────┘
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
- **AI assistance**: Claude
- **Built with**: Nim, Rime, Fcitx5
- **Dictionary**: Hindi WordNet (IIT Bombay, GPL)
- **Inspiration**: Google Input Tools (2009-2018)

## License

MIT — see [LICENSE](LICENSE)

## Contributing

Pull requests welcome! Especially for:

- More common Hinglish words
- Regional variations
- Other Indic languages (Tamil, Telugu, Bengali)
- Bug fixes

Open an issue first for major changes.
