import std/[os, strutils, sets, tables, unicode]

# Override tables and category sets for Hindi morphology
const
  irregularsArray = [
    ("आँख", "aankh", "आँखें:aankhen,आँखों:aankhon"),
    ("बात", "baat", "बातें:baaten,बातों:baaton"),
    ("रात", "raat", "रातें:raaten,रातों:raaton"),
    ("हाथ", "haath", "हाथ:haath,हाथों:haathon"),
    ("पैर", "pair", "पैर:pair,पैरों:pairon"),
    ("किताब", "kitab", "किताबें:kitaben,किताबों:kitabon"),
    ("औरत", "aurat", "औरतें:auraten,औरतों:auraton"),
    ("सड़क", "sadak", "सड़कें:sadaken,सड़कों:sadakon"),
    ("दुकान", "dukaan", "दुकानें:dukaanen,दुकानों:dukaanon"),
    ("जगह", "jagah", "जगहें:jagahen,जगहों:jagahon")
  ]

  femConsonantsArray = [
    "आँख", "बात", "रात", "किताब", "औरत", "बहन", "गाय", "सड़क", "जगह", "चीज़", "दीवार",
    "तस्वीर", "किरण", "आदत", "शर्त", "उम्मीद", "दुकान", "आवाज़", "खबर", "बूंद", "गेंद",
    "भैंस", "मेज", "पेंसिल", "कलम", "लहर", "सांझ", "सांस", "उम्र", "टांग", "झील", "रेल",
    "कार", "बस", "तारीख", "सरकार", "चाल", "बोतल", "चादर", "पोशाक", "इमारत", "मंजिल", "मौत",
    "याद", "चोट", "धूप", "दवा", "हवा", "सजा", "सुबह", "शाम", "नज़र", "मुस्कान", "राह", "शाख"
  ]

  femAListArray = [
    "समस्या", "भाषा", "कविता", "महिला", "शाखा", "दिशा", "कला", "माला", "सभा", "सेना",
    "कन्या", "परीक्षा", "संस्था", "योजना", "घटना", "सूचना", "आशा", "कथा", "प्रार्थना",
    "चिंता", "कृपा", "माया", "सेवा", "रक्षा", "यात्रा", "व्यवस्था", "संख्या", "प्रतिष्ठा",
    "भावना", "अवस्था", "कल्पना", "विद्या", "प्रतिमा", "छाया", "प्रजा", "पीड़ा", "वार्ता",
    "सीमा", "रेखा", "दशा", "शोभा", "प्रतिभा", "चेतना", "निष्ठा", "रचना", "तुलना", "प्रेरणा",
    "धारणा", "वेदना", "मर्यादा", "दुर्घटना", "समीक्षा", "सुरक्षा", "प्रशंसा", "दुनिया", "माता"
  ]

  mascExclusionsIArray = ["हाथी", "दही", "पानी", "घी", "मोती", "माली", "धोबी"]

  mascOnlyWords* = [
    "चतुर्भुज", "चक्रव्यूह", "द्वारका", "द्वापर", "सप्ताह",
    "नवरत्न", "दशानन", "पंचवटी", "पंचतत्व", "अष्टधातु",
    "चतुर्वेदी", "त्रिलोकीनाथ", "त्रिलोकनाथ"
  ].toHashSet

  # Common non-inflecting words: verbs/participles, pronouns, adverbs, postpositions
  nonNounExclusions = [
    # Verbs / Participles ending in -i
    "होगी", "गई", "गयी", "हुई", "दी", "ली", "रही", "आती", "जाती", "करती", "होती",
    "सोची", "लिखी", "चली", "पहुंची", "रखी", "देखी", "सुनी", "कही", "पढ़ी", "मिली",
    "सकती", "चाहिए", "बोली", "बनाई", "लगाई", "पाई", "खाई", "पी", "जी", "दी",
    # Pronouns ending in -i
    "मेरी", "तेरी", "हमारी", "तुम्हारी", "आपकी", "उसकी", "इसकी", "उनकी", "इनकी",
    "किसकी", "जिनकी", "कौंसी", "वही", "यही", "सही", "काफी",
    # Pronouns / Adverbs ending in -a
    "हमारा", "तुम्हारा", "आपका", "उसका", "इसका", "उनका", "इनका", "किसका", "जिसका",
    "कितना", "इतना", "उतना", "जितना", "पहला", "दूसरा", "तीसरा", "चौथा",
    # Postpositions / Conjunctions
    "वाला", "वाले", "वाली", "बिना", "अलावा", "द्वारा", "तथा", "अथवा", "या"
  ]

