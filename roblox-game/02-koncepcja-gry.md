# GDD: „Pick a Shroom" (robocza nazwa) — pełny koncept gry v1.0

> Wersja 2 koncepcji (2026-07-08) — oparta na pomyśle właściciela projektu:
> grzyby jako pasywne źródło dochodu (także offline), aktywne wyprawy w głąb
> lasu po coraz lepsze okazy, powrót do bazy ze zdobyczą, dwa narzędzia do
> ulepszania, światy, warianty/mutacje (gold, diamond, candy, glitch…).
> Zastępuje wcześniejszy szkic „Night Forager".

## 1. Elevator pitch

Wbiegasz w las tak głęboko, jak starczy ci odwagi i pojemności kosza. Im
dalej — tym rzadsze grzyby losujesz. Ale znaleźć to dopiero połowa roboty:
musisz jeszcze donieść zdobycz do bazy, zanim straci świeżość. W bazie każdy
grzyb **pracuje dla ciebie** — zarabia kasę co sekundę, nawet gdy śpisz.
Kasa → lepszy nożyk i kosz → głębsze pierścienie lasu → nowe światy, aż po
grzybobranie w kosmosie.

**Formuła:** pętla symulatora idle (Grow a Garden, Pet Sim) × dreszczyk
wyprawy i powrotu (trend 99 Nights / gier ekstrakcyjnych) × mutacje
kolekcjonerskie (Steal a Brainrot).

## 2. Pętla rozgrywki

### Pętla główna — „wyprawa" (60–150 sekund, celowo krótka)

```
BAZA → sprint w głąb lasu (pierścienie 1→5, coraz głębiej = lepsza pula)
     → ścinasz grzyby nożykiem (każde ścięcie = LOSOWANIE rzadkości + mutacji)
     → kosz się zapełnia (waga!), świeżość grzybów zaczyna spadać
     → DECYZJA: wracam z tym, co mam, czy pcham się głębiej po lepszy los?
     → powrót do bazy (im cięższy kosz, tym wolniej biegniesz)
     → grzyby lądują na półkach i ZARABIAJĄ kasę co sekundę
     → kasa → ulepszenia → głębiej/nowy świat → powtórz
```

### Pętla wolna — „imperium" (minuty/godziny/offline)

Półki w bazie generują dochód pasywnie. Offline też (z limitem — patrz §8).
Gracz wraca, odbiera kupkę kasy z popupem „Zarobiłeś 12 450 💰 kiedy cię nie
było!", kupuje ulepszenie, robi 2–3 wyprawy, wychodzi. Sesja: 10–20 minut.

### Dlaczego to działa (i moje uwagi do pierwotnego pomysłu)

Pomysł bazowy jest mocny, ale w surowej wersji ma trzy dziury, które GDD łata:

1. **Droga powrotna nie może być zwykłym spacerem** — bez presji to martwy
   czas. Rozwiązanie bez AI wrogów (tanie w budowie!): **świeżość** (timer
   od ścięcia; jak spadnie, wartość grzyba maleje do ×0,5) + **waga**
   (lepsze grzyby są cięższe → wolniejszy powrót). Głębiej = lepszy łup,
   ale dłuższa i wolniejsza droga = realny hazard bez jednej linijki AI.
