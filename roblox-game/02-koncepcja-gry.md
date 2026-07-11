# GDD: „Pick a Shroom" (robocza nazwa) — pełny koncept gry v1.1

> Wersja 3 koncepcji (2026-07-08). Zmiana względem v2 (decyzja właściciela
> projektu, inspiracja grami typu lucky block): **statystyki Nożyk i Kosz
> zastąpione przez Kondycję (jak daleko zajdziesz) i Termos (jak wolno
> grzyby tracą świeżość w drodze powrotnej)**. Reszta konceptu bez zmian:
> grzyby zarabiają pasywnie (też offline), wyprawy w głąb lasu, per-gracz
> losowania, światy, mutacje.

## 1. Elevator pitch

Wbiegasz w las tak głęboko, jak pozwoli ci kondycja. Im dalej — tym rzadsze
grzyby losujesz. Ale znaleźć to dopiero połowa roboty: musisz jeszcze wrócić,
a każda sekunda drogi odbiera grzybom świeżość i wartość. W bazie każdy grzyb
**pracuje dla ciebie** — zarabia kasę co sekundę, nawet gdy śpisz. Kasa →
lepsza kondycja i termos → głębiej → nowe światy, aż po grzybobranie
w kosmosie.

**Formuła:** pętla symulatora idle (Grow a Garden, Pet Sim) × dreszczyk
wyprawy i powrotu (trend 99 Nights / gier ekstrakcyjnych) × mutacje
kolekcjonerskie (Steal a Brainrot).

## 2. Pętla rozgrywki

### Pętla główna — „wyprawa" (60–150 sekund, celowo krótka)

```
BAZA → sprint w głąb lasu (pasek kondycji topnieje; głębiej = lepsza pula)
     → ścinasz grzyby (każde ścięcie = LOSOWANIE rzadkości + mutacji)
     → KOSZYK MA TYLKO 2 MIEJSCA (4 z passem): trzyma najlepsze okazy —
       słabszy roll sprzedaje się na miejscu za grosze, lepszy wypycha
       najsłabszego z koszyka (ścinasz dalej, „łowisz" lepsze rolle)
     → świeżość niesionych grzybów spada co sekundę
     → DECYZJA: wracam z tymi dwoma perłami, czy łowię głębiej lepszy los?
       (na powrót TEŻ trzeba kondycji — pusty pasek = wleczesz się!)
     → powrót do bazy (skróty ratują życie)
     → grzyby lądują na półkach i ZARABIAJĄ kasę co sekundę
     → kasa → ulepszenia → głębiej/nowy świat → powtórz
```

*Dlaczego mały koszyk:* pojedynczy grzyb ma znaczenie (przynosisz do bazy
2 okazy, nie wór), półki (4→16) zapełniają się decyzjami zamiast jednym
kursem, a ścinanie pozostaje nielimitowane — combo, XP i pity działają,
bo każde ścięcie to nadal los na loterii.

### Pętla wolna — „imperium" (minuty/godziny/offline)

Półki w bazie generują dochód pasywnie. Offline też (z limitem — patrz §8).
Gracz wraca, odbiera kupkę kasy z popupem „Zarobiłeś 12 450 💰 kiedy cię nie
było!", kupuje ulepszenie, robi 2–3 wyprawy, wychodzi. Sesja: 10–20 minut.

### Trzy zabezpieczenia projektowe pętli

1. **Powrót ma stawkę bez AI wrogów**: świeżość spada co sekundę, a pusty
   pasek kondycji oznacza powolny marsz. Za głęboka wyprawa = patrzenie,
   jak legendarny grzyb więdnie w rękach. Tanie w budowie, emocjonujące.
2. **Losowość ma „pity"**: co 15 ścięć gwarantowany Rzadki+; rosnący pasek
   szczęścia widoczny na ekranie.
3. **Offline z limitem** (2 h), żeby istniał powód logowania; wyższy limit
   to naturalny Game Pass zamiast psucia retencji.

## 3. Statystyki i ulepszenia — dokładnie 2 + 2