type
  Variant* = object
    hword*: string
    pkey*: string
    weight*: int

var
  gIrregulars: Table[string, seq[tuple[hword, pkey: string]]]
  gFemConsonants: HashSet[string]
  gFemAList: HashSet[string]
  gMascExclusionsI: HashSet[string]
  gNonNounExclusions: HashSet[string]
  gTablesInitialized = false

proc initTables() =
  if gTablesInitialized: return
  gFemConsonants = toHashSet(femConsonantsArray)
  gFemAList = toHashSet(femAListArray)
  gMascExclusionsI = toHashSet(mascExclusionsIArray)
  gNonNounExclusions = toHashSet(nonNounExclusions)
  gIrregulars = initTable[string, seq[tuple[hword, pkey: string]]]()

  for (baseHw, _, varStr) in irregularsArray:
    var list: seq[tuple[hword, pkey: string]] = @[]
    for item in varStr.split(','):
      let parts = item.split(':')
      if parts.len == 2:
        list.add((parts[0].strip(), parts[1].strip()))
    gIrregulars[baseHw] = list

  gTablesInitialized = true

proc getLastRune*(s: string): Rune =
  if s.len == 0: return Rune(0)
  var pos = s.len - 1
  while pos > 0 and (s[pos].ord and 0xC0) == 0x80:
    dec pos
  return s.runeAt(pos)

proc isDevanagariConsonant*(r: Rune): bool =
  let code = r.int
  return (code >= 0x0915 and code <= 0x0939) or (code >= 0x0958 and code <= 0x095F)

proc isDevanagari*(s: string): bool =
  if s.len == 0: return false
  let firstRune = s.runeAt(0)
  return firstRune.int >= 0x0900 and firstRune.int <= 0x097F

# Helper to remove unpronounced schwa 'a' on pkey when Devanagari ends in consonant
proc cleanPstem(hw, pk: string): string =
  if not hw.endsWith("ा") and pk.endsWith("a") and pk.len > 2:
    return pk[0 ..< pk.len - 1]
  return pk

proc addVariant(res: var seq[Variant], seen: var HashSet[string], hword, pkey: string, weight: int) =
  let key = hword & ":" & pkey
  if key notin seen:
    seen.incl(key)
    res.add(Variant(hword: hword, pkey: pkey, weight: weight))

