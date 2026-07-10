# Kod gry — montaż prototypu w Roblox Studio (~15 minut)

Komplet skryptów **grywalnego prototypu** (faza 4 planu + pierwsza porcja
fazy 5): mapa buduje się sama, więc niczego nie modelujesz ręcznie.
Wklejasz 6 plików i grasz.

Poza pętlą podstawową działa już: **eventy serwerowe** co 4–6 min (Złoty
Deszcz, Wysyp, Tęcza nad lasem, Przymrozek — baner z odliczaniem w lewym
górnym rogu), **skróty powrotne** (świecące portale na pierścieniach 2–5:
pierwsze użycie kupuje, kolejne teleportują do bazy), **sprzedaż
najsłabszego grzyba z półki** (przycisk pod ulepszeniami — zwalnia slot),
**dziennik grzybiarza** (przycisk 📖 w prawym górnym rogu; nagrody za 10/25/
50/70 wpisów), **3 dzienne zadania + skrzynka co 20 minut** (panel w lewym
dolnym rogu), **samouczek 3 kroków** prowadzący nowego gracza strzałką
(zetnij → odłóż → ulepsz, +150 💰 na koniec), **wszystkie 5 światów** (fioletowy
portal w bazie odblokowuje następny świat za kasę, zielony wraca; każdy świat
ma własną pulę 10 gatunków, mnożnik dochodu i szybsze psucie; Grzyboksiężyc ma
wyższy skok) oraz **wizualne półki**: stojak z twoim nickiem i dochodem stoi
w bazie, grzyby na nim mają kolor rzadkości, a mutacje świecą.

## Pliki i ich miejsca w Studio

| Plik | Typ skryptu | Gdzie w Studio | Nazwa w Studio |
|------|-------------|----------------|----------------|
| `GameConfig.luau` | **ModuleScript** | `ReplicatedStorage` | `GameConfig` |
| `DataService.luau` | **ModuleScript** | `ServerScriptService` | `DataService` |
| `EventService.luau` | **ModuleScript** | `ServerScriptService` | `EventService` |
| `MapBuilder.server.luau` | **Script** | `ServerScriptService` | `MapBuilder` |
| `GameServer.server.luau` | **Script** | `ServerScriptService` | `GameServer` |
| `ClientMain.client.luau` | **LocalScript** | `StarterPlayer → StarterPlayerScripts` | `ClientMain` |

(Końcówki `.server`/`.client` w nazwach plików mówią tylko, jakiego TYPU
skrypt utworzyć — w Studio nazwa jest bez nich.)

## Montaż krok po kroku

1. Otwórz Roblox Studio → **New** → szablon **Baseplate**.
2. Dla każdego pliku z tabeli: w oknie **Explorer** najedź na wskazany
   kontener → kliknij „+" → wybierz właściwy typ (ModuleScript / Script /
   LocalScript) → zmień nazwę → otwórz (2×klik) → usuń domyślną zawartość →
   wklej treść pliku.
3. **File → Publish to Roblox** (nadaj dowolną roboczą nazwę; gra może być
   prywatna).
4. **Game Settings → Security → włącz „Enable Studio Access to API
   Services"** — bez tego zapis postępu (DataStore) nie działa w Studio.
5. Wciśnij **Play** (F5).

## Jak sprawdzić, że wszystko działa (kryteria fazy 4)

- [ ] W konsoli Output: `[MapBuilder] Mapa gotowa…` i `[GameServer] …wystartował 🍄`.
- [ ] Widzisz HUD: kasa u góry, pasek kondycji na dole, kosz po prawej,
      3 przyciski ulepszeń po lewej.
- [ ] **Shift** = sprint; pasek spada; po wyzerowaniu wleczesz się chwilę.
- [ ] W lesie stoją grzybki — przytrzymaj **E** przy grzybku, trafia do kosza,
      jego świeżość tyka w dół.
- [ ] Wróć na drewniany **BasePad** w bazie → przytrzymaj **E** → grzyby idą
      na półki i kasa rośnie co sekundę.
- [ ] Kupujesz ulepszenia; po **Stop i ponownym Play** kasa/poziomy wracają
      (zapis działa).
- [ ] Po 4–6 minutach gry pojawia się baner eventu (⚡) z odliczaniem.
- [ ] Świecący portal na pierścieniu 2: pierwsze **E** kupuje skrót
      (2000 💰), kolejne teleportuje do bazy.
- [ ] Przycisk „💸 Sprzedaj najsłabszy" zdejmuje grzyb z półki i dodaje kasę.
- [ ] Na świeżym koncie widać samouczek (KROK 1/3 + znacznik ⬇️ nad
      najbliższym grzybkiem); po 3 krokach nagroda 150 💰.
- [ ] W lewym dolnym rogu: 3 zadania dzienne z postępem i odliczanie do 🎁.
- [ ] Przycisk „📖 Dziennik" otwiera kolekcję; nowy wpis po każdym nowym
      gatunku×rzadkości.
