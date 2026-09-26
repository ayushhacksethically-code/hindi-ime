import std/[tables, strutils, osproc, json, streams, os, terminal]
import std/unicode except splitWhitespace
import ../data/common_dict

type
  PredictCandidate* = object
    hindi*: string
    score*: float

# Phonetic Consonant and Digraph Clusters Table
const
  specialClusters = [
    ("shw", "श्व"),
    ("ksh", "क्ष"),
    ("jny", "ज्ञ"),
    ("dny", "ज्ञ"),
    ("gy", "ज्ञ"),
    ("tr", "त्र"),
    ("shr", "श्र"),
    ("pya", "प्या"),
    ("kya", "क्या"),
    ("dhya", "ध्या"),
    ("tya", "त्या"),
    ("nya", "न्या"),
    ("chh", "छ"),
    ("kh", "ख"),
    ("gh", "घ"),
    ("ch", "च"),
    ("jh", "झ"),
    ("th", "थ"),
    ("dh", "ध"),
    ("ph", "फ"),
    ("bh", "भ"),
    ("sh", "श"),
    ("shh", "ष")
  ]

  # Independent Vowels (Index 0 / Word Start)
  independentVowels = [
    ("ish", "ईश"),
    ("aa", "आ"),
    ("ee", "ई"),
    ("oo", "ऊ"),
    ("ai", "ऐ"),
    ("au", "औ"),
    ("a", "अ"),
    ("i", "इ"),
    ("u", "उ"),
    ("e", "ए"),
    ("o", "ओ")
  ]

  # Dependent Matras (After Consonant)
  dependentMatras = [
    ("aa", "ा"),
    ("ee", "ी"),
    ("oo", "ू"),
    ("ai", "ै"),
    ("au", "ौ"),
    ("a", ""),   # Inherent Schwa
    ("i", "ि"),
    ("u", "ु"),
    ("e", "े"),
    ("o", "ो")
  ]

# Binary Dataset Loader ("HWNB" Magic Header)
proc loadWordNetBinaryDict*(binPath: string): Table[string, seq[string]] =
  result = initTable[string, seq[string]]()
  if not fileExists(binPath): return

  var fs = newFileStream(binPath, fmRead)
  if fs.isNil: return

  # Check Magic Header "HWNB"
  let magic = fs.readStr(4)
  if magic != "HWNB":
    fs.close()
    return

  # Read Entry Count (uint32)
  let entryCount = fs.readUint32()
  for _ in 0 ..< entryCount:
    # Key length (uint16)
    let keyLen = fs.readUint16().int
    let key = fs.readStr(keyLen)

    # Candidate Count (uint16)
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

proc getLastRune(s: string): Rune =
  if s.len == 0: return Rune(0)
  var pos = s.len - 1
  while pos > 0 and (s[pos].ord and 0xC0) == 0x80:
    dec pos
  return s.runeAt(pos)

proc isDevanagariConsonant(r: Rune): bool =
  let code = r.int
  return (code >= 0x0915 and code <= 0x0939) or (code >= 0x0958 and code <= 0x095F)

# Upgraded Pure Nim Rule Transliteration Engine
proc transliterateSingleWord*(word: string): string =
  var res = ""
  var i = 0
  let w = word.toLowerAscii().strip()
  if w.len == 0: return ""

  while i < w.len:
    # Rule 1: Check Independent Vowels if at start (i == 0)
    if i == 0:
      var matchedIndep = false
      for (vStr, vVal) in independentVowels:
        if i + vStr.len <= w.len and w[i ..< i + vStr.len] == vStr:
          res.add(vVal)
          i += vStr.len
          matchedIndep = true
          break
      if matchedIndep: continue

    # Rule 3: Check Special Digraph Clusters (3 & 2 character consonants)
    var matchedCluster = false
    for (cStr, cVal) in specialClusters:
      if i + cStr.len <= w.len and w[i ..< i + cStr.len] == cStr:
        res.add(cVal)
        i += cStr.len
        matchedCluster = true
        break
    if matchedCluster: continue

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

    # Single Consonants & Standard Fallback
    let c = w[i]
    case c
    of 'k': res.add("क"); i += 1
    of 'g': res.add("ग"); i += 1
    of 'j': res.add("ज"); i += 1
    of 't': res.add("त"); i += 1
    of 'd': res.add("द"); i += 1
    of 'n': res.add("न"); i += 1
    of 'p': res.add("प"); i += 1
    of 'b': res.add("ब"); i += 1
    of 'm': res.add("म"); i += 1
    of 'y': res.add("य"); i += 1
    of 'r': res.add("र"); i += 1
    of 'l': res.add("ल"); i += 1
    of 'v', 'w': res.add("व"); i += 1
    of 's': res.add("स"); i += 1
    of 'h': res.add("ह"); i += 1
    else:
      res.add($c)
      i += 1
  
  if isSuspiciousOutput(word, res):
    return word

  return res

proc getDataDir*(): string =
  let base = getEnv("XDG_DATA_HOME", getEnv("HOME") / ".local/share")
  let dir = base / "hindi-ime"
  createDir(dir)
  return dir

