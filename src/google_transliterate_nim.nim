import std/[net, httpclient, json, strutils, tables, sequtils, uri, os, streams]

proc getCacheDir*(): string =
  let base = getEnv("XDG_CACHE_HOME", getEnv("HOME") / ".cache")
  let dir = base / "hindi-ime"
  createDir(dir)
  return dir

proc getCacheFile*(): string =
  getCacheDir() / "google_translit_cache.bin"

type
  CacheEntry = object
    key: string
    cands: seq[string]

var gCache: Table[string, seq[string]]

proc loadCache() =
  gCache = initTable[string, seq[string]]()
  let cacheFile = getCacheFile()
  if not fileExists(cacheFile): return
  try:
    var fs = newFileStream(cacheFile, fmRead)
    if not fs.isNil:
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
        gCache[k] = cands
      fs.close()
  except:
    discard

proc saveCache() =
  try:
    let cacheFile = getCacheFile()
    var fs = newFileStream(cacheFile, fmWrite)
    if not fs.isNil:
      fs.write(gCache.len.uint32)
      for k, cands in gCache:
        fs.write(k.len.uint16)
        fs.write(k)
        fs.write(cands.len.uint16)
        for c in cands:
          fs.write(c.len.uint16)
          fs.write(c)
      fs.close()
  except:
    discard

proc getConfigPath*(): string =
  let base = getEnv("XDG_CONFIG_HOME", getEnv("HOME") / ".config")
  let dir = base / "hindi-ime"
  createDir(dir)
  return dir / "config.json"

proc isGoogleApiEnabled*(): bool =
  # 1. Check environment variable first (highest priority)
  let envVal = getEnv("HINDI_IME_GOOGLE_API", "")
  if envVal.len > 0:
    case envVal.toLowerAscii()
    of "1", "true", "yes", "on": return true
    else: return false

  # 2. Check config file
  let configPath = getConfigPath()
  if fileExists(configPath):
    try:
      let cfg = parseFile(configPath)
      if cfg.hasKey("google_api"):
        let val = cfg["google_api"]
        if val.kind == JBool: return val.getBool()
        if val.kind == JString:
          case val.getStr().toLowerAscii()
          of "1", "true", "yes", "on": return true
          else: return false
    except:
      discard

  # 3. Default: disabled
  return false

proc fetchGoogleTransliteration*(word: string): seq[string] =
  if not isGoogleApiEnabled():
    return @[]

  let key = word.strip().toLowerAscii()
  if key.len == 0: return @[]

  # Check Cache First
  if gCache.hasKey(key):
    return gCache[key]

  # Fetch Live from Google Input Tools API (Google Translate Transliterate API)
  let url = "https://inputtools.google.com/request?text=" & encodeUrl(key) & "&itc=hi-t-i0-und&num=5&cp=0&cs=1&ie=utf-8&oe=utf-8&app=demopage"
  var client = newHttpClient(timeout = 1500)
  client.headers = newHttpHeaders({"User-Agent": "Mozilla/5.0"})

  try:
    let response = client.getContent(url)
    let node = parseJson(response)
    if node.kind == JArray and node.len > 1 and node[0].str == "SUCCESS":
      let candidatesNode = node[1][0][1]
      var result: seq[string] = @[]
      for item in candidatesNode:
        result.add(item.str)
      if result.len > 0:
        gCache[key] = result
        saveCache()
        return result
  except:
    discard
  finally:
    client.close()

  return @[]

when isMainModule:
  loadCache()
  if not isGoogleApiEnabled():
    echo "ℹ️  Google API is DISABLED (default)."
    echo "   To enable, either:"
    echo "     export HINDI_IME_GOOGLE_API=1"
    echo "   or create ~/.config/hindi-ime/config.json with:"
    echo "     {\"google_api\": true}"
    echo ""
  let params = commandLineParams()
  if params.len > 0:
    let word = params[0]
    let res = fetchGoogleTransliteration(word)
    echo "Google Transliterate Engine Output: ", res
  else:
    echo "Usage: google_transliterate_nim <word>"