- [ ] Fioletowy portal w bazie: odblokowanie Boru Iglastego za 25k 💰,
      podróż przenosi do nowej bazy, nazwa świata na HUD się zmienia.
- [ ] Przy BasePadzie stoi stojak z twoim nickiem; po dostawie pojawiają się
      na nim kulki w kolorach rzadkości (mutacje świecą).
- [ ] Test mobilny: zakładka **Test → Device** — przycisk BIEG jest na
      ekranie, prompty działają dotykiem.

## Warstwa wizualna (pass „żeby nie wyglądało generycznie")

- **Oświetlenie filmowe** ustawiane skryptem: ciepłe popołudnie, mgła
  (Atmosphere), Bloom, korekcja kolorów (podbita saturacja — low-poly żyje
  kolorem), promienie słońca.
- **Każdy biom wygląda inaczej**: Las = drzewa-kule, Bór = świerki z dysków,
  Mokradła = karłowate drzewa + świecące kałuże + świetliki, Grota = neonowe
  kryształy (część ze światłem), Księżyc = kratery i lewitujące skały.
  Środek mapy (pas biegu) jest zawsze wolny od dekoracji.
- **Bazy jak obozowiska**: stragan z daszkiem nad BasePadem, ognisko
  z cząsteczkami i ciepłym światłem, lampy przy wejściu w las, flaga
  w kolorze świata, przekrzywione drewniane tabliczki.
- **Portale z kamiennym łukiem**, poświatą, iskrami i światłem.
- **Grzyby w lesie**: kolory kapeluszy z palety świata, losowy rozmiar,
  białe kropki, iskierki; w pierścieniach 4-5 świecą własnym światłem.
- **Efekty**: rozbryzg w kolorze kapelusza przy ścięciu, nazwa znaleziska
  wylatuje w kolorze rzadkości, „+N 🍄" nad graczem przy dostawie.
- **Stojaki w bazie**: mini-grzybki w kolorach rzadkości (mutacje świecą),
  najlepszy okaz jest większy i sypie złotymi iskrami.

## Najczęstsza usterka: „nic się nie pojawia"

1. Mapa i gra powstają **dopiero po wciśnięciu Play (F5)** — w trybie edycji
   widać tylko pustą płytę.
2. Skrypty MUSZĄ siedzieć w kontenerach z tabeli powyżej. Wrzucone luzem
   (np. do Workspace) nie zadziałają. W Explorerze można je przeciągnąć
   myszką na właściwe miejsce.
3. `GameConfig` i `DataService` muszą być **ModuleScriptami** — wstawione
   jako Script powodują, że reszta wisi w nieskończoność (żółte ostrzeżenie
   `Infinite yield possible…` w Output).
4. Zawsze zaglądaj do **View → Output**: powinny być linijki
   `[MapBuilder] Mapa gotowa…` i `[GameServer] …wystartował 🍄`; czerwone
   błędy mówią, który skrypt jest nie tak.

## Praca bez ręcznego wklejania (opcjonalnie, na później)

- **Oficjalny Roblox Studio MCP** — Claude zainstalowany na Twoim
  komputerze (Claude Desktop / Claude Code) może wstawiać skrypty do Studio
  bezpośrednio: https://github.com/Roblox/studio-rust-mcp-server
- **Rojo** — plik `../default.project.json` mapuje te pliki na właściwe
  kontenery; po zainstalowaniu wtyczki Rojo w Studio i uruchomieniu
  `rojo serve` w katalogu `roblox-game/` wszystko synchronizuje się samo:
  https://rojo.space

## Zasady

- **Wszystkie liczby balansu żyją w `GameConfig.luau`** — skrypty logiki
  `require`'ują config, nigdy nie mają liczb wpisanych na sztywno.
- Serwer nie ufa klientowi: klient tylko wyświetla HUD i wysyła prośby
  (sprint, zakup); losowania, kasa i zapis są wyłącznie po stronie serwera.
- Pola `id = 0` w monetyzacji uzupełnimy po utworzeniu passów w Creator Hub
  (faza 8). Światy 2–5 mają puste pule gatunków — uzupełnimy w fazie MVP.

## Świadome skróty prototypu (do zrobienia porządnie w fazie MVP)

1. Grzyby innych graczy są *widoczne* dla wszystkich (ściąć może tylko
   właściciel). Docelowo: rendering per-gracz po stronie klienta (GDD §4).
2. Mapa ma skalę 0,5 (`MAP_SCALE` w MapBuilder) — testy bez zdzierania nóg.
3. Brak jeszcze: serii dziennej (login streak), Deszczu meteorów (wymaga
   wspólnych spawnów) i całej monetyzacji — dalsza część fazy 5 i faza 8.
4. Światy stoją obok siebie na jednej mapie (przesunięte o 400 studów) —
   docelowo osobne miejsca/teleporty, ale do testów to zaleta: widać wszystko.
4. Zapis przez `SetAsync` co 120 s — przed premierą przejdziemy na
   `UpdateAsync` + kolejkę (ochrona przed utratą danych przy awarii).
