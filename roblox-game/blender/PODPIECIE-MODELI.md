# Podpięcie modeli do gry — automatyczne, bez czekania na nikogo

Gra **sama wykrywa** modele w `ReplicatedStorage/Models` i używa ich zamiast
proceduralnych klocków. Brak folderu albo brak konkretnego modelu = nic się
nie psuje, gra stawia klocki jak dotąd. Możesz więc wgrywać modele partiami
(np. najpierw pety Świata 1) — każdy podłączy się od razu po wgraniu.

## Struktura folderów w Studio

W oknie Explorer utwórz w `ReplicatedStorage` folder **`Models`**
(prawy klik → Insert Object → Folder), a w nim:

```
ReplicatedStorage
└─ Models
   ├─ Grzyby          ← folder: modele gatunków (nazwa = nazwa gatunku)
   ├─ Pety            ← folder: modele petów (nazwa = nazwa peta)
   └─ GniazdoJajo     ← Model (bez folderu): stanowisko gachy ze skryptu 15
```

Po imporcie FBX (Home → Import 3D) każdy import wchodzi jako jeden Model —
**przeciągnij go w odpowiednie miejsce i zmień nazwę** na dokładnie tę z
tabel poniżej (łącznie z polskimi znakami i spacjami!). Wielkość liter ma
znaczenie.

## Co gra robi automatycznie

- **Grzyby w lesie**: miejscówka losuje gatunek już przy wyrośnięciu — jeśli
  w `Models/Grzyby` jest model o nazwie gatunku, stoi w lesie TEN model
  (obrócony losowo, przeskalowany losowo jak dotąd), a prompt pokazuje nazwę
  gatunku. Rozbryzg po ścięciu bierze kolor z części z `Kapelusz` w nazwie.
- **Pety**: jeśli w `Models/Pety` jest model o nazwie peta, lewituje on przy
  graczu zamiast kulki. Części `*Pierscien/Halo/Dysk/Orbita*` **wirują**,
  `*Warkocz/Drobiny/Materia/Ksiezyc/Skalki*` **falują** — animacja jedzie
  razem z petem. SEKRET-y dostają tęczowy podpis i smugę iskier jak dotąd.
- **Stanowisko jaja**: jeśli istnieje `Models/GniazdoJajo`, każda baza
  dostaje jego klon, a części z `Cetki/Krag/Drobiny/Kule` w nazwie są
  przemalowywane na kolor akcentu świata (5 baz = 5 kolorów z jednego
  modelu). Prompt wyklucia działa bez zmian.
- **Drobiazgi techniczne za Ciebie**: kotwiczenie (Anchored), wyłączenie
  kolizji, `*Glow` → Material Neon (gdybyś zapomniał ustawić), dobór skali
  petów do ~2 studów.
- **„Tekstury" też automatycznie**: klasycznych tekstur-obrazków ten styl
  nie potrzebuje — kolory FBX przenosi sam, a fakturę powierzchni dają
  wbudowane materiały Roblox, które gra przypisuje **po nazwach części**
  (reguły w `GameConfig.materialFor`): `Pien/Galazki/Kloda…` → deski,
  `Kamien/Glaz/Podest…` → łupek, `Krysztal/Ametyst/Klejnot…` → szkło,
  `Lod/Szron/Sopel` → lód, `Mech/Trawa/Korona/Listek…` → trawa,
  `Futro/Piora/Pusz` → tkanina, `Zloto/Metal` → folia metaliczna,
  `Blot/Kaluza` → grunt. Reszta zostaje gładka (SmoothPlastic — typowe
  dla stylu). Czyli: wgrywasz FBX i tyle — drewno wygląda jak drewno,
  kryształ błyszczy, futro ma splot.

Czego gra NIE podmienia (celowo): grzybów zasadzonych na grządkach — tam
kapelusz w kolorze rzadkości to ważny sygnał (od razu widać, komu wyrósł
Legendarny), a rozmiar pokazuje level 1–100.

## Nazwy modeli grzybów (`Models/Grzyby/…`)

Kolejność = kolejność w skryptach Blendera (1. najtańszy → 10. najcenniejszy).

