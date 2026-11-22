#!/usr/bin/env python3
import os
import re
import csv
import json
from collections import Counter, defaultdict

# 1. Load existing dictionary mappings from rime/hindi_ai.dict.yaml
dict_map = {}
dict_path = "rime/hindi_ai.dict.yaml"
if os.path.exists(dict_path):
    with open(dict_path, "r", encoding="utf-8") as f:
        for line in f:
            parts = line.strip().split("\t")
            if len(parts) >= 2:
                hw, pkey = parts[0], parts[1].lower()
                if pkey not in dict_map:
                    dict_map[pkey] = hw

# Preload existing categories from data/categories/*.nim
existing_category_map = {}
import glob
for cat_file in glob.glob("data/categories/*.nim"):
    base_name = os.path.basename(cat_file).replace(".nim", "")
    if base_name in ["mental_hospital_chat"]:
        continue
    with open(cat_file, "r", encoding="utf-8") as cf:
        for line in cf:
            m = re.search(r'result\["([^"]+)"\]\s*=\s*@\["([^"]+)"', line)
            if m:
                k = m.group(1).lower()
                dev = m.group(2)
                if k not in existing_category_map:
                    existing_category_map[k] = (dev, base_name)


# 2. Curated mapping for chat words, contractions, and colloquialisms
chat_word_overrides = {
    # Pronouns / Contractions
    "ldke": ("लड़के", "pronouns"),
    "ldki": ("लड़की", "pronouns"),
    "ldka": ("लड़का", "pronouns"),
    "ladkiya": ("लड़कियाँ", "pronouns"),
    "ladkiyo": ("लड़कियों", "pronouns"),
    "ladko": ("लड़कों", "pronouns"),
    "sabke": ("सबके", "pronouns"),
    "sabka": ("सबका", "pronouns"),
    "sabki": ("सबकी", "pronouns"),
    "sabko": ("सबको", "pronouns"),
    "apna": ("अपना", "pronouns"),
    "apne": ("अपने", "pronouns"),
    "apni": ("अपनी", "pronouns"),
    "kisko": ("किसको", "pronouns"),
    "jisko": ("जिसको", "pronouns"),
    "jise": ("जिसे", "pronouns"),
    "kise": ("किसे", "pronouns"),
    "inse": ("इनसे", "pronouns"),
    "ense": ("इनसे", "pronouns"),
    "unse": ("उनसे", "pronouns"),
    "ispe": ("इसपे", "pronouns"),
    "uspe": ("उसपे", "pronouns"),
    "inki": ("इनकी", "pronouns"),
    "inka": ("इनका", "pronouns"),
    "inke": ("इनके", "pronouns"),
    "unka": ("उनका", "pronouns"),
    "unke": ("उनके", "pronouns"),
    "unki": ("उनकी", "pronouns"),
    "tujhe": ("तुझे", "pronouns"),
    "mujhe": ("मुझे", "pronouns"),
    "muje": ("मुझे", "pronouns"),
    "hume": ("हमें", "pronouns"),
    "humein": ("हमें", "pronouns"),
    "humne": ("हमने", "pronouns"),
    "tumne": ("तुमने", "pronouns"),
    "maine": ("मैंने", "pronouns"),
    "usne": ("उसने", "pronouns"),
    "inhone": ("इन्होंने", "pronouns"),
    "unhone": ("उन्होंने", "pronouns"),
    "kisine": ("किसीने", "pronouns"),
    "sb": ("सब", "pronouns"),

    # Common chat short forms / Chat Slang
    "yrr": ("यार", "chat_slang"),
    "yr": ("यार", "chat_slang"),
    "bhaii": ("भाई", "family_relations"),
    "bro": ("ब्रो", "family_relations"),
    "nhi": ("नहीं", "chat_slang"),
    "ni": ("नहीं", "chat_slang"),
    "nai": ("नहीं", "chat_slang"),
    "hn": ("हाँ", "chat_slang"),
    "hnn": ("हाँ", "chat_slang"),
    "ha": ("हाँ", "chat_slang"),
    "haan": ("हाँ", "chat_slang"),
    "haa": ("हाँ", "chat_slang"),
    "kch": ("कुछ", "chat_slang"),
    "thk": ("ठीक", "chat_slang"),
    "thik": ("ठीक", "chat_slang"),
    "smjh": ("समझ", "verbs"),
    "smjha": ("समझा", "verbs"),
    "smjhi": ("समझी", "verbs"),
    "smjhe": ("समझे", "verbs"),
    "bta": ("बता", "verbs"),
    "btao": ("बताओ", "verbs"),
    "btana": ("बताना", "verbs"),
    "btaya": ("बताया", "verbs"),
    "btayi": ("बताई", "verbs"),
    "chl": ("चल", "verbs"),
    "chlo": ("चलो", "verbs"),
    "chle": ("चले", "verbs"),
    "chlta": ("चलता", "verbs"),
    "chlti": ("चलती", "verbs"),
    "kr": ("कर", "verbs"),
    "kro": ("करो", "verbs"),
    "kra": ("करा", "verbs"),
    "kre": ("करे", "verbs"),
    "krega": ("करेगा", "verbs"),
    "kregi": ("करेगी", "verbs"),
    "krege": ("करेंगे", "verbs"),
    "krungi": ("करूँगी", "verbs"),
    "kruga": ("करूँगा", "verbs"),
    "krunga": ("करूँगा", "verbs"),
    "krte": ("करते", "verbs"),
    "krti": ("करती", "verbs"),
    "krta": ("करता", "verbs"),
    "krke": ("करके", "verbs"),
    "krne": ("करने", "verbs"),
    "krna": ("करना", "verbs"),
    "skta": ("सकता", "verbs"),
    "skti": ("सकती", "verbs"),
    "skte": ("सकते", "verbs"),
    "dekh": ("देख", "verbs"),
    "dekho": ("देखो", "verbs"),
    "dekha": ("देखा", "verbs"),
    "dekhe": ("देखे", "verbs"),
    "dekhna": ("देखना", "verbs"),
    "sojao": ("सो जाओ", "verbs"),
    "sojaoo": ("सो जाओ", "verbs"),
    "sojaooo": ("सो जाओ", "verbs"),
    "soja": ("सो जा", "verbs"),
    "sota": ("सोता", "verbs"),
    "soti": ("सोती", "verbs"),
    "sona": ("सोना", "verbs"),
    "poch": ("पहुँच", "verbs"),
    "pocha": ("पहुँचा", "verbs"),
    "pochke": ("पहुँचके", "verbs"),
    "ghumta": ("घूमता", "verbs"),
    "ghumti": ("घूमती", "verbs"),
    "ghumo": ("घूमो", "verbs"),
    "bhagti": ("भागती", "verbs"),
    "bhagta": ("भागता", "verbs"),
    "bhago": ("भागो", "verbs"),
    "bhag": ("भाग", "verbs"),
    "pakad": ("पकड़", "verbs"),
    "pakdo": ("पकड़ों", "verbs"),
    "pakda": ("पकड़ा", "verbs"),
    "fek": ("फेंक", "verbs"),
    "feko": ("फेंको", "verbs"),
    "mara": ("मारा", "verbs"),
    "mari": ("मारी", "verbs"),
    "mare": ("मारे", "verbs"),
    "payegaa": ("पाएगा", "verbs"),
    "payegi": ("पाएगी", "verbs"),
    "payenge": ("पाएंगे", "verbs"),
    "jagaungi": ("जगाऊँगी", "verbs"),
    "bhejti": ("भेजती", "verbs"),
    "bheja": ("भेजा", "verbs"),
    "bhejo": ("भेजो", "verbs"),
    "rulla": ("रुला", "verbs"),
    "chrdu": ("छोड़ दूँ", "verbs"),
    "chrdo": ("छोड़ दो", "verbs"),
    "chor": ("छोड़", "verbs"),
    "chordo": ("छोड़ दो", "verbs"),
    "rok": ("रोक", "verbs"),
    "roko": ("रोको", "verbs"),
    "aao": ("आओ", "verbs"),
    "aara": ("आ रहा", "verbs"),
    "aari": ("आ रही", "verbs"),
    "aare": ("आ रहे", "verbs"),
    "jaara": ("जा रहा", "verbs"),
    "jaari": ("जा रही", "verbs"),
    "jaare": ("जा रहे", "verbs"),
    "jaiyo": ("जाइयो", "verbs"),
    "hojaye": ("हो जाए", "verbs"),
    "hojata": ("हो जाता", "verbs"),
    "hojati": ("हो जाती", "verbs"),
    "hoga": ("होगा", "verbs"),
    "hogi": ("होगी", "verbs"),
    "hogii": ("होगी", "verbs"),
    "honge": ("होंगे", "verbs"),
    "rhna": ("रहना", "verbs"),
    "rhta": ("रहता", "verbs"),
    "rhti": ("रहती", "verbs"),
    "rhte": ("रहते", "verbs"),
    "rhe": ("रहे", "verbs"),
    "rha": ("रहा", "verbs"),
    "rhi": ("रही", "verbs"),
    "milo": ("मिलो", "verbs"),
    "mila": ("मिला", "verbs"),
    "mili": ("मिली", "verbs"),
    "mile": ("मिले", "verbs"),
    "milte": ("मिलते", "verbs"),
    "milti": ("मिलती", "verbs"),
    "khana": ("खाना", "food"),
    "peena": ("पीना", "food"),
    "khate": ("खाते", "verbs"),
    "khao": ("खाओ", "verbs"),
    "kha": ("खा", "verbs"),
    "pina": ("पीना", "verbs"),
    "pita": ("पीता", "verbs"),
    "peete": ("पीते", "verbs"),

    # Adjectives & Qualities
    "sharif": ("शरीफ़", "adjectives"),
    "bauni": ("बौनी", "adjectives"),
    "bauna": ("बौना", "adjectives"),
    "motu": ("मोटू", "adjectives"),
    "mota": ("मोटा", "adjectives"),
    "moti": ("मोटी", "adjectives"),
    "chotu": ("छोटू", "adjectives"),
    "chota": ("छोटा", "adjectives"),
    "choti": ("छोटी", "adjectives"),
    "chote": ("छोटे", "adjectives"),
    "bada": ("बड़ा", "adjectives"),
    "badi": ("बड़ी", "adjectives"),
    "bade": ("बड़े", "adjectives"),
    "pagal": ("पागल", "adjectives"),
    "bichare": ("बेचारे", "adjectives"),
    "bichara": ("बेचारा", "adjectives"),
    "khush": ("खुश", "adjectives"),
    "vilupt": ("विलुप्त", "adjectives"),
    "tej": ("तेज़", "adjectives"),
    "kadwa": ("कड़वा", "adjectives"),
    "meetha": ("मीठा", "adjectives"),
    "sundar": ("सुंदर", "adjectives"),
    "badhiya": ("बढ़िया", "adjectives"),
    "badhiyaa": ("बढ़िया", "adjectives"),
    "faltu": ("फालतू", "adjectives"),
    "sahi": ("सही", "adjectives"),
    "saii": ("सही", "adjectives"),
    "galat": ("ग़लत", "adjectives"),
    "jhutt": ("झूठ", "adjectives"),
    "jhut": ("झूठ", "adjectives"),
    "jhooth": ("झूठ", "adjectives"),
    "asli": ("असली", "adjectives"),
    "nakli": ("नकली", "adjectives"),
    "achaaa": ("अच्छा", "adjectives"),
    "acha": ("अच्छा", "adjectives"),
    "accha": ("अच्छा", "adjectives"),
    "achha": ("अच्छा", "adjectives"),
    "achhi": ("अच्छी", "adjectives"),
    "achhe": ("अच्छे", "adjectives"),

    # Food & Drink
    "thekua": ("ठेकुआ", "food"),
    "chocolate": ("चॉकलेट", "food"),
    "tea": ("चाय", "food"),
    "coffee": ("कॉफ़ी", "food"),
    "pizza": ("पिज़्ज़ा", "food"),
    "burger": ("बर्गर", "food"),
    "momo": ("मोमो", "food"),
    "momos": ("मोमोज़", "food"),
    "roti": ("रोटी", "food"),
    "sabzi": ("सब्ज़ी", "food"),
    "daal": ("दाल", "food"),
    "chawal": ("चावल", "food"),
    "kheer": ("खीर", "food"),
    "mithai": ("मिठाई", "food"),
    "pani": ("पानी", "food"),
    "doodh": ("दूध", "food"),

    # Places & Travel
    "bihar": ("बिहार", "places"),
    "delhi": ("दिल्ली", "places"),
    "noida": ("नोएडा", "places"),
    "cllg": ("कॉलेज", "places"),
    "college": ("कॉलेज", "places"),
    "school": ("स्कूल", "places"),
    "metro": ("मेट्रो", "places"),
    "hospital": ("अस्पताल", "places"),
    "ghar": ("घर", "places"),
    "room": ("कमरा", "places"),
    "road": ("सड़क", "places"),
    "market": ("मार्केट", "places"),

    # Family & People
    "billa": ("बिल्ला", "family_relations"),
    "billi": ("बिल्ली", "family_relations"),
    "lala": ("लाला", "family_relations"),
    "laadli": ("लाडली", "family_relations"),
    "ladli": ("लाडली", "family_relations"),
    "bhai": ("भाई", "family_relations"),
    "bhaiya": ("भैया", "family_relations"),
    "didi": ("दीदी", "family_relations"),
    "behen": ("बहन", "family_relations"),
    "dost": ("दोस्त", "family_relations"),
    "bandi": ("बंदी", "family_relations"),
    "banda": ("बंदा", "family_relations"),
    "baccha": ("बच्चा", "family_relations"),
    "bchaa": ("बच्चा", "family_relations"),
    "bache": ("बच्चे", "family_relations"),
    "thakur": ("ठाकुर", "family_relations"),
    "tiwari": ("तिवारी", "family_relations"),
    "sharma": ("शर्मा", "family_relations"),
    "shree": ("श्री", "family_relations"),
    "aditya": ("आदित्य", "family_relations"),
    "gourav": ("गौरव", "family_relations"),
    "harry": ("हैरी", "family_relations"),
    "khanak": ("खनक", "family_relations"),
    "simran": ("सिमरन", "family_relations"),
    "palak": ("पलक", "family_relations"),
    "daksh": ("दक्ष", "family_relations"),
    "siddharth": ("सिद्धार्थ", "family_relations"),
    "fayzaa": ("फ़ैज़ा", "family_relations"),
    "rohan": ("रोहन", "family_relations"),
    "priya": ("प्रिया", "family_relations"),
    "neha": ("नेहा", "family_relations"),
    "kavya": ("काव्या", "family_relations"),
    "manish": ("मनीष", "family_relations"),

    # Greetings & Social Expressions
    "aslamvalekum": ("अस्सलाम वालेकुम", "greetings"),
    "valekumasalm": ("वालेकुम अस्सलाम", "greetings"),
    "wao": ("वाओ", "greetings"),
    "wow": ("वाओ", "greetings"),
    "hayee": ("हाय", "greetings"),
    "haye": ("हाय", "greetings"),
    "arre": ("अरे", "greetings"),
    "arr": ("अरे", "greetings"),
    "arrey": ("अरे", "greetings"),
    "shukriya": ("शुक्रिया", "greetings"),
    "dhanyawad": ("धन्यवाद", "greetings"),
    "namaste": ("नमस्ते", "greetings"),
    "hello": ("हैलो", "greetings"),
    "hlo": ("हैलो", "greetings"),
    "hlw": ("हैलो", "greetings"),
    "bye": ("बाय", "greetings"),
    "byee": ("बाय", "greetings"),
    "tata": ("टाटा", "greetings"),
    "gudnightt": ("गुड नाईट", "greetings"),
    "gudnightty": ("गुड नाईट", "greetings"),
    "nighttty": ("नाईट", "greetings"),
    "goodnight": ("गुड नाईट", "greetings"),
    "sori": ("सॉरी", "greetings"),
    "sorry": ("सॉरी", "greetings"),
    "pls": ("प्लीज़", "greetings"),
    "plss": ("प्लीज़", "greetings"),
    "please": ("प्लीज़", "greetings"),
    "rabba": ("रब्बा", "greetings"),
    "ooh": ("ऊह", "greetings"),
    "yo": ("यो", "greetings"),

    # Time & Temporal
    "sunday": ("रविवार", "time"),
    "monday": ("सोमवार", "time"),
    "raat": ("रात", "time"),
    "subah": ("सुबह", "time"),
    "shaam": ("शाम", "time"),
    "dopahar": ("दोपहर", "time"),
    "kal": ("कल", "time"),
    "aaj": ("आज", "time"),
    "abhi": ("अभी", "time"),
    "dino": ("दिनों", "time"),
    "din": ("दिन", "time"),
    "waqt": ("वक़्त", "time"),
    "samay": ("समय", "time"),
    "baje": ("बजे", "time"),
    "roj": ("रोज़", "time"),
    "ghante": ("घंटे", "time"),
    "minute": ("मिनट", "time"),

    # Question Words
    "kyu": ("क्यों", "question_words"),
    "kyuu": ("क्यों", "question_words"),
    "kyun": ("क्यों", "question_words"),
    "kya": ("क्या", "question_words"),
    "kaise": ("कैसे", "question_words"),
    "kaisa": ("कैसा", "question_words"),
    "kaisi": ("कैसी", "question_words"),
    "kab": ("कब", "question_words"),
    "kaha": ("कहाँ", "question_words"),
    "kahan": ("कहाँ", "question_words"),
    "kidhar": ("किधर", "question_words"),
    "kitna": ("कितना", "question_words"),
    "kitni": ("कितनी", "question_words"),
    "kitne": ("कितने", "question_words"),
    "kon": ("कौन", "question_words"),
    "kaun": ("कौन", "question_words"),

    # Postpositions & Spatial
    "uppar": ("ऊपर", "postpositions"),
    "upar": ("ऊपर", "postpositions"),
    "neeche": ("नीचे", "postpositions"),
    "saath": ("साथ", "postpositions"),
    "sath": ("साथ", "postpositions"),
    "bina": ("बिना", "postpositions"),
    "paas": ("पास", "postpositions"),
    "andar": ("अंदर", "postpositions"),
    "bahar": ("बाहर", "postpositions"),
    "liye": ("लिए", "postpositions"),
    "samne": ("सामने", "postpositions"),
    "aage": ("आगे", "postpositions"),
    "piche": ("पीछे", "postpositions"),

    # Expletives & Banter
    "ghalicho": ("गलीच", "expletives_slang"),
    "bakwaas": ("बकवास", "expletives_slang"),
    "chutiya": ("चूतिया", "expletives_slang"),
    "kamina": ("कमीना", "expletives_slang"),
    "bewakoof": ("बेवकूफ़", "expletives_slang"),
    "kuchupuchu": ("कुचुपूचू", "expletives_slang"),

    # English Loanwords & Passthrough
    "assignment": ("असाइनमेंट", "english_passthrough"),
    "bore": ("बोर", "english_passthrough"),
    "boys": ("बॉयज़", "english_passthrough"),
    "check": ("चेक", "english_passthrough"),
    "delete": ("डिलीट", "english_passthrough"),
    "filter": ("फ़िल्टर", "english_passthrough"),
    "gif": ("जिफ़", "english_passthrough"),
    "group": ("ग्रुप", "english_passthrough"),
    "gym": ("जिम", "english_passthrough"),
    "listen": ("लिसन", "english_passthrough"),
    "message": ("मैसेज", "english_passthrough"),
    "msg": ("मैसेज", "english_passthrough"),
    "phn": ("फ़ोन", "english_passthrough"),
    "phone": ("फ़ोन", "english_passthrough"),
    "reality": ("रियलिटी", "english_passthrough"),
    "reel": ("रील", "english_passthrough"),
    "reels": ("रील्स", "english_passthrough"),
    "reject": ("रिजेक्ट", "english_passthrough"),
    "reply": ("रिप्लाई", "english_passthrough"),
    "status": ("स्टेटस", "english_passthrough"),
    "voice": ("वॉइस", "english_passthrough"),
    "wait": ("वेट", "english_passthrough"),
    "weight": ("वेट", "english_passthrough"),
    "knight": ("नाइट", "english_passthrough"),
    "fallen": ("फॉलन", "english_passthrough"),
    "online": ("ऑनलाइन", "english_passthrough"),
    "mental": ("मेंटल", "english_passthrough"),
    "hospital": ("हॉस्पिटल", "english_passthrough"),
    "party": ("पार्टी", "english_passthrough"),
    "mood": ("मूड", "english_passthrough"),
    "game": ("गेम", "english_passthrough"),
    "link": ("लिंक", "english_passthrough"),
    "post": ("पोस्ट", "english_passthrough"),
    "story": ("स्टोरी", "english_passthrough"),
    "call": ("कॉल", "english_passthrough"),
    "chat": ("चैट", "english_passthrough"),
    "type": ("टाइप", "english_passthrough"),
    "typing": ("टाइपिंग", "english_passthrough"),
    "height": ("हाइट", "english_passthrough"),
    "photo": ("फ़ोटो", "english_passthrough"),
    "video": ("वीडियो", "english_passthrough"),
    "live": ("लाइव", "english_passthrough"),
    "love": ("लव", "english_passthrough"),
    "cute": ("क्यूट", "english_passthrough"),
    "busy": ("बिज़ी", "english_passthrough"),
    "free": ("फ्री", "english_passthrough"),
    "ready": ("रेडी", "english_passthrough"),

    # Misc & Nouns
    "mazak": ("मज़ाक", "misc_nouns"),
    "maza": ("मज़ा", "misc_nouns"),
    "ladai": ("लड़ाई", "misc_nouns"),
    "rakhi": ("राखी", "misc_nouns"),
    "baat": ("बात", "misc_nouns"),
    "baatein": ("बातें", "misc_nouns"),
    "nazar": ("नज़र", "misc_nouns"),
    "juban": ("ज़ुबान", "misc_nouns"),
    "chinta": ("चिंता", "misc_nouns"),
    "zarurat": ("ज़रूरत", "misc_nouns"),
    "tayari": ("तैयारी", "misc_nouns"),
    "bharmachari": ("ब्रह्मचारी", "misc_nouns"),
    "hatodaaa": ("हथौड़ा", "misc_nouns"),
    "hatoda": ("हथौड़ा", "misc_nouns"),
    "nukarnatak": ("नुक्कड़ नाटक", "misc_nouns"),
    "nind": ("नींद", "misc_nouns"),
    "sapna": ("सपना", "misc_nouns"),
    "dil": ("दिल", "misc_nouns"),
    "dimag": ("दिमाग़", "misc_nouns"),
    "sir": ("सर", "misc_nouns"),
    "haath": ("हाथ", "misc_nouns"),
    "aankhein": ("आँखें", "misc_nouns"),
    "kaan": ("कान", "misc_nouns"),
    "shakal": ("शक्ल", "misc_nouns"),
    "aawaz": ("आवाज़", "misc_nouns"),
    "naam": ("नाम", "misc_nouns"),
    "kaam": ("काम", "misc_nouns"),
    "km": ("काम", "misc_nouns"),
    "gyb": ("गायब", "misc_nouns"),
    "psnd": ("पसंद", "misc_nouns"),
}

