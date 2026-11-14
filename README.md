# Hindi IME — Hinglish to Devanagari

A fast, offline-first Hinglish → Devanagari transliteration system for Linux, built on Nim + Fcitx5 + Rime.

## Why This Exists

Linux में वो चीज़ नहीं मिल रही थी जो चीज़ मुझे चाहिए थी। जोकि मैं एक WhatsApp उपयोगकर्ता हूँ, इसलिए मैं Hinglish में लिखा करता था — परन्तु सोचा कि चलो हिन्दी देवनागरी में लिख लेते। नोट्स तो जैसा मैंने MS Word में feel किया था वैसा नहीं रहा, क्यूँकि यहाँ readymade ibus etc. के नियम strict थे — या भले न हों — परन्तु लिखने में flow टूट रहा था। इसलिए मैंने ये तैयार किया, AI के सहारे।

## Features

- ✅ **Natural Hinglish input** — not formal transliteration
- ✅ **Offline-first** — works without internet
- ✅ **No background daemon** — rule engine runs inline. Dictionary lookup is near-instant.
- ✅ **Hybrid intelligence** — rules → dict → fuzzy → API
- ✅ **197,662 entries** (88,600+ unique words)
- ✅ **100/100 on our internal daily-use test set** (see accuracy_test_general.txt)
- ✅ **2,700+ curated Hinglish words**
- ✅ **Hindi WordNet** (40k+ entries)
- ✅ **Architecture is language-agnostic** — Currently ships Hindi only.
- ✅ **Rime + Fcitx5 integration**
- ✅ **Optional Google API fallback** (runtime config, OFF by default)

## Recent Updates

- **Additional Vocabulary**: 40+ curated words across conversational phrases and terms (`assignment`, `pyq`, `datesheet`, `submit`, `aagya`, `chaiye`, `dedo`, `krege`, `skta`)
- **Conversational Chat Corpus**: 420+ curated chat words across slang (`gc`, `dm`, `kalesh`), verbs (`kr`, `rha`, `gya`, `bta`), pronouns, reactions, and loanwords
- **Curated Prefix Words**: 180+ words with prefixes (`be-`, `sam-`, `vi-`, `nir-`, `pra-`, `su-`, `up-`, `bad-`, `na-`, `khush-`)
- **Trailing Halant Cleanup**: Rule engine automatically trims dangling halant (`्`) for consonant-ending words
- **197,662 entries** (88,600+ unique words)
- **100/100 on our internal daily-use test set** (see accuracy_test_general.txt)
- WhatsApp conversation words (200+)
- Ordinal numbers 1-100
- Question words (koun, kaha, kaise)
- Matra handling fix (pyari, karti, gadiyan)
- Smart English passthrough (office, whatsapp)
- User choice respected (no forced defaults)

## Project Stats

![Started](https://img.shields.io/github/created-at/ayushhacksethically-code/hindi-ime?style=flat-square&label=Project%20Started&color=blue)
![Latest Release](https://img.shields.io/github/v/release/ayushhacksethically-code/hindi-ime?style=flat-square&label=Latest%20Release&color=green)
![Commits](https://img.shields.io/github/commit-activity/t/ayushhacksethically-code/hindi-ime?style=flat-square&label=Commits)
![Stars](https://img.shields.io/github/stars/ayushhacksethically-code/hindi-ime?style=flat-square&label=Stars)

- **Dictionary entries**: 197,662
- **Unique words**: 88,643
- **Accuracy:** 100/100 on our general daily-use benchmark (`accuracy_test_general.txt`). Specialized vocabulary — slang, expletives, technical terms — is tested separately in `accuracy_test_specialized.txt` (coverage: 103/115).
- **Dictionary file**: 6.8 MB
- **Source code**: ~9.5 MB
- **Full clone (with history)**: ~40 MB

## Install

No need to install Nim or compile anything.

### Recommended: Inspect before running

```bash
# Step 1: Download the installer
curl -fsSL https://raw.githubusercontent.com/ayushhacksethically-code/hindi-ime/main/install.sh -o install.sh

# Step 2: Inspect it (recommended)
less install.sh

# Step 3: Run it
bash install.sh
```

> ⚠️ **Security note:** Always inspect install scripts before running them. Never pipe `curl` directly to `bash`.

<details>
<summary>Quick install (not recommended)</summary>

```bash
curl -fsSL https://raw.githubusercontent.com/ayushhacksethically-code/hindi-ime/main/install.sh | bash
```

</details>

Then, select **Rime** in Fcitx5 and press F4 to select the **hindi_ai** schema.

## Quick Start (Manual / Developer)

### Prerequisites

- Fcitx5 with Rime
- Linux (X11 or Wayland)
- Nim 2.0+ (optional, only needed for compiling from source)

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

## How to Update

If you installed via the one-line script, just run the same command again:
```bash
curl -fsSL https://raw.githubusercontent.com/ayushhacksethically-code/hindi-ime/main/scripts/install.sh | bash
```

If you cloned the repository, just run:
```bash
cd hindi-ime
./scripts/update.sh
```

Both methods will update the dictionary and schema while preserving your Rime user learning data (`hindi_ai.userdb`).

### Dictionary Coverage

The repository includes a pre-generated Rime dictionary (`rime/hindi_ai.dict.yaml`, 6.8 MB) covering 197,662 entries (88,600+ unique words) derived from Hindi WordNet (IIT Bombay, GPL) plus curated Hinglish vocabulary.

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
| `koun` | कौन |
| `pyari` | प्यारी |
| `office` | office |
| `hlo` | हैलो |
| `bekhabar` | बेख़बर |
| `samvaad` | संवाद |
| `nirmaan` | निर्माण |
| `chaturbhuj` | चतुर्भुज |
| `samasyaen` | समस्याएँ |

Spacebar commits the candidate + inserts a space in one go.

## Bhai, test karo!

यह IME ready हैं परन्तु अकेले से पता नही चलेगा मुझे इसलिए आप टेस्ट कीजिये जो गलती दिखे issue कीजिये|

कैसे:
1. Install कीजिये|
2. रोज के मैसेज को type कीजिये|
3. जो गलत आये Github issue खोल के भेजीये|

गलती format:
```text
Input: jaan
Output: जाआँच
Expected: जान
Type: Informal
```

## Architecture

```
Input (Hinglish)
    ↓
Rule Engine
    ↓
Common Dict 
    ↓
WordNet Hindi (40k+)
    ↓
Inflections 
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
│   ├── categories/     Modular dictionaries (pronouns, verbs, prefix_words, etc.)
│   └── common_dict.nim Unified dictionary loader
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
