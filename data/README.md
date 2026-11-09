# Dictionary Data

This directory contains dictionary data sources and dictionary definitions used by the Hindi IME.

- `common_dict.nim`: High-frequency Hinglish-to-Devanagari mapping dictionary loader aggregating modular categories.
- `categories/`: Modular curated dictionaries organized by domain:
  - `prefix_words.nim`: 180+ curated words with common prefixes (e.g., `be-`, `sam-`, `vi-`, `nir-`, `pra-`, `su-`, `up-`, `bad-`, `na-`, `khush-`, `an-`).
  - `pronouns.nim`, `verbs.nim`, `family.nim`, `food.nim`, `places.nim`, `adjectives.nim`, `whatsapp_chat.nim`, etc.
- External sources (such as Hindi WordNet) are processed into binary dictionaries during compilation.
