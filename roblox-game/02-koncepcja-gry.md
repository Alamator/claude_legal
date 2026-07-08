# Koncepcja gry (mini-GDD): „Night Forager 🍄" (robocza nazwa)

> Wynik kroku 1 planu. Szkic do rewizji po fazie 2 (nauka podstaw) —
> wtedy zamrażamy zakres MVP.

## Jedno zdanie (elevator pitch)

Symulator zbieractwa w tajemniczym lesie: za dnia zbierasz grzyby i jagody,
sprzedajesz je i ulepszasz ekwipunek — a po zmroku las staje się groźny,
ale to właśnie nocą rosną najrzadsze, świecące okazy.

## Dlaczego ta koncepcja (na podstawie analizy z 01-analiza-formatow.md)

- Rdzeń = **format symulatora** (Fish It #9, Pet Simulator 99 #10, Grow a
  Garden 2 #1) — wykonalny dla początkującego, sprawdzona monetyzacja.
- Motyw nocnego lasu = **hak z trendu 2026** (99 Nights in the Forest, #5) —
  napięcie dzień/noc daje momenty idealne pod TikToka, ale w MVP noc to tylko
  „większe ryzyko i nagroda", bez AI wrogów.
- Temat grzybobrania jest globalnie czytelny, tani w assety (las low-poly)
  i nie zajęty przez dużego gracza w tym formacie.

## Pętla rozgrywki (core loop)

```
zbieraj (klik/dotknięcie) → plecak się zapełnia → sprzedaj u NPC w chacie
→ kupuj ulepszenia (kosz, buty, latarnia) → odblokuj głębsze strefy lasu
→ rzadsze okazy → (nocą: 2–3× wartość, ale ograniczona widoczność i „mgła")
```

Sesja docelowa: 15–25 minut. Motywator powrotu: dzienne bonusy, okazy
sezonowe, kolekcja (dziennik grzybiarza).

## Systemy MVP (wersja 1.0 — nic ponad to!)

1. **Zbieranie:** ~10 rodzajów znalezisk w 4 rzadkościach (zwykłe, niezwykłe,
   rzadkie, legendarne); spawn losowy wg strefy i pory doby.
2. **Ekonomia:** jedna waluta (Złoto); sprzedaż u jednego NPC.
3. **Ulepszenia (8–12):** pojemność kosza, szybkość zbierania, szybkość
   biegu, zasięg latarni (nocą), każdy poziom ~1,8× droższy.
4. **Strefy (4):** Polana (start) → Bór → Mokradła → Stary Las; wejście za
   jednorazową opłatą w Złocie.
5. **Cykl dzień/noc:** 8 min dzień / 4 min noc; nocą wartość znalezisk ×2,5,
   widoczność spada, pojawiają się okazy świecące (tylko nocne).
6. **Zapis danych:** Złoto, ulepszenia, odblokowane strefy, dziennik kolekcji.
7. **Onboarding:** 60-sekundowa ścieżka strzałek: zbierz → sprzedaj → ulepsz.

**Lista „NIE robię w v1.0":** AI przeciwników, PvP, handel między graczami,
pety, budowanie bazy, crafting, więcej niż 1 mapa, tryby sezonowe.

## Styl i klimat

Low-poly, ciepłe kolory za dnia / granat i bioluminescencja nocą. Serwery
6–12 osób (widok innych zbieraczy ożywia las, zero interakcji wymaganej).
Grupa docelowa: 9–14 lat, mobile-first.

## Monetyzacja (od fazy 8 planu)

- Game Passy: „Wielki Kosz ×2", „VIP +10% wartości", „Neonowa latarnia"
  (kosmetyka + większy zasięg nocą).
- Dev Products: pakiety Złota, „Eliksir szczęścia" (15 min podwyższonej
  szansy na rzadkie).
- Nic z tego nie jest wymagane do ukończenia progresji.

## Miary sukcesu

- Prototyp: obcy gracz gra 10 min bez pytań.
- Premiera: retencja D1 > 20%, średnia sesja > 12 min, oceny > 75% 👍.
- Miesiąc 1: 2–4 aktualizacje, pierwszy event weekendowy (×2 Złoto).

## Otwarte pytania (do rozstrzygnięcia po fazie 2)

- Czy noc w MVP ma jakiekolwiek zagrożenie (utrata części plecaka we mgle?)
  czy tylko nagrodę? Skłaniam się: sama nagroda w v1.0, zagrożenie w v1.1.
- Nazwa: „Night Forager" vs polsko-globalne „Mushroom Rush" — przetestować
  na miniaturach (CTR) przed premierą.