# 3. Simple phonetic transliterator for any unmapped words
# Character mappings based on ISO 15919 / ITRANS
CONSONANTS = [
    ("ksha", "क्ष"), ("kSa", "क्ष"), ("tra", "त्र"), ("gya", "ज्ञ"), ("shra", "श्र"),
    ("chha", "छ"), ("chh", "छ"), ("ch", "च"), ("kh", "ख"), ("gh", "घ"), ("jh", "झ"),
    ("th", "थ"), ("dh", "ध"), ("ph", "फ"), ("bh", "भ"), ("sh", "श"), ("sh", "ष"),
    ("t", "त"), ("d", "द"), ("n", "न"), ("p", "प"), ("b", "ब"), ("m", "म"),
    ("y", "य"), ("r", "र"), ("l", "ल"), ("v", "व"), ("w", "व"), ("s", "स"), ("h", "ह"),
    ("k", "क"), ("g", "ग"), ("j", "ज")
]

VOWELS = [
    ("aa", "ा"), ("ee", "ी"), ("oo", "ू"), ("ai", "ै"), ("au", "ौ"),
    ("a", ""), ("i", "ि"), ("u", "ु"), ("e", "े"), ("o", "ो")
]

INDEP_VOWELS = [
    ("aa", "आ"), ("ee", "ई"), ("oo", "ऊ"), ("ai", "ऐ"), ("au", "औ"),
    ("a", "अ"), ("i", "इ"), ("u", "उ"), ("e", "ए"), ("o", "ओ")
]