2. **Losowość musi mieć „pity"** — sama ruletka frustruje. Gwarancja:
   co 15 ścięć minimum Rare+, licznik widoczny na ekranie (pasek „szczęścia"
   który rośnie — to też „dużo się dzieje" na UI).
3. **Offline-dochód bez limitu zabija powroty** — musi być cap (2 h), żeby
   istniał powód logowania; podniesienie capu to zarazem naturalny Game Pass.

## 3. Statystyki i ulepszenia — dokładnie 2 + 2

Zgodnie z założeniem: **dwa narzędzia ulepszane wielokrotnie** (stat X —
krzywa kosztów) i **zakupy jednorazowe** (stat Y — bramki progresji).

### Narzędzia (ulepszane poziomami, koszt ~×1,35 na poziom)

| Narzędzie | Co daje | Efekt na pętlę |
|-----------|---------|----------------|
| 🔪 **Nożyk** | (a) jaki *tier* grzyba umiesz ściąć (twarde bramki co 10 poziomów), (b) szybkość ścinania | otwiera dostęp do lepszych okazów w głębi; szybsze ścinanie = krótsza wyprawa |
| 🧺 **Kosz** | (a) liczba udźwigniętych grzybów, (b) redukcja kary do szybkości od wagi | dłuższe wyprawy, mniej boleśnie ciężki powrót |

Celowo tylko dwa — każdy poziom ma odczuwalny efekt, a gracz zawsze wie,
na co zbiera. (Osobnej statystyki „szybkość biegu" NIE robimy — szybkość
wynika z kosza; trzeci suwak rozmyłby decyzje.)

### Zakupy jednorazowe (bramki)

| Zakup | Cena rosnąca | Efekt |
|-------|--------------|-------|
| 🪵 **Półka w bazie** (start: 4, max 16) | ×2,2 za każdą | +1 slot na pracującego grzyba = wyższy dochód pasywny |
| 🚪 **Brama pierścienia** (2→5 w każdym świecie) | wysokie progi | wpuszcza głębiej — do lepszej puli losowań |
| ⚡ **Skróty powrotne** (zjeżdżalnia, trampolina, tyrolka — po 1 na pierścień) | średnie | powrót z głębi w 10 s zamiast 40 s; kupione = widoczne na mapie, satysfakcja „zagospodarowałem las" |
| 🌍 **Portal do świata** | bardzo wysokie progi | nowy świat (patrz §5) |

## 4. Grzyby: losowanie, rzadkości, mutacje, świeżość

### Czy każdy widzi te same grzyby? → **Każdy gracz ma własne spawny.**

Decyzja projektowa (odpowiedź na kluczowe pytanie):

- **Miejscówki grzybowe są per-gracz** (renderowane tylko dla ciebie,
  losowanie po stronie serwera). Zero podbierania sprzed nosa, zero
  wyścigów z lagiem, działa tak samo dobrze przy 2 i przy 12 graczach
  na serwerze. Tak robi to nr 1 rankingu (Grow a Garden — każdy ma swój
  ogród).
- **Świat i inni gracze są wspólni**: widzisz innych biegających z koszami,
  widzisz ICH grzyby na ich półkach w bazach (flex!), a rzadkie trafienia
  ogłasza serwer: *„🌈 Kamil znalazł GLITCH Borowika w Borze!"* — to buduje
  FOMO i społeczność bez kosztów technicznych współdzielonych spawnów.

### Rzadkości (pula per świat, głębszy pierścień = lepsze wagi losowania)

| Rzadkość | Szansa bazowa (pierścień 1 / pierścień 5) | Mnożnik dochodu |
|----------|------------------------------------------:|----------------:|
| Zwykły | 70% / 30% | ×1 |
| Niezwykły | 24% / 34% | ×3 |
| Rzadki | 5% / 22% | ×10 |
| Epicki | 0,9% / 9% | ×35 |
| Legendarny | 0,1% / 4% | ×120 |
| Mityczny | — / 0,9% | ×500 |
| **Sekretny** | — / 0,1% | ×2500 |

Sekretne istnieją głównie po to, żeby lądowały na TikToku.

### Mutacje (warianty) — każdy grzyb może wylosować dodatkowo JEDNĄ

| Mutacja | Szansa | Mnożnik | Wygląd |
|---------|-------:|--------:|--------|
| — (czysty) | bazowa | ×1 | normalny |
| 🥇 Gold | 1/20 | ×3 | złota poświata |
| 💎 Diamond | 1/100 | ×8 | krystaliczny, refleksy |
| 🍬 Candy | 1/250 | ×15 | pasiasty, cukierkowy |
| 🌟 Neon | 1/500 | ×25 | świeci w nocy |
| 👾 Glitch | 1/2000 | ×75 | „rozjeżdżająca się" tekstura, dżumpscare-cute |
| 🌈 Rainbow | 1/10000 | ×150 | tęczowy, animowany |

Mnożniki rzadkości × mutacji się MNOŻĄ (Legendarny Glitch = ×120×75).
Eventy pogodowe podbijają szanse mutacji (patrz §7). W v1 jedna mutacja na
grzyba; „podwójne mutacje" zostawiamy na update (gotowy content na LiveOps).

### Świeżość (mechanika powrotu)

- Każdy ścięty grzyb ma pasek świeżości: 100% → spada ~1,5%/s.
- Wartość na półce = wartość × świeżość przy dostarczeniu (min. 50%).
- Rzadsze grzyby psują się SZYBCIEJ (dramaturgia: z Mitycznym w koszu
  sprint po tyrolce to czysta adrenalina).
- Konsekwencja projektowa: głębia × świeżość × waga = jedna spójna oś
  napięcia, zero AI, zero walki.

## 5. Światy (v1: 5 światów)

Każdy świat = nowa mapa, nowa pula ~10 gatunków, nowy biom wizualny,
mnożnik globalny dochodu i wyższe ceny ulepszeń. Struktura pierścieni 1–5
i mechaniki są identyczne (jeden zestaw kodu, różne dane — tanie w produkcji).

| # | Świat | Klimat | Mnożnik | Przykładowe gatunki (po 10 na świat) |
|---|-------|--------|--------:|---------------------------------------|
| 1 | **Las Liściasty** | ciepły, słoneczny | ×1 | Kurka, Podgrzybek, Borowik… |
| 2 | **Bór Iglasty** | mgła, chłód | ×8 | Rydz, Maślak, Muchomor Królewski… |
| 3 | **Mokradła** | bagno, bioluminescencja | ×50 | Błotnik, Zgniłek, Świetlik Bagienny… |
| 4 | **Kryształowa Grota** | podziemia, kryształy | ×300 | Kryształak, Ametystówka… |
| 5 | **Grzyboksiężyc** 🚀 | kosmos, niska grawitacja | ×2000 | Lunark, Nebulon, Czarna Dziura (sekretny) | 

Portal do świata n+1 kupuje się za kasę (jednorazowo). Na Grzyboksiężycu
niska grawitacja = dłuższe skoki — darmowy „wow" bez nowych mechanik.
Światy 6+ (Cukierkowy? Głębiny?) to gotowy plan aktualizacji po premierze.

## 6. Baza gracza

- Działka przy spawnie każdego świata; półki z grzybami WIDOCZNE dla innych
  (spacer po cudzych bazach = darmowy flex i motywacja).
- Grzyb na półce = animowany, z etykietą dochodu („+320/s"); najlepszy okaz
  na podświetlonym piedestale.
- **Dziennik Grzybiarza**: kolekcja wszystkich gatunków × rzadkości ×
  mutacji z nagrodami za skompletowanie stron (retencja długoterminowa,
  klasyka Fish It).
- Sprzedaż grzyba z półki możliwa zawsze (jednorazowa kasa zamiast dochodu) —
  decyzja ekonomiczna dla gracza: renta czy gotówka na upgrade.

## 7. „Musi się dużo dziać" — projekt pod krótkie skupienie

Zasada: **coś nowego na ekranie co maksymalnie 3 minuty**, a w tle zawsze
rosnące liczby.

- **Eventy serwerowe co 4–6 min** (rotacja, ogłaszane bannerem + dźwiękiem):
  - 🌧️ *Złoty Deszcz* — 90 s, szansa mutacji ×3;
  - 🍄 *Wysyp* — 60 s, spawny ×3 (las gęsty od grzybów);
  - 🌈 *Tęcza nad lasem* — 120 s, jedyna okazja na Rainbow poza 1/10000;
  - ☄️ *Deszcz meteorów* (tylko Grzyboksiężyc) — spada „grzyb-meteor",
    kto pierwszy dobiegnie, ten ścina (JEDYNY współdzielony spawn w grze —
    kontrolowany wyjątek dla emocji społecznych).
- **Feedback co sekundę**: popupy kasy z półek, pasek pity rosnący przy
  każdym ścięciu, licznik świeżości, serwerowe ogłoszenia rzadkich trafień.
- **Krótkie cele zawsze widoczne**: 3 dzienne zadania („Zetnij 5 Rzadkich",
  „Dobiegnij do pierścienia 4"), skrzynka co 20 min online, seria dzienna
  (dzień 1–7, rosnące nagrody).
- **Wyprawa trwa maks. 2,5 min** — pełna pętla nagrody mieści się w oknie
  uwagi; nigdy nie ma stanu „nic się nie dzieje, nic nie rośnie".

## 8. Ekonomia (szkielet do strojenia w becie)

- **Dochód grzyba/s** = wartość gatunku × mnożnik rzadkości × mnożnik
  mutacji × świeżość dostawy × mnożnik świata.
- **Koszt poziomu narzędzia** = koszt bazowy × 1,35^poziom (nożyk i kosz
  osobno). Bramki tierów nożyka co 10 poziomów wymuszają rytm „zbieram na
  próg".
- **Offline**: półki zarabiają 50% stawki, cap 2 h (Game Pass: 100% i 8 h).
- **Cel balansu**: pierwszy portal (Bór) po ~2–3 h gry; Grzyboksiężyc po
  ~30–40 h — wystarczająco daleko, by żyć z tego miesiąc, wystarczająco
  blisko, by nie odstraszać.
- Wszystkie liczby w JEDNYM ModuleScripcie konfiguracyjnym — strojenie bez
  grzebania w logice.

## 9. Komercjalizacja

Zasada: płaci się za **wygodę i tempo**, nigdy za dostęp do contentu.

### Game Passy (jednorazowe)
| Pass | Cena (Robux) | Efekt |
|------|-------------:|-------|
| 💰 Podwójna Kasa | 399 | dochód ×2 |
| 🧺 Złoty Kosz | 299 | +50% udźwigu, skin |
| 🪵 Druga Ściana Półek | 349 | +6 slotów w każdej bazie |
| 🌙 Nocny Marek | 249 | offline: 100% stawki i cap 8 h |
| ⚡ Teleport do Pierścieni | 249 | menu szybkiej podróży do odblokowanych pierścieni |
| 👑 VIP | 449 | +10% szczęścia, złoty nick, aura, tytuł w bazie |

### Developer Products (wielokrotne — główny przychód w tym formacie)
- Paczki kasy (4 progi cenowe);
- 🍀 **Eliksir Szczęścia** (20 min, szansa rzadkości ×2) — bestseller formatu;
- 🌀 **Totem Powrotu** ×5 (natychmiastowy teleport do bazy Z PEŁNĄ świeżością
  — monetyzuje dokładnie ten moment paniki, który tworzy mechanika świeżości);
- 🎲 **Kostka Mutacji** (przerzut mutacji jednego grzyba na półce).

### Pasywnie
- **Premium Payouts** (Robux za czas gry subskrybentów Premium — za darmo,
  wymaga tylko retencji);
- kosmetyki nożyka/kosza/śladu biegu w update'ach (czysty flex, zero mocy).

## 10. Zakres v1.0 — twarda lista „NIE"

Do premiery NIE robimy: petów/pomocników, handlu między graczami, kradzieży
z cudzych baz, prestiżu/rebirth (v1.1 jako „Nowy Sezon Grzybowy"), podwójnych
mutacji, craftingu, PvP, AI przeciwników, pogody wpływającej na ruch.
Każda z tych rzeczy to gotowy nagłówek przyszłej aktualizacji — nie zaległość.

## 11. Miary sukcesu (bez zmian względem planu)

Prototyp: obcy gracz gra 10 min bez pytań i robi drugą wyprawę z własnej
woli. Premiera: D1 > 20%, sesja > 12 min, 👍 > 75%. Miesiąc 1: 2–4 update'y,
pierwszy event weekendowy (×2 kasa).

## 12. Otwarte pytania (do rozstrzygnięcia prototypem, nie dyskusją)

1. Czy świeżość spadająca do 50% wystarczy jako presja, czy powrót ma być
   groźniejszy (np. „złodziejska wiewiórka" wytrącająca 1 grzyb przy
   otarciu)? → test na prototypie.
2. Długość pierścieni: 20 s czy 40 s biegu między bramami? → test.
3. Nazwa: „Pick a Shroom" vs „Mushroom Rush" vs „Shroom It" → test CTR
   miniatur przed premierą.
