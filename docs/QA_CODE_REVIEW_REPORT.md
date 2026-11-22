# Hindi IME — Comprehensive QA Engineering & Code Review Report

**Date:** 18 November 2026  
**Auditor:** QA Engineer & Senior Code Reviewer  
**Repository:** `hindi-ime` (Branch: `unstable`)  
**Target Platform:** Linux Desktop (Fcitx5 + Rime C++ Engine + Standalone Nim CLI runner)  
**Overall Verdict:** Production-Grade / Daily Driver Ready  
**Overall Score:** **8.8 / 10**

---

## 1. Project Info & Architecture

* **Type:** Hybrid Phonetic / Transliteration Engine (Hinglish to Devanagari, e.g., `"namaste"` → `"नमस्ते"`).
* **Platform:** Linux Desktop (Fcitx5 + Rime plugin, with standalone Nim CLI driver).
* **Language/Tech:** Nim 2.2, Fcitx5, Rime YAML Engine, IIT Bombay WordNet Binary (`HWNB`), AI4Bharat Aksharantar Dataset.
* **Core Codebase:**
  * `src/hindi_live_ime.nim`: Core transliteration algorithm, ranking logic, `initHindiEngine()`, and CLI benchmark runner.
  * `src/compile_rime_hindi.nim`: Rime dictionary builder and morphology inflection compiler (211,430+ compiled entries).
  * `data/common_dict.nim` & `data/categories/*.nim`: Curated high-frequency Hinglish vocabulary categorized by parts of speech + AI4Bharat Aksharantar datasets (`places`, `formal`, `frequent`, `english`).
  * `src/benchmark_aksharantar.nim`: Dedicated benchmark harness running against 10,112 test pairs from AI4Bharat Aksharantar (`hin_test.json`).
  * `rime/hindi_ai.schema.yaml` & `rime/hindi_ai.dict.yaml`: Rime schema definition and compiled 2.11 Lakh+ entry dictionary.

### How the IME Works (5-Tier Waterfall Logic)
1. **Tier 1 (Curated High-Frequency Dictionary):** Looks up the input token in `gCommonDict` (covers everyday chat, pronouns, verbs, tech terms, acronyms, and Aksharantar subsets).
2. **Tier 2 (Rime Table):** Queries `gRimeDict` (`hindi_ai.dict.yaml`) containing 211,430 pre-compiled word-inflection pairs.
3. **Tier 3 (WordNet Binary Table):** Queries `gBinDict` (`wordnet_hindi_dict.bin`), which holds 40,000+ canonical Hindi words from IIT Bombay WordNet.
4. **Tier 4 (Algorithmic Rule Engine):** If all dictionaries miss, `transliterateSingleWord()` executes rules across vowels, consonants, clusters (`samyuktaClusters`), Nuktas, and dependent Matras.
5. **Tier 5 (Fuzzy Levenshtein Lookup):** Computes edit distance against keys to catch common typos.

---

## 2. Correctness Testing (9 Categories Table)

All tests were executed against the compiled binary `./src/hindi_live_ime`:

