# Plan działania: od zera do wydanej gry na Roblox

> Plan dla jednej osoby, która **nie ma żadnego doświadczenia** w tworzeniu gier.
> Przygotowany 2026-07-08 na podstawie analizy aktualnych rankingów popularności
> (patrz [`01-analiza-formatow.md`](01-analiza-formatow.md)).
>
> **Status:** Krok 1 (analiza rynku + wybór formatu + koncepcja) — ✅ wykonany.
> Wynik: [`02-koncepcja-gry.md`](02-koncepcja-gry.md).

## Jak czytać ten plan

- Fazy wykonuj po kolei — każda ma listę zadań, szacowany czas i „kryterium
  wyjścia" (co musi być prawdą, żeby przejść dalej).
- Czasy zakładają ok. **10–15 h pracy tygodniowo** po godzinach. Przy pełnym
  etacie nad grą podziel je przez ~3.
- Wszystko, czego potrzebujesz, jest darmowe (Roblox Studio, dokumentacja,
  darmowe assety). Budżet pieniężny jest opcjonalny aż do fazy marketingu.

## Mapa całości

| Faza | Nazwa | Czas | Status |
|------|-------|------|--------|
| 0 | Fundamenty: konto i narzędzia | 1–2 dni | ⬜ |
| 1 | Analiza rynku i wybór formatu | 2–3 dni | ✅ wykonane |
| 2 | Nauka podstaw Studio i Luau | 3–4 tygodnie | ⬜ |
| 3 | Koncepcja i mini-GDD | 2–3 dni | ✅ szkic gotowy (do przeglądu po fazie 2) |
| 4 | Prototyp pętli rozgrywki | 2–3 tygodnie | ⬜ |
| 5 | Produkcja MVP | 6–10 tygodni | ⬜ |
| 6 | Oprawa: grafika, dźwięk, UI | 2–3 tygodnie (równolegle z 5) | ⬜ |
| 7 | Testy i poprawki | 2 tygodnie | ⬜ |
| 8 | Monetyzacja | 3–5 dni | ⬜ |
| 9 | Publikacja | 2–3 dni | ⬜ |
| 10 | Marketing i pierwsi gracze | ciągłe, start w dniu premiery | ⬜ |
| 11 | LiveOps: aktualizacje i utrzymanie | ciągłe | ⬜ |

**Realistyczny czas do premiery: ~4–6 miesięcy** pracy po godzinach.

---

## Faza 0 — Fundamenty: konto i narzędzia (1–2 dni)

1. **Załóż konto Roblox** na [roblox.com](https://www.roblox.com) (albo użyj
   istniejącego). Ustaw prawdziwą datę urodzenia — konta 13+ mają mniej
   ograniczeń w publikowaniu i monetyzacji.
2. **Włącz weryfikację dwuetapową (2FA)** — Ustawienia → Bezpieczeństwo.
   Przejęte konto = utrata gry i zarobków. To nie jest opcjonalne.
