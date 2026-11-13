# Bhai, contribute kar — Hindi IME better banate hain!

## How to test your changes safely

You do NOT need to install the IME system-wide to test. Use the sandbox
mode:

1. **Transliteration logic only (no system changes):**
   ```bash
   nim c -r src/hindi_live_ime.nim --test "bhai"
   ```
   This runs the rule engine in isolation and prints candidate outputs.

2. **Rime schema test (no fcitx5 install):**
   ```bash
   rime_dict_manager -s rime/ --test
   ```

3. **Full IME test (reversible):**
   ```bash
   bash install.sh --dry-run   # shows what will be touched
   bash install.sh             # installs; uninstall.sh reverts
   ```
   Always keep `uninstall.sh` handy. If anything breaks, run:
   ```bash
   bash uninstall.sh && rm -rf ~/.config/fcitx5/rime/
   ```

4. **Benchmark before submitting a PR:**
   Run both benchmarks before submitting a PR:
   ```bash
   nim c -r src/hindi_live_ime.nim --benchmark accuracy_test_general.txt
   nim c -r src/hindi_live_ime.nim --benchmark accuracy_test_specialized.txt
   ```
   General benchmark must stay at 100/100. Specialized benchmark coverage
   should not regress. Paste the output in your PR description.

## Kya kar sakta hai?

### 1. Galti bata

Sabse aasan kaam. Jo galat aaye, GitHub issue kholo.

Format:
```text
Input: jaan
Output: जाआँच
Expected: जान
Type: Informal
```

### 2. Word add kar

Tere area ke words add kar. Jaise:

```nim
result["jaan"] = @["जान"]
result["kasam"] = @["कसम"]
```

`data/categories/` ke relevant file (jaise `misc.nim` ya `prefix_words.nim`) mein daal, phir:
```bash
./scripts/build_dict.sh
fcitx5 -r -d
```

Test kar, phir PR bhej.

### 3. Code improve kar

Rule engine better kar, naye features add kar.

### 4. Document kar

README better kar, examples add kar.

## Kaise PR bheje?

1. Fork kar
2. Branch bana: `git checkout -b feature/mere-changes`
3. Changes kar
4. Commit: `git commit -m "dict: add 50 naye words"`
5. Push: `git push origin feature/mere-changes`
6. PR kholo

## Rules

- Friendly raho. Sab naye hain.
- Test karo — PR se pehle.
- Chhote changes karo — ek PR, ek kaam.
- Explain karo — kya kiya, kyun kiya.

## Kya nahi karna

- Force mat karo — kisi ko kuch thopna nahi.
- Galti mat dhundho — help karo.
- Language mat judge karo — formal, informal, sab theek.

---

Bhai, chalo milkar Hindi typing better banate hain! 🇮🇳

---

## Content Policy

This IME includes common Hindi/Hinglish expletives as part of the 
language. These are included for legitimate use cases:

- Songwriting, poetry, rap
- Creative writing
- Realistic dialogue in scripts

We treat these as vocabulary, not as offensive content. They have 
the same status as any other word in the dictionary.

**However, we do NOT include:**

- Casteist slurs
- Communal/religious slurs
- Hate speech targeting any group

If you're unsure whether a word qualifies, open an issue before 
submitting a PR.

If you find that a word you need is missing, please open an issue 
with:
- The Hinglish spelling(s) you type
- The Devanagari form you expect
- The context in which you use it

---