proc generateVariantsForWord*(hword, pkey: string, weight: int = 50): seq[Variant] =
  initTables()
  result = @[]

  if not isDevanagari(hword) or hword.runeLen < 2:
    return

  if hword in mascOnlyWords:
    return @[]  # no inflection

  if hword in gNonNounExclusions:
    return

  let cleanPk = pkey.toLowerAscii().strip()
  if cleanPk.len == 0: return

  var seen = initHashSet[string]()

  # 1. IRREGULAR OVERRIDES
  # आँख → आँखें, आँखों; बात → बातें, बातों; रात → रातें, रातों; हाथ → हाथ, हाथों; पैर → पैर, पैरों
  if gIrregulars.hasKey(hword):
    let ps = cleanPstem(hword, cleanPk)
    for (varHw, varPkTemplate) in gIrregulars[hword]:
      result.addVariant(seen, varHw, varPkTemplate, weight)
      if varHw.endsWith("ें"):
        result.addVariant(seen, varHw, ps & "en", weight)
        result.addVariant(seen, varHw, ps & "ein", weight)
      elif varHw.endsWith("ों"):
        result.addVariant(seen, varHw, ps & "on", weight)
        result.addVariant(seen, varHw, ps & "o", weight)
      else:
        result.addVariant(seen, varHw, cleanPk, weight)
    return

  # Other irregular feminine consonant nouns (किताब, औरत, सड़क, etc.)
  if hword in gFemConsonants:
    let ps = cleanPstem(hword, cleanPk)
    result.addVariant(seen, hword & "ें", ps & "en", weight)
    result.addVariant(seen, hword & "ें", ps & "ein", weight)
    result.addVariant(seen, hword & "ों", ps & "on", weight)
    result.addVariant(seen, hword & "ों", ps & "o", weight)
    return

  # 2. FEMININE -ā (समस्या)
  # -āen → समस्याएँ, -āon → समस्याओं
  let isFemA = (hword in gFemAList) or
               (hword.endsWith("ता") and hword.runeLen > 3) or
               (hword.endsWith("िका") and hword.runeLen > 3)

  if isFemA and hword.endsWith("ा"):
    var ps = cleanPk
    if not ps.endsWith("a"): ps.add("a")
    result.addVariant(seen, hword & "एँ", ps & "en", weight)
    result.addVariant(seen, hword & "एँ", ps & "ein", weight)
    result.addVariant(seen, hword & "ओं", ps & "on", weight)
    result.addVariant(seen, hword & "ओं", ps & "o", weight)
    return

  # Skip feminine verbal suffixes: -ती (-ti), -गी (-gi), -नी (-ni)
  if (hword.endsWith("ती") and cleanPk.endsWith("ti")) or
     (hword.endsWith("गी") and cleanPk.endsWith("gi")) or
     (hword.endsWith("नी") and cleanPk.endsWith("ni")):
    return

  # 3. FEMININE -ī (लड़की)
  # -iyān → लड़कियाँ, -iyon → लड़कियों
  if hword.endsWith("ी") and hword notin gMascExclusionsI:
    let hstem = hword[0 ..< hword.len - "ी".len]
    var pstem = cleanPk
    if pstem.endsWith("ee"): pstem = pstem[0 ..< pstem.len - 2]
    elif pstem.endsWith("i"): pstem = pstem[0 ..< pstem.len - 1]

    result.addVariant(seen, hstem & "ियाँ", pstem & "iyan", weight)
    result.addVariant(seen, hstem & "ियाँ", pstem & "iyaan", weight)
    result.addVariant(seen, hstem & "ियों", pstem & "iyon", weight)
    result.addVariant(seen, hstem & "ियों", pstem & "iyo", weight)
    return

  # 2b. FEMININE -iyā (चिड़िया, डिबिया, गुड़िया)
  if hword.endsWith("िया") and hword.runeLen > 3:
    let hstem = hword[0 ..< hword.len - "या".len]
    var pstem = cleanPk
    if pstem.endsWith("ya"): pstem = pstem[0 ..< pstem.len - 2]
    elif pstem.endsWith("iya"): pstem = pstem[0 ..< pstem.len - 3]

    result.addVariant(seen, hstem & "याँ", pstem & "yan", weight)
    result.addVariant(seen, hstem & "याँ", pstem & "iyan", weight)
    result.addVariant(seen, hstem & "यों", pstem & "yon", weight)
    result.addVariant(seen, hstem & "यों", pstem & "iyo", weight)
    return

  # Skip infinitive verbs ending in -na (e.g. बोलना, करना, चलना)
  if hword.endsWith("ना") and cleanPk.endsWith("na") and hword.runeLen >= 3:
    return

  # 4. MASCULINE -ā (लड़का)
  # -e → लड़के, -on → लड़कों
  if hword.endsWith("ा") and not isFemA:
    let hstem = hword[0 ..< hword.len - "ा".len]
    var pstem = cleanPk
    if pstem.endsWith("a"): pstem = pstem[0 ..< pstem.len - 1]

    result.addVariant(seen, hstem & "े", pstem & "e", weight)
    result.addVariant(seen, hstem & "ों", pstem & "on", weight)
    result.addVariant(seen, hstem & "ों", pstem & "o", weight)
    return

  # 5. MASCULINE CONSONANT (घर)
  # -on → घरों
  let lastR = getLastRune(hword)
  if isDevanagariConsonant(lastR):
    let ps = cleanPstem(hword, cleanPk)
    result.addVariant(seen, hword & "ों", ps & "on", weight)
    result.addVariant(seen, hword & "ों", ps & "o", weight)
    return