| # | Świat 1 (skrypt 05) | Świat 2 (skrypt 08) | Świat 3 (skrypt 10) | Świat 4 (skrypt 12) | Świat 5 (skrypt 06) |
|--:|---------------------|---------------------|---------------------|---------------------|---------------------|
| 1 | `Kurka` | `Rydz Borowy` | `Błotnik` | `Kwarcownik` | `Kraterek` |
| 2 | `Podgrzybek` | `Maślak Sosnowy` | `Zgniłek` | `Grotołaz` | `Lunark` |
| 3 | `Maślak Zwyczajny` | `Opieńka Mglista` | `Trzęsak Bagienny` | `Echowiec` | `Kometka` |
| 4 | `Kania` | `Zieleniatka` | `Mszarnik` | `Lazuryt` | `Gwiezdny Pył` |
| 5 | `Gąska Zielona` | `Szyszkówka` | `Bagienna Kurka` | `Rubinek` | `Orbitalny Borowik` |
| 6 | `Rydz Młody` | `Mroźnik` | `Fosforek` | `Szmaragdziak` | `Plazmiak` |
| 7 | `Borowik Szlachetny` | `Igłowiec` | `Świetlik Bagienny` | `Ametystówka` | `Nebulon` |
| 8 | `Koźlarz Czerwony` | `Smolak` | `Topielec` | `Obsydianka` | `Antygrawik` |
| 9 | `Smardz Złocisty` | `Borowik Królewski` | `Mglak` | `Kryształak` | `Supernowik` |
| 10 | `Muchomor Cesarski` | `Widmowy Muchomor` | `Król Mokradeł` | `Diamentowy Kapelusz` | `Czarna Dziura` |

## Nazwy modeli petów (`Models/Pety/…`)

Kolejność = rzadkość (1. Rzadki 55% → 5. SEKRET 0,1%).

| # | Świat 1 (skrypt 16) | Świat 2 (skrypt 17) | Świat 3 (skrypt 18) | Świat 4 (skrypt 19) | Świat 5 (skrypt 20) |
|--:|---------------------|---------------------|---------------------|---------------------|---------------------|
| 1 | `Grzybek Skoczek` | `Sowa Mgielna` | `Bagienny Glut` | `Kryształowy Żuk` | `Kosmiczny Grzybek` |
| 2 | `Ślimak Zamszowy` | `Szyszkostwór` | `Świetlik Bzyk` | `Ametystowy Nietoperz` | `Lunar Puf` |
| 3 | `Jeżozwierzyk` | `Lisek Borowy` | `Neonowy Żabol` | `Gemek` | `Meteorek` |
| 4 | `Biedronix` | `Mroźny Puszek` | `Ropuch Królewski` | `Grotowy Golem` | `Gwiezdny Ślimak` |
| 5 | `Wiewiór Rudzik` | `Dzięciołek` | `Mglisty Duszek` | `Pryzmatek` | `Czarnodziurek` |

## Szybki test po wgraniu

1. Wgraj JEDEN model (np. `Grzyby/Kurka`), kliknij ▶ Play.
2. Biegnij do lasu — część miejscówek w Świecie 1 to teraz Twoja Kurka
   (miejscówki odrastają co kilka sekund, więc chwilę potrwa, aż się wylosuje).
3. **Rozmiar jest normalizowany automatycznie** — nawet jeśli FBX wyszedł
   gigantyczny albo mikroskopijny, gra sama sprowadza grzyby, pety
   i stanowisko jaja do właściwej wielkości. Jeśli model leży na BOKU:
   w Blenderze zaznacz wszystko → `Ctrl+A → All Transforms` i eksportuj
   ponownie.
4. Pety sprawdzisz wykluwając jajo (albo tymczasowo ustaw w GameConfig
   `eggCostByWorld[1] = 1`).

## „Wgrałem i NIC się nie pojawia" — checklista

Po kolei (99% przypadków to punkt 2 albo 3):

1. **Import 3D wstawia model do `workspace`** (mapa) — tam ma tylko leżeć
   chwilowo. Gra NIE używa modeli z workspace!
2. **Model musi trafić do `ReplicatedStorage → Models → Grzyby`**
   (przeciągnij w Explorerze). Sprawdź strukturę: folder `Models`,
   w nim folder `Grzyby` — wielkość liter się liczy.
3. **Nazwa modelu = DOKŁADNIE nazwa gatunku** z tabeli wyżej, z polskimi
   znakami i spacjami: `Kurka`, `Maślak Zwyczajny`, `Borowik Szlachetny`…
   Import nazywa model tak jak plik (np. `grzyb1`) — ZMIEŃ nazwę (F2).
4. Model w `ReplicatedStorage` jest NIEWIDOCZNY w świecie — to magazyn.
   Gra go klonuje do lasu przy WYROŚNIĘCIU nowej miejscówki: wciśnij
   Play i odczekaj kilkanaście sekund w lesie.
5. Upewnij się, że wgrałeś aktualne pliki `GameServer`/`MapBuilder` —
   auto-podpięcie modeli siedzi właśnie tam.
6. Nadal nic? Otwórz Output (View → Output) i przyślij mi czerwone linie.
