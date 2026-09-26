import std/[tables, strutils, json, streams, os, math, unicode]

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

proc getCommonDict(): Table[string, seq[string]] =
  result = initTable[string, seq[string]]()

  # ============================================================
  # CONSOLIDATED HINGLISH DICT
  # Data Sources:
  # - Common high-frequency Hinglish vocabulary (curated)
  # - Hindi WordNet (IIT Bombay, GPL license)
  # - Conversational corpus (anonymized, aggregated)
  # - Academic & technical terms (geography, science, etc.)
  # ============================================================

  # ============ PRONOUNS ============
  result["main"] = @["मैं"]
  result["mai"] = @["मैं"]
  result["hum"] = @["हम"]
  result["humlog"] = @["हमलोग"]
  result["humein"] = @["हमें"]
  result["hume"] = @["हमें"]
  result["mujhe"] = @["मुझे"]
  result["muje"] = @["मुझे"]
  result["mujhko"] = @["मुझको"]
  result["tum"] = @["तुम"]
  result["tumlog"] = @["तुमलोग"]
  result["tumhe"] = @["तुम्हें"]
  result["tumhein"] = @["तुम्हें"]
  result["aap"] = @["आप"]
  result["aaplog"] = @["आपलोग"]
  result["aplog"] = @["आपलोग"]
  result["aapko"] = @["आपको"]
  result["aapka"] = @["आपका"]
  result["aapki"] = @["आपकी"]
  result["aapke"] = @["आपके"]
  result["tera"] = @["तेरा"]
  result["teri"] = @["तेरी"]
  result["tere"] = @["तेरे"]
  result["mera"] = @["मेरा"]
  result["meri"] = @["मेरी"]
  result["mere"] = @["मेरे"]
  result["hamara"] = @["हमारा"]
  result["hamari"] = @["हमारी"]
  result["hamare"] = @["हमारे"]
  result["uska"] = @["उसका"]
  result["uski"] = @["उसकी"]
  result["uske"] = @["उसके"]
  result["iska"] = @["इसका"]
  result["iski"] = @["इसकी"]
  result["iske"] = @["इसके"]
  result["kiska"] = @["किसका"]
  result["kiski"] = @["किसकी"]
  result["kiske"] = @["किसके"]
  result["inka"] = @["इनका"]
  result["inki"] = @["इनकी"]
  result["inke"] = @["इनके"]
  result["unka"] = @["उनका"]
  result["unki"] = @["उनकी"]
  result["unke"] = @["उनके"]
  result["ye"] = @["ये"]
  result["yeh"] = @["यह"]
  result["wo"] = @["वो"]
  result["woh"] = @["वह"]
  result["ise"] = @["इसे"]
  result["use"] = @["उसे"]
  result["inhe"] = @["इन्हें"]
  result["unhe"] = @["उन्हें"]
  result["khud"] = @["खुद"]
  result["apna"] = @["अपना"]
  result["apni"] = @["अपनी"]
  result["apne"] = @["अपने"]

  # ============ VERBS - PRESENT/PAST/FUTURE ============
  result["hai"] = @["है"]
  result["h"] = @["है"]
  result["hain"] = @["हैं"]
  result["ho"] = @["हो"]
  result["hun"] = @["हूँ"]
  result["hoon"] = @["हूँ"]
  result["tha"] = @["था"]
  result["thi"] = @["थी"]
  result["the"] = @["थे"]
  result["hoga"] = @["होगा"]
  result["hogi"] = @["होगी"]
  result["honge"] = @["होंगे"]
  result["hota"] = @["होता"]
  result["hoti"] = @["होती"]
  result["hote"] = @["होते"]
  result["hua"] = @["हुआ"]
  result["huw"] = @["हुआ"]
  result["hogaya"] = @["होगया", "हो गया"]

  # Future suffixes
  result["ga"] = @["गा"]
  result["gaa"] = @["गा"]
  result["gi"] = @["गी"]
  result["ge"] = @["गे"]

  # Kar-
  result["karta"] = @["करता"]
  result["karti"] = @["करती"]
  result["karte"] = @["करते"]
  result["karunga"] = @["करूँगा"]
  result["karungi"] = @["करूँगी"]
  result["karenge"] = @["करेंगे"]
  result["karu"] = @["करूँ"]
  result["karun"] = @["करूँ"]
  result["kare"] = @["करे"]
  result["karo"] = @["करो"]
  result["kar"] = @["कर"]
  result["kiya"] = @["किया"]
  result["kiye"] = @["किये"]
  result["karke"] = @["करके"]
  result["karna"] = @["करना"]
  result["karni"] = @["करनी"]
  result["karne"] = @["करने"]
  result["kariye"] = @["कीजिए"]
  result["koshish"] = @["कोशिश"]
  result["kosish"] = @["कोशिश"]

  # Ja-
  result["jata"] = @["जाता"]
  result["jati"] = @["जाती"]
  result["jate"] = @["जाते"]
  result["jaunga"] = @["जाऊँगा"]
  result["jayegi"] = @["जाएगी"]
  result["jayenge"] = @["जाएँगे"]
  result["jaoge"] = @["जाओगे"]
  result["gaya"] = @["गया"]
  result["gayi"] = @["गई"]
  result["gaye"] = @["गए"]
  result["jana"] = @["जाना"]
  result["jani"] = @["जानी"]
  result["jane"] = @["जाने"]
  result["jake"] = @["जाके"]
  result["jaake"] = @["जाके"]

  # Aa-
  result["aata"] = @["आता"]
  result["aati"] = @["आती"]
  result["aate"] = @["आते"]
  result["aaya"] = @["आया"]
  result["aayi"] = @["आई"]
  result["aaye"] = @["आए"]
  result["aana"] = @["आना"]
  result["aani"] = @["आनी"]
  result["aane"] = @["आने"]

  # De-
  result["deta"] = @["देता"]
  result["deti"] = @["देती"]
  result["dete"] = @["देते"]
  result["diya"] = @["दिया"]
  result["diye"] = @["दिये"]
  result["dena"] = @["देना"]
  result["deni"] = @["देनी"]
  result["dene"] = @["देने"]
  result["dijiye"] = @["दीजिए"]
  result["dijiyega"] = @["दीजिएगा"]
  result["dijiye ga"] = @["दीजिएगा"]

  # Le-
  result["leta"] = @["लेता"]
  result["leti"] = @["लेती"]
  result["lete"] = @["लेते"]
  result["liya"] = @["लिया"]
  result["liye"] = @["लिये"]
  result["lena"] = @["लेना"]
  result["leni"] = @["लेनी"]
  result["lene"] = @["लेने"]
  result["leke"] = @["लेके"]

  # Dekh-
  result["dekha"] = @["देखा"]
  result["dekhi"] = @["देखी"]
  result["dekhe"] = @["देखे"]
  result["dekhna"] = @["देखना"]
  result["dekhta"] = @["देखता"]
  result["dekhti"] = @["देखती"]
  result["dekhte"] = @["देखते"]

  # Bol-/Kah-
  result["bola"] = @["बोला"]
  result["boli"] = @["बोली"]
  result["bole"] = @["बोले"]
  result["bolna"] = @["बोलना"]
  result["bolta"] = @["बोलता"]
  result["bolti"] = @["बोलती"]
  result["bolte"] = @["बोलते"]
  result["kaha"] = @["कहा"]
  result["kahi"] = @["कही"]
  result["kahe"] = @["कहे"]
  result["kahna"] = @["कहना"]
  result["kahta"] = @["कहता"]
  result["kahti"] = @["कहती"]
  result["kahte"] = @["कहते"]

  # Sun-
  result["suna"] = @["सुना"]
  result["suni"] = @["सुनी"]
  result["sune"] = @["सुने"]
  result["sunna"] = @["सुनना"]
  result["sunta"] = @["सुनता"]
  result["sunti"] = @["सुनती"]
  result["sunte"] = @["सुनते"]

  # Padh-
  result["padha"] = @["पढ़ा"]
  result["padhi"] = @["पढ़ी"]
  result["padhe"] = @["पढ़े"]
  result["padhna"] = @["पढ़ना"]
  result["padhta"] = @["पढ़ता"]
  result["padhti"] = @["पढ़ती"]
  result["padhte"] = @["पढ़ते"]

  # Likh-
  result["likha"] = @["लिखा"]
  result["likhi"] = @["लिखी"]
  result["likhe"] = @["लिखे"]
  result["likhna"] = @["लिखना"]
  result["likhta"] = @["लिखता"]
  result["likhti"] = @["लिखती"]
  result["likhte"] = @["लिखते"]

  # Soch-
  result["socha"] = @["सोचा"]
  result["sochi"] = @["सोची"]
  result["soche"] = @["सोचे"]
  result["sochna"] = @["सोचना"]
  result["sochta"] = @["सोचता"]
  result["sochti"] = @["सोचती"]
  result["sochte"] = @["सोचते"]

  # Samajh-
  result["samjha"] = @["समझा"]
  result["samjhi"] = @["समझी"]
  result["samjhe"] = @["समझे"]
  result["samajhna"] = @["समझना"]
  result["samajhta"] = @["समझता"]
  result["samajhti"] = @["समझती"]
  result["samajhte"] = @["समझते"]

  # Chal-
  result["chala"] = @["चला"]
  result["chali"] = @["चली"]
  result["chale"] = @["चले"]
  result["chalna"] = @["चलना"]
  result["chalta"] = @["चलता"]
  result["chalti"] = @["चलती"]
  result["chalte"] = @["चलते"]

  # Bhej-/Puch-/Bata-
  result["bhejo"] = @["भेजो"]
  result["bhej"] = @["भेज"]
  result["bheja"] = @["भेजा"]
  result["veje"] = @["भेजे"]
  result["vej"] = @["भेज"]
  result["puch"] = @["पूछ"]
  result["pooch"] = @["पूछ"]
  result["pucha"] = @["पूछा"]
  result["bata"] = @["बता"]
  result["batao"] = @["बताओ"]
  result["banaya"] = @["बनाया"]
  result["banaye"] = @["बनाये"]
  result["bana"] = @["बना"]
  result["rakh"] = @["रख"]
  result["rakhna"] = @["रखना"]
  result["rakhiye"] = @["रखिये"]
  result["maang"] = @["मांग"]
  result["mang"] = @["मांग"]
  result["cover"] = @["कवर"]
  result["loon"] = @["लूँ"]
  result["lu"] = @["लूँ"]
  result["lag"] = @["लग"]
  result["raha"] = @["रहा"]
  result["rahi"] = @["रही"]
  result["rahe"] = @["रहे"]

  # ============ FAMILY ============
  result["maa"] = @["माँ"]
  result["ma"] = @["माँ"]
  result["mata"] = @["माता"]
  result["papa"] = @["पापा"]
  result["pitaji"] = @["पिताजी"]
  result["pita"] = @["पिता"]
  result["baap"] = @["बाप"]
  result["bhai"] = @["भाई"]
  result["bhaiya"] = @["भैया"]
  result["behen"] = @["बहन"]
  result["behan"] = @["बहन"]
  result["bahan"] = @["बहन"]
  result["didi"] = @["दीदी"]
  result["bhabhi"] = @["भाभी"]
  result["devar"] = @["देवर"]
  result["jeth"] = @["जेठ"]
  result["sasur"] = @["ससुर"]
  result["saas"] = @["सास"]
  result["sasural"] = @["ससुराल"]
  result["beta"] = @["बेटा"]
  result["beti"] = @["बेटी"]
  result["bacha"] = @["बच्चा"]
  result["bachcha"] = @["बच्चा"]
  result["bache"] = @["बच्चे"]
  result["bacche"] = @["बच्चे"]
  result["bachche"] = @["बच्चे"]
  result["pati"] = @["पति"]
  result["patni"] = @["पत्नी"]
  result["biwi"] = @["बीवी"]
  result["shauhar"] = @["शौहर"]
  result["dada"] = @["दादा"]
  result["dadi"] = @["दादी"]
  result["nana"] = @["नाना"]
  result["nani"] = @["नानी"]
  result["chacha"] = @["चाचा"]
  result["chachi"] = @["चाची"]
  result["mama"] = @["मामा"]
  result["mami"] = @["मामी"]
  result["tau"] = @["ताऊ"]
  result["tai"] = @["ताई"]

  # ============ BODY ============
  result["sar"] = @["सिर"]
  result["hath"] = @["हाथ"]
  result["haath"] = @["हाथ"]
  result["pair"] = @["पैर"]
  result["paer"] = @["पैर"]
  result["aankh"] = @["आँख"]
  result["aankhen"] = @["आँखें"]
  result["kaan"] = @["कान"]
  result["naak"] = @["नाक"]
  result["muh"] = @["मुँह"]
  result["munh"] = @["मुँह"]
  result["daant"] = @["दाँत"]
  result["jeebh"] = @["जीभ"]
  result["jibh"] = @["जीभ"]
  result["pet"] = @["पेट"]
  result["kamar"] = @["कमर"]
  result["kandha"] = @["कंधा"]
  result["gala"] = @["गला"]
  result["dil"] = @["दिल"]

  # ============ HOME ============
  result["ghar"] = @["घर"]
  result["makan"] = @["मकान"]
  result["darwaza"] = @["दरवाजा"]
  result["darwaja"] = @["दरवाजा"]
  result["khidki"] = @["खिड़की"]
  result["chhat"] = @["छत"]
  result["chat"] = @["छत"]
  result["farsh"] = @["फर्श"]
  result["deewar"] = @["दीवार"]
  result["diwar"] = @["दीवार"]
  result["kamra"] = @["कमरा"]
  result["rasoi"] = @["रसोई"]
  result["bistar"] = @["बिस्तर"]
  result["takiya"] = @["तकिया"]
  result["chadar"] = @["चादर"]
  result["kambal"] = @["कंबल"]
  result["kursi"] = @["कुर्सी"]
  result["mez"] = @["मेज़"]
  result["almari"] = @["अलमारी"]
  result["palang"] = @["पलंग"]
  result["chabhi"] = @["चाबी"]
  result["taala"] = @["ताला"]
  result["batti"] = @["बत्ती"]
  result["bijli"] = @["बिजली"]
  result["paani"] = @["पानी"]
  result["pani"] = @["पानी"]
  result["khana"] = @["खाना"]
  result["chai"] = @["चाय"]
  result["dudh"] = @["दूध"]
  result["doodh"] = @["दूध"]

  # ============ FOOD ============
  result["roti"] = @["रोटी"]
  result["chapati"] = @["चपाती"]
  result["chawal"] = @["चावल"]
  result["dal"] = @["दाल"]
  result["daal"] = @["दाल"]
  result["sabzi"] = @["सब्ज़ी"]
  result["sabji"] = @["सब्ज़ी"]
  result["aata"] = @["आटा"]
  result["atta"] = @["आटा"]
  result["namak"] = @["नमक"]
  result["cheeni"] = @["चीनी"]
  result["chini"] = @["चीनी"]
  result["ghee"] = @["घी"]
  result["tel"] = @["तेल"]
  result["masala"] = @["मसाला"]
  result["mirchi"] = @["मिर्ची"]
  result["haldi"] = @["हल्दी"]
  result["pyaz"] = @["प्याज़"]
  result["pyaaz"] = @["प्याज़"]
  result["lehsun"] = @["लहसुन"]
  result["adrak"] = @["अदरक"]

  # ============ TIME ============
  result["din"] = @["दिन"]
  result["raat"] = @["रात"]
  result["rat"] = @["रात"]
  result["subah"] = @["सुबह"]
  result["subha"] = @["सुबह"]
  result["shaam"] = @["शाम"]
  result["sham"] = @["शाम"]
  result["dopahar"] = @["दोपहर"]
  result["abhi"] = @["अभी"]
  result["ab"] = @["अब"]
  result["kal"] = @["कल"]
  result["aaj"] = @["आज"]
  result["aj"] = @["आज"]
  result["parso"] = @["परसों"]
  result["samay"] = @["समय"]
  result["waqt"] = @["वक़्त"]
  result["ghanta"] = @["घंटा"]
  result["ghante"] = @["घंटे"]
  result["minute"] = @["मिनट"]
  result["second"] = @["सेकंड"]
  result["saal"] = @["साल"]
  result["mahina"] = @["महीना"]
  result["mahine"] = @["महीने"]
  result["hafta"] = @["हफ़्ता"]
  result["hafte"] = @["हफ़्ते"]
  result["monday"] = @["मंडे"]
  result["weekend"] = @["वीकेंड"]

  # ============ PLACES ============
  result["jagah"] = @["जगह"]
  result["jagha"] = @["जगह"]
  result["sthan"] = @["स्थान"]
  result["gaon"] = @["गाँव"]
  result["gaaon"] = @["गाँव"]
  result["shahar"] = @["शहर"]
  result["shehar"] = @["शहर"]
  result["gali"] = @["गली"]
  result["rasta"] = @["रास्ता"]
  result["raasta"] = @["रास्ता"]
  result["sadak"] = @["सड़क"]
  result["bazaar"] = @["बाज़ार"]
  result["bajar"] = @["बाज़ार"]
  result["mandir"] = @["मंदिर"]
  result["masjid"] = @["मस्जिद"]
  result["school"] = @["स्कूल"]
  result["college"] = @["कॉलेज"]
  result["office"] = @["ऑफिस"]
  result["dukaan"] = @["दुकान"]
  result["dukan"] = @["दुकान"]
  result["station"] = @["स्टेशन"]
  result["desh"] = @["देश"]
  result["videsh"] = @["विदेश"]
  result["bharat"] = @["भारत"]
  result["hindustan"] = @["हिंदुस्तान"]

  # ============ ABSTRACT NOUNS ============
  result["baat"] = @["बात"]
  result["bat"] = @["बात"]
  result["kaam"] = @["काम"]
  result["kam"] = @["काम"]
  result["cheez"] = @["चीज़"]
  result["chiz"] = @["चीज़"]
  result["samasya"] = @["समस्या"]
  result["problem"] = @["प्रॉब्लम"]
  result["pareshani"] = @["परेशानी"]
  result["sawal"] = @["सवाल"]
  result["sawaal"] = @["सवाल"]
  result["jawab"] = @["जवाब"]
  result["jawaab"] = @["जवाब"]
  result["fayda"] = @["फ़ायदा"]
  result["nuksan"] = @["नुकसान"]
  result["mushkil"] = @["मुश्किल"]
  result["aasan"] = @["आसान"]
  result["asaan"] = @["आसान"]
  result["sach"] = @["सच"]
  result["jhooth"] = @["झूठ"]
  result["jhuth"] = @["झूठ"]
  result["pyaar"] = @["प्यार"]
  result["pyar"] = @["प्यार"]
  result["nafrat"] = @["नफ़रत"]
  result["khushi"] = @["खुशी"]
  result["gham"] = @["ग़म"]
  result["gum"] = @["ग़म"]
  result["dukh"] = @["दुख"]
  result["sukh"] = @["सुख"]
  result["umeed"] = @["उम्मीद"]
  result["ummid"] = @["उम्मीद"]
  result["nirasha"] = @["निराशा"]
  result["himmat"] = @["हिम्मत"]
  result["taakat"] = @["ताक़त"]
  result["shakti"] = @["शक्ति"]
  result["gyan"] = @["ज्ञान"]
  result["shiksha"] = @["शिक्षा"]
  result["sanskriti"] = @["संस्कृति"]
  result["sanskrit"] = @["संस्कृत"]
  result["kshetra"] = @["क्षेत्र"]
  result["itihas"] = @["इतिहास"]
  result["bhavishya"] = @["भविष्य"]
  result["vartman"] = @["वर्तमान"]
  result["jivan"] = @["जीवन"]
  result["jindagi"] = @["ज़िंदगी"]
  result["zindagi"] = @["ज़िंदगी"]

  # ============ PEOPLE ============
  result["log"] = @["लोग"]
  result["aadmi"] = @["आदमी"]
  result["aadamee"] = @["आदमी"]
  result["aurat"] = @["औरत"]
  result["ladka"] = @["लड़का"]
  result["ladki"] = @["लड़की"]
  result["ladke"] = @["लड़के"]
  result["dost"] = @["दोस्त"]
  result["dosti"] = @["दोस्ती"]
  result["padosi"] = @["पड़ोसी"]
  result["rishtedaar"] = @["रिश्तेदार"]
  result["mehman"] = @["मेहमान"]
  result["mehmaan"] = @["मेहमान"]
  result["saathi"] = @["साथी"]
  result["sathi"] = @["साथी"]
  result["dushman"] = @["दुश्मन"]
  result["neta"] = @["नेता"]
  result["teacher"] = @["टीचर"]
  result["student"] = @["स्टूडेंट"]
  result["sir"] = @["सर", "सिर"]

  # ============ ADJECTIVES ============
  result["accha"] = @["अच्छा"]
  result["acha"] = @["अच्छा"]
  result["achha"] = @["अच्छा"]
  result["achhi"] = @["अच्छी"]
  result["achhe"] = @["अच्छे"]
  result["bura"] = @["बुरा"]
  result["buri"] = @["बुरी"]
  result["bure"] = @["बुरे"]
  result["bada"] = @["बड़ा"]
  result["badi"] = @["बड़ी"]
  result["bade"] = @["बड़े"]
  result["chota"] = @["छोटा"]
  result["chhota"] = @["छोटा"]
  result["choti"] = @["छोटी"]
  result["chote"] = @["छोटे"]
  result["chhote"] = @["छोटे"]
  result["naya"] = @["नया"]
  result["nayi"] = @["नई"]
  result["naye"] = @["नए"]
  result["purana"] = @["पुराना"]
  result["purani"] = @["पुरानी"]
  result["purane"] = @["पुराने"]
  result["sahi"] = @["सही"]
  result["galat"] = @["ग़लत"]
  result["thik"] = @["ठीक"]
  result["theek"] = @["ठीक"]
  result["sundar"] = @["सुंदर"]
  result["khoobsurat"] = @["खूबसूरत"]
  result["khubsurat"] = @["खूबसूरत"]
  result["mahan"] = @["महान"]
  result["kamzor"] = @["कमज़ोर"]
  result["mazboot"] = @["मज़बूत"]
  result["mazbut"] = @["मज़बूत"]
  result["tez"] = @["तेज़"]
  result["dheema"] = @["धीमा"]
  result["garam"] = @["गरम"]
  result["thanda"] = @["ठंडा"]
  result["mitha"] = @["मीठा"]
  result["meetha"] = @["मीठा"]
  result["khatta"] = @["खट्टा"]
  result["bhara"] = @["भरा"]
  result["khali"] = @["खाली"]
  result["pura"] = @["पूरा"]
  result["poora"] = @["पूरा"]
  result["aadha"] = @["आधा"]

  # ============ ADVERBS ============
  result["bahut"] = @["बहुत"]
  result["bahot"] = @["बहुत"]
  result["bohot"] = @["बहुत"]
  result["zyada"] = @["ज़्यादा"]
  result["zada"] = @["ज़्यादा"]
  result["jyada"] = @["ज़्यादा"]
  result["thoda"] = @["थोड़ा"]
  result["thora"] = @["थोड़ा"]
  result["bilkul"] = @["बिलकुल"]
  result["ekdum"] = @["एकदम"]
  result["hamesha"] = @["हमेशा"]
  result["kabhi"] = @["कभी"]
  result["aksar"] = @["अक्सर"]
  result["phir"] = @["फिर"]
  result["fir"] = @["फिर"]
  result["yahan"] = @["यहाँ"]
  result["yaha"] = @["यहाँ"]
  result["wahan"] = @["वहाँ"]
  result["waha"] = @["वहाँ"]
  result["jahan"] = @["जहाँ"]
  result["jaha"] = @["जहाँ"]
  result["aise"] = @["ऐसे"]
  result["waise"] = @["वैसे"]
  result["vaise"] = @["वैसे"]
  result["vaishe"] = @["वैसे"]
  result["isliye"] = @["इसलिए"]
  result["kyunki"] = @["क्योंकि"]
  result["kyonki"] = @["क्योंकि"]
  result["lekin"] = @["लेकिन"]
  result["magar"] = @["मगर"]
  result["sirf"] = @["सिर्फ़"]
  result["bas"] = @["बस"]
  result["lagbhag"] = @["लगभग"]
  result["kaafi"] = @["काफी"]
  result["kafi"] = @["काफी"]
  result["almost"] = @["ऑलमोस्ट"]
  result["exact"] = @["एक्ज़ैक्ट"]
  result["accordingly"] = @["एकॉर्डिंगली"]

  # ============ QUESTION WORDS ============
  result["kya"] = @["क्या"]
  result["kyun"] = @["क्यों"]
  result["kyon"] = @["क्यों"]
  result["kaise"] = @["कैसे"]
  result["kahan"] = @["कहाँ"]
  result["kaha"] = @["कहाँ", "कहा"]
  result["kab"] = @["कब"]
  result["kaun"] = @["कौन"]
  result["koun"] = @["कौन"]
  result["kitna"] = @["कितना"]
  result["kitne"] = @["कितने"]
  result["kitni"] = @["कितनी"]
  result["konsa"] = @["कौनसा"]
  result["kaunsa"] = @["कौनसा"]
  result["kaisa"] = @["कैसा"]
  result["kaisi"] = @["कैसी"]

  # ============ POSTPOSITIONS ============
  result["ka"] = @["का"]
  result["ki"] = @["की"]
  result["ke"] = @["के"]
  result["ko"] = @["को"]
  result["se"] = @["से"]
  result["mein"] = @["में"]
  result["me"] = @["में"]
  result["may"] = @["में"]
  result["par"] = @["पर"]
  result["tak"] = @["तक"]
  result["thak"] = @["तक"]
  result["liye"] = @["लिए"]
  result["saath"] = @["साथ"]
  result["sath"] = @["साथ"]
  result["bina"] = @["बिना"]
  result["andar"] = @["अंदर"]
  result["bahar"] = @["बाहर"]
  result["upar"] = @["ऊपर"]
  result["upr"] = @["ऊपर"]
  result["niche"] = @["नीचे"]
  result["neeche"] = @["नीचे"]
  result["aage"] = @["आगे"]
  result["peeche"] = @["पीछे"]
  result["piche"] = @["पीछे"]
  result["paas"] = @["पास"]
  result["pass"] = @["पास"]
  result["door"] = @["दूर"]
  result["dur"] = @["दूर"]

  # ============ CONJUNCTIONS ============
  result["aur"] = @["और"]
  result["or"] = @["और"]
  result["ya"] = @["या"]
  result["toh"] = @["तो"]
  result["to"] = @["तो"]
  result["ki"] = @["कि"]
  result["jo"] = @["जो"]
  result["agar"] = @["अगर"]
  result["agr"] = @["अगर"]

  # ============ NUMBERS ============
  result["ek"] = @["एक"]
  result["do"] = @["दो"]
  result["teen"] = @["तीन"]
  result["tin"] = @["तीन"]
  result["chaar"] = @["चार"]
  result["char"] = @["चार"]
  result["paanch"] = @["पाँच"]
  result["panch"] = @["पाँच"]
  result["cheh"] = @["छह"]
  result["chah"] = @["छह"]
  result["saat"] = @["सात"]
  result["aath"] = @["आठ"]
  result["ath"] = @["आठ"]
  result["nau"] = @["नौ"]
  result["das"] = @["दस"]
  result["gyarah"] = @["ग्यारह"]
  result["barah"] = @["बारह"]
  result["terah"] = @["तेरह"]
  result["chaudah"] = @["चौदह"]
  result["pandrah"] = @["पंद्रह"]
  result["solah"] = @["सोलह"]
  result["satrah"] = @["सत्रह"]
  result["atharah"] = @["अठारह"]
  result["unnis"] = @["उन्नीस"]
  result["bees"] = @["बीस"]
  result["pachas"] = @["पचास"]
  result["sau"] = @["सौ"]
  result["hazaar"] = @["हज़ार"]
  result["hazar"] = @["हज़ार"]
  result["lakh"] = @["लाख"]
  result["crore"] = @["करोड़"]