proc testSample(dictPath: string, sampleLimit: int = 1000) =
  initTables()
  echo "═══════════════════════════════════════════════════════════"
  echo "STEP 3: TEST ON SAMPLE (First ", sampleLimit, " words)"
  echo "═══════════════════════════════════════════════════════════"

  # 1. Show Generated variants for 10 common words
  echo "\n--- Generated variants for 10 common words ---"
  let testWords = [
    ("समस्या", "samasya"),
    ("लड़की", "ladki"),
    ("लड़का", "ladka"),
    ("घर", "ghar"),
    ("बात", "baat"),
    ("रात", "raat"),
    ("आँख", "aankh"),
    ("हाथ", "haath"),
    ("पैर", "pair"),
    ("गाड़ी", "gaadi")
  ]

  for (hw, pk) in testWords:
    let vars = generateVariantsForWord(hw, pk, 50)
    var varStrs: seq[string] = @[]
    for v in vars:
      varStrs.add(v.hword & " (" & v.pkey & ", 50)")
    echo "  ", hw, " [", pk, "] → ", varStrs.join(" | ")

  # 2. Process first sampleLimit words from dictionary
  echo "\n--- Scanning first ", sampleLimit, " words in dictionary ---"
  var existing = initHashSet[string]()
  var baseEntries: seq[tuple[hword, pkey: string]] = @[]
  var totalLines = 0

  for line in lines(dictPath):
    inc totalLines
    let trimmed = line.strip()
    if trimmed.len == 0 or trimmed.startsWith("#") or trimmed == "---" or trimmed == "...":
      continue
    let parts = trimmed.split('\t')
    if parts.len >= 2:
      let hw = parts[0].strip()
      let pk = parts[1].strip()
      let hashKey = hw & ":" & pk
      existing.incl(hashKey)

      # If line does not have weight 50, it is a base word candidate
      if parts.len == 2 and baseEntries.len < sampleLimit:
        baseEntries.add((hw, pk))

  echo "Loaded ", existing.len, " unique existing entries from dictionary."
  echo "Selected ", baseEntries.len, " base words from sample."

  var newEntries: seq[Variant] = @[]
  var seenNew = initHashSet[string]()

  for (hw, pk) in baseEntries:
    let vars = generateVariantsForWord(hw, pk, 50)
    for v in vars:
      let hashKey = v.hword & ":" & v.pkey
      if hashKey notin existing and hashKey notin seenNew:
        seenNew.incl(hashKey)
        newEntries.add(v)

  echo "\n--- Summary for Sample ---"
  echo "Total new entries generated: ", newEntries.len

  echo "\n--- Sample Output (first 25 generated entries) ---"
  for i in 0 ..< min(25, newEntries.len):
    let v = newEntries[i]
    echo v.hword, "\t", v.pkey, "\t", v.weight

proc fullGeneration(dictPath: string, outputPath: string = "") =
  initTables()
  let targetPath = if outputPath.len > 0: outputPath else: dictPath
  echo "═══════════════════════════════════════════════════════════"
  echo "STEP 4: FULL GENERATION on ", dictPath
  echo "═══════════════════════════════════════════════════════════"

  var existing = initHashSet[string]()
  var baseEntries: seq[tuple[hword, pkey: string]] = @[]
  var headerLines: seq[string] = @[]
  var allExistingLines: seq[string] = @[]

  var inHeader = true
  for line in lines(dictPath):
    let trimmed = line.strip()
    if inHeader:
      headerLines.add(line)
      if trimmed == "...":
        inHeader = false
      continue

    allExistingLines.add(line)
    if trimmed.len == 0 or trimmed.startsWith("#"):
      continue

    let parts = trimmed.split('\t')
    if parts.len >= 2:
      let hw = parts[0].strip()
      let pk = parts[1].strip()
      existing.incl(hw & ":" & pk)

      # Base entries (weight != 50)
      if parts.len == 2:
        baseEntries.add((hw, pk))

  echo "Total existing lines: ", allExistingLines.len
  echo "Total unique existing entries: ", existing.len
  echo "Total base candidate entries: ", baseEntries.len

  var newEntries: seq[Variant] = @[]
  var seenNew = initHashSet[string]()

  for (hw, pk) in baseEntries:
    let vars = generateVariantsForWord(hw, pk, 50)
    for v in vars:
      let hashKey = v.hword & ":" & v.pkey
      if hashKey notin existing and hashKey notin seenNew:
        seenNew.incl(hashKey)
        newEntries.add(v)

  echo "Total new inflected entries to add: ", newEntries.len

  # Append new entries to output file
  var f = open(targetPath, fmWrite)
  for hl in headerLines:
    f.writeLine(hl)
  for el in allExistingLines:
    f.writeLine(el)
  for v in newEntries:
    f.writeLine(v.hword & "\t" & v.pkey & "\t" & $v.weight)
  f.close()

  echo "✅ Successfully written to ", targetPath
  echo "Final line count: ", headerLines.len + allExistingLines.len + newEntries.len

when isMainModule:
  let params = commandLineParams()
  let defaultDict = getAppDir().parentDir / "rime" / "hindi_ai.dict.yaml"

  if params.len == 0 or params.contains("--sample") or params.contains("-s"):
    testSample(defaultDict, 1000)
  elif params.contains("--full") or params.contains("-f"):
    fullGeneration(defaultDict)
  else:
    echo "Usage: generate_variants [--sample | --full] [dict_path]"