def phonetic_transliterate(w):
    w = w.lower().strip()
    # Normalize elongated chars: e.g. 'sojaooo' -> 'sojao'
    w_norm = re.sub(r'([a-z])\1{2,}', r'\1\1', w)
    
    # Check overrides
    if w in chat_word_overrides:
        return chat_word_overrides[w][0]
    if w_norm in chat_word_overrides:
        return chat_word_overrides[w_norm][0]
    if w in existing_category_map:
        return existing_category_map[w][0]
    if w_norm in existing_category_map:
        return existing_category_map[w_norm][0]
    if w in dict_map:
        return dict_map[w]
    if w_norm in dict_map:
        return dict_map[w_norm]
    
    # Heuristic fallback transliteration
    res = ""
    i = 0
    first = True
    while i < len(w_norm):
        if first:
            matched_v = False
            for v_str, v_val in INDEP_VOWELS:
                if w_norm.startswith(v_str, i):
                    res += v_val
                    i += len(v_str)
                    matched_v = True
                    first = False
                    break
            if matched_v:
                continue

        matched_c = False
        for c_str, c_val in CONSONANTS:
            if w_norm.startswith(c_str, i):
                res += c_val
                i += len(c_str)
                first = False
                matched_c = True
                # Check for vowel following consonant
                for v_str, v_val in VOWELS:
                    if w_norm.startswith(v_str, i):
                        res += v_val
                        i += len(v_str)
                        break
                break
        if not matched_c:
            # Fallback single letter
            ch = w_norm[i]
            if ch == 'a': res += "" if not first else "अ"
            elif ch == 'i': res += "ि" if not first else "इ"
            elif ch == 'u': res += "ु" if not first else "उ"
            elif ch == 'e': res += "े" if not first else "ए"
            elif ch == 'o': res += "ो" if not first else "ओ"
            i += 1
            first = False
            
    return res if res else w

