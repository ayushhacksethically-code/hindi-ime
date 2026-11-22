#!/usr/bin/env python3
import os, sys, json, re, random
from collections import Counter, defaultdict

def main():
    print("==========================================================")
    print("      AKSHARANTAR CURATED DATASET INTEGRATION PIPELINE    ")
    print("==========================================================")

    proj_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    train_path = os.path.expanduser("~/Pictures/hin/hin_train.json")
    dict_path = os.path.join(proj_dir, "rime/hindi_ai.dict.yaml")
    cat_dir = os.path.join(proj_dir, "data/categories")

    # 1. Load all existing keys from rime/hindi_ai.dict.yaml
    existing_keys = set()
    if os.path.exists(dict_path):
        with open(dict_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and not line.startswith("-") and not line.startswith("."):
                    parts = line.split("\t")
                    if len(parts) >= 2:
                        existing_keys.add(parts[1].strip().lower())
    print(f"[*] Loaded {len(existing_keys)} existing dictionary keys from {dict_path}")

    # Also load keys from all existing category files
    import glob
    for cf in glob.glob(os.path.join(cat_dir, "*.nim")):
        if "aksharantar_" in cf: continue
        with open(cf, "r", encoding="utf-8") as f:
            for line in f:
                m = re.search(r'result\["([^"]+)"\]', line)
                if m:
                    existing_keys.add(m.group(1).lower())
    print(f"[*] Total unique protected keys across repo: {len(existing_keys)}")

    # 2. Common English words list for passthrough detection & filter
    common_english = set([
        "winter", "summer", "autumn", "spring", "watson", "computer", "doctor", "engineer",
        "school", "college", "university", "student", "teacher", "hospital", "station",
        "airport", "office", "company", "project", "department", "market", "supermarket",
        "road", "street", "avenue", "highway", "traffic", "police", "court", "judge",
        "lawyer", "bank", "account", "manager", "director", "president", "minister",
        "prime", "chief", "officer", "staff", "team", "group", "club", "party",
        "hotel", "restaurant", "cafe", "bar", "park", "garden", "center", "centre",
        "hall", "room", "house", "building", "tower", "bridge", "palace", "temple",
        "church", "mosque", "film", "movie", "cinema", "theatre", "drama", "music",
        "song", "dance", "art", "artist", "actor", "actress", "director", "producer",
        "game", "sport", "cricket", "football", "hockey", "tennis", "match", "cup",
        "league", "trophy", "champion", "player", "coach", "captain", "stadium",
        "ground", "pitch", "court", "ring", "track", "race", "car", "bus", "train",
        "truck", "bike", "cycle", "plane", "flight", "ship", "boat", "driver",
        "pilot", "ticket", "seat", "berth", "coach", "engine", "wheel", "brake",
        "phone", "mobile", "laptop", "tablet", "screen", "keyboard", "mouse", "cable",
        "wire", "battery", "charger", "network", "signal", "wifi", "internet", "data",
        "server", "site", "website", "page", "link", "post", "blog", "video",
        "audio", "photo", "image", "file", "folder", "document", "report", "card",
        "paul", "gates", "watts", "pleasant", "vista", "morrison", "cathedral", "flynn",
        "beavercreek", "placentia", "lowell", "springfield", "goodyear", "dearborn", "solis"
    ])

    # 3. Phonetic matching definitions
    initial_map = {
        'k': {'क', 'ख', 'क़', 'क्ष'},
        'g': {'ग', 'घ', 'ग़'},
        'c': {'च', 'छ', 'क'},
        'j': {'ज', 'झ', 'ज़', 'ज्ञ'},
        't': {'त', 'थ', 'ट', 'ठ', 'त्र'},
        'd': {'द', 'ध', 'ड', 'ढ'},
        'p': {'प', 'फ', 'फ़'},
        'f': {'फ', 'फ़'},
        'b': {'ब', 'भ'},
        'm': {'म'},
        'y': {'य'},
        'r': {'र', 'ऋ', 'ड़', 'ढ़'},
        'l': {'ल'},
        'v': {'व'},
        'w': {'व'},
        's': {'स', 'श', 'ष'},
        'h': {'ह'},
        'n': {'न', 'ण', 'ञ', 'ङ'},
        'a': {'अ', 'आ', 'ऐ', 'औ'},
        'e': {'ए', 'ऐ', 'इ', 'ई'},
        'i': {'इ', 'ई'},
        'o': {'ओ', 'औ'},
        'u': {'उ', 'ऊ'}
    }

    devanagari_regex = re.compile(r'^[\u0900-\u097F]+$')
    alpha_regex = re.compile(r'^[a-z]+$')

    # Category buckets
    cat_formal = {}    # Dakshina -> aksharantar_formal
    cat_places = {}    # AK-NEI / Wikidata -> aksharantar_places
    cat_frequent = {}  # AK-Freq -> aksharantar_frequent
    cat_english = {}   # AK-NEF / English -> aksharantar_english

    rejection_stats = Counter()
    rejected_samples = []

    print("[*] Processing Aksharantar dataset with multi-stage quality checks...")

    # Process hin_train.json
    with open(train_path, "r", encoding="utf-8") as f:
        for line_num, line in enumerate(f, 1):
            if not line.strip(): continue
            node = json.loads(line)
            eng = node.get("english word", "").strip().lower()
            dev = node.get("native word", "").strip()
            src = node.get("source", "Unknown")

            # REJECT a: Hinglish not strictly lowercase a-z
            if not alpha_regex.fullmatch(eng):
                rejection_stats["a) Non-lowercase a-z"] += 1
                if len(rejected_samples) < 50:
                    rejected_samples.append((eng, dev, "Contains non-alpha characters or symbols"))
                continue

            # REJECT d: Hinglish length > 15 chars or < 3
            if len(eng) < 3 or len(eng) > 15:
                rejection_stats["d) Hinglish length out of bounds (3-15)"] += 1
                if len(rejected_samples) < 50:
                    rejected_samples.append((eng, dev, f"Hinglish length {len(eng)} not in 3-15 range"))
                continue

            # REJECT b: Devanagari doesn't match Devanagari Unicode range
            if not devanagari_regex.fullmatch(dev):
                rejection_stats["b) Non-Devanagari characters"] += 1
                if len(rejected_samples) < 50:
                    rejected_samples.append((eng, dev, "Contains characters outside Devanagari range"))
                continue

            # REJECT e: Devanagari length > 12 chars or < 2
            if len(dev) < 2 or len(dev) > 12:
                rejection_stats["e) Devanagari length out of bounds (2-12)"] += 1
                if len(rejected_samples) < 50:
                    rejected_samples.append((eng, dev, f"Devanagari length {len(dev)} not in 2-12 range"))
                continue

            # REJECT b2: Devanagari irregular patterns / noise
            if dev.endswith('ः') or 'ः' in dev or dev.endswith('्') or 'ेा' in dev or 'ाे' in dev or 'ेे' in dev or 'ाा' in dev:
                rejection_stats["b) Irregular Devanagari / trailing visarga/virama"] += 1
                if len(rejected_samples) < 50:
                    rejected_samples.append((eng, dev, "Irregular Devanagari orthography or trailing punctuation"))
                continue

            # REJECT c: Word already exists in current dictionary (Shadowing protection)
            if eng in existing_keys:
                rejection_stats["c) Word already in dictionary (Shadowing prevention)"] += 1
                continue

            # REJECT f / Route to English category:
            if eng in common_english or src == "AK-NEF":
                if eng not in cat_english and len(cat_english) < 400:
                    cat_english[eng] = eng
                continue

            # ACCEPT b: Basic phonetic consistency check
            first_c = eng[0]
            first_d = dev[0]
            if first_c in initial_map and first_d not in initial_map[first_c]:
                rejection_stats["Phonetic initial consonant mismatch"] += 1
                if len(rejected_samples) < 50:
                    rejected_samples.append((eng, dev, f"Initial consonant mismatch ({first_c} vs {first_d})"))
                continue

            # Vowel phonetic consistency
            if "aa" in eng and ("ा" not in dev and "आ" not in dev):
                rejection_stats["Phonetic 'aa' vowel mismatch"] += 1
                if len(rejected_samples) < 50:
                    rejected_samples.append((eng, dev, "Hinglish has 'aa' but Devanagari lacks 'ा' or 'आ'"))
                continue
            if "ee" in eng and ("ी" not in dev and "ई" not in dev and "ि" not in dev):
                rejection_stats["Phonetic 'ee' vowel mismatch"] += 1
                continue
            if "oo" in eng and ("ू" not in dev and "ऊ" not in dev and "ु" not in dev and "ो" not in dev):
                rejection_stats["Phonetic 'oo' vowel mismatch"] += 1
                continue

            # Categorize into target files based on source
            if src == "Dakshina":
                if eng not in cat_formal and len(cat_formal) < 1600:
                    cat_formal[eng] = dev
            elif src == "AK-Freq":
                if eng not in cat_frequent and len(cat_frequent) < 1200:
                    cat_frequent[eng] = dev
            elif src in ["Wikidata", "AK-NEI", "Existing"]:
                if eng not in cat_places and len(cat_places) < 1000:
                    cat_places[eng] = dev

            # Check if all category quotas reached
            if (len(cat_formal) >= 1600 and len(cat_frequent) >= 1200 and 
                len(cat_places) >= 1000 and len(cat_english) >= 350):
                print(f"[*] All target category quotas reached at line {line_num}!")
                break

    total_curated = len(cat_formal) + len(cat_frequent) + len(cat_places) + len(cat_english)
    print("\n----------------------------------------------------------")
    print(f"[*] Total curated high-confidence words accepted: {total_curated}")
    print(f"    - aksharantar_formal:   {len(cat_formal)}")
    print(f"    - aksharantar_frequent: {len(cat_frequent)}")
    print(f"    - aksharantar_places:   {len(cat_places)}")
    print(f"    - aksharantar_english:  {len(cat_english)}")
    print("----------------------------------------------------------")

    # 4. Write category files
    def write_category_file(filename, data_dict, is_english=False):
        filepath = os.path.join(cat_dir, filename)
        with open(filepath, "w", encoding="utf-8") as f:
            cat_title = filename.replace("aksharantar_", "").replace(".nim", "").upper()
            f.write(f"# ============ AKSHARANTAR CURATED: {cat_title} ({len(data_dict)}) ============\n\n")
            for k in sorted(data_dict.keys()):
                val = data_dict[k]
                f.write(f'result["{k}"] = @["{val}"]\n')
        print(f"[+] Written {len(data_dict)} entries to {filepath}")

    write_category_file("aksharantar_places.nim", cat_places)
    write_category_file("aksharantar_formal.nim", cat_formal)
    write_category_file("aksharantar_frequent.nim", cat_frequent)
    write_category_file("aksharantar_english.nim", cat_english, is_english=True)

    # 5. Update data/common_dict.nim
    common_dict_path = os.path.join(proj_dir, "data/common_dict.nim")
    with open(common_dict_path, "r", encoding="utf-8") as f:
        cd_content = f.read()

    new_includes = [
        "  include categories/aksharantar_places",
        "  include categories/aksharantar_formal",
        "  include categories/aksharantar_frequent",
        "  include categories/aksharantar_english"
    ]

    for inc in new_includes:
        if inc not in cd_content:
            cd_content = cd_content.rstrip() + "\n" + inc + "\n"

    with open(common_dict_path, "w", encoding="utf-8") as f:
        f.write(cd_content)
    print(f"[+] Updated {common_dict_path} with modular Aksharantar includes.")

    # 6. Print filter stats
    print("\n==========================================================")
    print("                  1. FILTER STATS                         ")
    print("==========================================================")
    for reason, count in rejection_stats.most_common():
        print(f"  - {reason:55}: {count:,} rejected")

    # 7. Print Sample of 20 accepted words
    print("\n==========================================================")
    print("          2. SAMPLE OF ACCEPTED WORDS (20 RANDOM)         ")
    print("==========================================================")
    all_accepted = []
    for k, v in cat_formal.items(): all_accepted.append((k, v, "Formal (Dakshina)"))
    for k, v in cat_places.items(): all_accepted.append((k, v, "Places (AK-NEI/Wikidata)"))
    for k, v in cat_frequent.items(): all_accepted.append((k, v, "Frequent (AK-Freq)"))
    for k, v in cat_english.items(): all_accepted.append((k, v, "English Passthrough"))

    random.seed(123)
    sample_acc = random.sample(all_accepted, min(20, len(all_accepted)))
    for i, (k, v, cat) in enumerate(sample_acc, 1):
        print(f"  {i:2d}. {k:18} -> {v:16} | Category: {cat}")

    # 8. Print Sample of 10 rejected words with reasons
    print("\n==========================================================")
    print("      3. SAMPLE OF REJECTED WORDS (10 RANDOM WITH REASONS)")
    print("==========================================================")
    sample_rej = random.sample(rejected_samples, min(10, len(rejected_samples)))
    for i, (k, v, reason) in enumerate(sample_rej, 1):
        print(f"  {i:2d}. Input: {k:16} | Output: {v:16} | Reason: {reason}")
    print("==========================================================\n")

if __name__ == "__main__":
    main()
