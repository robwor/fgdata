# fgdata — dlaczego to repo jest puste

Pełne lustro `gitlab.com/flightgear/fgdata` (gałąź `next`) nie wchodzi na GitHuba:
GitHub odrzuca każdy plik większy niż 100 MB, a w historii fgdata są:

    219,7 MB  Textures/Globe/ocean_depth_1.xcf
    148,7 MB  Airports/apt.dat.ws3.gz     (4 wersje w historii, ~0,59 GB)
    148,3 MB  Airports/apt.dat.ws3.gz
    147,3 MB  Airports/apt.dat.ws3.gz
    144,1 MB  Airports/apt.dat.ws3.gz

`apt.dat.ws3.gz` leży też w obecnym drzewie, więc nawet jednocommitowa migawka
zostanie odrzucona. Cała historia gałęzi `next` to 5,16 GB (11 143 commity).

## Gdzie to faktycznie leży

- Pełne lustro fgdata `next` (5,2 GB, bare): VPS `/srv/git/fgdata.git`,
  klonowanie: `git clone ssh://root@168.231.84.172/srv/git/fgdata.git`
- Mod Nasal (drgania kokpitu, `dynamic_view.nas`) — https://github.com/robwor/flightgear-nasal-mods
  (gałąź `real-cockpit` = gotowy plik, `main` = patch + oryginał)

## Gdyby jednak miało być na GitHubie

Jedyna droga to Git LFS dla tych pięciu blobów (`git lfs migrate import --above=100MB`).
Wtedy historia tych plików jest przepisana (SHA commitów się zmieniają), do LFS idzie
0,79 GB (limit darmowego konta: 1 GB), a reszta repo to ~4,4 GB wysyłane kawałkami,
bo pojedynczy push powyżej 2 GB jest odrzucany.
