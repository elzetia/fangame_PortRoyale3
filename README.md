# Port Royale : Under the wind

Fan game de *Port Royale* : la carte stratégique des Caraïbes en 3D stylisée,
avec la simulation économique qui tourne en Lua, à côté du moteur.

Projet **Godot 4.7** (Forward+). Non affilié à Kalypso ni à Gaming Minds Studios.

## Lancer

Ouvre le dossier dans Godot 4.7, ou double-clique `jouer.bat` / `editeur.bat`
(les deux pointent vers une installation WinGet de Godot — ajuste le chemin si
le tien diffère). Scène principale : `scenes/carte.tscn`.

## Comment c'est agencé

| Dossier | Ce qu'on y trouve |
|---|---|
| `sim/` | La simulation en Lua : économie, marchands, navigation, calendrier, villes. Indépendante de Godot, appelée via `bridge.lua`. |
| `scripts/` | Le côté moteur en GDScript : caméra stratégique, cuisson de la carte, navires, pavillons, ambiance. |
| `shaders/` | La cuisson du terrain (`cuisson_carte`), la mer animée, la houle, les nuages. |
| `scenes/` | `carte.tscn` (le jeu), `cuisson.tscn` (l'atelier de cuisson de la carte). |
| `outils/` | Scripts Python hors moteur : découpe d'atlas, conversion DDS, planches de contact, relief vers terrain. |
| `tools/` | Sondes GDScript pour vérifier que le pont Lua répond. |
| `sprites/`, `assets_generes/` | Les sprites du jeu, générés puis découpés en atlas. |

La carte du monde **est celle de Port Royale 3** : `outils/carte_ombrage.py` la
décode depuis les textures du jeu, puis l'ombre d'après ses propres hauteurs —
avec la lumière de PR3 lui-même (`LightDirection` −1/−1/−1, soit un soleil à
35,26°). Elle n'est pas dans le dépôt ; l'outil la refabrique depuis ta copie.

Le terrain en relief, lui, est **cuit** par `shaders/cuisson_carte.gdshader` à
partir d'un champ d'altitude : `carte_relief.png` et `carte_champ.png`, que
produit `outils/champ_cote.py`.

## Ce qui n'est pas dans le dépôt

- **`carte_cuite.png`** — la carte du monde peinte de Port Royale 3 (© Kalypso /
  Gaming Minds). Refabrique-la depuis ta propre copie du jeu :
  `py -3 outils/carte_ombrage.py`, puis `py -3 outils/carte_eau.py` pour rendre
  l'eau du large à la nappe animée.
- **`reference_pr3/`** — textures extraites de Port Royale 3 (© Kalypso /
  Gaming Minds), gardées en local comme référence de direction artistique.
  Regénère-les depuis ta propre copie du jeu avec `outils/dds2png.py`, et les
  anneaux de sélection de la carte maritime avec
  `outils/extraire_selection_pr3.py`.
- **Les binaires non-Windows de `lua-gdextension`** — l'addon en livre ~209 Mo
  pour toutes les plateformes. Seul Windows est versionné ; prends les autres
  chez [gilzoide/lua-gdextension](https://github.com/gilzoide/lua-gdextension).
- **`.godot/`** — cache du moteur, régénéré au premier lancement.

## Crédits

Musiques générées avec [Suno](https://suno.com). Sprites générés à partir des
prompts de `reference_pr3/prompts_gemini.md`, sur une direction artistique
relevée dans les jeux originaux. `addons/lua-gdextension` est sous licence MIT.