**Dwie statystyki ulepszane wielokrotnie** (krzywa kosztów) i **zakupy
jednorazowe** (bramki progresji). Obie statystyki grają na tej samej osi
napięcia — głębia kontra świeżość — więc każda nawzajem podbija wartość
drugiej: im głębiej sięgasz Kondycją, tym dłuższy powrót, tym bardziej
opłaca się Termos.

### Statystyki (ulepszane poziomami, koszt ~×1,35 na poziom)

| Statystyka | Co daje | Liczby startowe (do strojenia w becie) |
|------------|---------|----------------------------------------|
| 🏃 **Kondycja** | dłuższy pasek sprintu = dalej w głąb lasu (i sprawny powrót) | pasek 100 pkt, sprint zużywa 10 pkt/s; +8 pkt za poziom; pierścień 5 wymaga ~90 s sprintu w jedną stronę. **Pasek odnawia się TYLKO w bazie** (w lesie zero regeneracji) — to twardy budżet wyprawy: wyzerowanie = 3 s zadyszki, potem tylko zwykły chód do bazy |
| ❄️ **Termos** | grzyby wolniej tracą świeżość | spadek świeżości ×0,975 za poziom (poz. 10 ≈ −22%, poz. 30 ≈ −53%); twarde dno: nigdy mniej niż 30% bazowego tempa świata |

**Dwa warunki balansu, żeby ten duet nie zepsuł gry** (wpisane celowo,
z doświadczeń tego formatu):

1. **Termos nie może wyzerować spadku świeżości** — przy zerze znika całe
   napięcie powrotu i gra robi się płaska. Stąd twarde dno 30% oraz rosnące
   bazowe tempo psucia w kolejnych światach (patrz tabela w §4): stat jest
   zawsze opłacalny, ale nigdy nie „wyłącza" mechaniki.
2. **Kondycja zastępuje bramy pierścieni** — głębia jest gated statystyką,
   nie zakupem jednorazowym (usunięte względem v2). Dzięki temu każdy
   poziom Kondycji jest odczuwalny: dosłownie widzisz, że dobiegasz dalej.

### Zakupy jednorazowe (bramki)

| Zakup | Cena rosnąca | Efekt |
|-------|--------------|-------|
| 🌱 **Grządka na działce** (start: 10 — dwa rządki po 5; dokupowanie PO JEDNEJ do 20) | ×2,2 za każdą | +1 zasadzony grzyb = wyższa produkcja; pass „Grzybowa Grządka +5" podnosi limit do 25 |
| ⚡ **Skróty powrotne** (zjeżdżalnia, trampolina, tyrolka — po 1 na pierścień) | średnie | powrót z głębi w 10 s zamiast 40+ s i BEZ zużywania kondycji; kupione = widoczne na mapie |
| 🌍 **Portal do świata** | bardzo wysokie progi | nowy świat (patrz §5) |

Skróty robią się ważniejsze niż w v2: skoro powrót zużywa kondycję, kupiony
skrót to de facto „więcej kondycji na drogę w głąb". Dobra decyzja zakupowa
do rozważania przez gracza (poziom Kondycji vs skrót).

## 4. Grzyby: losowanie, rzadkości, mutacje, świeżość

### Czy każdy widzi te same grzyby? → **Każdy gracz ma własne spawny.**

- **Miejscówki grzybowe są per-gracz** (renderowane tylko dla ciebie,
  losowanie po stronie serwera). Zero podbierania sprzed nosa, zero
  wyścigów z lagiem, działa tak samo dobrze przy 2 i przy 12 graczach
  na serwerze. Tak robi to nr 1 rankingu (Grow a Garden — każdy ma swój
  ogród).
- **Świat i inni gracze są wspólni**: widzisz innych biegających, widzisz
  ICH grzyby na ich półkach w bazach (flex!), a rzadkie trafienia ogłasza
  serwer: *„🌈 Kamil znalazł GLITCH Borowika w Borze!"*.

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
| ❄️ Frost | 1/1200 | ×40 | oszroniony, zimna mgiełka |
| 🌋 Magma | 1/2500 | ×60 | pęknięcia z żarem |
| 👾 Glitch | 1/4000 | ×80 | „rozjeżdżająca się" tekstura |
| 🕳️ Void | 1/8000 | ×120 | czarny, pochłania światło |
| 🌈 Rainbow | 1/10000 | ×150 | tęczowy, animowany (event Tęcza: 1/150) |
| 🌌 Galaxy | 1/25000 | ×400 | gwiazdy i mgławice na kapeluszu |