def categorize_word(w, devanagari_w):
    w_lower = w.lower()
    w_norm = re.sub(r'([a-z])\1{2,}', r'\1\1', w_lower)
    
    # 1. Overrides
    if w_lower in chat_word_overrides:
        return chat_word_overrides[w_lower][1]
    if w_norm in chat_word_overrides:
        return chat_word_overrides[w_norm][1]
        
    # 2. Existing Canonical Categories
    if w_lower in existing_category_map:
        cat = existing_category_map[w_lower][1]
        if cat.startswith("aksharantar_"):
            cat = cat.replace("aksharantar_", "")
        if cat in ["daily_use_264", "misc"]:
            cat = "misc_nouns"
        return cat
    if w_norm in existing_category_map:
        cat = existing_category_map[w_norm][1]
        if cat.startswith("aksharantar_"):
            cat = cat.replace("aksharantar_", "")
        if cat in ["daily_use_264", "misc"]:
            cat = "misc_nouns"
        return cat
    
    # 2. Heuristics based on suffixes and patterns
    # Verbs
    if w_lower.endswith(("ega", "egi", "enge", "unga", "ungi", "unga", "aungi", "auga",
                         "kar", "karo", "kare", "karna", "karta", "karti", "karte",
                         "raha", "rahi", "rahe", "gaya", "gayi", "gaye",
                         "aaya", "aayi", "aaye", "aana", "jaana", "gaya", "gye",
                         "te", "ti", "ta", "yo", "ao", "ye")):
        return "verbs"
        
    # Question words
    if w_lower in ["kya", "kab", "kaha", "kahan", "kaise", "kaisa", "kaisi", "kaun", "kon", "kyu", "kyun", "kitna", "kitne"]:
        return "question_words"
        
    # Pronouns
    if w_lower in ["main", "mai", "me", "hum", "tum", "tu", "aap", "wo", "voh", "ye", "yeh", "kisi", "koi", "sab"]:
        return "pronouns"
        
    # Postpositions
    if w_lower in ["se", "ko", "par", "pe", "ka", "ke", "ki", "mein", "me", "tak", "saath"]:
        return "postpositions"
        
    # Greetings / Social
    if w_lower in ["hi", "hello", "hey", "hlo", "hlw", "ok", "okay", "hmmm", "hmm", "haan", "ha", "hn", "nhi", "nah", "no", "yes"]:
        return "greetings"
        
    # Chat slang
    if len(w_lower) >= 3 and (w_lower[-1] * 2 in w_lower or w_lower in ["yrr", "bc", "bhai", "plss", "sojao", "jhut"]):
        return "chat_slang"
        
    # Common English words
    english_suffixes = ("ing", "ed", "tion", "able", "ment", "ness", "ity", "ly", "er", "est")
    if w_lower.endswith(english_suffixes) or len(w_lower) > 7:
        return "english_passthrough"
        
    return "misc_nouns"

