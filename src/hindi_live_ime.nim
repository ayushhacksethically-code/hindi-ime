import std/[tables, strutils, json, streams, os, math, sequtils, sets, algorithm, unicode]
import ../data/common_dict

type
  PredictCandidate* = object
    hindi*: string
    score*: float

type Transform = tuple[`from`, `to`: string]

proc generateAsciiVariants*(input: string, maxVariants: int = 25): seq[string] =
  ## Romanized word (IAST/ITRANS with diacritics or capitals) ko
  ## multiple ASCII Hinglish spellings mein convert karta hai.
  ##
  ## Example:
  ##   "samasyā"  → ["samasya", "samasyaa", "samasy", "samasyā"]
  ##   "kartā"    → ["karta", "kartaa", "kart"]
  ##   "jñāna"    → ["gyan", "jnan", "gnan", "gyana", "dnyan", ...]
  ##   "śrī"      → ["shri", "sri", "shree", "shri"]
  
  result = @[]
  if input.len == 0: return
  
  var seen = initHashSet[string]()
  
  proc tryAdd(v: string) =
    let clean = v.strip().toLowerAscii()
    if clean.len > 0 and clean notin seen:
      seen.incl(clean)
      result.add(clean)
  
  # ============================================================
  # STAGE 1: Diacritics → ASCII doubles (IAST → ITRANS)
  # ============================================================
  var s = input
  # Long vowels
  s = s.replace("ā", "aa").replace("Ā", "aa")
  s = s.replace("ī", "ii").replace("Ī", "ii")
  s = s.replace("ū", "uu").replace("Ū", "uu")
  # Vocalic r/l
  s = s.replace("ṛ", "ri").replace("ṝ", "rii")
  s = s.replace("ḷ", "li").replace("ḹ", "lii")
  # Sibilants
  s = s.replace("ś", "sh").replace("Ś", "sh")
  s = s.replace("ṣ", "sh").replace("Ṣ", "sh")
  # Nasals
  s = s.replace("ñ", "n").replace("Ñ", "n")
  s = s.replace("ṅ", "ng").replace("Ṅ", "ng")
  s = s.replace("ṇ", "n").replace("Ṇ", "n")
  s = s.replace("ṃ", "n").replace("Ṃ", "n")
  s = s.replace("ṁ", "n").replace("Ṁ", "n")
  # Retroflex
  s = s.replace("ṭ", "t").replace("Ṭ", "t")
  s = s.replace("ḍ", "d").replace("Ḍ", "d")
  # Visarga
  s = s.replace("ḥ", "h").replace("Ḥ", "h")
  
  # ============================================================
  # STAGE 2: ITRANS capitals → doubles
  # ============================================================
  s = s.replace("A", "aa")
  s = s.replace("I", "ii")
  s = s.replace("U", "uu")
  s = s.replace("R", "ri")
  s = s.replace("M", "n")
  s = s.replace("H", "h")
  s = s.replace("T", "t")
  s = s.replace("D", "d")
  s = s.replace("N", "n")
  s = s.replace("S", "sh")
  s = s.toLowerAscii()
  
  tryAdd(s)  # primary variant derived from input
  
  # ============================================================
  # STAGE 3: Cluster-level transforms
  # ============================================================
  let clusterTransforms: seq[Transform] = @[
    # jñ variants (jñāna → gyan, jnan, gnan, dnyan)
    ("jñ", "gy"), ("jñ", "jn"), ("jñ", "gn"), ("jñ", "dny"),
    # kṣ variants (kṣetra → kshetra, xetra)
    ("kṣ", "ksh"), ("kṣ", "x"), ("kṣ", "chh"), ("kṣ", "ks"),
    # śr variants (śrī → shri, sri, shree)
    ("śr", "shr"), ("śr", "sr"),
    ("shr", "shri"), ("shr", "sri"), ("shr", "shree"),
    # tr, pr, br, etc
    ("tra", "tra"), ("pra", "pra"),
  ]
  
  var variants: seq[string] = @[s]
  for (fromStr, toStr) in clusterTransforms:
    let v = s.replace(fromStr, toStr)
    if v != s:
      variants.add(v)
      tryAdd(v)
    if result.len >= maxVariants: return
  
  # ============================================================
  # STAGE 4: Vowel simplifications
  # ============================================================
  let vowelTransforms: seq[Transform] = @[
    ("aa", "a"),   # samasyaa → samasya
    ("ii", "i"),   # kariib  → karib
    ("uu", "u"),   # duur    → dur
    ("ee", "i"),   # kareeb  → karib
    ("oo", "u"),   # doodh   → dudh
    ("ai", "ei"),  # bhai    → bhei (rare)
    ("au", "ou"),  # aur     → our
  ]
  
  var baseVariants = variants
  for base in baseVariants:
    for (fromStr, toStr) in vowelTransforms:
      let v = base.replace(fromStr, toStr)
      if v != base:
        tryAdd(v)
        if result.len >= maxVariants: return
  
  # ============================================================
  # STAGE 5: Consonant simplifications (Hinglish shortcuts)
  # ============================================================
  let consonantTransforms: seq[Transform] = @[
    ("ph", "f"),   # phone  → fone
    ("bh", "b"),   # bhai   → bai
    ("dh", "d"),   # dhan   → dan
    ("gh", "g"),   # ghar   → gar
    ("jh", "j"),   # jhanda → janda
    ("kh", "k"),   # khana  → kana
    ("th", "t"),   # thoda  → toda
    ("ch", "c"),   # chai   → cai
    ("sh", "s"),   # shri   → sri
    ("v", "w"),    # van    → wan
    ("w", "v"),    # wan    → van
    ("z", "j"),    # zindagi → jindagi
    ("q", "k"),    # qalam  → kalam
    ("x", "ks"),   # taxi   → taksi
  ]
  
  baseVariants = result
  for base in baseVariants:
    for (fromStr, toStr) in consonantTransforms:
      let v = base.replace(fromStr, toStr)
      if v != base:
        tryAdd(v)
        if result.len >= maxVariants: return
  
  # ============================================================
  # STAGE 6: Schwa deletion at end
  # ============================================================
  baseVariants = result
  for base in baseVariants:
    if base.len > 3 and base[^1] == 'a':
      tryAdd(base[0 ..< base.len - 1])
      if result.len >= maxVariants: return
  
  # ============================================================
  # STAGE 7: Hinglish suffix tweaks
  # ============================================================
  baseVariants = result
  for base in baseVariants:
    if base.endsWith("y") and base.len > 3:
      tryAdd(base[0 ..< base.len - 1] & "i")
    if base.endsWith("i") and base.len > 3:
      tryAdd(base[0 ..< base.len - 1] & "y")
    if base.endsWith("an") and base.len > 3:
      tryAdd(base & "g")
    if result.len >= maxVariants: return
  
  # ============================================================
  # STAGE 8: Sort — short/simple first (better matches likely)
  # ============================================================
  if result.len > 1:
    let first = result[0]
    var rest = result[1 .. ^1]
    rest.sort(proc(a, b: string): int = cmp(a.len, b.len))
    result = @[first] & rest
  
  return result