Mnożniki rzadkości × mutacji się MNOŻĄ (Legendarny Glitch = ×120×75).
Eventy pogodowe podbijają szanse mutacji (patrz §7). W v1 jedna mutacja na
grzyba; „podwójne mutacje" zostawiamy na update (gotowy content na LiveOps).

### Świeżość (mechanika powrotu — serce gry)

- Każdy ścięty grzyb ma pasek świeżości 100% → spada co sekundę wg tempa
  bazowego świata, modyfikowanego Termosem:

| Świat | Bazowe tempo psucia |
|-------|--------------------:|
| Las Liściasty | 1,2%/s |
| Bór Iglasty | 1,6%/s |
| Mokradła | 2,2%/s |
| Kryształowa Grota | 3,0%/s |
| Grzyboksiężyc | 4,0%/s |

- **Wartość na półce = wartość × świeżość przy dostarczeniu.**
- Poniżej 20% świeżości grzyb jest „zwiędnięty": wartość ×0,2, ale nigdy
  nie przepada całkiem (w v1; „gnicie do zera" przetestujemy w prototypie —
  większe emocje, ale może być zbyt brutalne dla młodszych graczy).
- Rzadsze grzyby psują się szybciej (mnożnik ×1,1 za każdy stopień
  rzadkości) — z Mitycznym w rękach sprint po tyrolce to czysta adrenalina.
