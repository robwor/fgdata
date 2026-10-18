# fgdata `next` — ostatnie 2 lata, z Git LFS

Gałąź `next` z `gitlab.com/flightgear/fgdata`, ucięta do ostatnich dwóch lat:
480 commitów, root z 2024-10-17, czubek z 2026-10-17. Zawartość plików w czubku
jest identyczna z upstreamem (`3a64d7044c…` po obu stronach), różni się tylko
historia.

## Dlaczego ucięta

Pełna historia `next` to 5,16 GB. GitHub nie przyjmie pliku większego niż 100 MB,
a w historii siedzą cztery wersje `Airports/apt.dat.ws3.gz` (144–149 MB) i
`Textures/Globe/ocean_depth_1.xcf` (219,7 MB). Po migracji do LFS plików zostaje
~4,4 GB do wysłania, a łącze nadaje ~2,3 Mbit/s — pełne lustro to kilka godzin.
Cięcie do dwóch lat zostawia 2,55 GB historii i jeden plik w LFS.

## Co jest w LFS

`Airports/apt.dat.ws3.gz` (148,7 MB) — jedyny plik >100 MB w tej historii.
Reszta (największy 91,8 MB) idzie zwykłym git-em.

Skutek: SHA commitów są przepisane względem upstreamu, więc to nie jest
bit-identyczne lustro — drzewa te same, historia własna.

## Klonowanie

    git lfs install
    git clone https://github.com/robwor/fgdata.git
    cd fgdata && git checkout next

Bez `git lfs install` dostaniesz `apt.dat.ws3.gz` jako 134-bajtowy wskaźnik.

## Pełna historia i mod Nasal

- Pełne lustro `next` (5,2 GB, bare, 11 143 commity): VPS `/srv/git/fgdata.git`,
  `git clone ssh://root@168.231.84.172/srv/git/fgdata.git`; gałąź `real-cockpit`
  ma nałożony mod drgania kokpitu
- Mod Nasal osobno: https://github.com/robwor/flightgear-nasal-mods
  (`real-cockpit` = gotowy `Nasal/dynamic_view.nas`, `main` = patch + oryginał)

## Limity darmowego LFS

1 GB miejsca i 1 GB transferu miesięcznie. Jedno pełne klonowanie pobiera LFS
raz (148,7 MB), więc w limit się mieści; do codziennej pracy wygodniejszy jest VPS.
