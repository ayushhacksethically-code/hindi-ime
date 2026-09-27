import std/[sets, strutils, unicode]
import generate_variants

export generate_variants

type InflectionResult* = tuple[hword: string, pkey: string, weight: int]

proc generateInflections*(hword, pkey: string, weight: int = 50): seq[InflectionResult] =
  let vars = generateVariantsForWord(hword, pkey, weight)
  result = @[]
  for v in vars:
    result.add((v.hword, v.pkey, v.weight))

when isMainModule:
  echo "=== TESTING 10 COMMON WORDS VIA INFLECT_HINDI ==="
  let samples = [
    ("समस्या", "samasya"),
    ("लड़की", "ladki"),
    ("लड़का", "ladka"),
    ("घर", "ghar"),
    ("किताब", "kitab"),
    ("बात", "baat"),
    ("रात", "raat"),
    ("आँख", "aankh"),
    ("हाथ", "haath"),
    ("पैर", "pair")
  ]
  for (hw, pk) in samples:
    let infs = generateInflections(hw, pk)
    echo hw, " (", pk, ") -> "
    for r in infs:
      echo "   ", r.hword, "\t", r.pkey, "\t", r.weight
