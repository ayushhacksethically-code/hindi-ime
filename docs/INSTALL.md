# Installation Guide

## Prerequisites

1. **Nim**: Install Nim compiler (version 2.0+ recommended):
   ```bash
   curl https://nim-lang.org/choosenim/init.sh -sSf | sh
   ```
2. **Fcitx5 and Rime**:
   - On Debian/Ubuntu:
     ```bash
     sudo apt install fcitx5 fcitx5-rime
     ```
   - On Fedora:
     ```bash
     sudo dnf install fcitx5 fcitx5-rime
     ```
   - On Arch Linux:
     ```bash
     sudo pacman -S fcitx5 fcitx5-rime
     ```

## Automated Installation

Run the provided installation script:
```bash
./scripts/install.sh
```

## Manual Installation

1. Build the dictionary compiler:
   ```bash
   nim c -d:release src/compile_rime_hindi.nim
   ```
2. Generate the Rime dictionary:
   ```bash
   ./src/compile_rime_hindi
   ```
3. Copy schema and dictionary to Fcitx5-Rime directory:
   ```bash
   mkdir -p ~/.local/share/fcitx5/rime
   cp rime/*.yaml ~/.local/share/fcitx5/rime/
   ```
4. Restart Fcitx5:
   ```bash
   fcitx5 -r -d
   ```
5. In Fcitx5 Configuration, add or select `hindi_ai`.
