import std/[strutils, tables]

# IAST → Hinglish conversion rules
const
  overridePairs = [
    # Multi-word & full-word overrides
    ("saṃskṛta", "sanskrit"),
    ("saṃskṛ", "sanskrit"),
    ("jñāna", "gyan"),
    ("jñā", "gya"),
    ("jñ", "gy"),
    ("kṣetra", "kshetra"),
    ("kṣ", "ksh"),
    ("śrīm", "shrim"),
    ("śrī", "shri"),
    ("rāma", "ram"),
    ("karma", "karm"),
    ("dharma", "dharm"),
    ("nāma", "naam"),
    ("kāma", "kaam"),
    ("rājā", "raja"),
    ("putra", "putra"),
    ("putr", "putr"),
    ("gṛha", "griha"),
    ("gṛh", "grih"),
    ("ṅg", "ng"),
  ]

  diacriticPairs = [
    ("ā", "a"), ("Ā", "A"),
    ("ī", "i"), ("Ī", "I"),
    ("ū", "u"), ("Ū", "U"),
    ("ṝ", "ri"), ("ṛ", "ri"),
    ("ḹ", "li"), ("ḷ", "li"),
    ("ś", "sh"), ("Ś", "Sh"),
    ("ṣ", "sh"), ("Ṣ", "Sh"),
    ("ñ", "n"), ("Ñ", "N"),
    ("ṅ", "ng"), ("Ṅ", "Ng"),
    ("ṇ", "n"), ("Ṇ", "N"),
    ("ṃ", "n"), ("Ṃ", "N"),
    ("ṁ", "n"), ("Ṁ", "N"),
    ("ṭ", "t"), ("Ṭ", "T"),
    ("ḍ", "d"), ("Ḍ", "D"),
    ("ḥ", "h"), ("Ḥ", "H"),
  ]

let
  overrides* = overridePairs.toTable
  diacritics* = diacriticPairs.toTable

proc applyOverrides*(s: string): string =
  result = s
  for (k, v) in overridePairs:
    result = result.replace(k, v)

proc applyDiacritics*(s: string): string =
  result = s
  for (k, v) in diacriticPairs:
    result = result.replace(k, v)

proc iastToHinglish*(s: string): string =
  var work = s
  # 1. Apply overrides first (special cases)
  work = applyOverrides(work)
  # 2. Apply diacritic mapping
  work = applyDiacritics(work)
  # 3. Lowercase
  work = work.toLowerAscii()
  return work

when isMainModule:
  # Test cases
  let tests = [
    "samasyā", "kartā", "jñāna", "śrī", "saṃskṛta",
    "rāma", "karma", "dharma", "nāma", "kāma",
    "rājā", "vidyālaya", "ardhāṅginī", "krishnāya",
    "namah", "dīrghaśmaśrujaṭāya", "pradhānmantrī",
    "āyurveda", "gaṇita", "vijñāna", "itihāsa"
  ]
  for t in tests:
    echo t, " → ", iastToHinglish(t)