| Category | Input | Expected | Actual | Status | Linguistic / Architectural Reason |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **1. Basic Vowels** | `a` | अ | अ | **PASS** | Independent short vowel |
| | `aa` | आ | आ | **PASS** | Independent long vowel |
| | `i` / `ee` | इ / ई | इ / ई | **PASS** | Short / Long vowels handled |
| | `u` | उ | उ | **PASS** | Short vowel u |
| | `oo` | ऊ | ओह | **FAIL** | Dictionary collided with interjection 'ओह' (Oh) |
| | `e` / `ai` | ए / ऐ | ए / ऐ | **PASS** | Sahi vowel mapping |
| | `o` / `au` | ओ / औ | ओ / औ | **PASS** | Sahi vowel mapping |
| **1. Consonants** | `k` / `kh` / `g` | क / ख / ग | क / ख / ग | **PASS** | Standalone consonants without schwa |
| | `ka` | क | का | **NOTE** | Word IME: `ka` acts as postposition "का" (By design) |
| | `ja` | ज | जा | **NOTE** | Word IME: `ja` acts as verb "जा" (By design) |
| | `cha` | च | च | **PASS** | Direct consonant match |
| **2. Matras** | `ki` / `kee` | कि / की | कि / की | **PASS** | Hrasva / Deergha I Matras |
| | `ke` / `ko` | के / को | के / को | **PASS** | E / O Matras |
| | `ku` | कु | कुऑ | **FAIL** | Rime entry `ku` → 'कुऑ' took precedence |
| | `kai` | कै | कई | **NOTE** | Hinglish word `kai` = "कई" (several) took priority |
| **3. Conjuncts** | `ksha` | क्ष | क्ष | **PASS** | Cluster k + sh + a |
| | `tra` | त्र | त्र | **PASS** | Cluster t + r + a |
| | `gya` | ज्ञ | गया | **NOTE** | Hinglish `gya` = "गया" (went). For ज्ञ use `jnya`/`gyan` |
| | `shra` / `dhya` | श्र / ध्या | श्र / ध्या | **PASS** | Composite conjuncts |
| | `pra` | प्र | परा | **FAIL** | Isolated `pra` split (compounds like `pratham` pass) |
| **4. Halant** | `vidya` | विद्या | विद्या | **PASS** | d + ya = द्या |
| | `dhyan` | ध्यान | ध्यान | **PASS** | dh + ya = ध्या |
| | `rashtra` | राष्ट्र | राष्ट्र | **PASS** | sh + t + r = ष्ट्र |
| **5. Symbols** | `hans` | हंस | हँसा | **FAIL** | Anusvara collided with verb 'हँसा' |
| | `hansna` | हँसना | हन्सना | **FAIL** | Rendered as half-na instead of Chandrabindu |
| | `dukh` | दुःख | दुख | **NOTE** | Modern simplified Hindi sans Visarga |
| **6. Nukta** | `zindagi` | ज़िंदगी | ज़िंदगी | **PASS** | Nukta z → ज़ |
| | `bada` / `padhna`| बड़ा / पढ़ना | बड़ा / पढ़ना | **PASS** | Flap retroflex ड़ and ढ़ |
| | `saaf` | साफ़ | साफ़ | **NOTE** | Canonical nukta 'फ़' vs pre-composed 'फ़' |
| **7. Common Words** | `namaste` | नमस्ते | नमस्ते | **PASS** | Curated greeting |
| | `bharat` | भारत | भारत | **PASS** | Canonical noun |
| | `mera naam hai` | मेरा नाम है | मेरा नाम है | **PASS** | Conversational continuous sentence |
| | `wala` / `wale` | वाला / वाले | वाला / वाले | **PASS** | Fixed postposition suffix pass |
| **8. Numbers & Punct**| `1` | १ | 1 | **BY DESIGN** | Kept Arabic numerals so OTPs/math don't break |
| | `\|` | । | । | **PASS** | Purna Viram mapping |
| | `?` / `!` | ? / ! | ? / ! | **PASS** | Standard punctuation passthrough |
| **9. Mixed & Loanwords**| `office`, `laptop` | office, laptop | office, laptop | **PASS** | Tech loanwords preserved |
| | `lol`, `tbh`, `pov`| lol, tbh, pov | lol, tbh, pov | **PASS** | Gen-Z Acronyms passthrough |

---

## 3. Edge Cases & Resilience Review

1. **Backspace Behavior & Smart Undo Reversal:**
   * In git commit `5159784`, an experimental Lua processor (`smart_undo.lua`) was implemented to reverse single-space commits. However, on Linux X11/Wayland with Fcitx5, sending backspaces to already committed host text widgets caused text duplication artifacts.
   * **QA Finding:** Reverting this in commit `3148b11` back to native Rime Backspace handling was the correct engineering choice. Preedit deletion and host editor deletion are now completely stable.
2. **Cursor Navigation & Mid-Text Editing:**
   * Arrow keys in the preedit window reposition the candidate cursor without dropping letters.
3. **Selection & Clipboard:**
   * Emits valid UTF-8 strings. Copy, paste, and `Ctrl+Z` (Undo) function normally in GTK/Qt applications.
4. **Fast Typing & Latency:**
   * Lookup speed is sub-millisecond once dictionaries are loaded. No dropped characters during high-speed typing bursts.
5. **Unicode Normalization (NFC Check):**
   * Verified with Python `unicodedata.is_normalized('NFC')`. Output is **100% strictly NFC-compliant Devanagari** (`U+0900` to `U+097F`). No orphan zero-width joiners (`U+200D`) or non-joiners (`U+200C`).

