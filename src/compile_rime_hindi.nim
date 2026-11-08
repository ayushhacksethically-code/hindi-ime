import std/[tables, strutils, json, streams, os, math, unicode]
import inflect_hindi
import ../data/common_dict

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
    ("shra", "श्र"), ("zra", "श्र"),
    ("pya", "प्या"), ("kya", "क्या"), ("dhya", "ध्या"), ("tya", "त्या"), ("nya", "न्या"), ("vya", "व्या"), ("bya", "ब्या")
  ]

  englishClusters = [
    ("gr", "ग्र्"), ("dr", "द्र्"), ("pr", "प्र्"), ("br", "ब्र्"), ("fr", "फ्र्"), ("cr", "क्र्"), ("tr", "त्र्"),
    ("st", "स्त्"), ("sp", "स्प्"), ("sk", "स्क्"), ("sm", "स्म्"), ("sn", "स्न्"), ("sl", "स्ल्"), ("sw", "स्व्")
  ]

  consonantClusters = [
    ("chh", "छ्"), ("Ch", "छ्"), ("ch", "च्"), ("kh", "ख्"), ("gh", "घ्"), ("jh", "झ्"), ("nY", "ञ्"),
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

proc loadWordNetBinaryDict(binPath: string): Table[string, seq[string]] =
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

proc getLastRune(s: string): Rune =
  if s.len == 0: return Rune(0)
  var pos = s.len - 1
  while pos > 0 and (s[pos].ord and 0xC0) == 0x80:
    dec pos
  return s.runeAt(pos)

proc isDevanagariConsonant(r: Rune): bool =
  let code = r.int
  return (code >= 0x0915 and code <= 0x0939) or (code >= 0x0958 and code <= 0x095F)

proc transliterateSingleWord*(word: string): string =
  var res = ""
  var i = 0
  let w = word.strip()
  if w.len == 0: return ""

  while i < w.len:
    if i == 0:
      var matchedIndep = false
      for (vStr, vVal) in independentVowels:
        if i + vStr.len <= w.len and w[i ..< i + vStr.len] == vStr:
          res.add(vVal)
          i += vStr.len
          matchedIndep = true
          break
      if matchedIndep: continue

    var matchedSymbol = false
    for (sStr, sVal) in specialSymbols:
      if i + sStr.len <= w.len and w[i ..< i + sStr.len] == sStr:
        res.add(sVal)
        i += sStr.len
        matchedSymbol = true
        break
    if matchedSymbol: continue

    var matchedNukta = false
    for (nStr, nVal) in customNuktaConsonants:
      if i + nStr.len <= w.len and w[i ..< i + nStr.len] == nStr:
        res.add(nVal)
        i += nStr.len
        matchedNukta = true
        break
    if matchedNukta: continue

    var matchedSamyukta = false
    for (sStr, sVal) in samyuktaClusters:
      if i + sStr.len <= w.len and w[i ..< i + sStr.len] == sStr:
        res.add(sVal)
        i += sStr.len
        matchedSamyukta = true
        break
    if matchedSamyukta: continue

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

    # Dependent Matras & Vowels
    var matchedMatra = false
    for (mStr, mVal) in dependentMatras:
      if i + mStr.len <= w.len and w[i ..< i + mStr.len] == mStr:
        let prevIsCons = res.len > 0 and isDevanagariConsonant(getLastRune(res))
        if prevIsCons:
          var actualMatra = mVal
          if mStr == "i" and i + mStr.len == w.len:
            actualMatra = "ी"
          elif mStr == "a" and i + mStr.len == w.len and w.len > 2:
            actualMatra = "ा"
          res.add(actualMatra)
        else:
          var indepVal = ""
          for (vStr, vVal) in independentVowels:
            if vStr == mStr:
              indepVal = vVal
              break
          if indepVal.len == 0: indepVal = mVal
          if mStr == "i" and res.len > 0:
            indepVal = "ई"
          res.add(indepVal)
        i += mStr.len
        matchedMatra = true
        break
    if matchedMatra: continue

    let c = w[i]
    res.add($c)
    i += 1

  return res

proc loadGoogleCache(cachePath: string): Table[string, seq[string]] =
  result = initTable[string, seq[string]]()
  if not fileExists(cachePath): return
  var fs = newFileStream(cachePath, fmRead)
  if fs.isNil: return
  let count = fs.readUint32().int
  for _ in 0 ..< count:
    if fs.atEnd(): break
    let kLen = fs.readUint16().int
    let k = fs.readStr(kLen)
    let cCount = fs.readUint16().int
    var cands: seq[string] = @[]
    for _ in 0 ..< cCount:
      let cLen = fs.readUint16().int
      cands.add(fs.readStr(cLen))
    result[k] = cands
  fs.close()


proc normalizeToHinglish*(word: string): seq[string] =
  let raw = word.strip()
  if raw.len == 0: return @[]

  var r = raw
  # Long vowels
  r = r.replace("ā", "a").replace("Ā", "A")
  r = r.replace("ī", "i").replace("Ī", "I")
  r = r.replace("ū", "u").replace("Ū", "U")
  # Sibilants
  r = r.replace("ś", "sh").replace("Ś", "Sh")
  r = r.replace("ṣ", "sh").replace("Ṣ", "Sh")
  # Nasals
  r = r.replace("ñ", "n").replace("ṅ", "ng")
  r = r.replace("ṇ", "n").replace("ṃ", "n").replace("ṁ", "n")
  # Retroflex
  r = r.replace("ṭ", "t").replace("ḍ", "d")
  # Misc
  r = r.replace("ḥ", "h").replace("ṛ", "ri").replace("ṝ", "ri")
  r = r.replace("ḷ", "li").replace("ḹ", "li")
  r = r.toLowerAscii()

  var variants = @[r]

  # Cluster transforms
  if "jñ" in raw or "jn" in r:
    variants.add(r.replace("jn", "gy"))
  if "kṣ" in raw:
    variants.add(r.replace("ks", "ksh"))
    variants.add(r.replace("ks", "x"))
  if "sh" in r:
    variants.add(r.replace("sh", "s"))

  # Schwa deletion at end
  var schwaVariants: seq[string] = @[]
  for v in variants:
    if v.len > 3 and v[^1] == 'a':
      if not (raw.endsWith("ā") or raw.endsWith("Ā") or v.endsWith("aa") or v.endsWith("ya")):
        schwaVariants.add(v[0 ..< v.len - 1])
  variants.add(schwaVariants)

  # Deduplicate
  result = @[]
  for v in variants:
    let clean = v.strip().toLowerAscii()
    if clean.len > 0 and clean notin result:
      result.add(clean)

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

proc getRimeDir*(): string =
  let base = getEnv("XDG_DATA_HOME", getEnv("HOME") / ".local/share")
  let dir = getEnv("HINDI_IME_RIME_DIR", base / "fcitx5/rime")
  createDir(dir)
  return dir

proc generateFullRimeHindiDict() =
  let projDir = currentSourcePath.parentDir
  var binPath = getDataDir() / "wordnet_hindi_dict.bin"
  if not fileExists(binPath):
    binPath = projDir / "wordnet_hindi_dict.bin"
  var cachePath = getCacheDir() / "google_translit_cache.bin"
  if not fileExists(cachePath):
    cachePath = projDir / "google_translit_cache.bin"
  let rimeDictPath = getRimeDir() / "hindi_ai.dict.yaml"
  let binDict = loadWordNetBinaryDict(binPath)
  let googleCache = loadGoogleCache(cachePath)
  let commonDict = getCommonDict()

  var f = open(rimeDictPath, fmWrite)
  f.writeLine("# Rime dictionary: hindi_ai")
  f.writeLine("# Generated by Pure Nim Compiler (All Features Integrated)")
  f.writeLine("---")
  f.writeLine("name: hindi_ai")
  f.writeLine("version: \"2.0\"")
  f.writeLine("sort: by_weight")
  f.writeLine("use_preset_vocabulary: false")
  f.writeLine("...")
  f.writeLine("")

  var seen = initTable[string, bool]()
  var count = 0
  var baseEntries: seq[tuple[hword: string, pkey: string]] = @[]

  # 1. Google Transliterate Cached Words (Highest Priority)
  for pkey, cands in googleCache:
    for hw in cands:
      let hword = hw.strip()
      let hashKey = pkey & ":" & hword
      if not seen.hasKey(hashKey):
        f.writeLine(hword & "\t" & pkey)
        seen[hashKey] = true
        baseEntries.add((hword, pkey))
        inc count

  # 2. Curated High-Frequency Common Dictionary
  for pkey, cands in commonDict:
    for hw in cands:
      let hword = hw.strip()
      let hashKey = pkey & ":" & hword
      if not seen.hasKey(hashKey):
        f.writeLine(hword & "\t" & pkey)
        seen[hashKey] = true
        baseEntries.add((hword, pkey))
        inc count

  # 3. WordNet Hindi Dictionary (Normalized to Hinglish)
  for key, cands in binDict:
    let variants = normalizeToHinglish(key)
    for pkey in variants:
      for hword in cands:
        let hw = hword.strip()
        let hashKey = pkey & ":" & hw
        if not seen.hasKey(hashKey):
          f.writeLine(hw & "\t" & pkey)
          seen[hashKey] = true
          baseEntries.add((hw, pkey))
          inc count

  # 4. Inflected Variants (Plural, Oblique, Feminine, Verbal forms) with weight 50
  var inflectedCount = 0
  for (hw, pk) in baseEntries:
    let inflections = generateInflections(hw, pk, weight = 50)
    for inf in inflections:
      let hashKey = inf.pkey & ":" & inf.hword
      if not seen.hasKey(hashKey):
        f.writeLine(inf.hword & "\t" & inf.pkey & "\t" & $inf.weight)
        seen[hashKey] = true
        inc count
        inc inflectedCount
        if count >= 450000: break
    if count >= 450000: break

  f.close()
  echo "🚀 Pure Nim Rime Builder compiled ", count, " entries (including ", inflectedCount, " inflections) into ", rimeDictPath

  let repoDictPath = projDir.parentDir / "rime" / "hindi_ai.dict.yaml"
  if fileExists(rimeDictPath) and dirExists(projDir.parentDir / "rime"):
    copyFile(rimeDictPath, repoDictPath)
    echo "📄 Also synced dictionary to repository: ", repoDictPath

when isMainModule:
  generateFullRimeHindiDict()
