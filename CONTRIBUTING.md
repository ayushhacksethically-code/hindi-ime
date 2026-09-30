# Bhai, contribute kar — Hindi IME better banate hain!

## Kya kar sakta hai?

### 1. Galti bata

Sabse aasan kaam. Jo galat aaye, GitHub issue kholo.

Format:
```text
Input: jaan
Output: जाआँच
Expected: जान
Type: Informal
```

### 2. Word add kar

Tere area ke words add kar. Jaise:

```nim
result["jaan"] = @["जान"]
result["kasam"] = @["कसम"]
```

`data/common_dict.nim` mein daal, phir:
```bash
./scripts/build_dict.sh
fcitx5 -r -d
```

Test kar, phir PR bhej.

### 3. Code improve kar

Rule engine better kar, naye features add kar.

### 4. Document kar

README better kar, examples add kar.

## Kaise PR bheje?

1. Fork kar
2. Branch bana: `git checkout -b feature/mere-changes`
3. Changes kar
4. Commit: `git commit -m "dict: add 50 naye words"`
5. Push: `git push origin feature/mere-changes`
6. PR kholo

## Rules

- Friendly raho. Sab naye hain.
- Test karo — PR se pehle.
- Chhote changes karo — ek PR, ek kaam.
- Explain karo — kya kiya, kyun kiya.

## Kya nahi karna

- Force mat karo — kisi ko kuch thopna nahi.
- Galti mat dhundho — help karo.
- Language mat judge karo — formal, informal, sab theek.

---

Bhai, chalo milkar Hindi typing better banate hain! 🇮🇳
