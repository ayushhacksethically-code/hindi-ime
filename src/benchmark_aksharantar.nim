import std/[tables, strutils, json, streams, os, math, unicode]
import hindi_live_ime

type
  SourceStats = object
    total: int
    top1: int
    top3: int
    top5: int

proc main() =
  let jsonPath = getHomeDir() / "Pictures/hin/hin_test.json"
  if not fileExists(jsonPath):
    echo "Error: Test dataset not found at ", jsonPath
    quit(1)

  let params = commandLineParams()
  var customDict = ""
  if params.len > 0 and fileExists(params[0]):
    customDict = params[0]

  echo "=========================================================="
  echo "      AI4BHARAT AKSHARANTAR BENCHMARK SUITE FOR HINDI IME  "
  echo "=========================================================="
  echo "Dataset: ", jsonPath
  echo "Loading dictionaries into memory..."

  initHindiEngine()

  if customDict.len > 0:
    echo "Overriding Rime dictionary with: ", customDict
    loadRimeDict(customDict)

  echo "Dictionary loaded. Running benchmark on 10,112 test pairs..."
  echo "----------------------------------------------------------"

  var overallStats = SourceStats()
  var sourceMap = initTable[string, SourceStats]()

  var lineNum = 0
  for line in lines(jsonPath):
    inc lineNum
    let trimmed = line.strip()
    if trimmed.len == 0: continue
    
    let node = parseJson(trimmed)
    let eng = node["english word"].getStr().strip().toLowerAscii()
    let expected = node["native word"].getStr().strip()
    let src = node.getOrDefault("source").getStr("Unknown")

    if eng.len == 0 or expected.len == 0: continue

    if not sourceMap.hasKey(src):
      sourceMap[src] = SourceStats()

    var srcStat = sourceMap[src]

    inc overallStats.total
    inc srcStat.total

    let cands = getPhoneticCandidates(eng)

    var matchedRank = 0
    for idx, cand in cands:
      if cand == expected:
        matchedRank = idx + 1
        break

    if matchedRank == 1:
      inc overallStats.top1
      inc srcStat.top1
    if matchedRank >= 1 and matchedRank <= 3:
      inc overallStats.top3
      inc srcStat.top3
    if matchedRank >= 1 and matchedRank <= 5:
      inc overallStats.top5
      inc srcStat.top5

    sourceMap[src] = srcStat

    if lineNum mod 2000 == 0:
      echo "Processed ", lineNum, " / 10112 words..."

  echo "----------------------------------------------------------"
  echo "                      RESULTS SUMMARY                     "
  echo "----------------------------------------------------------"
  echo alignLeft("Category", 15), alignLeft("Total", 10), alignLeft("Top-1 Acc", 14), alignLeft("Top-3 Acc", 14), alignLeft("Top-5 Acc", 14)
  echo "----------------------------------------------------------"

  for src, stat in sourceMap:
    let top1Pct = (stat.top1.float / stat.total.float) * 100.0
    let top3Pct = (stat.top3.float / stat.total.float) * 100.0
    let top5Pct = (stat.top5.float / stat.total.float) * 100.0
    echo alignLeft(src, 15),
         alignLeft($stat.total, 10),
         alignLeft(formatFloat(top1Pct, ffDecimal, 2) & "%", 14),
         alignLeft(formatFloat(top3Pct, ffDecimal, 2) & "%", 14),
         alignLeft(formatFloat(top5Pct, ffDecimal, 2) & "%", 14)

  echo "----------------------------------------------------------"
  let ovTop1 = (overallStats.top1.float / overallStats.total.float) * 100.0
  let ovTop3 = (overallStats.top3.float / overallStats.total.float) * 100.0
  let ovTop5 = (overallStats.top5.float / overallStats.total.float) * 100.0
  echo alignLeft("OVERALL", 15),
       alignLeft($overallStats.total, 10),
       alignLeft(formatFloat(ovTop1, ffDecimal, 2) & "%", 14),
       alignLeft(formatFloat(ovTop3, ffDecimal, 2) & "%", 14),
       alignLeft(formatFloat(ovTop5, ffDecimal, 2) & "%", 14)
  echo "=========================================================="

main()