def main():
    chat_file = "data/raw_chat/chat.txt"
    if not os.path.exists(chat_file):
        print(f"Error: {chat_file} not found")
        return

    with open(chat_file, "r", encoding="utf-8") as f:
        lines = f.readlines()

    word_counts = Counter()
    word_contexts = {}

    for line in lines:
        line = line.strip()
        m = re.match(r'^\[.*?\]\s*([^:]+):\s*(.*)$', line)
        if not m:
            continue
        sender, msg = m.group(1).strip(), m.group(2).strip()
        if '<स्टिकर' in msg or '<मीडिया' in msg or '<डिलीट' in msg:
            continue
        # Clean URLs and mentions
        msg_clean = re.sub(r'https?://\S+', '', msg)
        msg_clean = re.sub(r'@[^\s]+', '', msg_clean)
        
        tokens = re.findall(r'\b[a-zA-Z]+\b', msg_clean)
        for t in tokens:
            if len(t) >= 2:
                tl = t.lower()
                word_counts[tl] += 1
                if tl not in word_contexts:
                    word_contexts[tl] = msg_clean.strip()

    print(f"[*] Processed {len(word_counts)} unique word tokens from chat.")

    categorized_data = []
    category_buckets = defaultdict(list)

    for word, count in word_counts.most_common():
        devanagari = phonetic_transliterate(word)
        category = categorize_word(word, devanagari)
        
        entry = {
            "word": word,
            "devanagari": devanagari,
            "category": category,
            "frequency": count,
            "sample_context": word_contexts.get(word, "")
        }
        categorized_data.append(entry)
        category_buckets[category].append(entry)

    # Output 1: JSON format
    os.makedirs("data/categorized_data", exist_ok=True)
    json_path = "data/categorized_data/categorized_chat_words.json"
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(categorized_data, f, ensure_ascii=False, indent=2)
    print(f"[+] Wrote {len(categorized_data)} categorized words to {json_path}")

    # Output 2: CSV format
    csv_path = "data/categorized_data/categorized_chat_words.csv"
    with open(csv_path, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["Word (Hinglish)", "Devanagari (Hindi)", "Category", "Frequency", "Sample Context"])
        for e in categorized_data:
            writer.writerow([e["word"], e["devanagari"], e["category"], e["frequency"], e["sample_context"]])
    print(f"[+] Wrote CSV dataset to {csv_path}")

    # Output 3: Markdown Documentation
    md_path = "data/categorized_data/README.md"
    with open(md_path, "w", encoding="utf-8") as f:
        f.write("# Categorized Chat Vocabulary: online mental hospital 🏥\n\n")
        f.write(f"- **Total Unique Words Categorized:** {len(categorized_data)}\n")
        f.write(f"- **Total Chat Tokens Processed:** {sum(word_counts.values())}\n\n")
        f.write("## Category Breakdown\n\n")
        f.write("| Category | Description | Word Count | Top Examples |\n")
        f.write("| :--- | :--- | :--- | :--- |\n")
        
        category_names = {
            "verbs": "Verbs & Conjugations (क्रिया)",
            "pronouns": "Pronouns & Demonstratives (सर्वनाम)",
            "adjectives": "Adjectives & Descriptors (विशेषण)",
            "chat_slang": "Chat Slang, Contractions & Fillers (चैट संक्षेप)",
            "greetings": "Greetings & Social Expressions (अभिवादन)",
            "family_relations": "People, Relations & Names (व्यक्ति व सम्बंध)",
            "food": "Food & Beverages (खान-पान)",
            "places": "Places & Transport (स्थान व यात्रा)",
            "time": "Time & Calendar (समय)",
            "question_words": "Question Words (प्रश्नवाचक)",
            "postpositions": "Postpositions & Case (परसर्ग)",
            "english_passthrough": "English Loanwords (अंग्रेज़ी शब्द)",
            "expletives_slang": "Banter & Informal Expletives (तंज व गाली)",
            "misc_nouns": "Miscellaneous Nouns (विविध संज्ञा)"
        }
        
        for cat, label in category_names.items():
            words_in_cat = category_buckets.get(cat, [])
            top_ex = ", ".join([f"{x['word']} ({x['devanagari']})" for x in words_in_cat[:5]])
            f.write(f"| **{cat}** | {label} | {len(words_in_cat)} | {top_ex} |\n")
            
        f.write("\n## Sample Entries\n\n")
        f.write("| Hinglish | Devanagari | Category | Frequency |\n")
        f.write("| :--- | :--- | :--- | :--- |\n")
        for e in categorized_data[:30]:
            f.write(f"| `{e['word']}` | {e['devanagari']} | `{e['category']}` | {e['frequency']} |\n")

    print(f"[+] Wrote Documentation to {md_path}")

    # Output 4: Create modular Nim dictionary file: data/categories/mental_hospital_chat.nim
    nim_file = "data/categories/mental_hospital_chat.nim"
    with open(nim_file, "w", encoding="utf-8") as f:
        f.write("# ============ CHAT VOCABULARY: online mental hospital 🏥 ============\n")
        f.write("# Automatically categorized and curated from chat export\n\n")
        
        for cat, entries in category_buckets.items():
            cat_label = category_names.get(cat, cat.upper())
            f.write(f"\n# --- {cat_label} ---\n")
            for e in entries:
                # Filter out pure noise / malformed tokens
                w = e["word"]
                d = e["devanagari"]
                if not d or d == w:
                    continue
                f.write(f'result["{w}"] = @["{d}"]\n')

    print(f"[+] Generated Nim modular category file: {nim_file}")

    # Output 5: Check and update data/common_dict.nim to include mental_hospital_chat
    common_dict_path = "data/common_dict.nim"
    if os.path.exists(common_dict_path):
        with open(common_dict_path, "r", encoding="utf-8") as f:
            content = f.read()
        if "include categories/mental_hospital_chat" not in content:
            new_content = content.strip() + "\n  include categories/mental_hospital_chat\n"
            with open(common_dict_path, "w", encoding="utf-8") as f:
                f.write(new_content)
            print(f"[+] Updated {common_dict_path} to include categories/mental_hospital_chat")
        else:
            print(f"[*] {common_dict_path} already includes mental_hospital_chat")

if __name__ == "__main__":
    main()
