-- Sauver et reprendre une partie.
--
-- POURQUOI CE MODULE. Le projet vise un Port Royale qu'on modifie. Sans
-- sauvegarde, on ne peut ni quitter une partie ni juger une modification sur la
-- durée : c'est le préalable à tout le reste.
--
-- CE QU'ON SAUVE, ET CE QU'ON NE SAUVE PAS. L'état modifiable d'une partie tient
-- en cinq endroits — la compagnie, l'économie, les marchands de l'IA,
-- l'exploration et le calendrier. Tout le reste (l'archipel, les marchandises,
-- les types de navires, les stratégies) est de la DONNÉE, pas de l'état : elle
-- est rechargée depuis ses fichiers au démarrage. C'est d'ailleurs ce qui rend le
-- jeu modifiable — on change la donnée, les parties existantes suivent.
--
-- LE PIÈGE DES NAVIRES. Un convoi porte des RÉFÉRENCES aux fiches de
-- `Navires.liste`. Les écrire telles quelles ferait trois choses, toutes
-- mauvaises : une sauvegarde énorme, une duplication de la donnée, et une partie
-- qui ne verrait jamais une correction apportée aux navires. On n'écrit donc que
-- la CLÉ du type, et l'on reconstruit au chargement.
--
-- LE FORMAT est une table Lua simple — nombres, chaînes, booléens, tables. Le
-- moteur la convertit en JSON et l'écrit sur le disque : la simulation ne connaît
-- pas Godot et n'a pas à savoir où va le fichier.
--
-- Lua pur : ce fichier ne connaît pas Godot.

local Archipel   = require("sim.archipel")
local Calendrier = require("sim.calendrier")
local Compagnie  = require("sim.compagnie")
local Economie   = require("sim.economie")
local Exploration = require("sim.exploration")
local Marchands  = require("sim.marchands")
local Navires    = require("sim.navires")

local Sauvegarde = {}

-- Monte de un à chaque changement de format. Une sauvegarde d'une autre version
-- est REFUSÉE plutôt que lue de travers : mieux vaut un message clair qu'une
-- partie silencieusement corrompue.
Sauvegarde.VERSION = 1

-- Les champs d'un convoi qui valent d'être écrits. Tout ce qui se recalcule
-- (capacité, vitesse, entretien, nom) est laissé de côté et refait au
-- chargement : deux sources pour une même valeur finissent toujours par diverger.
local CHAMPS_CONVOI = {
  "cle", "genre", "strategie", "nom", "nation", "attache", "mode", "joueur",
  "or_", "etape", "quete", "x", "z", "cap", "escale",
  "rotations", "rotation_jours", "rotation_gain", "rotation_age", "rotation_or",
  "ville", "destination",
}

local function copier_table(t)
  if type(t) ~= "table" then return nil end
  local out = {}
  for k, v in pairs(t) do
    out[k] = (type(v) == "table") and copier_table(v) or v
  end
  return out
end


-- --- convois ------------------------------------------------------------------

