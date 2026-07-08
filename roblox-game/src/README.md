# Kod gry — jak używać tych plików w Roblox Studio

Ten katalog będzie stopniowo zapełniał się skryptami gry. Każdy plik ma
w nagłówku komentarz mówiący, **gdzie w Studio go wkleić** i jaką ma mieć
nazwę.

## Stan obecny

| Plik | Gdzie w Studio | Co robi |
|------|----------------|---------|
| `GameConfig.luau` | ModuleScript w `ReplicatedStorage`, nazwa `GameConfig` | Cały balans gry w jednym miejscu: statystyki, rzadkości, mutacje, światy, ceny, eventy, monetyzacja |

## Jak wkleić skrypt do Studio (dla przypomnienia)

1. Otwórz projekt w Roblox Studio.
2. W oknie **Explorer** znajdź wskazany kontener (np. `ReplicatedStorage`).
3. Kliknij „+" → wybierz typ (np. **ModuleScript**) → zmień nazwę na podaną.
4. Otwórz skrypt (2×klik), usuń domyślną zawartość, wklej treść pliku.

## Zasady (te same co w GDD §8)

- **Wszystkie liczby balansu żyją w `GameConfig.luau`** — jeśli jakiś skrypt
  potrzebuje ceny, szansy czy mnożnika, ma go `require`'ować z configu,
  nigdy nie wpisywać na sztywno.
- Pola `id = 0` w sekcji monetyzacji uzupełnimy prawdziwymi ID po utworzeniu
  Game Passów i Developer Products w Creator Hub (faza 8 planu).
- Pule gatunków dla światów 2–5 są puste (`species = {}`) — uzupełnimy je
  w fazie produkcji MVP; do prototypu wystarczy Świat 1.