# Combined Phonetic Mappings: ISO 15919 + User Custom Keybindings + ITRANS / IAST / Harvard-Kyoto
const
  customNuktaConsonants = [
    ("NnN", "ऩ्"), ("LlL", "ऴ्"), ("DdD", "ड़्"), ("RrR", "ढ़्"), ("gG", "ग़्"), ("qh", "ख़्"),
    ("qa", "क़"), ("q", "क़्"), ("za", "ज़"), ("z", "ज़्"), ("fa", "फ़"), ("f", "फ़्"),
    ("Y", "य़्"), ("R", "ऱ्"), ("L", "ळ्"),
    ("_kh", "ख़"), (".g", "ग़"), (".dha", "ढ़"), (".da", "ड़"), ("_n", "ऩ"), ("_r", "ऱ"), ("_l", "ऴ"), (".l", "ळ"), (";y", "य़"), ("^z", "झ़")
  ]

  specialSymbols = [
    ("AOM", "ॐ"), ("||", "॥"), ("|", "।"), ("AO", "ँ"), ("aA", "ऽ"), ("M", "ं"), (".n", "ं"), (".m", "ं"), ("~m", "ँ"), ("H", "ः"), (":", "ः")
  ]

  samyuktaClusters = [
    ("kSha", "क्ष"), ("ksha", "क्ष"), ("kSa", "क्ष"), ("xa", "क्ष"),
    ("tra", "त्र"), ("GYa", "ज्ञ"), ("gya", "ज्ञ"), ("j~na", "ज्ञ"), ("jnya", "ज्ञ"), ("jJa", "ज्ञ"),
    ("shra", "श्र"), ("zra", "श्र")
  ]

  # English / Hybrid Consonant Clusters (e.g. gr -> ग्र, dr -> द्र, tr -> त्र, pr -> प्र, br -> ब्र, fr -> फ्र, cr -> क्र)
  englishClusters = [
    ("gr", "ग्र्"), ("dr", "द्र्"), ("pr", "प्र्"), ("br", "ब्र्"), ("fr", "फ्र्"), ("cr", "क्र्"), ("tr", "त्र्"),
    ("st", "स्त्"), ("sp", "स्प्"), ("sk", "स्क्"), ("sm", "स्म्"), ("sn", "स्न्"), ("sl", "स्ल्"), ("sw", "स्व्")
  ]

  consonantClusters = [
    ("Ch", "छ्"), ("ch", "च्"), ("kh", "ख्"), ("gh", "घ्"), ("jh", "झ्"), ("nY", "ञ्"),
    ("Th", "थ्"), ("Dh", "ध्"), ("ph", "फ्"), ("Bh", "भ्"), ("bh", "भ्"), ("B", "भ्"),
    ("sh", "श्"), ("Sh", "ष्"), ("G", "ङ्"), ("t", "ट्"), ("T", "ठ्"), ("d", "ड्"), ("D", "ढ्"),
    ("N", "ण्"), ("th", "त्"), ("dh", "द्"), ("n", "न्"), ("p", "प्"), ("b", "ब्"), ("m", "म्"),
    ("y", "य्"), ("r", "र्"), ("l", "ल्"), ("v", "व्"), ("w", "व्"), ("s", "स्"), ("h", "ह्"),
    ("k", "क्"), ("g", "ग्"), ("j", "ज्")
  ]

  independentVowels = [
    ("AOM", "ॐ"), ("AO", "ऑ"), ("Ao", "ऑ"), ("En", "ऍ"), ("tR", "ऋ"), ("TR", "ॠ"),
    ("aa", "आ"), ("A", "आ"), ("ee", "ई"), ("I", "ई"), ("oo", "ऊ"), ("U", "ऊ"),
    ("ai", "ऐ"), ("au", "औ"), ("a", "अ"), ("i", "इ"), ("u", "उ"), ("e", "ए"), ("o", "ओ"),
    ("^e", "ऍ"), ("^o", "ऑ"), (",r", "ऋ"), (",rr", "ॠ"), (",l", "ऌ"), (",ll", "ॡ")
  ]

  dependentMatras = [
    ("Ao", "ॉ"), ("En", "ॅ"), ("aa", "ा"), ("A", "ा"), ("ee", "ी"), ("I", "ी"),
    ("oo", "ू"), ("U", "ू"), ("tR", "ृ"), ("TR", "ॄ"), ("ai", "ै"), ("au", "ौ"),
    ("a", ""), ("i", "ि"), ("u", "ु"), ("e", "े"), ("o", "ो"),
    ("^e", "ॅ"), ("^o", "ॉ"), (",r", "ृ"), (",rr", "ॄ"), (",l", "ॢ"), (",ll", "ॣ")
  ]

