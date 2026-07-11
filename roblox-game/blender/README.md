# Modele 3D — skrypty do Blendera

**Zasada stylu (obowiązuje wszystkie modele):** klockowato-uroczy Roblox
low-poly — mało segmentów (wyraźne, „kwadratowe" fasety), **płaskie
cieniowanie** (każda ścianka łapie światło osobno), pełne soczyste kolory,
przysadziste proporcje. Ma być ślicznie, ale po robloxowemu — a drabinka
rzadkości ma budzić ciekawość: „skoro ten jest taki, to jak wygląda
najrzadszy?"

Gotowe skrypty generujące modele gry w Blenderze (darmowy,
[blender.org](https://www.blender.org)). Nie musisz umieć modelować —
wklejasz skrypt, klikasz Run, model stoi w scenie.

## Kolejność (od najważniejszego)

| Skrypt | Co generuje | Gdzie trafi w grze |
|--------|-------------|--------------------|
| `05-grzyby-swiat1.py` | **10 gatunków Świata 1** — po jednym modelu na gatunek, im cenniejszy tym efektowniejszy (Kurka-lejek → Muchomor Cesarski ze złotymi kropkami, pierścieniem i koroną) | miejscówki w lesie, mini na półkach, dziennik |
| `08-grzyby-swiat2.py` | **10 gatunków Boru Iglastego**: rydz, lśniący maślak z kroplą żywicy, opieńka rosnąca w kępie, zieleniatka z igłą na kapeluszu, szyszkówka (kapelusz-szyszka z łuskami), mroźnik ze szronem, igłowiec-jeż, smolisty smolak z kroplami, Borowik Królewski ze złotą wirującą obręczą, Widmowy Muchomor-duch z dryfującymi kropkami | świat 2 |
| `06-grzyby-swiat5.py` | **10 gatunków Grzyboksiężyca (endgame)** — kratery, świetliste halo, warkocz komety, gwiezdny pył, pierścienie orbitalne z księżycem, plazma z rdzeniem, mgławica, antygrawitacyjny rozerwany trzon, supernowa, czarna dziura z dyskiem akrecyjnym. Części z `Glow` w nazwie → w Roblox ustaw Material = **Neon** | świat 5 |
| `01-grzyby.py` | 4 ogólne warianty grzyba (klasyk z kropkami, szeroki talerz, smukły stożek, kulka) | placeholdery / dekoracje |
| `02-drzewa.py` | drzewo liściaste, świerk, krzywe drzewo bagienne | dekoracje biomów (MapBuilder) |
| `09-natura-swiat2.py` | **komplet natury Boru Iglastego**: świerk duży (dwa odcienie pięter) i młody, sosna-parasol, martwe drzewo z konarami, pniak z rudym igliwiem, szyszka z łuskami + kupka szyszek, paproć, głaz ze szronem, krzaczek borówek z jagodami | poszycie Świata 2 |
| `07-natura-swiat1.py` | **komplet natury Świata 1**: liściak (dwukolorowa korona), brzoza z kreskami, krzak, pieniek z mini-grzybkami, omszała kłoda, kamień z mchem, stokrotka, dzwonek, kępka trawy, płat mchu | poszycie Lasu Liściastego; rozmiary losuje MapBuilder skalą klonów 0.8–1.4 |
| `03-stragan.py` | stragan: konstrukcja, dwuspadowy daszek, białe pasy, skrzynki | centrum każdej bazy |
| `04-sprzedawca.py` | NPC-sprzedawca z grzybowym kapeluszem (ręka uniesiona do machania) | za ladą straganu |

## Jak uruchomić skrypt (2 minuty)

1. Otwórz Blendera → górna zakładka **Scripting**.
2. Kliknij **New** (nowy tekst) → wklej całą zawartość pliku `.py`.
3. Kliknij **▶ Run Script**. Model pojawi się w scenie, w osobnej kolekcji
   (panel po prawej: `PickAShroom_…`).
4. Możesz odpalić kilka skryptów po kolei — każdy tworzy własną kolekcję.

## Dlaczego części są osobnymi obiektami

W Roblox **jeden MeshPart = jeden kolor**. Dlatego kapelusz, trzon i kropki
to osobne obiekty — w Studio pomalujesz każdy niezależnie (paleta świata
zostaje w rękach `GameConfig`, jak dotąd). Nie łącz ich w Blenderze!

## Eksport do Roblox (FBX)

1. Zaznacz w Blenderze obiekty JEDNEGO modelu (np. wszystkie `Grzyb1_…`) —
   klik + Shift-klik albo zaznacz całą kolekcję.
2. **File → Export → FBX (.fbx)**.
3. W opcjach eksportu (panel po prawej):
   - zaznacz **Selected Objects**,
   - Transform → **Apply Scalings: FBX All**,
   - reszta może zostać domyślna.
4. Nazwij plik np. `grzyb1.fbx` → Export.

## Import w Roblox Studio

1. Studio → zakładka **Home → Import 3D** → wybierz plik `.fbx`.
2. W oknie importu zostaw domyślne ustawienia; każda część wejdzie jako
   osobny MeshPart w jednym Modelu.
3. Wstaw do `ReplicatedStorage` do folderu `Models` (utwórz go) i nazwij
   czytelnie: `MushroomClassic`, `TreeLeafy`, `Stall`, `Vendor` itd.
4. **Ustaw każdemu MeshPartowi Anchored = true** i sprawdź skalę
   (1 jednostka Blendera ≈ 1 stud; grzyb ma ~2, drzewo ~6, stragan ~7).

## Podpięcie do gry (zrobię ja)

Gdy modele będą w `ReplicatedStorage.Models`, napisz do mnie — podmienię
funkcje w `MapBuilder`/`GameServer` z budowania z klocków na klonowanie
modeli (`model:Clone()`), z zachowaniem kolorowania palety świata przez
`GameConfig`. Kod jest na to gotowy: każda dekoracja to jedna funkcja.

## Nazwy części = automatyczne animacje w grze

Skrypt `src/FxClient.client.luau` ożywia części po nazwach, więc modele
z tego katalogu **animują się same** po imporcie — niczego nie ustawiasz:

- `…Pierscien… / …Halo… / …Dysk… / …Orbita… / …Fala…` → obraca się
  w swojej płaszczyźnie (halo Lunarka, pierścienie Orbitalnego Borowika,
  dysk akrecyjny Czarnej Dziury…);
- `…TrzonSeg… / …Skalki… / …Drobiny… / …Materia… / …Ksiezyc… / …Warkocz…`
  → lewituje (segmenty Antygrawika, wciągana materia, księżyc na orbicie);
- `…Glow…` → sypie iskrami w kolorze części (pamiętaj: Material = Neon).

Dlatego **nie zmieniaj nazw części przy imporcie** — nazwa to instrukcja.
(Animacji nie robimy w Blenderze celowo: FBX i tak nie przenosi do Roblox
ani animacji obiektów, ani particli — silnik gry robi to lepiej i za darmo.)

## Uwaga o wersjach

Skrypty używają tylko stabilnego API (`bpy.ops.mesh.primitive_*`) —
działają w Blenderze 3.x i 4.x. Jeśli coś rzuci błędem, skopiuj mi treść
błędu z konsoli (okno na dole zakładki Scripting).