- Rosnące tempo psucia w kolejnych światach sprawia, że Termos nigdy nie
  przestaje być potrzebny — to główna dźwignia długości progresji.

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
niska grawitacja = dłuższe skoki (kondycja „starcza na więcej") — darmowy
„wow" bez nowych mechanik. Światy 6+ (Cukierkowy? Głębiny?) to gotowy plan
aktualizacji po premierze.

## 6. Baza gracza — DZIAŁKA Z GRZĄDKAMI

- Każdy gracz ma działkę przy bazie świata: grzyby są **ZASADZONE W ZIEMI**
  na grządkach (start: 10 — dwa rządki po 5, „po 5 na stronę"; dokupowanie
  po jednej do 20; pass +5 → max 25). Widoczne dla innych = flex.
- **Pod każdą grządką zielone pole**, na którym zlicza się urobek grzyba
  („💰 1 240"). Kasa NIE wpada sama — **wchodzisz na pole i zbierasz**
  (dźwięk + delikatne particlesy + wyskakujące „+X 💰"). Przebiegnięcie
  wzdłuż rządka i zgarnięcie wszystkich pól to codzienna mikro-frajda.
- Najlepszy okaz na działce sypie złotymi iskrami.
- **Poziomy grzybów (lvl 1→100):** każdy zasadzony grzyb ulepszasz
  przytrzymując E na kapeluszu. Dochód ×1,05/poziom (lvl 100 ≈ ×125),
  koszt ×1,10/poziom skalowany z wartością własną grzyba — zwrot rośnie
  z ~60 s do ~1,5 h, więc początek to dopamina, a setka to prestiż.
  Grzyb ROŚNIE z poziomem (lvl 100 ≈ ×3 — kolos nad działką); wymaksowanie
  ogłaszane serwerowi. To główny zlew na kasę w late game.
- **Dziennik Grzybiarza**: kolekcja wszystkich gatunków × rzadkości ×
  mutacji z nagrodami za skompletowanie stron (retencja długoterminowa).
- Sprzedaż grzyba z półki możliwa zawsze (jednorazowa kasa zamiast dochodu) —
  decyzja ekonomiczna: renta czy gotówka na upgrade.

## 7. „Musi się dużo dziać" — projekt pod krótkie skupienie

Zasada: **coś nowego na ekranie co maksymalnie 3 minuty**, a w tle zawsze
rosnące liczby.

- **Eventy serwerowe co 4–6 min** (rotacja, ogłaszane bannerem + dźwiękiem):
  - 🌧️ *Złoty Deszcz* — 90 s, szansa mutacji ×3;
  - 🍄 *Wysyp* — 60 s, spawny ×3 (las gęsty od grzybów);
  - 🌈 *Tęcza nad lasem* — 120 s, jedyna okazja na Rainbow poza 1/10000;
  - ❄️ *Przymrozek* — 120 s, świeżość spada 2× WOLNIEJ (okno na rajd
    w głąb ponad stan kondycji — „teraz albo nigdy!");
  - ☄️ *Deszcz meteorów* (tylko Grzyboksiężyc) — spada „grzyb-meteor",
    kto pierwszy dobiegnie, ten ścina (JEDYNY współdzielony spawn w grze —
    kontrolowany wyjątek dla emocji społecznych).
- **Feedback co sekundę**: popupy kasy z półek, pasek pity rosnący przy
  każdym ścięciu, tykający pasek świeżości, ogłoszenia rzadkich trafień.
- **Poziomy gracza (XP)**: każde ścięcie karmi zawsze widoczny pasek XP;
  poziom = kasa + trwałe +0,5% szczęścia (progres nigdy nie jest pusty);
  co 5 poziomów kamień milowy ×5 ogłaszany serwerowi.
- **Combo**: ścięcia w oknie 4 s budują serię (mnożnik XP do ×3, kasa za
  ×10/×25/×50); dźwięk ścięcia rośnie pitchem z każdym stackiem — pętla
  uwagi chwila-po-chwili i materiał na klipy.
- **Seria dzienna**: dzień 1–7 z rosnącymi nagrodami (skalowane poziomem);
  przerwa zeruje serię — powód, by wrócić jutro.
- **Krótkie cele zawsze widoczne**: 3 dzienne zadania („Zetnij 5 Rzadkich",
  „Dobiegnij do pierścienia 4"), skrzynka co 20 min online, seria dzienna.
- **Wyprawa trwa maks. 2,5 min** — pełna pętla nagrody mieści się w oknie
  uwagi; nigdy nie ma stanu „nic się nie dzieje, nic nie rośnie".

## 8. Ekonomia (szkielet do strojenia w becie)

- **Dochód grzyba/s** = wartość gatunku × mnożnik rzadkości × mnożnik
  mutacji × świeżość dostawy × mnożnik świata.
- **Koszt poziomu statystyki** = koszt bazowy × 1,35^poziom (Kondycja
  i Termos osobno).
- **Offline**: półki zarabiają 50% stawki, cap 2 h (Game Pass: 100% i 8 h).
- **Cel balansu**: pierwszy portal (Bór) po ~2–3 h gry; Grzyboksiężyc po
  ~30–40 h.
- Wszystkie liczby w JEDNYM ModuleScripcie konfiguracyjnym
  ([`src/GameConfig.luau`](src/GameConfig.luau)) — strojenie bez grzebania
  w logice.

## 9. Komercjalizacja

Zasada: płaci się za **wygodę i tempo**, nigdy za dostęp do contentu.

### Game Passy (jednorazowe)
| Pass | Cena (Robux) | Efekt |
|------|-------------:|-------|
| 💰 Podwójna Kasa | 399 | dochód ×2 |
| 🧊 Lodówka Turystyczna | 299 | świeżość spada dodatkowe 20% wolniej (mnoży się z Termosem, dno 30% dalej obowiązuje) |
| 🌱 Grzybowa Grządka +5 | 199 | +5 grządek na działce (20 → 25) |
| 🌙 Nocny Marek | 249 | offline: 100% stawki i cap 8 h |
| ⚡ Teleport do Pierścieni | 249 | szybka podróż do pierścieni, do których już dobiegłeś o własnych siłach |
| 👑 VIP | 449 | +10% szczęścia, złoty nick, aura, tytuł w bazie |
| 🎒 Głęboki Koszyk | 249 | +2 miejsca w koszyku wypraw (2 → 4) |
| 🥚 Otwórz ×3 | 199 | każde podejście do jaja otwiera 3 naraz (każde płatne) |
| 🤖 Auto-Otwieranie | 99 | przełącznik AUTO przy jajku — otwiera co 3 s, gdy stoisz obok |
| 🍀 Szczęście Jaj ×3 | 199 | wagi Rzadki+ w jajach ×3 |
| 🍀 Szczęście Jaj ×6 | 499 | wagi Rzadki+ w jajach ×6 (zastępuje ×3) |

### Developer Products (wielokrotne — główny przychód w tym formacie)
- 🌙 **Podwójny Zbiór Nocny** (19 Robux) — przycisk „×2" w modalu
  powitalnym podwaja zarobek offline; niska cena + moment maksymalnej
  satysfakcji = klasyczny bestseller gier idle;
- Paczki kasy (4 progi cenowe);
- 🍀 **Eliksir Szczęścia** (20 min, szansa rzadkości ×2) — bestseller formatu;
- 🌀 **Totem Powrotu** ×5 (natychmiastowy teleport do bazy Z PEŁNĄ świeżością
  — monetyzuje dokładnie ten moment paniki, który tworzy mechanika świeżości);
- ⚡ **Energetyk** ×5 (natychmiastowe pełne odnowienie kondycji w terenie);
- 🎲 **Kostka Mutacji** (przerzut mutacji jednego grzyba na półce).

### Pasywnie
- **Premium Payouts** (Robux za czas gry subskrybentów Premium);
- kosmetyki termosu/butów/śladu biegu w update'ach (czysty flex, zero mocy).

## 10. Zakres v1.0 — twarda lista „NIE"

Do premiery NIE robimy: handlu między graczami, kradzieży z cudzych baz
(ew. tryb eventowy v1.2+), craftingu, PvP, AI przeciwników, pogody
wpływającej na ruch.

**Pety — przeniesione do v1.0 (gacha):** każda baza ma gniazdo z jajem
(5k → 500M wg świata); pozycja w puli świata = rzadkość (pet nr 1 Zwykły
60% … nr 5 Legendarny 1%), więc podgląd przy jajku uczciwie pokazuje
szanse. Przy podejściu do gniazda wyświetla się panel dropów; klik w peta
zaznacza go do auto-usuwania po wylosowaniu (Legendarnych nie można). Założone pety (max 3;
4. slot = przyszły pass) dają +5–60% dochodu i +2–30% szczęścia. Pety
lewitują przy graczu (widoczne dla wszystkich = flex), przeżywają rebirth
jak dziennik. Fanfara wyklucia w kolorze rzadkości; Legendarny ogłaszany
serwerowi. Fuzje/złote pety = content na update'y.

**Podwójne mutacje — zakodowane, wyłączone flagą** (`Config.DoubleMutations.
enabled`): włączenie jednym `true` daje gotowy event „Weekend Podwójnych
Mutacji" (druga mutacja losuje się z 25% normalnych szans, mnożniki się
mnożą, każde podwójne trafienie jest ogłaszane serwerowi).

**Rebirth (przeniesiony z v1.1 do v1.0):** za rosnącą cenę (50k ×6 za każdy
kolejny) zerujesz kasę, ulepszenia, półki, skróty i światy — w zamian trwały
mnożnik dochodu (+50%/szt.) i szczęścia (+2%/szt.). Zostaje: poziom/XP,
dziennik, seria dzienna. To domyka pętlę długoterminową: świeży start jest
szybszy i szczęśliwszy, a licznik 🌀 to status na serwerze.
Każda z tych rzeczy to gotowy nagłówek przyszłej aktualizacji — nie zaległość.

## 11. Miary sukcesu

Prototyp: obcy gracz gra 10 min bez pytań i robi drugą wyprawę z własnej
woli. Premiera: D1 > 20%, sesja > 12 min, 👍 > 75%. Miesiąc 1: 2–4 update'y,
pierwszy event weekendowy (×2 kasa).

## 12. Otwarte pytania (do rozstrzygnięcia prototypem, nie dyskusją)

1. Czy „zwiędnięcie" (×0,2) wystarczy jako kara, czy testujemy „gnicie do
   zera" (grzyb przepada) dla większych emocji? → test na prototypie.
2. Czy powrót zużywa kondycję 1:1 jak wejście, czy taniej (np. 50%)? Start:
   50% — hojniej dla nowych, dokręcimy w becie.
3. Długość pierścieni: 20 s czy 40 s sprintu między pierścieniami? → test.
4. Nazwa: „Pick a Shroom" vs „Mushroom Rush" vs „Shroom It" → test CTR
   miniatur przed premierą.