proc editDistance*(s1, s2: string): int =
  let m = s1.len
  let n = s2.len
  var dp = newSeqWith(m + 1, newSeq[int](n + 1))

  for i in 0 .. m: dp[i][0] = i
  for j in 0 .. n: dp[0][j] = j

  for i in 1 .. m:
    for j in 1 .. n:
      if s1[i - 1] == s2[j - 1]:
        dp[i][j] = dp[i - 1][j - 1]
      else:
        dp[i][j] = 1 + min(dp[i - 1][j], min(dp[i][j - 1], dp[i - 1][j - 1]))

  return dp[m][n]

proc loadWordNetBinaryDict*(binPath: string): Table[string, seq[string]] =
  result = initTable[string, seq[string]]()
  if not fileExists(binPath): return

  var fs = newFileStream(binPath, fmRead)
  if fs.isNil: return

  let magic = fs.readStr(4)
  if magic != "HWNB":
    fs.close()
    return

  let entryCount = fs.readUint32()
  for _ in 0 ..< entryCount:
    if fs.atEnd(): break
    let keyLen = fs.readUint16().int
    let key = fs.readStr(keyLen)
    let candCount = fs.readUint16().int
    var cands: seq[string] = @[]
    for _ in 0 ..< candCount:
      let candLen = fs.readUint16().int
      cands.add(fs.readStr(candLen))
    result[key] = cands

  fs.close()