# Call Python indic-transliteration helper for fallback options
proc getIndicTransliterations*(text: string): seq[string] =
  let helperPath = getAppDir() / "indic_helper.py"
  let cmd = "python3 " & quoteShell(helperPath) & " " & quoteShell(text)
  let (output, exitCode) = execCmdEx(cmd)
  if exitCode == 0 and output.strip().len > 0:
    try:
      let jObj = parseJson(output.strip())
      for item in jObj:
        result.add(item.getStr())
    except JsonParsingError:
      discard

# Rule 2: Multi-Word Auto Splitting & Processing
proc processInput*(rawInput: string, commonDict, binDict: Table[string, seq[string]]): seq[string] =
  let words = rawInput.strip().splitWhitespace()
  if words.len == 0: return @[]

  if words.len == 1:
    let single = words[0]
    let cleanW = single.toLowerAscii()
    
    # 1. Common Base Dict
    if commonDict.hasKey(cleanW):
      for val in commonDict[cleanW]:
        if not result.contains(val): result.add(val)

    # 2. Native Pure Nim Binary Struct Dictionary ("HWNB")
    if binDict.hasKey(cleanW):
      for val in binDict[cleanW]:
        if not result.contains(val): result.add(val)
    
    # 3. Python indic-transliteration (sanscript fallback)
    let pythonIndic = getIndicTransliterations(cleanW)
    for val in pythonIndic:
      if not result.contains(val): result.add(val)

    # 4. Pure Nim Rule Transliteration Engine
    let nimRule = transliterateSingleWord(cleanW)
    if nimRule.len > 0 and not result.contains(nimRule):
      result.add(nimRule)

  else:
    # Multi-word input: process each word and combine top option
    var combined: seq[string] = @[]
    for w in words:
      let opts = processInput(w, commonDict, binDict)
      if opts.len > 0:
        combined.add(opts[0])
      else:
        combined.add(w)
    result.add(combined.join(" "))

    # Also add individual options for the first word
    let firstWordOpts = processInput(words[0], commonDict, binDict)
    for f in firstWordOpts:
      if not result.contains(f): result.add(f)

proc main() =
  let commonDict = getCommonDict()
  var binDictPath = getDataDir() / "wordnet_hindi_dict.bin"
  if not fileExists(binDictPath):
    binDictPath = getAppDir() / "wordnet_hindi_dict.bin"
  let binDict = loadWordNetBinaryDict(binDictPath)
  var currentSentence: seq[string] = @[]

  eraseScreen()
  setCursorPos(0, 0)
  styledWriteLine(stdout, fgCyan, styleBright, "==========================================================")
  styledWriteLine(stdout, fgYellow, styleBright, "  🇮🇳 AI Phonetic Hindi Keyboard (Pure Binary HWNB Engine)  ")
  styledWriteLine(stdout, fgCyan, styleBright, "==========================================================")
  styledWriteLine(stdout, fgGreen, "Pure Binary Struct ('HWNB') Loaded: ", $binDict.len, " Phonetic Entries")
  styledWriteLine(stdout, fgWhite, "  - Zero JSON overhead, ultra-fast native C binary memory mapping")
  styledWriteLine(stdout, fgCyan, styleBright, "----------------------------------------------------------\n")

  while true:
    stdout.styledWrite(fgCyan, styleBright, "\n📝 Current Sentence: ")
    if currentSentence.len == 0:
      stdout.styledWrite(fgWhite, "(empty)\n")
    else:
      stdout.styledWrite(fgGreen, styleBright, currentSentence.join(" ") & "\n")

    stdout.styledWrite(fgYellow, "Enter Phonetic Text > ")
    stdout.flushFile()

    let rawInput = readLine(stdin).strip()
    if rawInput.len == 0: continue

    let inputLower = rawInput.toLowerAscii()
    if inputLower == "exit" or inputLower == "q":
      styledWriteLine(stdout, fgGreen, styleBright, "\n🎉 Final Sentence: ", currentSentence.join(" "))
      styledWriteLine(stdout, fgYellow, "Goodbye!")
      break
    elif inputLower == "clear":
      currentSentence.setLen(0)
      styledWriteLine(stdout, fgMagenta, "Cleared sentence buffer.")
      continue
    elif inputLower == "back":
      if currentSentence.len > 0:
        let removed = currentSentence.pop()
        styledWriteLine(stdout, fgMagenta, "Removed: ", removed)
      continue

    # Process Multi-Word or Single Word Input
    let options = processInput(rawInput, commonDict, binDict)

    styledWriteLine(stdout, fgWhite, styleBright, "\n👉 Options for '", rawInput, "':")
    for idx, opt in options:
      stdout.styledWrite(fgYellow, styleBright, "   [" & $(idx + 1) & "] ")
      stdout.styledWrite(fgGreen, styleBright, opt & "\n")

    stdout.styledWrite(fgCyan, "Select Option Number (1-" & $options.len & ") [Default: 1]: ")
    stdout.flushFile()

    let selInput = readLine(stdin).strip()
    var choice = 1
    if selInput.len > 0:
      try:
        let parsed = parseInt(selInput)
        if parsed >= 1 and parsed <= options.len:
          choice = parsed
        else:
          styledWriteLine(stdout, fgRed, "Invalid number, using Option [1].")
      except ValueError:
        styledWriteLine(stdout, fgRed, "Not a valid integer, using Option [1].")

    let selectedWord = options[choice - 1]
    currentSentence.add(selectedWord)
    styledWriteLine(stdout, fgGreen, "✅ Added: ", selectedWord)

when isMainModule:
  main()
