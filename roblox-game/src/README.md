# Kod gry — montaż prototypu w Roblox Studio (~15 minut)

Komplet skryptów **grywalnego prototypu** (faza 4 planu): mapa buduje się
sama, więc niczego nie modelujesz ręcznie. Wklejasz 5 plików i grasz.

## Pliki i ich miejsca w Studio

| Plik | Typ skryptu | Gdzie w Studio | Nazwa w Studio |
|------|-------------|----------------|----------------|
| `GameConfig.luau` | **ModuleScript** | `ReplicatedStorage` | `GameConfig` |
| `DataService.luau` | **ModuleScript** | `ServerScriptService` | `DataService` |
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
- [ ] Test mobilny: zakładka **Test → Device** — przycisk BIEG jest na
      ekranie, prompty działają dotykiem.

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
3. Brak eventów serwerowych, skrótów powrotnych, dziennika i sprzedaży
   z półek — wchodzą w fazie 5 (produkcja MVP).
4. Zapis przez `SetAsync` co 120 s — przed premierą przejdziemy na
   `UpdateAsync` + kolejkę (ochrona przed utratą danych przy awarii).