proc isSuspiciousOutput(input, output: string): bool =
  # 1. Output is too long compared to input
  if output.runeLen > input.len * 2:
    return true
  # 2. Too many matras (vowel signs) in output
  const matras = ["ा", "ि", "ी", "ु", "ू", "े", "ै", "ो", "ौ", "ं", "ँ", "ृ", "ॄ"]
  var matraCount = 0
  for m in matras:
    matraCount += output.count(m)
  if matraCount > input.len:
    return true
  # 3. Input is a common English word (list from Step 2)
  const englishWords = ["office","school","college","whatsapp","instagram","facebook",
    "google","youtube","mobile","laptop","computer","internet","email","password","login",
    "logout","file","folder","photo","video","audio","music","movie","game","time","date",
    "year","month","week","day","hour","minute","second","number","address","phone","name",
    "city","country","india","delhi","mumbai","bangalore","chennai","kolkata","hyderabad",
    "pune","ahmedabad","jaipur","lucknow","patna","bhopal","indore","kanpur","nagpur","surat",
    "vadodara","rajkot","noida","gurgaon","ghaziabad","faridabad"]
  if input.toLowerAscii() in englishWords:
    return true
  return false

# Complete Comprehensive Algorithmic Transliteration Engine
proc transliterateSingleWord*(word: string): string =
  var res = ""
  var i = 0
  let w = word.strip()
  if w.len == 0: return ""

  while i < w.len:
    # 1. Independent Vowels at Start
    if i == 0:
      var matchedIndep = false
      for (vStr, vVal) in independentVowels:
        if i + vStr.len <= w.len and w[i ..< i + vStr.len] == vStr:
          res.add(vVal)
          i += vStr.len
          matchedIndep = true
          break
      if matchedIndep: continue

    # 2. Special Symbols & Punctuation
    var matchedSymbol = false
    for (sStr, sVal) in specialSymbols:
      if i + sStr.len <= w.len and w[i ..< i + sStr.len] == sStr:
        res.add(sVal)
        i += sStr.len
        matchedSymbol = true
        break
    if matchedSymbol: continue

    # 3. Custom Nukta Consonants
    var matchedNukta = false
    for (nStr, nVal) in customNuktaConsonants:
      if i + nStr.len <= w.len and w[i ..< i + nStr.len] == nStr:
        res.add(nVal)
        i += nStr.len
        matchedNukta = true
        break
    if matchedNukta: continue

    # 4. Samyuktaksar
    var matchedSamyukta = false
    for (sStr, sVal) in samyuktaClusters:
      if i + sStr.len <= w.len and w[i ..< i + sStr.len] == sStr:
        res.add(sVal)
        i += sStr.len
        matchedSamyukta = true
        break
    if matchedSamyukta: continue

    # 5. English Hybrid Consonant Clusters (gr, dr, pr, br, fr, cr, st, sp, sk, sm, sn, sl, sw)
    var matchedEngCluster = false
    for (eStr, eVal) in englishClusters:
      if i + eStr.len <= w.len and w[i ..< i + eStr.len] == eStr:
        var hasVowelNext = false
        if i + eStr.len < w.len:
          for (mStr, mVal) in dependentMatras:
            if i + eStr.len + mStr.len <= w.len and w[i + eStr.len ..< i + eStr.len + mStr.len] == mStr:
              hasVowelNext = true
              break
        if hasVowelNext:
          let cleanVal = eVal.replace("्", "")
          res.add(cleanVal)
        else:
          res.add(eVal)

        i += eStr.len
        matchedEngCluster = true
        break
    if matchedEngCluster: continue

    # 6. Standard Consonants & Clusters
    var matchedCons = false
    for (cStr, cVal) in consonantClusters:
      if i + cStr.len <= w.len and w[i ..< i + cStr.len] == cStr:
        var hasVowelNext = false
        if i + cStr.len < w.len:
          for (mStr, mVal) in dependentMatras:
            if i + cStr.len + mStr.len <= w.len and w[i + cStr.len ..< i + cStr.len + mStr.len] == mStr:
              hasVowelNext = true
              break
        if hasVowelNext:
          let cleanVal = cVal.replace("्", "")
          res.add(cleanVal)
        else:
          res.add(cVal)

        i += cStr.len
        matchedCons = true
        break
    if matchedCons: continue

    # 7. Dependent Matras
    if res.len > 0:
      var matchedMatra = false
      for (mStr, mVal) in dependentMatras:
        if i + mStr.len <= w.len and w[i ..< i + mStr.len] == mStr:
          res.add(mVal)
          i += mStr.len
          matchedMatra = true
          break
      if matchedMatra: continue

    let c = w[i]
    res.add($c)
    i += 1

  if isSuspiciousOutput(word, res):
    return word # return original English

  return res

