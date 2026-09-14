-- Ce que le joueur a découvert : les VILLES, et ce que ses convois ont en vue.
--
-- IL N'Y A PAS DE VOILE SUR LA CARTE DE PORT ROYALE 3, et le jeu le dit lui-même :
--
--   « La carte maritime montre TOUT LE MONDE DU JEU et toutes les villes que vous
--     avez découvertes. D'autres villes vont apparaître quand vous les
--     découvrirez. »            (`ID_PLAYER_TIPP_A00_TEXT`)
--
--   « Pour découvrir une ville, vous devez EN APPROCHER AVEC VOTRE CONVOI. »
--                               (`ID_TUTORIAL_A04_TEXT2`)
--
-- La géographie est donc toujours visible ; ce sont les ENTITÉS qui manquent — les
-- villes qu'on n'a pas approchées, et les convois qu'on n'a pas en vue. Le registre
-- d'entités de la carte maritime (`0x460d11`) le confirme par son silence : il
-- liste `PlayerShipConvoy`, `SelectionConvoyMap`, `SelectionConvoyTown`,
-- `ConvoyTargetLine`, `ConvoyRoute`, `SeaMapView` — aucune texture de brouillard.
--
-- UNE PREMIÈRE VERSION DE CE FICHIER POSAIT UN VOILE, avec une grille de 79 200
-- cases et un shader. C'était une invention, et elle butait d'ailleurs sur une
-- absurdité qui aurait dû m'alerter : appliqué à du terrain, `RangeOfVision1` = 8
-- donnait un disque de dix-sept pixels sur une carte de trois mille. L'anomalie
-- venait de mon hypothèse. Rapportée au REPÉRAGE D'UNE ENTITÉ, cette portée
-- redevient d'un ordre de grandeur plausible.
--
-- CE QUI RESTE INCONNU, et que je ne remplace pas par une invention : l'UNITÉ de
-- `[SeaMapMovement] RangeOfVision1` = 8 / `RangeOfVision2` = 12 /
-- `RangeOfVisionWatch` = 12. Le rayon ci-dessous est donc CHOISI, isolé dans une
-- seule constante pour être corrigé d'un geste le jour où l'unité sortira de
-- l'exécutable.
--
-- LA VUE EST UNE AFFAIRE DE CAPITAINE chez PR3 : une statistique
-- (`ID_GUI_TT_CAPTAIN_SIGHT`, « Distance de vision ») que fait monter une
-- compétence (`ID_GUI_TT_TC_GET_SKILL_SIGHT_PLUS`, « Portée de vue + ») — la vigie,
-- sixième compétence de la vignette. La sim n'a pas de capitaines : le crochet
-- `portee_de` existe et rend une valeur unique.

local Archipel = require("sim.archipel")

local Exploration = {}

-- Rayon de repérage d'un convoi, en UNITÉS DE MONDE. CHOISI, pas relevé : voir
-- l'en-tête. Six cents unités valent cinquante cases, soit un peu plus d'une
-- journée de mer — on découvre une ville en passant au large, pas en la frôlant.
Exploration.PORTEE = 600.0

-- Les portées de PR3, gardées sous les yeux bien qu'inapplicables faute d'unité.
Exploration.PR3_VISION1 = 8
Exploration.PR3_VISION2 = 12
Exploration.PR3_VISION_WATCH = 12

-- Les villes découvertes, par clé. La découverte est PERSISTANTE : une ville vue
-- une fois reste sur la carte, comme le compte de « Villes découvertes » de PR3
-- (`ID_GUI_OUTGAME_MENU_DISCOVERED_TOWNS`) l'implique.
Exploration.villes = {}

-- Où sont les yeux du joueur en ce moment : la position de chacun de ses convois.
-- Rafraîchie à chaque pas ; elle ne se garde pas d'un tour sur l'autre, puisque
-- voir un convoi étranger est instantané, à la différence de connaître une ville.
Exploration.yeux = {}

-- Monte à chaque ville nouvellement découverte : le moteur s'en sert pour ne
-- refaire ses marqueurs que lorsque quelque chose a changé.
Exploration.version = 0


function Exploration.reinitialiser()
  Exploration.villes = {}
  Exploration.yeux = {}
  Exploration.version = 0
end


-- La portée de vue d'un convoi, en unités de monde. Le crochet existe pour le jour
-- où la sim aura des capitaines ; aujourd'hui elle ne dépend de rien.
function Exploration.portee_de(_convoi)
  return Exploration.PORTEE
end


function Exploration.ville_decouverte(cle)
  return Exploration.villes[cle] == true
end


function Exploration.nombre_decouvertes()
  local n = 0
  for _ in pairs(Exploration.villes) do n = n + 1 end
  return n
end


-- Un convoi passe ici : il découvre les villes qu'il approche, et pose ses yeux.
-- Rend le nombre de villes nouvellement découvertes — zéro la plupart du temps.
function Exploration.approcher(x, z, portee)
  portee = portee or Exploration.PORTEE
  Exploration.yeux[#Exploration.yeux + 1] = { x = x, z = z, r = portee }
  local r2 = portee * portee
  local neuves = 0
  for _, port in ipairs(Archipel.ports) do
    if not Exploration.villes[port.cle] then
      local _, _, rx, rz = Archipel.positionPort(port)
      local dx, dz = rx - x, rz - z
      if dx * dx + dz * dz <= r2 then
        Exploration.villes[port.cle] = true
        neuves = neuves + 1
      end
    end
  end
  if neuves > 0 then Exploration.version = Exploration.version + 1 end
  return neuves
end


-- À appeler avant de piloter les convois du pas : les yeux d'hier ne valent pas
-- pour aujourd'hui.
function Exploration.oublier_les_yeux()
  Exploration.yeux = {}
end


-- Ce point du monde est-il sous les yeux d'un convoi du joueur EN CE MOMENT ?
-- Sert à ne montrer un convoi étranger que là où l'on regarde.
function Exploration.en_vue(x, z)
  for _, oeil in ipairs(Exploration.yeux) do
    local dx, dz = oeil.x - x, oeil.z - z
    if dx * dx + dz * dz <= oeil.r * oeil.r then return true end
  end
  return false
end


return Exploration
