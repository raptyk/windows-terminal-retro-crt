# windows-terminal-retro-crt

[English](README.md) | **Polski** · [Strona projektu](https://raptyk.github.io/windows-terminal-retro-crt/#pl)

Wygląd starego monitora CRT w Windows Terminal: cztery profile z fosforowymi schematami kolorów, shaderami CRT i klasycznymi czcionkami terminalowymi. Jeden skrypt instaluje wszystko na czystym Windowsie.

![Cztery profile Retro CRT: VGA, Terminus, Plex i C64](docs/screenshots/overview.png)

> [!IMPORTANT]
> **Platforma: tylko Windows**  
> Windows 10 / 11. Windows Terminal i PowerShell 7 instalują się automatycznie, jeśli ich brakuje. Wszystko instaluje się dla bieżącego użytkownika; uprawnienia administratora nie są potrzebne, chyba że winget instaluje PowerShell 7.

## Profile

| Profil | Czcionka | Powłoka | Wygląd |
|---|---|---|---|
| **Retro CRT · VGA** | PxPlus IBM VGA 9x16, 12 pt | Windows PowerShell | Na co dzień. Oryginalna czcionka trybu tekstowego IBM VGA, piksel w piksel. |
| **Retro CRT · Terminus** | Terminus (TTF), 12 pt | Windows PowerShell | Na co dzień. Czcionka konsoli Linuksa z prawdziwym pogrubieniem. |
| **Retro CRT · Plex** | IBM Plex Mono, 10 pt | Windows PowerShell | Na co dzień. Gładka czcionka wektorowa, najmniej „pikselowa”. |
| **Retro CRT · C64** | C64 Pro Mono, 11 pt | PowerShell 7 | Dla zabawy: wypukłe szkło, mocna poświata, linie skanowania, migotanie i szum. |

Trzy profile do codziennej pracy mają wspólny shader `crt-daily.hlsl` (linie skanowania, poświata wokół znaków, ciemniejsze brzegi kineskopu, bez animacji) i schemat **Retro CRT · Phosphor Daily**: zwykły tekst jest fosforowo zielony, a błędy, ostrzeżenia i git zachowują swoje kolory. Profil C64 używa `crt.hlsl` i schematu **Retro CRT · Green Phosphor**.

| VGA | Terminus |
|---|---|
| ![Retro CRT · VGA](docs/screenshots/vga.png) | ![Retro CRT · Terminus](docs/screenshots/terminus.png) |
| **Plex** | **C64** |
| ![Retro CRT · Plex](docs/screenshots/plex.png) | ![Retro CRT · C64](docs/screenshots/c64.png) |

## Instalacja

```powershell
git clone https://github.com/raptyk/windows-terminal-retro-crt
cd windows-terminal-retro-crt
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Nie masz gita? Pobierz [ZIP](https://github.com/raptyk/windows-terminal-retro-crt/archive/refs/heads/main.zip), rozpakuj go i uruchom `install.ps1` tak samo.

Potem zamknij **wszystkie** okna Windows Terminal i uruchom go ponownie (Terminal wczytuje listę czcionek tylko przy starcie). Profile znajdziesz w menu nowej karty.

Co robi `install.ps1`:

1. Instaluje Windows Terminal i PowerShell 7, jeśli ich brakuje: przez `winget` albo, gdy `winget` nie jest dostępny, z oficjalnych wydań na GitHubie do `%LOCALAPPDATA%\Programs`. Ten krok pomija parametr `-SkipDependencies`.
2. Instaluje czcionki dla bieżącego użytkownika (`%LOCALAPPDATA%\Microsoft\Windows\Fonts`). Pobierane paczki mają przypiętą wersję i sprawdzaną sumę SHA256.
3. Kopiuje shadery do `%LOCALAPPDATA%\Microsoft\Windows Terminal\RetroCRT\shaders`.
4. Dodaje profile i schematy kolorów do `settings.json` Terminala (wersje ze Sklepu, Preview i bez pakietu). Najpierw zapisuje obok kopię zapasową `settings.json.retrocrt-<data>.bak`. Podmienia tylko profile Retro CRT (rozpoznawane po GUID) i ich schematy kolorów; pozostałe ustawienia zostają bez zmian.

Ponowne uruchomienie aktualizuje istniejącą instalację.

> [!NOTE]
> Efekty shaderów wymagają akceleracji GPU. W maszynach wirtualnych bez GPU (na przykład w Windows Sandbox z wyłączonym vGPU) profile działają, ale bez efektu CRT.

## Odinstalowanie

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1              # profile, schematy kolorów, shadery
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1 -RemoveFonts # ...i czcionki
```

Przed usunięciem profili `settings.json` jest kopiowany. Windows Terminal i PowerShell 7 nigdy nie są usuwane.

## Narzędzia

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\font-test.ps1     # zwykły tekst i pogrubienie, kolory, polskie znaki, podobne znaki
powershell -ExecutionPolicy Bypass -File .\tools\demo.ps1          # przykładowy ekran ze zrzutów (-Style C64 dla ekranu C64)
powershell -ExecutionPolicy Bypass -File .\tools\test-shaders.ps1  # kompilacja shaderów systemowym kompilatorem D3D
```

## Strojenie

- **Efekty:** zmień stałe na początku `shaders\crt-daily.hlsl` albo `shaders\crt.hlsl` (na przykład `SCANLINE_STRENGTH`, `GLOW_STRENGTH`) i uruchom `install.ps1` ponownie. Terminal przeładowuje shader, gdy tylko plik się zmieni.
- **Czcionki pikselowe muszą mieć natywny rozmiar.** PxPlus i Terminus są rysowane na siatce 16 px: używaj 12 pt (16 px przy skalowaniu 100%) albo 24 pt. Inne rozmiary przeskalowują znaki i je rozmywają. Z tego samego powodu `crt-daily.hlsl` nigdy nie przeskalowuje obrazu.
- **Pogrubienie:** profile mają `"intenseTextStyle": "all"`, więc pogrubienie ANSI (SGR 1) jest rysowane grubiej *i* jaśniej. Domyślne ustawienie Terminala (`"bright"`) zmienia tylko kolor, co nic nie daje dla tekstu w domyślnym kolorze. Czcionki PxPlus nie mają wariantu pogrubionego, więc Terminal pogrubia je sztucznie; Terminus i Plex mają prawdziwe pogrubienie.

## Czcionki i licencje

| Czcionka | Źródło | Licencja | Dystrybucja |
|---|---|---|---|
| PxPlus IBM VGA 9x16, VGA 8x14, VGA 9x14, EGA 8x14 | [The Ultimate Oldschool PC Font Pack](https://int10h.org/oldschool-pc-fonts/) v2.2, autor VileR | CC BY-SA 4.0 | dołączone w `fonts/int10h/` (bez zmian, z `LICENSE.TXT`), bo int10h.org blokuje pobieranie skryptami |
| C64 Pro Mono | [Style64 C64 TrueType](https://style64.org/c64-truetype) v1.2.1 | [licencja Style64](https://style64.org/c64-truetype/license) | pobierana ze style64.org podczas instalacji (redystrybucja jest zabroniona) |
| Terminus (TTF) | [Terminus TTF](https://files.ax86.net/terminus-ttf/) 4.49.3 | SIL OFL 1.1 | pobierana podczas instalacji |
| IBM Plex Mono | [IBM Plex](https://github.com/IBM/plex) 2.5.0 | SIL OFL 1.1 | pobierana podczas instalacji |

Shadery, schematy kolorów, skrypty i strona w tym repozytorium to praca własna.
