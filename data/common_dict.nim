import std/tables

proc getCommonDict*(): Table[string, seq[string]] =
  result = initTable[string, seq[string]]()

  # ============================================================
  # CONSOLIDATED HINGLISH DICT (MODULAR CATEGORIES)
  # Data Sources:
  # - Common high-frequency Hinglish vocabulary (curated)
  # - Hindi WordNet (IIT Bombay, GPL license)
  # - Conversational corpus (anonymized, aggregated)
  # - Academic & technical terms (geography, science, etc.)
  # ============================================================

  include categories/pronouns
  include categories/verbs
  include categories/family
  include categories/body
  include categories/home
  include categories/food
  include categories/time
  include categories/places
  include categories/adjectives
  include categories/question_words
  include categories/postpositions
  include categories/numbers
  include categories/ordinals
  include categories/greetings
  include categories/misc
  include categories/english_passthrough
  include categories/whatsapp_chat
  include categories/daily_use_264
  include categories/expletives
  include categories/prefix_words
  include categories/chat_slang
  include categories/chat_verbs
  include categories/chat_pronouns
  include categories/chat_reactions
  include categories/chat_english
