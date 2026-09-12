# Kontekst projektu „Pick a Shroom" — przeczytaj przed pracą

Ten plik to pamięć projektu. Jeśli jesteś nową sesją Claude (np. lokalną,
podpiętą przez MCP do Roblox Studio) — tu jest wszystko, co ustaliliśmy.

## Co to jest

Gra Roblox: **symulator grzybiarza** (sprint do lasu → ścinanie grzybów
z losowaniem rzadkości i mutacji → powrót z ograniczonym koszykiem →
sadzenie na grządkach, które zarabiają → ulepszenia → 5 światów → pety →
rebirth). Właściciel projektu jest **początkujący** (nie zna Luau ani
Blendera) i pracuje po polsku — odpowiadaj po polsku, tłumacz kroki
łopatologicznie, nie zakładaj wiedzy technicznej.

## Mapa plików

- `START.md` — instrukcja składania (Etapy: kod → modele → monetyzacja)
- `PLAN.md` — plan całości z statusami faz
- `02-koncepcja-gry.md` — GDD (ekonomia, systemy, monetyzacja)
- `src/` — 7 plików gry + README montażu; **GameConfig.luau to JEDYNE
  źródło liczb balansu** (nigdy nie hardkoduj wartości w innych plikach)
- `blender/` — 20 skryptów generujących modele + README +
  `PODPIECIE-MODELI.md` (dokładne nazwy, których gra szuka w
  `ReplicatedStorage/Models`)

## Twarde zasady projektu (nie łam ich)

1. **Serwer nigdy nie ufa klientowi** — wszystkie losowania, kasa, zakupy
   po stronie serwera; klient tylko wyświetla atrybuty i wysyła prośby
   przez RemoteEventy.
2. **Styl wizualny**: low-poly „klockowato-uroczy" Roblox — mało segmentów,
   płaskie cieniowanie, soczyste kolory, przysadziste proporcje. Cytat
   właściciela: „trochę kwadratowe, ale zajebiście ładne". Im rzadszy
   grzyb/pet, tym bardziej odjechany model.
3. **Liczby w grze mają sięgać absurdów** (10Qt, 100Qa) — formatowanie
   TYLKO przez `Config.fmtNumber` (drabinka K…Dc).
4. **SEKRET-y petów**: twarde 0,1% szansy, passy szczęścia ich NIE
   podbijają (`luckSkipsLast`); nazwa zawsze tęczowym świecącym fontem
   (`markRainbow` w ClientMain).
5. **Pętla wyprawy (redesign 2026-07)**: sprint PRZYMUSOWY; do lasu tylko
   przez STREFĘ STARTU (minigra paska = head start; serwer liczy pozycję
   z `Config.launchPosition`, klient tylko wysyła stop). Kondycja
   regeneruje się TYLKO w bazie i spala TYLKO biegnąc w głąb; powrót
   za darmo. Koszyk: 1 miejsce (+2 pass), BEZ wypychania. Ścięcie budzi
   WILKA (Config.Wolves; głębiej = szybszy); dogonienie = utrata łupu.
   Po powrocie łup trafia do PLECAKA (Tool w hotbarze, uid→data.inventory);
   gracz sam wybiera grządkę (Tool.Activated przy wolnej grządce, wpisy
   shelf mają pole slot). Stragan NPC = sklep (przyciski ulepszeń widoczne
   tylko przy StallCounter). 5 osobnych decków/serwer (Config.Base.deckCenters).
6. **Retention przede wszystkim**: combo (sekundy) → XP (minuty) → eventy
   → skrzynka → dzienne → streak → rebirth → levele grzybów. Coś musi
   „dziać się" co chwilę.
7. **Modele z Blendera podpinają się AUTOMATYCZNIE** po nazwach
   (`ReplicatedStorage/Models/{Grzyby,Pety}/<nazwa>`, `Models/GniazdoJajo`)
   — z auto-materiałami po nazwach części (`Config.materialFor`)
   i animacjami po nazwach (`FxClient`: Pierscien/Dysk wirują,
   Warkocz/Drobiny/Ksiezyc falują, `*Glow` sypie iskrami = Neon).
   Nazw części NIE zmieniać — nazwa to instrukcja animacji.
8. **Wszystko commituj i wypychaj** na branch `claude/roblox-game-plan-dmsegi`
   — właściciel boi się utraty pracy; push po każdej skończonej rzeczy.

## Stan (2026-07-14)

- Kod: kompletny prototyp MVP (7 plików przechodzi weryfikację struktury).
  Właściciel właśnie składa go w Studio wg `START.md`.
- Modele: 20 skryptów gotowych (50 grzybów, 25 petów, natura 5 światów,
  stragan, sprzedawca, gniazdo-jajo); właściciel eksportuje FBX partiami.
- NIE podpięte automatycznie (celowo, na później): natura/drzewa/stragan —
  mapa proceduralna z MapBuildera na razie zostaje.
- Monetyzacja: passy/producty w GameConfig mają `id = 0` (wyłączone) do
  czasu utworzenia ich w Creator Hub przez właściciela.
- Znane ograniczenie: kasa > ~9·10^15 straci precyzję (double) — przy
  skalach Sx+ trzeba będzie przejść na mantysę+wykładnik w zapisie.

## Jak pracuje właściciel

Wkleja pliki ręcznie do Studio (bez Rojo na razie; `default.project.json`
jest gotowy, gdyby chciał). Testuje sam i przynosi zrzuty ekranu + treść
błędów z Output. Uwagi ma głównie graficzne — oczekuj iteracji na wyglądzie
(GUI, oświetlenie, mapy) na podstawie screenshotów gier-wzorców.
