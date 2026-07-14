# START — składanie gry w całość, krok po kroku

Kolejność jest ważna: **najpierw kod (Etap 1), potem modele (Etap 2)**.
Kod działa bez modeli — gra buduje wszystko z klocków, więc już po Etapie 1
masz działającą grę do biegania. Modele wgrywasz potem partiami, a gra
podpina je automatycznie, bez zmian w kodzie.

---

## Etap 1 — kod w Roblox Studio (~20 minut)

Szczegóły: [`src/README.md`](src/README.md). W skrócie:

1. Roblox Studio → **New** → szablon **Baseplate**.
2. Wklej **7 plików** z `src/` wg tabeli w README — pilnuj TYPU skryptu
   (ModuleScript / Script / LocalScript), MIEJSCA i NAZWY:
   - `GameConfig` → ModuleScript w `ReplicatedStorage`
   - `DataService`, `EventService` → ModuleScripty w `ServerScriptService`
   - `MapBuilder`, `GameServer` → Scripty w `ServerScriptService`
   - `ClientMain`, `FxClient` → LocalScripty w `StarterPlayer → StarterPlayerScripts`
3. **File → Publish to Roblox** (nazwa robocza, gra może być prywatna).
4. **Game Settings → Security → Enable Studio Access to API Services** = ON
   (bez tego nie działa zapis postępu).
5. **Play (F5)** i przejdź checklistę z `src/README.md` („Jak sprawdzić, że
   wszystko działa"): sprint + trzęsienie kamery, ścinanie grzybów,
   powrót do bazy i sadzenie, zbiór z zielonego pada, ulepszanie grzyba,
   jajko z petami, rebirth, HUD.

**Coś nie działa?** Otwórz okno **Output** (View → Output) — czerwona linia
mówi, w którym skrypcie i której linii jest problem. Najczęstsza usterka
(„nic się nie pojawia") też jest opisana w `src/README.md`. Skopiuj mi
treść błędu, jeśli utkniesz.

> Na tym etapie NIE ruszaj game passów — gra działa bez nich (ID = 0
> traktowane jest jako „pass wyłączony"). To Etap 3, na koniec.

## Etap 2 — modele z Blendera (partiami, w dowolnym tempie)

Szczegóły: [`blender/README.md`](blender/README.md) (jak uruchamiać skrypty
i eksportować FBX) + [`blender/PODPIECIE-MODELI.md`](blender/PODPIECIE-MODELI.md)
(struktura folderów i DOKŁADNE nazwy).

**Zacznij od jednego modelu-próbki**, żeby przećwiczyć cały pipeline:

1. Blender → zakładka **Scripting** → New → wklej `blender/05-grzyby-swiat1.py`
   → **Run Script**. (Szare modele? Wciśnij `Z` → **Material Preview** —
   kolory są, tylko domyślny podgląd ich nie pokazuje.)
2. Zaznacz części JEDNEGO grzyba (np. wszystkie zaczynające się od `G01_`),
   **File → Export → FBX**, w opcjach: ✔ Selected Objects,
   Transform → Apply Scalings: **FBX All**.
3. Studio → **Home → Import 3D** → wybierz plik → Import.
4. W Explorerze: utwórz w `ReplicatedStorage` folder `Models`, w nim folder
   `Grzyby`, przeciągnij tam zaimportowany model i **nazwij go dokładnie**
   `Kurka` (nazwy: tabele w PODPIECIE-MODELI.md).
5. **Play** — biegnij do lasu; część miejscówek Świata 1 to teraz Twoja
   Kurka (miejscówki odrastają co kilka sekund). Prompt pokaże „Kurka".

Działa? To teraz seryjnie, wg priorytetu (co daje najwięcej efektu):

| Kolejność | Co | Skrypty | Gdzie w Models |
|-----------|----|---------|----------------|
| 1 | Grzyby Świata 1 (reszta) | `05` | `Models/Grzyby/…` |
| 2 | Stanowisko jaja | `15` | `Models/GniazdoJajo` (jeden model, bez folderu) |
| 3 | Pety Świata 1 | `16` | `Models/Pety/…` |
| 4 | Grzyby Światów 2–5 | `08, 10, 12, 06` | `Models/Grzyby/…` |
| 5 | Pety Światów 2–5 | `17, 18, 19, 20` | `Models/Pety/…` |

Gra sama ustawia: kotwiczenie, kolizje, `*Glow` → Neon, skalę petów oraz
**materiały-„tekstury" po nazwach części** (drewno, kamień, szkło, lód,
trawa, futro…). Niczego nie konfigurujesz.

**Natura (drzewa, kamienie, kwiatki — skrypty 01–04, 07, 09, 11, 13, 14)
na razie zostaw.** Mapę buduje proceduralnie MapBuilder i wygląda dobrze;
podmiana dekoracji na modele to osobny krok, który zrobię w kodzie, gdy
grzyby i pety będą już śmigać. (Możesz je oczywiście już wygenerować
i wyeksportować do plików — po prostu jeszcze ich nie wgrywaj.)

## Etap 3 — monetyzacja (na koniec, gdy gra działa)

1. [Creator Hub](https://create.roblox.com) → Twoje doświadczenie →
   **Monetization**: utwórz Game Passy i Developer Products o nazwach
   i cenach z tabeli w `02-koncepcja-gry.md` §9.
2. Każdy utworzony pass/produkt ma numeryczne **ID** — wpisz je
   w `GameConfig` w miejsca `id = 0` (sekcje `Config.GamePasses`
   i `Config.DevProducts`), np. `id = 123456789`.
3. Przetestuj zakup w Studio (transakcje testowe nie pobierają Robux).

## Częste problemy

| Objaw | Przyczyna / naprawa |
|-------|---------------------|
| Nic się nie dzieje po Play | Zły typ skryptu albo złe miejsce — porównaj z tabelą w `src/README.md`; sprawdź Output |
| „DataStore … 403" w Output | Nie włączono API Services (Etap 1 pkt 4) albo gra nieopublikowana |
| Model po imporcie leży na boku / jest ogromny | W Blenderze przed eksportem: zaznacz wszystko → `Ctrl+A` → All Transforms; w FBX: Apply Scalings = FBX All |
| Model wgrany, ale w grze dalej klocki | Zła nazwa (musi być co do litery, z polskimi znakami — tabele w PODPIECIE-MODELI.md) albo zły folder |
| Części modelu nie świecą | To normalne do czasu podpięcia — gra sama ustawia Neon częściom `*Glow` przy klonowaniu; w samym folderze Models mogą wyglądać zwyczajnie |
| Szaro w Blenderze | `Z` → Material Preview (to tylko podgląd; FBX i tak niesie kolory) |

Utknąłeś? Skopiuj mi dokładną treść błędu z Output (albo opisz, co widzisz),
a poprawię kod / podpowiem następny ruch.
