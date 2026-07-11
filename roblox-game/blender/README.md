# Modele 3D — skrypty do Blendera

Gotowe skrypty generujące modele gry w Blenderze (darmowy,
[blender.org](https://www.blender.org)). Nie musisz umieć modelować —
wklejasz skrypt, klikasz Run, model stoi w scenie.

## Kolejność (od najważniejszego)

| Skrypt | Co generuje | Gdzie trafi w grze |
|--------|-------------|--------------------|
| `01-grzyby.py` | 4 warianty grzyba (klasyk z kropkami, szeroki talerz, smukły stożek, kulka) | miejscówki w lesie, mini-grzybki na półkach i skrzynkach |
| `02-drzewa.py` | drzewo liściaste, świerk, krzywe drzewo bagienne | dekoracje biomów (MapBuilder) |
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

## Uwaga o wersjach

Skrypty używają tylko stabilnego API (`bpy.ops.mesh.primitive_*`) —
działają w Blenderze 3.x i 4.x. Jeśli coś rzuci błędem, skopiuj mi treść
błędu z konsoli (okno na dole zakładki Scripting).