var gBinDict: Table[string, seq[string]]
var gCommonDict: Table[string, seq[string]]

proc getFuzzyDictMatches(text: string): seq[string] =
  result = @[]
  if text.len <= 2: return

  for key, cands in gBinDict:
    if abs(key.len - text.len) <= 2:
      let dist = editDistance(text, key)
      if dist == 1 or (text.len > 5 and dist == 2):
        for c in cands:
          if not result.contains(c):
            result.add(c)
            if result.len >= 3: return

proc getPhoneticCandidates*(text: string): seq[string] =
  result = @[]
  let w = text.strip()
  if w.len == 0: return @[]
  let wLower = w.toLowerAscii()

  if gCommonDict.hasKey(wLower):
    for item in gCommonDict[wLower]:
      if not result.contains(item): result.add(item)

  if gBinDict.hasKey(wLower):
    for item in gBinDict[wLower]:
      if not result.contains(item): result.add(item)

  let algoResult = transliterateSingleWord(w)
  if algoResult.len > 0 and not result.contains(algoResult):
    result.add(algoResult)

  let fuzzyMatches = getFuzzyDictMatches(wLower)
  for item in fuzzyMatches:
    if not result.contains(item): result.add(item)

proc processPhoneticWord*(text: string): string =
  let candidates = getPhoneticCandidates(text)
  if candidates.len > 0:
    return candidates[0]
  return text

proc getDataDir*(): string =
  let base = getEnv("XDG_DATA_HOME", getEnv("HOME") / ".local/share")
  let dir = base / "hindi-ime"
  createDir(dir)
  return dir

proc getCacheDir*(): string =
  let base = getEnv("XDG_CACHE_HOME", getEnv("HOME") / ".cache")
  let dir = base / "hindi-ime"
  createDir(dir)
  return dir

when isMainModule:
  var binPath = getDataDir() / "wordnet_hindi_dict.bin"
  if not fileExists(binPath):
    binPath = getAppDir() / "wordnet_hindi_dict.bin"
  gBinDict = loadWordNetBinaryDict(binPath)
  gCommonDict = getCommonDict()
  let params = commandLineParams()
  if params.len > 0:
    let inputStr = params.join(" ")
    let candidates = getPhoneticCandidates(inputStr)
    if candidates.len > 0:
      var formatted: seq[string] = @[]
      for idx, cand in candidates[0 ..< min(5, candidates.len)]:
        formatted.add($(idx + 1) & ". " & cand)
      echo formatted.join("  ")
    else:
      echo inputStr
  else:
    echo "Usage: hindi_live_ime <phonetic_word>"