local function convoi_vers_table(m)
  local d = {}
  for _, champ in ipairs(CHAMPS_CONVOI) do d[champ] = m[champ] end
  -- Les navires : leur CLÉ de type, jamais la fiche.
  local types = {}
  for _, n in ipairs(m.navires or {}) do types[#types + 1] = n.cle end
  d.navires = types
  d.cale = copier_table(m.cale) or {}
  d.achats = copier_table(m.achats) or {}
  d.circuit = copier_table(m.circuit) or {}
  -- La route suivie est une liste de points {x, z} : on la garde pour que le
  -- convoi reprenne sa traversée là où il en était, et non depuis son port.
  local route = {}
  for _, p in ipairs(m.route or {}) do route[#route + 1] = { p[1], p[2] } end
  d.route = route
  d.navires_joueur = copier_table(m.navires_joueur)
  return d
end

local function convoi_depuis_table(d)
  local types = {}
  for _, cle in ipairs(d.navires or {}) do
    local n = Navires.get(cle)
    if n then types[#types + 1] = n end
  end
  if #types == 0 then return nil end          -- un convoi sans navire n'existe pas
  local port = Archipel.portsParCle[d.attache]
  if not port then return nil end
  local m = Marchands.armer_joueur(d.attache, types, d.circuit, d.strategie, d.or_ or 0)
  if not m then return nil end
  for _, champ in ipairs(CHAMPS_CONVOI) do
    if d[champ] ~= nil then m[champ] = d[champ] end
  end
  m.navires = types
  m.cale = copier_table(d.cale) or {}
  m.achats = copier_table(d.achats) or {}
  m.circuit = copier_table(d.circuit) or {}
  local route = {}
  for _, p in ipairs(d.route or {}) do route[#route + 1] = { p[1], p[2] } end
  m.route = route
  m.navires_joueur = copier_table(d.navires_joueur)
  return m
end


-- --- capture ------------------------------------------------------------------

function Sauvegarde.etat()
  local d = { version = Sauvegarde.VERSION }

  d.calendrier = {
    annee = Calendrier.annee, mois = Calendrier.mois, jour = Calendrier.jour,
    heure = Calendrier.heure, indiceVitesse = Calendrier.indiceVitesse,
    derniereVitesse = Calendrier.derniereVitesse,
    joursEcoules = Calendrier.joursEcoules,
  }

  local convois = {}
  for _, m in ipairs(Compagnie.convois) do convois[#convois + 1] = convoi_vers_table(m) end
  local flotte = {}
  for _, n in ipairs(Compagnie.flotte) do
    flotte[#flotte + 1] = { cle = n.cle, nom = n.nom, attache = n.attache }
  end
  d.compagnie = {
    or_ = Compagnie.or_, rang = Compagnie.rang,
    compteur_navires = Compagnie.compteur_navires,
    selection = Compagnie.selection,
    reputation = copier_table(Compagnie.reputation) or {},
    file_chantier = copier_table(Compagnie.file_chantier) or {},
    flotte = flotte, convois = convois,
  }

  -- L'économie : un enregistrement par ville, et seulement ce qui bouge. La
  -- production et les ateliers se recalculent depuis la donnée du port.
  local villes = {}
  for cle, v in pairs(Economie.villes) do
    villes[cle] = {
      habitants = v.habitants, stock = copier_table(v.stock) or {},
      faim = v.faim, penurie = v.penurie, knapp = v.knapp,
      knapp_serie = v.knapp_serie, qualite = v.qualite, niveau = v.niveau,
      tendance = v.tendance, maisons = v.maisons, capacite = v.capacite,
      fleau = copier_table(v.fleau), rendement = copier_table(v.rendement),
    }
  end
  d.economie = { villes = villes, avancement = Economie.avancement() }

  local ia = {}
  for _, m in ipairs(Marchands.liste) do ia[#ia + 1] = convoi_vers_table(m) end
  d.marchands = { liste = ia, fonds = Marchands.fonds }

  d.exploration = {
    villes = copier_table(Exploration.villes) or {},
    version = Exploration.version,
  }
  return d
end


-- --- restitution ---------------------------------------------------------------

-- Rend `true` si la partie a été reprise, ou `false, message` — jamais une partie
-- à moitié chargée : on refuse avant de toucher à quoi que ce soit.
function Sauvegarde.restaurer(d)
  if type(d) ~= "table" then return false, "Sauvegarde illisible." end
  if tonumber(d.version) ~= Sauvegarde.VERSION then
    return false, string.format(
      "Sauvegarde de version %s, le jeu attend la version %d.",
      tostring(d.version), Sauvegarde.VERSION)
  end
  if type(d.compagnie) ~= "table" or type(d.economie) ~= "table" then
    return false, "Sauvegarde incomplète."
  end

  -- On repart d'une partie neuve : tout ce que la sauvegarde ne dit pas reprend
  -- sa valeur de départ, au lieu de garder celle de la partie précédente.
  Economie.reinitialiser()
  Compagnie.reinitialiser()
  Marchands.reinitialiser()

  local c = d.calendrier or {}
  Calendrier.annee = c.annee or 1600
  Calendrier.mois = c.mois or 1
  Calendrier.jour = c.jour or 1
  Calendrier.heure = c.heure or 6
  Calendrier.indiceVitesse = c.indiceVitesse or 2
  Calendrier.derniereVitesse = c.derniereVitesse or 2
  Calendrier.survol = false            -- on ne reprend jamais en survol
  Calendrier.joursEcoules = c.joursEcoules or 0

  for cle, v in pairs((d.economie.villes or {})) do
    local ville = Economie.villes[cle]
    if ville then
      ville.habitants = v.habitants or ville.habitants
      ville.stock = copier_table(v.stock) or {}
      ville.faim = v.faim or ville.faim
      ville.penurie = v.penurie or ville.penurie
      ville.knapp = v.knapp and true or false
      ville.knapp_serie = v.knapp_serie or 0
      ville.qualite = v.qualite or ville.qualite
      ville.niveau = v.niveau or ville.niveau
      ville.tendance = v.tendance or 0
      ville.maisons = v.maisons or ville.maisons
      ville.capacite = v.capacite or ville.capacite
      ville.fleau = copier_table(v.fleau)
      ville.rendement = copier_table(v.rendement)
    end
  end
  Economie.poser_avancement(d.economie.avancement)

  local cp = d.compagnie
  Compagnie.or_ = cp.or_ or 20000
  Compagnie.rang = cp.rang or 0
  Compagnie.compteur_navires = cp.compteur_navires or 0
  Compagnie.reputation = copier_table(cp.reputation) or {}
  Compagnie.file_chantier = copier_table(cp.file_chantier) or {}
  Compagnie.flotte = {}
  for _, n in ipairs(cp.flotte or {}) do
    local t = Navires.get(n.cle)
    if t then
      local copie = copier_table(t)
      copie.nom = n.nom or copie.nom
      copie.attache = n.attache
      Compagnie.flotte[#Compagnie.flotte + 1] = copie
    end
  end
  Compagnie.convois = {}
  for _, dc in ipairs(cp.convois or {}) do
    local m = convoi_depuis_table(dc)
    if m then Compagnie.convois[#Compagnie.convois + 1] = m end
  end
  Compagnie.selection = math.min(cp.selection or 1, math.max(1, #Compagnie.convois))

  Marchands.liste = {}
  for _, dm in ipairs((d.marchands or {}).liste or {}) do
    local m = convoi_depuis_table(dm)
    if m then Marchands.liste[#Marchands.liste + 1] = m end
  end
  Marchands.fonds = (d.marchands or {}).fonds or 0

  Exploration.villes = copier_table((d.exploration or {}).villes) or {}
  Exploration.version = (d.exploration or {}).version or 0
  return true
end


return Sauvegarde