3. **Zainstaluj Roblox Studio** — darmowy, oficjalny edytor:
   [create.roblox.com](https://create.roblox.com). Działa na Windows i macOS.
4. **Zweryfikuj wiek dokumentem** w ustawieniach konta (Ustawienia →
   Weryfikacja). Potrzebne później do monetyzacji i publikacji bez ograniczeń.
5. Otwórz Studio, wybierz szablon „Baseplate", pochodź po świecie, postaw
   kilka klocków. Cel: oswoić się z kamerą i interfejsem, nic więcej.
6. (Opcjonalnie, na później) Zapisz sobie linki:
   - Dokumentacja: [create.roblox.com/docs](https://create.roblox.com/docs)
   - Forum deweloperów: [devforum.roblox.com](https://devforum.roblox.com)

**Kryterium wyjścia:** Studio uruchamia się, masz konto z 2FA, umiesz wstawić
part i przetestować grę przyciskiem Play.

---

## Faza 1 — Analiza rynku i wybór formatu (✅ wykonane)

Wykonane 2026-07-08 — pełna analiza w
[`01-analiza-formatow.md`](01-analiza-formatow.md). Najkrótsze streszczenie:

- Przeanalizowano miejsca **4–10** aktualnych rankingów (top 3 pominięte
  zgodnie z założeniem): kooperacyjne survivale nocne, strzelanki PvP,
  grindowe RPG, dedukcja społeczna, symulatory zbieractwa, symulatory petów,
  hiper-casualowe obby.
- **Rekomendowany format dla początkującego solo-dewelopera:** symulator
  zbieractwa (pętla „zbieraj → sprzedawaj → ulepszaj → odblokuj") z motywem
  z trendującego formatu survivalowego. Uzasadnienie i dwie alternatywy —
  w analizie.

---

## Faza 2 — Nauka podstaw Studio i Luau (3–4 tygodnie)

Język skryptowy Roblox to **Luau** (dialekt Lua) — jeden z najłatwiejszych
języków dla początkujących. Nie ucz się „całego programowania" na zapas；
ucz się dokładnie tego, czego wymaga twoja gra.

### Tydzień 1 — Studio bez kodu
- Oficjalny kurs: create.roblox.com/docs → **„Tutorials"** → ścieżka
  „Build It, Play It". Zrób pierwszy tutorial od A do Z.
- Naucz się: Explorer, Properties, Toolbox, kotwiczenie (Anchor),
  grupowanie (Model), materiały, oświetlenie, Terrain Editor (podstawy).
- Mini-projekt: zbuduj małą scenę (polana + chatka + ognisko). Bez skryptów.

### Tydzień 2 — Podstawy Luau
- Kurs skryptowania z dokumentacji („Scripting" → „Basic Scripting") albo
  seria wideo dla początkujących (na YouTube: BrawlDev / TheDevKing —
  „Beginner Scripting"). Jedno źródło, nie pięć naraz.
- Naucz się: zmienne, `if`, pętle, funkcje, tabele, zdarzenia
  (`Touched`, `ClickDetector`), `print()` i konsola Output.
- Mini-projekt: część, która po dotknięciu daje punkt i znika, licznik
  punktów na leaderboardzie (`leaderstats`).

### Tydzień 3 — Model klient–serwer (najważniejszy tydzień!)
- Zrozum podział: **Script** (serwer) vs **LocalScript** (klient) vs
  **ModuleScript** (biblioteka współdzielona).
- Naucz się `RemoteEvent` / `RemoteFunction` — komunikacja klient↔serwer.
- Zasada żelazna: **serwer nigdy nie ufa klientowi** (inaczej gracze będą
  oszukiwać). Wszystkie decyzje o pieniądzach/punktach podejmuje serwer.
- Mini-projekt: sklep — klient klika przycisk GUI, serwer sprawdza,
  czy stać gracza, odejmuje walutę i daje przedmiot.

### Tydzień 4 — Zapisywanie danych i GUI
- **DataStoreService**: zapis postępu gracza (waluta, ekwipunek) między
  sesjami. Naucz się `pcall`, zapisu przy wyjściu (`PlayerRemoving`,
  `BindToClose`) i ochrony przed utratą danych.
- **ScreenGui / Frame / TextButton**: proste menu, sklep, licznik waluty.
- Mini-projekt: gra-zabawka „klikaj i zbieraj" z zapisem stanu — czyli
  szkielet ~40% docelowej gry.

**Kryterium wyjścia:** umiesz samodzielnie (bez tutoriala) zrobić: przedmiot
do zebrania → waluta u gracza → sklep z ulepszeniem → zapis danych.

---

## Faza 3 — Koncepcja i mini-GDD (✅ szkic gotowy)

Szkic koncepcji powstał w kroku 1: [`02-koncepcja-gry.md`](02-koncepcja-gry.md).
Po fazie 2 wróć do niego i:

1. Przeczytaj ponownie — z wiedzą ze Studio ocenisz, co jest realne.
2. Wytnij wszystko, co nie jest potrzebne w wersji 1.0 (zasada: **MVP to
   jedna pętla rozgrywki, jedna mapa, jeden system ulepszeń**).
3. Zamroź zakres: spisz listę „NIE robię w v1.0" i się jej trzymaj.

**Kryterium wyjścia:** jednostronicowy opis MVP, z którego wynika lista
konkretnych zadań do fazy 4 i 5.

---

## Faza 4 — Prototyp pętli rozgrywki (2–3 tygodnie)

Cel: **brzydka, ale grywalna** wersja głównej pętli. Zero grafiki, klocki
i placeholdery.

1. Świat-atrapa: płaska mapa, strefy oznaczone kolorami.
2. Główna pętla: zbieranie zasobu → sprzedaż u NPC → zakup ulepszenia
   (szybkość/pojemność) → dostęp do lepszej strefy.
3. Zapis postępu (DataStore z fazy 2).
4. Podstawowy HUD: waluta, pojemność plecaka.
5. **Test na ludziach**: daj zagrać 2–3 znajomym (Studio → publikuj jako
   prywatne doświadczenie). Pytanie kontrolne: „czy chce ci się grać drugi
   raz?". Jeśli nie — popraw pętlę, zanim zbudujesz cokolwiek więcej.

**Kryterium wyjścia:** obcy człowiek gra 10+ minut bez instrukcji i rozumie,
co robić.

---

## Faza 5 — Produkcja MVP (6–10 tygodni)

Buduj w tej kolejności (każdy punkt = działa + przetestowane, zanim ruszysz
dalej):

1. **Mapa właściwa** — jedna dopracowana mapa zamiast atrap (Terrain +
   modele z Toolboxa; wybieraj assety z dobrą oceną, sprawdzaj czy nie
   zawierają obcych skryptów — usuwaj wszystkie skrypty z pobranych modeli).
2. **Pełna pętla progresji** — 4–6 stref/poziomów zasobów, 8–12 ulepszeń,
   krzywa cen (każde kolejne ulepszenie ~1,6–2× droższe).
3. **System rzadkości** — zwykłe/rzadkie/legendarne znaleziska (to napędza
   „jeszcze jedną rundę" i przyszłą monetyzację).
4. **Element trendu** (wg koncepcji): cykl dzień/noc ze zwiększonym ryzykiem
   i nagrodą w nocy.
5. **Onboarding** — pierwsze 60 sekund: strzałka/podświetlenie prowadzące do
   pierwszego zbioru, pierwszej sprzedaży i pierwszego ulepszenia.
6. **Porządek w kodzie** — logika w ModuleScriptach, konfiguracja (ceny,
   strefy) w jednym module-tabeli, żadnych liczb rozsianych po skryptach.
7. **Zabezpieczenia** — walidacja wszystkiego na serwerze, limity częstości
   akcji (anty-exploit minimum).

**Kryterium wyjścia:** 30–60 minut sensownej rozgrywki; nowy gracz sam
rozumie pętlę; dane nie giną.

---

## Faza 6 — Oprawa: grafika, dźwięk, UI (2–3 tygodnie, równolegle z fazą 5)

- **Styl:** prosty i spójny bije „ładny ale przypadkowy". Low-poly +
  dobre oświetlenie to standard topowych gier.
- **Assety:** Toolbox (Creator Store) — filtruj po ocenach; dźwięki z
  darmowej biblioteki Roblox (licencjonowane audio API).
- **UI:** czytelne na telefonie! **Większość graczy Roblox gra na
  urządzeniach mobilnych** — testuj w Studio emulatorem urządzeń
  (Device Emulator) od początku, nie na końcu.
- **Ikona i miniatura (thumbnail)** — to jest twój marketing nr 1. Zrób 2–3
  warianty; jasne kolory, jedna wyraźna postać/obiekt, duży czytelny motyw.
  Zobacz, jak wyglądają ikony gier z miejsc 4–10 rankingu — naśladuj poziom,
  nie treść.
- **Dźwięk:** minimum to odgłos zbierania, sprzedaży, ulepszenia i muzyka tła.
  Feedback dźwiękowy podnosi „feel" gry bardziej niż grafika.

---

## Faza 7 — Testy i poprawki (2 tygodnie)

1. **Testy własne:** przejdź grę jako nowy gracz (nowe konto), na PC
   i emulatorze telefonu; celowo próbuj psuć (spam klikania, wychodzenie
   w trakcie akcji, brak pieniędzy itd.).
2. **Playtesty zamknięte:** 5–10 osób (znajomi, devforum, znajomi dzieci —
   docelowa grupa wiekowa!). Obserwuj, nie podpowiadaj. Notuj, gdzie utykają.
3. **Analityka wbudowana:** włącz w Creator Hub — retencja D1/D7, czas sesji,
   lejek onboardingu.
4. Napraw w kolejności: crashe/utrata danych → miejsca porzucania gry →
   balans → kosmetyka.

**Kryterium wyjścia:** zero znanych błędów krytycznych; nowy gracz przechodzi
onboarding bez pomocy; sesja testera ≥ 15 minut.

---

## Faza 8 — Monetyzacja (3–5 dni)

Zasady: uczciwie (bez pay-to-win w PvP), zgodnie z regulaminem Roblox,
i **nigdy nie blokuj podstawowej pętli za paywallem**.

- **Game Passy** (jednorazowe): np. „2× pojemność plecaka", „VIP: +10%
  wartości sprzedaży", dostęp do strefy kosmetycznej. 3–5 passów na start,
  ceny 49–399 Robux.
- **Developer Products** (wielokrotne): pakiety waluty, „przyspieszenie"
  (skip czasu). To główne źródło przychodu w symulatorach.
- **Premium Payouts:** dostajesz Robux za czas gry subskrybentów Premium —
  automatyczne, nic nie musisz robić poza utrzymaniem retencji.
- Konfiguracja wypłat: Robux → wymiana na pieniądze przez **DevEx**
  (wymagane: konto zweryfikowane, 13+, minimalny próg ~30 000 Robux).

---

## Faza 9 — Publikacja (2–3 dni)

1. **Kwestionariusz ratingu wieku** (Maturity & Compliance) w Creator Hub —
   obowiązkowy; bez niego gra ma zerową widoczność.
2. **Strona gry:** tytuł (krótki, z „hakiem", może zawierać emoji), opis
   z frazami, których szukają gracze; ikona + 2–3 miniatury; gatunek.
3. **Ustawienia:** publiczna, wszystkie platformy (koniecznie mobile!),
   liczba graczy na serwer (dla symulatora: 6–12).
4. **Miękki start:** opublikuj bez rozgłosu, obserwuj analitykę i błędy
   z pierwszych organicznych graczy przez 3–7 dni, napraw, dopiero potem
   promuj.
5. Zrób grę **aktualizowalną**: trzymaj wersję roboczą osobno, publikuj
   przez „Publish to Roblox As…" świadomie, nigdy „na żywca" bez testu.

---

## Faza 10 — Marketing i pierwsi gracze (od premiery, ciągłe)

- **TikTok/YouTube Shorts to darmowy silnik wzrostu Roblox** — krótkie
  klipy z zabawnym/satysfakcjonującym momentem gry (rzadkie znalezisko,
  nocna ucieczka). 3–5 klipów tygodniowo przez pierwszy miesiąc.
- **Sponsored Ads w Roblox** (opcjonalny budżet): zacznij od małych kwot
  i testuj ikony/miniatury; wyłącz, jeśli koszt pozyskania > przychód.
- **Devforum + społeczności**: pokaż grę w wątkach feedbackowych.
- **Grupa/serwer Discord** dla graczy — kanał ogłoszeń o aktualizacjach.
- Mierz: CTR ikony, retencję D1 (cel: >20%), D7 (cel: >5%), średnią sesję.

---

## Faza 11 — LiveOps: aktualizacje i utrzymanie (ciągłe)

- **Rytm aktualizacji co 1–2 tygodnie** przez pierwsze 2–3 miesiące — topowe
  gry z rankingu żyją z cotygodniowych update'ów i eventów sezonowych.
- Każda aktualizacja = konkretna nowość ogłoszona na stronie gry i Discordzie
  (nowa strefa, nowy rzadki przedmiot, event weekendowy ×2 nagrody).
- Obserwuj analitykę i opinie; napraw → dodaj → promuj, w tej kolejności.
- Po ustabilizowaniu gry: decyzja — rozwijać dalej, czy zaczynać grę nr 2
  z całą zdobytą wiedzą (większość hitów to nie pierwsza gra autora).

---

## Ryzyka i jak nimi zarządzać

| Ryzyko | Przeciwdziałanie |
|--------|------------------|
| Zbyt duży zakres („scope creep") | Lista „NIE robię w v1.0" z fazy 3; MVP = 1 pętla, 1 mapa |
| Wypalenie | Małe tygodniowe cele; publikuj postęp, np. na devforum |
| Utrata danych graczy | `pcall` + retry przy DataStore, test wyjścia z gry od fazy 4 |
| Exploity | Cała logika na serwerze od pierwszego dnia (faza 2, tydzień 3) |
| Gra „umiera" po premierze | Miękki start, iteracja po analityce, rytm update'ów |
| Trend przeminie | Format symulatora jest ponadczasowy; trend to tylko motyw/skórka |

## Zasoby (wszystkie darmowe)

- Dokumentacja i tutoriale: create.roblox.com/docs
- Forum deweloperów: devforum.roblox.com
- Analityka i publikacja: create.roblox.com (Creator Hub)
- Kursy wideo dla początkujących: YouTube — BrawlDev, TheDevKing, GnomeCode
- Zasady społeczności i monetyzacji: en.help.roblox.com → Community Standards