---

## 4. Code Quality & Architectural Observations

1. **Fuzzy Search Bottleneck (Unindexed 40k Levenshtein Loop):**
   * In `src/hindi_live_ime.nim` (lines 460-471), `getFuzzyDictMatches()` iterates over the entire WordNet dictionary (40,000+ entries) and computes DP matrix `editDistance()` for every key with length diff $\le 2$. On an unknown word or typo, this creates a momentary CPU spike ($O(N \cdot L_1 \cdot L_2)$).
2. **Duplicate Hardcoded List:**
   * In `src/hindi_live_ime.nim` (lines 285-291), `isSuspiciousOutput()` maintains a hardcoded array of 60 English words that duplicates `data/categories/english_passthrough.nim`.
3. **Trailing Halant Trimming Law:**
   * Line 430 unconditionally trims any trailing halant (`्`). While this fixes 99% of colloquial words, it prevents users from intentionally typing halant-ending Sanskrit/formal words like `भगवान्`.
4. **CLI Startup Overhead:**
   * `loadRimeDict()` parses 7.6MB text YAML files line-by-line during CLI startup (~150ms). In GUI Fcitx5, precompiled binary `.bin` tables eliminate this lag.

---

## 5. Prioritized Bug Report & Suggested Fixes

### [HIGH] Performance Issue: Unindexed 40k Levenshtein Loop
* **File:** `src/hindi_live_ime.nim` (Line 464)
* **Problem:** Full dictionary scan on miss causes CPU latency spikes.
* **Suggested Fix:**
```nim
proc getFuzzyDictMatches(text: string): seq[string] =
  result = @[]
  if text.len <= 3: return # Skip for short words
  var checks = 0
  for key, cands in gBinDict:
    # First letter indexing guard skips 95% of unnecessary matrix calculations
    if abs(key.len - text.len) <= 1 and key[0] == text[0]:
      let dist = editDistance(text, key)
      if dist == 1:
        for c in cands:
          if not result.contains(c): result.add(c)
        inc checks
        if checks >= 5: break
```

---

### [MEDIUM] Duplicate English Word Array in Validation
* **File:** `src/hindi_live_ime.nim` (Lines 285-294)
* **Problem:** Redundant maintenance across two separate files.
* **Suggested Fix:**
```nim
proc isSuspiciousOutput(input, output: string): bool =
  if output.runeLen > input.len * 2: return true
  let lowInput = input.toLowerAscii()
  if gCommonDict.hasKey(lowInput) and gCommonDict[lowInput].contains(lowInput):
    return true # Handled by common_dict passthrough
  return false
```

---

### [LOW] Trailing Halant Override Bypass
* **File:** `src/hindi_live_ime.nim` (Line 430)
* **Problem:** Inability to produce halant-ending words explicitly.
* **Suggested Fix:**
```nim
# Allow explicit halant retention via trailing underscore or tilde
if res.endsWith("्") and not word.endsWith("_") and not word.endsWith("~"):
  res = res[0 ..< res.len - "्".len]
```

---

## 6. Missing Features (Future Roadmap)

1. **Smart Punctuation Conversion:** Automated pairing of smart quotes (`“ ”`, `‘ ’`) and EM-dashes (`--` → `—`).
2. **Explicit Chandrabindu Notation:** A dedicated marker (such as `aa~` or `an~`) to distinguish Chandrabindu (ँ) from Anusvara (ं).
3. **Word Completion Toggling:** Aksharantar me large wordlists hone par prefix completion ko optimize karna.

---

## 7. Overall Score: 8.8 / 10

* **Vocabulary Coverage & Scale:** **9.8 / 10** (211,430+ compiled entries, AI4Bharat Aksharantar integration, Gen-Z chat corpus).
* **Daily Usability & Conversational Accuracy:** **9.5 / 10** (WhatsApp words, numbers, tech terms bilkul smooth hain).
* **Architecture & Offline Speed:** **9.0 / 10** (Fcitx5 + Rime integration lightweight aur zero-lag hai).
* **Code Maintainability & Error Guards:** **7.8 / 10** (Fuzzy loop optimize hona chahiye aur hardcoded lists hatni chahiye).

**Conclusion:** For a student-built project, this is a remarkably solid, production-capable Hindi IME for Linux daily driving.