# ============ ORDINAL NUMBERS (1-100) ============
  result["aathva"] = @["आठवाँ"]
  result["aathvi"] = @["आठवीं"]
  result["aathwa"] = @["आठवाँ"]
  result["aathwan"] = @["आठवाँ"]
  result["aathwe"] = @["आठवें"]
  result["adhtalisva"] = @["अड़तालीसवाँ"]
  result["adhtalisvi"] = @["अड़तालीसवीं"]
  result["adhtaliswa"] = @["अड़तालीसवाँ"]
  result["adhtaliswan"] = @["अड़तालीसवाँ"]
  result["adhtisva"] = @["अड़तीसवाँ"]
  result["adhtisvi"] = @["अड़तीसवीं"]
  result["adhtiswa"] = @["अड़तीसवाँ"]
  result["adhtiswan"] = @["अड़तीसवाँ"]
  result["adsath"] = @["अड़सठवाँ"]
  result["adsathva"] = @["अड़सठवाँ"]
  result["adsathvi"] = @["अड़सठवीं"]
  result["adsathwa"] = @["अड़सठवाँ"]
  result["adsathwan"] = @["अड़सठवाँ"]
  result["assi"] = @["अस्सीवाँ"]
  result["assi_vi"] = @["अस्सीवीं"]
  result["assiva"] = @["अस्सीवाँ"]
  result["assivi"] = @["अस्सीवीं"]
  result["assiwa"] = @["अस्सीवाँ"]
  result["assiwan"] = @["अस्सीवाँ"]
  result["atharahva"] = @["अठारहवाँ"]
  result["atharahvi"] = @["अठारहवीं"]
  result["atharahwa"] = @["अठारहवाँ"]
  result["atharahwan"] = @["अठारहवाँ"]
  result["athhattar"] = @["अठहत्तरवाँ"]
  result["athhattarva"] = @["अठहत्तरवाँ"]
  result["athhattarvi"] = @["अठहत्तरवीं"]
  result["athhattarwa"] = @["अठहत्तरवाँ"]
  result["athhattarwan"] = @["अठहत्तरवाँ"]
  result["athva"] = @["आठवाँ"]
  result["athvi"] = @["आठवीं"]
  result["athwa"] = @["आठवाँ"]
  result["athwan"] = @["आठवाँ"]
  result["athwe"] = @["आठवें"]
  result["atthaanve"] = @["अट्ठानवेवाँ"]
  result["atthaanve_vi"] = @["अट्ठानवेवीं"]
  result["atthaanveva"] = @["अट्ठानवेवाँ"]
  result["atthaanvevi"] = @["अट्ठानवेवीं"]
  result["atthaanvewa"] = @["अट्ठानवेवाँ"]
  result["atthaanvewan"] = @["अट्ठानवेवाँ"]
  result["atthaasi"] = @["अट्ठासीवाँ"]
  result["atthaasi_vi"] = @["अट्ठासीवीं"]
  result["atthaasiva"] = @["अट्ठासीवाँ"]
  result["atthaasivi"] = @["अट्ठासीवीं"]
  result["atthaasiwa"] = @["अट्ठासीवाँ"]
  result["atthaasiwan"] = @["अट्ठासीवाँ"]
  result["atthaisva"] = @["अट्ठाईसवाँ"]
  result["atthaisvi"] = @["अट्ठाईसवीं"]
  result["atthaiswa"] = @["अट्ठाईसवाँ"]
  result["atthaiswan"] = @["अट्ठाईसवाँ"]
  result["atthavan"] = @["अट्ठावनवाँ"]
  result["atthavanva"] = @["अट्ठावनवाँ"]
  result["atthavanvi"] = @["अट्ठावनवीं"]
  result["atthavanwa"] = @["अट्ठावनवाँ"]
  result["atthavanwan"] = @["अट्ठावनवाँ"]
  result["baanve"] = @["बानवेवाँ"]
  result["baanve_vi"] = @["बानवेवीं"]
  result["baanveva"] = @["बानवेवाँ"]
  result["baanvevi"] = @["बानवेवीं"]
  result["baanvewa"] = @["बानवेवाँ"]
  result["baanvewan"] = @["बानवेवाँ"]
  result["baasath"] = @["बासठवाँ"]
  result["baasathva"] = @["बासठवाँ"]
  result["baasathvi"] = @["बासठवीं"]
  result["baasathwa"] = @["बासठवाँ"]
  result["baasathwan"] = @["बासठवाँ"]
  result["baeesva"] = @["बाईसवाँ"]
  result["baeesvi"] = @["बाईसवीं"]
  result["baeeswa"] = @["बाईसवाँ"]
  result["baeeswan"] = @["बाईसवाँ"]
  result["bahattar"] = @["बहत्तरवाँ"]
  result["bahattarva"] = @["बहत्तरवाँ"]
  result["bahattarvi"] = @["बहत्तरवीं"]
  result["bahattarwa"] = @["बहत्तरवाँ"]
  result["bahattarwan"] = @["बहत्तरवाँ"]
  result["barahva"] = @["बारहवाँ"]
  result["barahvi"] = @["बारहवीं"]
  result["barahwa"] = @["बारहवाँ"]
  result["barahwan"] = @["बारहवाँ"]
  result["battisva"] = @["बत्तीसवाँ"]
  result["battisvi"] = @["बत्तीसवीं"]
  result["battiswa"] = @["बत्तीसवाँ"]
  result["battiswan"] = @["बत्तीसवाँ"]
  result["bavan"] = @["बावनवाँ"]
  result["bavanva"] = @["बावनवाँ"]
  result["bavanvi"] = @["बावनवीं"]
  result["bavanwa"] = @["बावनवाँ"]
  result["bavanwan"] = @["बावनवाँ"]
  result["bayaasi"] = @["बयासीवाँ"]
  result["bayaasi_vi"] = @["बयासीवीं"]
  result["bayaasiva"] = @["बयासीवाँ"]
  result["bayaasivi"] = @["बयासीवीं"]
  result["bayaasiwa"] = @["बयासीवाँ"]
  result["bayaasiwan"] = @["बयासीवाँ"]
  result["bayalisva"] = @["बयालीसवाँ"]
  result["bayalisvi"] = @["बयालीसवीं"]
  result["bayaliswa"] = @["बयालीसवाँ"]
  result["bayaliswan"] = @["बयालीसवाँ"]
  result["beesva"] = @["बीसवाँ"]
  result["beesvi"] = @["बीसवीं"]
  result["beeswa"] = @["बीसवाँ"]
  result["beeswan"] = @["बीसवाँ"]
  result["chalisva"] = @["चालीसवाँ"]
  result["chalisvi"] = @["चालीसवीं"]
  result["chaliswa"] = @["चालीसवाँ"]
  result["chaliswan"] = @["चालीसवाँ"]
  result["chaubisva"] = @["चौबीसवाँ"]
  result["chaubisvi"] = @["चौबीसवीं"]
  result["chaubiswa"] = @["चौबीसवाँ"]
  result["chaubiswan"] = @["चौबीसवाँ"]
  result["chaudahva"] = @["चौदहवाँ"]
  result["chaudahvi"] = @["चौदहवीं"]
  result["chaudahwa"] = @["चौदहवाँ"]
  result["chaudahwan"] = @["चौदहवाँ"]
  result["chauhattar"] = @["चौहत्तरवाँ"]
  result["chauhattarva"] = @["चौहत्तरवाँ"]
  result["chauhattarvi"] = @["चौहत्तरवीं"]
  result["chauhattarwa"] = @["चौहत्तरवाँ"]
  result["chauhattarwan"] = @["चौहत्तरवाँ"]
  result["chauntisva"] = @["चौंतीसवाँ"]
  result["chauntisvi"] = @["चौंतीसवीं"]
  result["chauntiswa"] = @["चौंतीसवाँ"]
  result["chauntiswan"] = @["चौंतीसवाँ"]
  result["chauraasi"] = @["चौरासीवाँ"]
  result["chauraasi_vi"] = @["चौरासीवीं"]
  result["chauraasiva"] = @["चौरासीवाँ"]
  result["chauraasivi"] = @["चौरासीवीं"]
  result["chauraasiwa"] = @["चौरासीवाँ"]
  result["chauraasiwan"] = @["चौरासीवाँ"]
  result["chauranve"] = @["चौरानवेवाँ"]
  result["chauranve_vi"] = @["चौरानवेवीं"]
  result["chauranveva"] = @["चौरानवेवाँ"]
  result["chauranvevi"] = @["चौरानवेवीं"]
  result["chauranvewa"] = @["चौरानवेवाँ"]
  result["chauranvewan"] = @["चौरानवेवाँ"]
  result["chausath"] = @["चौसठवाँ"]
  result["chausathva"] = @["चौसठवाँ"]
  result["chausathvi"] = @["चौसठवीं"]
  result["chausathwa"] = @["चौसठवाँ"]
  result["chausathwan"] = @["चौसठवाँ"]
  result["chautha"] = @["चौथा"]
  result["chauthe"] = @["चौथे"]
  result["chauthi"] = @["चौथी"]
  result["chauvan"] = @["चौवनवाँ"]
  result["chauvanva"] = @["चौवनवाँ"]
  result["chauvanvi"] = @["चौवनवीं"]
  result["chauvanwa"] = @["चौवनवाँ"]
  result["chauvanwan"] = @["चौवनवाँ"]
  result["chavalisva"] = @["चवालीसवाँ"]
  result["chavalisvi"] = @["चवालीसवीं"]
  result["chavaliswa"] = @["चवालीसवाँ"]
  result["chavaliswan"] = @["चवालीसवाँ"]
  result["chhabbisva"] = @["छब्बीसवाँ"]
  result["chhabbisvi"] = @["छब्बीसवीं"]
  result["chhabbiswa"] = @["छब्बीसवाँ"]
  result["chhabbiswan"] = @["छब्बीसवाँ"]
  result["chhappan"] = @["छप्पनवाँ"]
  result["chhappanva"] = @["छप्पनवाँ"]
  result["chhappanvi"] = @["छप्पनवीं"]
  result["chhappanwa"] = @["छप्पनवाँ"]
  result["chhappanwan"] = @["छप्पनवाँ"]
  result["chhatha"] = @["छठा"]
  result["chhathe"] = @["छठे"]
  result["chhathi"] = @["छठी"]
  result["chhattisva"] = @["छत्तीसवाँ"]
  result["chhattisvi"] = @["छत्तीसवीं"]
  result["chhattiswa"] = @["छत्तीसवाँ"]
  result["chhattiswan"] = @["छत्तीसवाँ"]
  result["chhihattar"] = @["छिहत्तरवाँ"]
  result["chhihattarva"] = @["छिहत्तरवाँ"]
  result["chhihattarvi"] = @["छिहत्तरवीं"]
  result["chhihattarwa"] = @["छिहत्तरवाँ"]
  result["chhihattarwan"] = @["छिहत्तरवाँ"]
  result["chhiyaanve"] = @["छियानवेवाँ"]
  result["chhiyaanve_vi"] = @["छियानवेवीं"]
  result["chhiyaanveva"] = @["छियानवेवाँ"]
  result["chhiyaanvevi"] = @["छियानवेवीं"]
  result["chhiyaanvewa"] = @["छियानवेवाँ"]
  result["chhiyaanvewan"] = @["छियानवेवाँ"]
  result["chhiyaasi"] = @["छियासीवाँ"]
  result["chhiyaasi_vi"] = @["छियासीवीं"]
  result["chhiyaasiva"] = @["छियासीवाँ"]
  result["chhiyaasivi"] = @["छियासीवीं"]
  result["chhiyaasiwa"] = @["छियासीवाँ"]
  result["chhiyaasiwan"] = @["छियासीवाँ"]
  result["chhiyalisva"] = @["छियालीसवाँ"]
  result["chhiyalisvi"] = @["छियालीसवीं"]
  result["chhiyaliswa"] = @["छियालीसवाँ"]
  result["chhiyaliswan"] = @["छियालीसवाँ"]
  result["chhiyasath"] = @["छियासठवाँ"]
  result["chhiyasathva"] = @["छियासठवाँ"]
  result["chhiyasathvi"] = @["छियासठवीं"]
  result["chhiyasathwa"] = @["छियासठवाँ"]
  result["chhiyasathwan"] = @["छियासठवाँ"]
  result["chotha"] = @["चौथा"]
  result["chothe"] = @["चौथे"]
  result["chothi"] = @["चौथी"]
  result["dasva"] = @["दसवाँ"]
  result["dasvi"] = @["दसवीं"]
  result["daswa"] = @["दसवाँ"]
  result["daswan"] = @["दसवाँ"]
  result["daswe"] = @["दसवें"]
  result["doosra"] = @["दूसरा"]
  result["doosre"] = @["दूसरे"]
  result["doosri"] = @["दूसरी"]
  result["dusra"] = @["दूसरा"]
  result["dusre"] = @["दूसरे"]
  result["dusri"] = @["दूसरी"]
  result["gyarahva"] = @["ग्यारहवाँ"]
  result["gyarahvi"] = @["ग्यारहवीं"]
  result["gyarahwa"] = @["ग्यारहवाँ"]
  result["gyarahwan"] = @["ग्यारहवाँ"]
  result["ikattisva"] = @["इकतीसवाँ"]
  result["ikattisvi"] = @["इकतीसवीं"]
  result["ikattiswa"] = @["इकतीसवाँ"]
  result["ikattiswan"] = @["इकतीसवाँ"]
  result["ikhattar"] = @["इकहत्तरवाँ"]
  result["ikhattarva"] = @["इकहत्तरवाँ"]
  result["ikhattarvi"] = @["इकहत्तरवीं"]
  result["ikhattarwa"] = @["इकहत्तरवाँ"]
  result["ikhattarwan"] = @["इकहत्तरवाँ"]
  result["ikkeesva"] = @["इक्कीसवाँ"]
  result["ikkeesvi"] = @["इक्कीसवीं"]
  result["ikkeeswa"] = @["इक्कीसवाँ"]
  result["ikkeeswan"] = @["इक्कीसवाँ"]
  result["iksath"] = @["इकसठवाँ"]
  result["iksathva"] = @["इकसठवाँ"]
  result["iksathvi"] = @["इकसठवीं"]
  result["iksathwa"] = @["इकसठवाँ"]
  result["iksathwan"] = @["इकसठवाँ"]
  result["iktalisva"] = @["इकतालीसवाँ"]
  result["iktalisvi"] = @["इकतालीसवीं"]
  result["iktaliswa"] = @["इकतालीसवाँ"]
  result["iktaliswan"] = @["इकतालीसवाँ"]
  result["ikyaanve"] = @["इक्यानवेवाँ"]
  result["ikyaanve_vi"] = @["इक्यानवेवीं"]
  result["ikyaanveva"] = @["इक्यानवेवाँ"]
  result["ikyaanvevi"] = @["इक्यानवेवीं"]
  result["ikyaanvewa"] = @["इक्यानवेवाँ"]
  result["ikyaanvewan"] = @["इक्यानवेवाँ"]
  result["ikyaasi"] = @["इक्यासीवाँ"]
  result["ikyaasi_vi"] = @["इक्यासीवीं"]
  result["ikyaasiva"] = @["इक्यासीवाँ"]
  result["ikyaasivi"] = @["इक्यासीवीं"]
  result["ikyaasiwa"] = @["इक्यासीवाँ"]
  result["ikyaasiwan"] = @["इक्यासीवाँ"]
  result["ikyaavan"] = @["इक्यावनवाँ"]
  result["ikyaavanva"] = @["इक्यावनवाँ"]
  result["ikyaavanvi"] = @["इक्यावनवीं"]
  result["ikyaavanwa"] = @["इक्यावनवाँ"]
  result["ikyaavanwan"] = @["इक्यावनवाँ"]
  result["nabbe"] = @["नब्बेवाँ"]
  result["nabbe_vi"] = @["नब्बेवीं"]
  result["nabbeva"] = @["नब्बेवाँ"]
  result["nabbevi"] = @["नब्बेवीं"]
  result["nabbewa"] = @["नब्बेवाँ"]
  result["nabbewan"] = @["नब्बेवाँ"]
  result["nauva"] = @["नौवाँ"]
  result["nauvi"] = @["नौवीं"]
  result["nauwa"] = @["नौवाँ"]
  result["nauwan"] = @["नौवाँ"]
  result["nauwe"] = @["नौवें"]
  result["nawaan"] = @["नौवाँ"]
  result["nawasi"] = @["नवासीवाँ"]
  result["nawasi_vi"] = @["नवासीवीं"]
  result["nawasiva"] = @["नवासीवाँ"]
  result["nawasivi"] = @["नवासीवीं"]
  result["nawasiwa"] = @["नवासीवाँ"]
  result["nawasiwan"] = @["नवासीवाँ"]
  result["ninyaanve"] = @["निन्यानवेवाँ"]
  result["ninyaanve_vi"] = @["निन्यानवेवीं"]
  result["ninyaanveva"] = @["निन्यानवेवाँ"]
  result["ninyaanvevi"] = @["निन्यानवेवीं"]
  result["ninyaanvewa"] = @["निन्यानवेवाँ"]
  result["ninyaanvewan"] = @["निन्यानवेवाँ"]
  result["paanchva"] = @["पाँचवाँ"]
  result["paanchvi"] = @["पाँचवीं"]
  result["paanchwa"] = @["पाँचवाँ"]
  result["paanchwan"] = @["पाँचवाँ"]
  result["paanchwe"] = @["पाँचवें"]
  result["pachaanve"] = @["पचानवेवाँ"]
  result["pachaanve_vi"] = @["पचानवेवीं"]
  result["pachaanveva"] = @["पचानवेवाँ"]
  result["pachaanvevi"] = @["पचानवेवीं"]
  result["pachaanvewa"] = @["पचानवेवाँ"]
  result["pachaanvewan"] = @["पचानवेवाँ"]
  result["pachaasi"] = @["पचासीवाँ"]
  result["pachaasi_vi"] = @["पचासीवीं"]
  result["pachaasiva"] = @["पचासीवाँ"]
  result["pachaasivi"] = @["पचासीवीं"]
  result["pachaasiwa"] = @["पचासीवाँ"]
  result["pachaasiwan"] = @["पचासीवाँ"]
  result["pachasva"] = @["पचासवाँ"]
  result["pachasvi"] = @["पचासवीं"]
  result["pachaswa"] = @["पचासवाँ"]
  result["pachaswan"] = @["पचासवाँ"]
  result["pachattar"] = @["पचहत्तरवाँ"]
  result["pachattarva"] = @["पचहत्तरवाँ"]
  result["pachattarvi"] = @["पचहत्तरवीं"]
  result["pachattarwa"] = @["पचहत्तरवाँ"]
  result["pachattarwan"] = @["पचहत्तरवाँ"]
  result["pachchisva"] = @["पच्चीसवाँ"]
  result["pachchisvi"] = @["पच्चीसवीं"]
  result["pachchiswa"] = @["पच्चीसवाँ"]
  result["pachchiswan"] = @["पच्चीसवाँ"]
  result["pachpan"] = @["पचपनवाँ"]
  result["pachpanva"] = @["पचपनवाँ"]
  result["pachpanvi"] = @["पचपनवीं"]
  result["pachpanwa"] = @["पचपनवाँ"]
  result["pachpanwan"] = @["पचपनवाँ"]
  result["pahla"] = @["पहला"]
  result["pahle"] = @["पहले"]
  result["pahli"] = @["पहली"]
  result["painntalisva"] = @["पैंतालीसवाँ"]
  result["painntalisvi"] = @["पैंतालीसवीं"]
  result["painntaliswa"] = @["पैंतालीसवाँ"]
  result["painntaliswan"] = @["पैंतालीसवाँ"]
  result["painntisva"] = @["पैंतीसवाँ"]
  result["painntisvi"] = @["पैंतीसवीं"]
  result["painntiswa"] = @["पैंतीसवाँ"]
  result["painntiswan"] = @["पैंतीसवाँ"]
  result["painsath"] = @["पैंसठवाँ"]
  result["painsathva"] = @["पैंसठवाँ"]
  result["painsathvi"] = @["पैंसठवीं"]
  result["painsathwa"] = @["पैंसठवाँ"]
  result["painsathwan"] = @["पैंसठवाँ"]
  result["paintalisva"] = @["पैंतालीसवाँ"]
  result["paintalisvi"] = @["पैंतालीसवीं"]
  result["paintaliswa"] = @["पैंतालीसवाँ"]
  result["paintaliswan"] = @["पैंतालीसवाँ"]
  result["paintisva"] = @["पैंतीसवाँ"]
  result["paintisvi"] = @["पैंतीसवीं"]
  result["paintiswa"] = @["पैंतीसवाँ"]
  result["paintiswan"] = @["पैंतीसवाँ"]
  result["panchva"] = @["पाँचवाँ"]
  result["panchvi"] = @["पाँचवीं"]
  result["panchwa"] = @["पाँचवाँ"]
  result["panchwan"] = @["पाँचवाँ"]
  result["panchwe"] = @["पाँचवें"]
  result["pandrahva"] = @["पंद्रहवाँ"]
  result["pandrahvi"] = @["पंद्रहवीं"]
  result["pandrahwa"] = @["पंद्रहवाँ"]
  result["pandrahwan"] = @["पंद्रहवाँ"]
  result["pehla"] = @["पहला"]
  result["pehle"] = @["पहले"]
  result["pehli"] = @["पहली"]
  result["saath"] = @["साठवाँ"]
  result["saathva"] = @["साठवाँ"]
  result["saathvi"] = @["साठवीं"]
  result["saathwa"] = @["साठवाँ"]
  result["saathwan"] = @["साठवाँ"]
  result["saatva"] = @["सातवाँ"]
  result["saatvi"] = @["सातवीं"]
  result["saatwa"] = @["सातवाँ"]
  result["saatwan"] = @["सातवाँ"]
  result["saatwe"] = @["सातवें"]
  result["sainntalisva"] = @["सैंतालीसवाँ"]
  result["sainntalisvi"] = @["सैंतालीसवीं"]
  result["sainntaliswa"] = @["सैंतालीसवाँ"]
  result["sainntaliswan"] = @["सैंतालीसवाँ"]
  result["sainntisva"] = @["सैंतीसवाँ"]
  result["sainntisvi"] = @["सैंतीसवीं"]
  result["sainntiswa"] = @["सैंतीसवाँ"]
  result["sainntiswan"] = @["सैंतीसवाँ"]
  result["saintalisva"] = @["सैंतालीसवाँ"]
  result["saintalisvi"] = @["सैंतालीसवीं"]
  result["saintaliswa"] = @["सैंतालीसवाँ"]
  result["saintaliswan"] = @["सैंतालीसवाँ"]
  result["saintisva"] = @["सैंतीसवाँ"]
  result["saintisvi"] = @["सैंतीसवीं"]
  result["saintiswa"] = @["सैंतीसवाँ"]
  result["saintiswan"] = @["सैंतीसवाँ"]
  result["sarsath"] = @["सड़सठवाँ"]
  result["sarsathva"] = @["सड़सठवाँ"]
  result["sarsathvi"] = @["सड़सठवीं"]
  result["sarsathwa"] = @["सड़सठवाँ"]
  result["sarsathwan"] = @["सड़सठवाँ"]
  result["satahattar"] = @["सतहत्तरवाँ"]
  result["satahattarva"] = @["सतहत्तरवाँ"]
  result["satahattarvi"] = @["सतहत्तरवीं"]
  result["satahattarwa"] = @["सतहत्तरवाँ"]
  result["satahattarwan"] = @["सतहत्तरवाँ"]
  result["satrahva"] = @["सत्रहवाँ"]
  result["satrahvi"] = @["सत्रहवीं"]
  result["satrahwa"] = @["सत्रहवाँ"]
  result["satrahwan"] = @["सत्रहवाँ"]
  result["sattaanve"] = @["सत्तानवेवाँ"]
  result["sattaanve_vi"] = @["सत्तानवेवीं"]
  result["sattaanveva"] = @["सत्तानवेवाँ"]
  result["sattaanvevi"] = @["सत्तानवेवीं"]
  result["sattaanvewa"] = @["सत्तानवेवाँ"]
  result["sattaanvewan"] = @["सत्तानवेवाँ"]
  result["sattaasi"] = @["सत्तासीवाँ"]
  result["sattaasi_vi"] = @["सत्तासीवीं"]
  result["sattaasiva"] = @["सत्तासीवाँ"]
  result["sattaasivi"] = @["सत्तासीवीं"]
  result["sattaasiwa"] = @["सत्तासीवाँ"]
  result["sattaasiwan"] = @["सत्तासीवाँ"]
  result["sattaisva"] = @["सत्ताईसवाँ"]
  result["sattaisvi"] = @["सत्ताईसवीं"]
  result["sattaiswa"] = @["सत्ताईसवाँ"]
  result["sattaiswan"] = @["सत्ताईसवाँ"]
  result["sattar"] = @["सत्तरवाँ"]
  result["sattarva"] = @["सत्तरवाँ"]
  result["sattarvi"] = @["सत्तरवीं"]
  result["sattarwa"] = @["सत्तरवाँ"]
  result["sattarwan"] = @["सत्तरवाँ"]
  result["sattavan"] = @["सत्तावनवाँ"]
  result["sattavanva"] = @["सत्तावनवाँ"]
  result["sattavanvi"] = @["सत्तावनवीं"]
  result["sattavanwa"] = @["सत्तावनवाँ"]
  result["sattavanwan"] = @["सत्तावनवाँ"]
  result["satva"] = @["सातवाँ"]
  result["satvi"] = @["सातवीं"]
  result["satwa"] = @["सातवाँ"]
  result["satwan"] = @["सातवाँ"]
  result["satwe"] = @["सातवें"]
  result["sauva"] = @["सौवाँ"]
  result["sauvi"] = @["सौवीं"]
  result["sauwa"] = @["सौवाँ"]
  result["sauwan"] = @["सौवाँ"]
  result["solahva"] = @["सोलहवाँ"]
  result["solahvi"] = @["सोलहवीं"]
  result["solahwa"] = @["सोलहवाँ"]
  result["solahwan"] = @["सोलहवाँ"]
  result["taintalisva"] = @["तैंतालीसवाँ"]
  result["taintalisvi"] = @["तैंतालीसवीं"]
  result["taintaliswa"] = @["तैंतालीसवाँ"]
  result["taintaliswan"] = @["तैंतालीसवाँ"]
  result["taintisva"] = @["तैंतीसवाँ"]
  result["taintisvi"] = @["तैंतीसवीं"]
  result["taintiswa"] = @["तैंतीसवाँ"]
  result["taintiswan"] = @["तैंतीसवाँ"]
  result["teesra"] = @["तीसरा"]
  result["teesre"] = @["तीसरे"]
  result["teesri"] = @["तीसरी"]
  result["teesva"] = @["तीसवाँ"]
  result["teesvi"] = @["तीसवीं"]
  result["teeswa"] = @["तीसवाँ"]
  result["teeswan"] = @["तीसवाँ"]
  result["teisva"] = @["तेईसवाँ"]
  result["teisvi"] = @["तेईसवीं"]
  result["teiswa"] = @["तेईसवाँ"]
  result["teiswan"] = @["तेईसवाँ"]
  result["terahva"] = @["तेरहवाँ"]
  result["terahvi"] = @["तेरहवीं"]
  result["terahwa"] = @["तेरहवाँ"]
  result["terahwan"] = @["तेरहवाँ"]
  result["tihattar"] = @["तिहत्तरवाँ"]
  result["tihattarva"] = @["तिहत्तरवाँ"]
  result["tihattarvi"] = @["तिहत्तरवीं"]
  result["tihattarwa"] = @["तिहत्तरवाँ"]
  result["tihattarwan"] = @["तिहत्तरवाँ"]
  result["tiraasi"] = @["तिरासीवाँ"]
  result["tiraasi_vi"] = @["तिरासीवीं"]
  result["tiraasiva"] = @["तिरासीवाँ"]
  result["tiraasivi"] = @["तिरासीवीं"]
  result["tiraasiwa"] = @["तिरासीवाँ"]
  result["tiraasiwan"] = @["तिरासीवाँ"]
  result["tiranve"] = @["तिरानवेवाँ"]
  result["tiranve_vi"] = @["तिरानवेवीं"]
  result["tiranveva"] = @["तिरानवेवाँ"]
  result["tiranvevi"] = @["तिरानवेवीं"]
  result["tiranvewa"] = @["तिरानवेवाँ"]
  result["tiranvewan"] = @["तिरानवेवाँ"]
  result["tirpan"] = @["तिरपनवाँ"]
  result["tirpanva"] = @["तिरपनवाँ"]
  result["tirpanvi"] = @["तिरपनवीं"]
  result["tirpanwa"] = @["तिरपनवाँ"]
  result["tirpanwan"] = @["तिरपनवाँ"]
  result["tirsath"] = @["तिरसठवाँ"]
  result["tirsathva"] = @["तिरसठवाँ"]
  result["tirsathvi"] = @["तिरसठवीं"]
  result["tirsathwa"] = @["तिरसठवाँ"]
  result["tirsathwan"] = @["तिरसठवाँ"]
  result["tisra"] = @["तीसरा"]
  result["tisre"] = @["तीसरे"]
  result["tisri"] = @["तीसरी"]
  result["unasi"] = @["उनासीवाँ"]
  result["unasi_vi"] = @["उनासीवीं"]
  result["unasiva"] = @["उनासीवाँ"]
  result["unasivi"] = @["उनासीवीं"]
  result["unasiwa"] = @["उनासीवाँ"]
  result["unasiwan"] = @["उनासीवाँ"]
  result["unchasva"] = @["उनचासवाँ"]
  result["unchasvi"] = @["उनचासवीं"]
  result["unchaswa"] = @["उनचासवाँ"]
  result["unchaswan"] = @["उनचासवाँ"]
  result["unhattar"] = @["उनहत्तरवाँ"]
  result["unhattarva"] = @["उनहत्तरवाँ"]
  result["unhattarvi"] = @["उनहत्तरवीं"]
  result["unhattarwa"] = @["उनहत्तरवाँ"]
  result["unhattarwan"] = @["उनहत्तरवाँ"]
  result["unnatisva"] = @["उनतीसवाँ"]
  result["unnatisvi"] = @["उनतीसवीं"]
  result["unnatiswa"] = @["उनतीसवाँ"]
  result["unnatiswan"] = @["उनतीसवाँ"]
  result["unnisva"] = @["उन्नीसवाँ"]
  result["unnisvi"] = @["उन्नीसवीं"]
  result["unniswa"] = @["उन्नीसवाँ"]
  result["unniswan"] = @["उन्नीसवाँ"]
  result["unsath"] = @["उनसठवाँ"]
  result["unsathva"] = @["उनसठवाँ"]
  result["unsathvi"] = @["उनसठवीं"]
  result["unsathwa"] = @["उनसठवाँ"]
  result["unsathwan"] = @["उनसठवाँ"]
  result["untalisva"] = @["उनतालीसवाँ"]
  result["untalisvi"] = @["उनतालीसवीं"]
  result["untaliswa"] = @["उनतालीसवाँ"]
  result["untaliswan"] = @["उनतालीसवाँ"]

  # ============ GREETINGS ============
  result["namaste"] = @["नमस्ते"]
  result["namaskar"] = @["नमस्कार"]
  result["salaam"] = @["सलाम"]
  result["salam"] = @["सलाम"]
  result["dhanyawad"] = @["धन्यवाद"]
  result["dhanyavad"] = @["धन्यवाद"]
  result["shukriya"] = @["शुक्रिया"]
  result["alvida"] = @["अलविदा"]
  result["swagat"] = @["स्वागत"]
  result["hello"] = @["हैलो"]
  result["ok"] = @["ओके"]
  result["okay"] = @["ओके"]

  # ============ NEGATION ============
  result["nahi"] = @["नहीं"]
  result["nahin"] = @["नहीं"]
  result["nhi"] = @["नहीं"]
  result["nhii"] = @["नहीं"]
  result["nhiii"] = @["नहीं"]
  result["nai"] = @["नहीं"]
  result["na"] = @["ना"]
  result["naa"] = @["ना"]
  result["mat"] = @["मत"]

  # ============ AGREEMENT ============
  result["haan"] = @["हाँ"]
  result["han"] = @["हाँ"]
  result["hn"] = @["हाँ"]
  result["hmm"] = @["हम्म"]

  # ============ MISC ============
  result["bhi"] = @["भी"]
  result["bhee"] = @["भी"]
  result["vi"] = @["भी"]
  result["hi"] = @["ही"]
  result["hee"] = @["ही"]
  result["sab"] = @["सब"]
  result["sabb"] = @["सब"]
  result["kuch"] = @["कुछ"]
  result["kuchh"] = @["कुछ"]
  result["koi"] = @["कोई"]
  result["koyi"] = @["कोई"]
  result["saare"] = @["सारे"]
  result["sare"] = @["सारे"]
  result["tab"] = @["तब"]
  result["jab"] = @["जब"]
  result["yaar"] = @["यार"]
  result["yar"] = @["यार"]
  result["bro"] = @["ब्रो"]
  result["please"] = @["कृपया"]
  result["kripya"] = @["कृपया"]
  result["sorry"] = @["माफ़"]
  result["maaf"] = @["माफ़"]
  result["maafi"] = @["माफ़ी"]
  result["taaki"] = @["ताकि"]
  result["taki"] = @["ताकि"]
  result["baar"] = @["बार"]
  result["bar"] = @["बार"]
  result["pata"] = @["पता"]
  result["patta"] = @["पता"]
  result["are"] = @["अरे"]
  result["arre"] = @["अरे"]
  result["mean"] = @["मीन"]
  result["jarur"] = @["ज़रूर"]
  result["zarur"] = @["ज़रूर"]
  result["zaroor"] = @["ज़रूर"]
  result["jaroor"] = @["ज़रूर"]

  # ============ CORE CONCEPTS & CULTURE ============
  result["dharm"] = @["धर्म"]
  result["dharma"] = @["धर्म"]
  result["karm"] = @["कर्म"]
  result["karma"] = @["कर्म"]
  result["ram"] = @["राम"]
  result["rama"] = @["राम"]
  result["naam"] = @["नाम"]
  result["nam"] = @["नाम"]
  result["ishq"] = @["इश्क़", "इश्क"]
  result["ishk"] = @["इश्क", "इश्क़"]

  # ============ COLLEGE / EDUCATION ============
  result["practical"] = @["प्रैक्टिकल"]
  result["topic"] = @["टॉपिक"]
  result["topics"] = @["टॉपिक्स"]
  result["doubt"] = @["डाउट"]
  result["subject"] = @["सब्जेक्ट"]
  result["syllabus"] = @["सिलेबस"]
  result["sem"] = @["सेम"]
  result["lab"] = @["लैब"]
  result["project"] = @["प्रोजेक्ट"]
  result["data"] = @["डेटा"]
  result["template"] = @["टेम्पलेट"]
  result["photo"] = @["फोटो"]
  result["spelling"] = @["स्पेलिंग"]
  result["mistake"] = @["मिस्टेक"]
  result["complete"] = @["कंप्लीट"]
  result["portion"] = @["पोर्शन"]
  result["khatam"] = @["खत्म"]

  # ============ GEOGRAPHY & ACADEMIC TERMS ============
  result["rainfall"] = @["रेनफॉल"]
  result["rain"] = @["रेन"]
  result["fall"] = @["फॉल"]
  result["dispersion"] = @["डिस्पर्शन"]
  result["climatic"] = @["क्लाइमेटिक"]
  result["climate"] = @["क्लाइमेट"]
  result["water"] = @["वाटर"]
  result["budget"] = @["बजट"]
  result["mercator"] = @["मर्केटर"]
  result["projection"] = @["प्रोजेक्शन"]
  result["vernier"] = @["वर्नियर"]
  result["scale"] = @["स्केल"]
  result["diagram"] = @["डायग्राम"]
  result["digaram"] = @["डायग्राम"]

  # ============ SHANI STOTRA (Dasharathkrit) ============
  result["dashrathkrit"] = @["दशरथकृत"]
  result["dasharathkrit"] = @["दशरथकृत"]
  result["shani"] = @["शनि"]
  result["stotra"] = @["स्तोत्र"]
  result["stotram"] = @["स्तोत्रम्"]
  result["namah"] = @["नमः"]
  result["namaha"] = @["नमः"]
  result["krishnaya"] = @["कृष्णाय"]
  result["neelaya"] = @["नीलाय"]
  result["nilaya"] = @["नीलाय"]
  result["shitikanth"] = @["शितिकण्ठ"]
  result["shitikantha"] = @["शितिकण्ठ"]
  result["nibhaya"] = @["निभाय"]
  result["ch"] = @["च"]
  result["cha"] = @["च"]
  result["kalagniropaya"] = @["कालाग्निरूपाय"]
  result["kalagnirupaya"] = @["कालाग्निरूपाय"]
  result["kritantaya"] = @["कृतान्ताय"]
  result["vai"] = @["वै"]
  result["namo"] = @["नमो"]
  result["nirmans"] = @["निर्मांस"]
  result["nirmansa"] = @["निर्मांस"]
  result["dehay"] = @["देहाय"]
  result["dehaya"] = @["देहाय"]
  result["dirghashmashrujatay"] = @["दीर्घश्मश्रुजटाय"]
  result["dirghashmashrujataya"] = @["दीर्घश्मश्रुजटाय"]
  result["vishalnetray"] = @["विशालनेत्राय"]
  result["vishalnetraya"] = @["विशालनेत्राय"]
  result["shushkodar"] = @["शुष्कोदर"]
  result["shushkodara"] = @["शुष्कोदर"]
  result["bhayakrite"] = @["भयाकृते"]
  result["pushkalagatray"] = @["पुष्कलगात्राय"]
  result["pushkalagatraya"] = @["पुष्कलगात्राय"]
  result["sthoolaromne"] = @["स्थूलरोम्णे"]
  result["sthularomne"] = @["स्थूलरोम्णे"]
  result["ath"] = @["अथ", "आठ"]
  result["atha"] = @["अथ"]
  result["dirghay"] = @["दीर्घाय"]
  result["dirghaya"] = @["दीर्घाय"]
  result["shushkay"] = @["शुष्काय"]
  result["shushkaya"] = @["शुष्काय"]
  result["kaldanshtra"] = @["कालदंष्ट्र"]
  result["kaladanshtra"] = @["कालदंष्ट्र"]
  result["namostu"] = @["नमोऽस्तु"]
  result["te"] = @["ते"]
  result["namaste"] = @["नमस्ते"]
  result["kotrakshay"] = @["कोटराक्षाय"]
  result["kotrakshaya"] = @["कोटराक्षाय"]
  result["kotarakshaya"] = @["कोटराक्षाय"]
  result["durnarikshyay"] = @["दुर्नरीक्ष्याय"]
  result["durnarikshyaya"] = @["दुर्नरीक्ष्याय"]
  result["ghoray"] = @["घोराय"]
  result["ghoraya"] = @["घोराय"]
  result["raudray"] = @["रौद्राय"]
  result["raudraya"] = @["रौद्राय"]
  result["bhishanay"] = @["भीषणाय"]
  result["bhishanaya"] = @["भीषणाय"]
  result["kapaline"] = @["कपालिने"]
  result["sarvabhakshay"] = @["सर्वभक्षाय"]
  result["sarvabhakshaya"] = @["सर्वभक्षाय"]
  result["balimukh"] = @["बलीमुख"]
  result["balimukha"] = @["बलीमुख"]
  result["suryaputra"] = @["सूर्यपुत्र"]
  result["namastestu"] = @["नमस्तेऽस्तु"]
  result["bhaskare"] = @["भास्करे"]
  result["abhayaday"] = @["अभयदाय"]
  result["abhayadaya"] = @["अभयदाय"]
  result["adhodrishteh"] = @["अधोदृष्टे:"]
  result["adhodrishte"] = @["अधोदृष्टे:"]
  result["samvartak"] = @["संवर्तक"]
  result["samvartaka"] = @["संवर्तक"]
  result["mandagate"] = @["मन्दगते"]
  result["tubhyam"] = @["तुभ्यं"]
  result["nistrimshay"] = @["निस्त्रिंशाय"]
  result["nistrimshaya"] = @["निस्त्रिंशाय"]
  result["namostute"] = @["नमोऽस्तुते"]
  result["tapasa"] = @["तपसा"]
  result["dagdha-dehay"] = @["दग्ध-देहाय"]
  result["dagdhadehay"] = @["दग्ध-देहाय", "दग्धदेहाय"]
  result["dagdhadehaya"] = @["दग्ध-देहाय", "दग्धदेहाय"]
  result["nityam"] = @["नित्यं"]
  result["yogratay"] = @["योगरताय"]
  result["yogrataya"] = @["योगरताय"]
  result["yogarataya"] = @["योगरताय"]
  result["kshudhartay"] = @["क्षुधार्ताय"]
  result["kshudhartaya"] = @["क्षुधार्ताय"]
  result["atriptay"] = @["अतृप्ताय"]
  result["atriptaya"] = @["अतृप्ताय"]
  result["gyanachakshurnamastestu"] = @["ज्ञानचक्षुर्नमस्तेऽस्तु"]
  result["jnanachakshurnamastestu"] = @["ज्ञानचक्षुर्नमस्तेऽस्तु"]
  result["kashyapatmaj-soonave"] = @["कश्यपात्मज-सूनवे"]
  result["kashyapatmajsoonave"] = @["कश्यपात्मज-सूनवे"]
  result["kashyapatmajsunave"] = @["कश्यपात्मज-सूनवे"]
  result["tushto"] = @["तुष्टो"]
  result["dadasi"] = @["ददासि"]
  result["rajyam"] = @["राज्यं"]
  result["rushto"] = @["रुष्टो"]
  result["harsi"] = @["हरसि"]
  result["tatkshanat"] = @["तत्क्षणात्"]
  result["devasuramanyashcha"] = @["देवासुरमनुष्याश्च"]
  result["devasuramanushyashcha"] = @["देवासुरमनुष्याश्च"]
  result["siddha-vidyadharoragah"] = @["सिद्ध-विद्याधरोरगा:"]
  result["siddhavidyadharoragah"] = @["सिद्ध-विद्याधरोरगा:"]
  result["tvaya"] = @["त्वया"]
  result["vilokitah"] = @["विलोकिता:"]
  result["sarve"] = @["सर्वे"]
  result["nasham"] = @["नाशं"]
  result["yanti"] = @["यान्ति"]
  result["samoolatah"] = @["समूलत:"]
  result["samulatah"] = @["समूलत:"]
  result["dashrath"] = @["दशरथ"]
  result["dasharath"] = @["दशरथ"]
  result["dasharatha"] = @["दशरथ"]
  result["uvach"] = @["उवाच"]
  result["uvacha"] = @["उवाच"]
  result["prasad"] = @["प्रसाद"]
  result["prasada"] = @["प्रसाद"]
  result["kuru"] = @["कुरु"]
  result["me"] = @["में", "मे"]
  result["saure"] = @["सौरे"]
  result["varado"] = @["वारदो"]
  result["bhav"] = @["भव"]
  result["bhava"] = @["भव"]
  result["evam"] = @["एवं"]
  result["stutastada"] = @["स्तुतस्तदा"]
  result["saurirgraharajo"] = @["सौरिर्ग्रहराजो"]
  result["mahabalah"] = @["महाबल:"]
  result["mahabala"] = @["महाबल:"]

  # ============ COMMON ENGLISH PASSTHROUGH ============
  result["office"] = @["office"]
  result["school"] = @["school"]
  result["college"] = @["college"]
  result["whatsapp"] = @["whatsapp"]
  result["instagram"] = @["instagram"]
  result["facebook"] = @["facebook"]
  result["google"] = @["google"]
  result["youtube"] = @["youtube"]
  result["mobile"] = @["mobile"]
  result["laptop"] = @["laptop"]
  result["computer"] = @["computer"]
  result["internet"] = @["internet"]
  result["email"] = @["email"]
  result["password"] = @["password"]
  result["login"] = @["login"]
  result["logout"] = @["logout"]
  result["file"] = @["file"]
  result["folder"] = @["folder"]
  result["photo"] = @["photo"]
  result["video"] = @["video"]
  result["audio"] = @["audio"]
  result["music"] = @["music"]
  result["movie"] = @["movie"]
  result["game"] = @["game"]
  result["time"] = @["time"]
  result["date"] = @["date"]
  result["year"] = @["year"]
  result["month"] = @["month"]
  result["week"] = @["week"]
  result["day"] = @["day"]
  result["hour"] = @["hour"]
  result["minute"] = @["minute"]
  result["second"] = @["second"]
  result["number"] = @["number"]
  result["address"] = @["address"]
  result["phone"] = @["phone"]
  result["name"] = @["name"]
  result["city"] = @["city"]
  result["country"] = @["country"]
  result["india"] = @["india"]
  result["delhi"] = @["delhi"]
  result["mumbai"] = @["mumbai"]
  result["bangalore"] = @["bangalore"]
  result["chennai"] = @["chennai"]
  result["kolkata"] = @["kolkata"]
  result["hyderabad"] = @["hyderabad"]
  result["pune"] = @["pune"]
  result["ahmedabad"] = @["ahmedabad"]
  result["jaipur"] = @["jaipur"]
  result["lucknow"] = @["lucknow"]
  result["patna"] = @["patna"]
  result["bhopal"] = @["bhopal"]
  result["indore"] = @["indore"]
  result["kanpur"] = @["kanpur"]
  result["nagpur"] = @["nagpur"]
  result["surat"] = @["surat"]
  result["vadodara"] = @["vadodara"]
  result["rajkot"] = @["rajkot"]
  result["noida"] = @["noida"]
  result["gurgaon"] = @["gurgaon"]
  result["ghaziabad"] = @["ghaziabad"]
  result["faridabad"] = @["faridabad"]

  # ============ COMMON -i, -u, -e ENDINGS & VOCABULARY ============
  result["pyari"] = @["प्यारी"]
  result["pyara"] = @["प्यारा"]
  result["pyare"] = @["प्यारे"]
  result["pyar"] = @["प्यार"]
  result["pyaar"] = @["प्यार"]

  result["kar"] = @["कर"]
  result["karta"] = @["करता"]
  result["karti"] = @["करती"]
  result["karte"] = @["करते"]

  result["sundar"] = @["सुंदर", "सुन्दर"]
  result["sundari"] = @["सुंदरी", "सुन्दरी"]

  result["ladka"] = @["लड़का"]
  result["ladki"] = @["लड़की"]
  result["ladke"] = @["लड़के"]

  result["roti"] = @["रोटी"]
  result["rotli"] = @["रोटली"]

  result["gadi"] = @["गाड़ी"]
  result["gaadi"] = @["गाड़ी"]
  result["gadiyan"] = @["गाड़ियाँ", "गाड़ियां"]
  result["gaadiyan"] = @["गाड़ियाँ", "गाड़ियां"]

  result["nadi"] = @["नदी"]
  result["naadi"] = @["नदी"]
  result["nadiyan"] = @["नदियाँ", "नदियां"]
  result["naadiyan"] = @["नदियाँ", "नदियां"]

  result["sakha"] = @["सखा"]
  result["sakhi"] = @["सखी"]

  result["didi"] = @["दीदी"]
  result["bhabhi"] = @["भाभी"]
  result["dadi"] = @["दादी"]
  result["nani"] = @["नानी"]
  result["chachi"] = @["चाची"]
  result["mami"] = @["मामी"]
  result["mausi"] = @["मौसी"]
  result["bua"] = @["बुआ"]
  result["beti"] = @["बेटी"]
  result["beta"] = @["बेटा"]
  result["bete"] = @["बेटे"]
  result["pati"] = @["पति"]
  result["patni"] = @["पत्नी"]
  result["rani"] = @["रानी"]
  result["raja"] = @["राजा"]

  result["pani"] = @["पानी"]
  result["chai"] = @["चाय"]
  result["kahani"] = @["कहानी"]
  result["dosti"] = @["दोस्ती"]
  result["khushi"] = @["खुशी"]
  result["chidiya"] = @["चिड़िया"]
  result["gudiya"] = @["गुड़िया"]
  result["duniya"] = @["दुनिया"]
  result["billi"] = @["बिल्ली"]
  result["dilli"] = @["दिल्ली"]
  result["mummy"] = @["मम्मी"]

  result["chalti"] = @["चलती"]
  result["chalta"] = @["चलता"]
  result["chalte"] = @["चलते"]
  result["chal"] = @["चल"]
  result["aati"] = @["आती"]
  result["aata"] = @["आता"]
  result["aate"] = @["आते"]
  result["jati"] = @["जाती"]
  result["jata"] = @["जाता"]
  result["jate"] = @["जाते"]
  result["hoti"] = @["होती"]
  result["hota"] = @["होता"]
  result["hote"] = @["होते"]
  result["leti"] = @["लेती"]
  result["leta"] = @["लेता"]
  result["lete"] = @["लेते"]
  result["deti"] = @["देती"]
  result["deta"] = @["देता"]
  result["dete"] = @["देते"]
  result["kahti"] = @["कहती"]
  result["kahta"] = @["कहता"]
  result["kahte"] = @["कहते"]
  result["rahti"] = @["रहती"]
  result["rahta"] = @["रहता"]
  result["rahte"] = @["रहते"]
  result["sunti"] = @["सुनती"]
  result["sunta"] = @["सुनता"]
  result["sunte"] = @["सुनते"]
  result["dekhti"] = @["देखती"]
  result["dekhta"] = @["देखता"]
  result["dekhte"] = @["देखते"]

  result["badi"] = @["बड़ी"]
  result["bada"] = @["बड़ा"]
  result["bade"] = @["बड़े"]
  result["chhoti"] = @["छोटी"]
  result["chhota"] = @["छोटा"]
  result["chhote"] = @["छोटे"]
  result["achhi"] = @["अच्छी"]
  result["achha"] = @["अच्छा"]
  result["achhe"] = @["अच्छे"]
  result["acchi"] = @["अच्छी"]
  result["accha"] = @["अच्छा"]
  result["acche"] = @["अच्छे"]
  result["sacchi"] = @["सच्ची"]
  result["saccha"] = @["सच्चा"]
  result["sacche"] = @["सच्चे"]
  result["sachi"] = @["सच्ची"]
  result["sacha"] = @["सच्चा"]
  result["sache"] = @["सच्चे"]
  result["meethi"] = @["मीठी"]
  result["meetha"] = @["मीठा"]
  result["meethe"] = @["मीठे"]
  result["kadwi"] = @["कड़वी"]
  result["kadwa"] = @["कड़वा"]
  result["thandi"] = @["ठंडी"]
  result["thanda"] = @["ठंडा"]
  result["garam"] = @["गरम"]

  result["babu"] = @["बाबू"]
  result["chaku"] = @["चाकू"]
  result["laddu"] = @["लड्डू"]
  result["bhalu"] = @["भालू"]
  result["aalu"] = @["आलू"]
  result["alu"] = @["आलू"]
  result["kachalu"] = @["कचालू"]
  result["champu"] = @["चंपू"]
  result["ullu"] = @["उल्लू"]
  result["guru"] = @["गुरु"]
  result["shuru"] = @["शुरू"]
  result["jhadu"] = @["झाड़ू"]
  result["tarazu"] = @["तराज़ू", "तराजू"]
  result["taraju"] = @["तराज़ू", "तराजू"]
  result["baalu"] = @["बालू"]
  result["bapu"] = @["बापू"]
  result["sadhu"] = @["साधु"]
  result["madhu"] = @["मधु"]
  result["aayu"] = @["आयु"]
  result["kintu"] = @["किंतु"]
  result["parantu"] = @["परंतु"]

  result["pehle"] = @["पहले"]
  result["aage"] = @["आगे"]
  result["peeche"] = @["पीछे"]
  result["piche"] = @["पीछे"]
  result["niche"] = @["नीचे"]
  result["neeche"] = @["नीचे"]
  result["saamne"] = @["सामने"]
  result["samne"] = @["सामने"]
  result["jaise"] = @["जैसे"]
  result["aise"] = @["ऐसे"]
  result["waise"] = @["वैसे"]
  result["kaise"] = @["कैसे"]
  result["isliye"] = @["इसलिए"]
  result["chahiye"] = @["चाहिए"]
  result["huye"] = @["हुए"]
  result["hue"] = @["हुए"]
  result["gaye"] = @["गए"]
  result["aaye"] = @["आए"]
  result["soche"] = @["सोचे"]
  result["dekhe"] = @["देखे"]

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

  # 1. Google Transliterate Cached Words (Highest Priority)
  for pkey, cands in googleCache:
    for hw in cands:
      let hword = hw.strip()
      let hashKey = pkey & ":" & hword
      if not seen.hasKey(hashKey):
        f.writeLine(hword & "\t" & pkey)
        seen[hashKey] = true
        inc count

  # 2. Curated High-Frequency Common Dictionary
  for pkey, cands in commonDict:
    for hw in cands:
      let hword = hw.strip()
      let hashKey = pkey & ":" & hword
      if not seen.hasKey(hashKey):
        f.writeLine(hword & "\t" & pkey)
        seen[hashKey] = true
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
          inc count

  f.close()
  echo "🚀 Pure Nim Rime Builder compiled ", count, " entries into ", rimeDictPath

  let repoDictPath = projDir.parentDir / "rime" / "hindi_ai.dict.yaml"
  if fileExists(rimeDictPath) and dirExists(projDir.parentDir / "rime"):
    copyFile(rimeDictPath, repoDictPath)
    echo "📄 Also synced dictionary to repository: ", repoDictPath

when isMainModule:
  generateFullRimeHindiDict()
