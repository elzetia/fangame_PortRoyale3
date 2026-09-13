-- Adaptateur Godot : le seul fichier de sim/ qui connaisse le moteur.
-- Il traduit les tables Lua de la simulation en types natifs Godot
-- (Array, Dictionary, Vector2/3) pour que GDScript les manipule sans friction.
-- Tout le reste de sim/ reste du Lua portable.

local Archipel     = require("sim.archipel")
local Navigation   = require("sim.navigation")
local Calendrier   = require("sim.calendrier")
local Marchandises = require("sim.marchandises")
local Economie     = require("sim.economie")
local Compagnie    = require("sim.compagnie")
local Marchands    = require("sim.marchands")
local Navires      = require("sim.navires")
local Chantier     = require("sim.chantier")

local Bridge = {}

-- Échelle de la simulation : la carte n'est pas à l'échelle géographique.
-- 3 000 m de décor représentent environ 640 milles nautiques, comme dans
-- l'archipel de la version 2D. C'est ce qui donne des traversées en jours.
Bridge.NM_PAR_METRE = 0.213

local function couleur(c)
  return Color(c[1], c[2], c[3])
end

function Bridge.iles(segments)
  segments = segments or 160
  local sortie = Array()
  for _, ile in ipairs(Archipel.iles) do
    local d = Dictionary()
    d.cle    = ile.cle
    d.nom    = ile.nom
    d.centre = Vector3(ile.x, 0, ile.z)
    d.rayon  = ile.rayon
    d.sommet = ile.sommet

    -- Le contour exact, échantillonné : c'est lui qui devient le maillage.
    local contour = PackedVector2Array()
    for _, p in ipairs(Archipel.contour(ile, segments)) do
      contour:append(Vector2(p.x, p.z))
    end
    d.contour = contour

    sortie:append(d)
  end
  return sortie
end

-- Paramètres bruts des îles, pour la cuisson de la carte : le shader de
-- cuisson recalcule lui-même le relief à partir de ces harmoniques, au lieu
-- de travailler sur un maillage. C'est ce qui permet du pixel-parfait.
function Bridge.iles_parametres()
  local sortie = Array()
  for _, ile in ipairs(Archipel.iles) do
    local d = Dictionary()
    d.centre     = Vector2(ile.x, ile.z)
    d.rayon      = ile.rayon
    d.sommet     = ile.sommet
    d.ecrasement = Vector2(ile.ecrasement[1], ile.ecrasement[2])
    local h = Array()
    for _, harm in ipairs(ile.harmoniques) do
      h:append(Vector3(harm[1], harm[2], harm[3]))   -- freq, amplitude, phase
    end
    d.harmoniques = h
    sortie:append(d)
  end
  return sortie
end


function Bridge.ports()
  local sortie = Array()
  for _, port in ipairs(Archipel.ports) do
    local nation = Archipel.nations[port.nation]
    local bx, bz, rx, rz = Archipel.positionPort(port)
    local d = Dictionary()
    d.cle          = port.cle
    d.nom          = port.nom
    d.nation       = nation.nom
    d.nation_cle   = nation.cle
    d.nation_adj   = nation.adj
    d.couleur      = couleur(nation.couleur)
    d.couleur_bord = couleur(nation.bord)
    d.habitants    = port.habitants
    -- La classe de taille de Port Royale 3 : 1 bourg, 2 ville, 3 grande ville.
    -- Le rendu s'en sert pour hierarchiser les etiquettes, qui a soixante ports
    -- se recouvriraient toutes.
    d.taille       = port.taille or 1
    -- A-t-elle un chantier naval, et de quel niveau ? Le radial n'affiche le
    -- pétale chantier que si oui ; le niveau borne les navires constructibles.
    d.chantier     = port.chantier == true
    d.niveau_chantier = port.niveau_chantier or 0
    -- Les CINQ marchandises que la ville produit, dans l'ordre de PR3. Le
    -- panneau d'infos les aligne telles quelles : c'est la carte d'identité
    -- économique du port, et elle ne change jamais en cours de partie.
    local prod = Array()
    for _, cle in ipairs(port.produits or {}) do prod:append(cle) end
    d.produits     = prod
    local dec = port.decalage or { 0, 0 }
    d.decalage     = Vector2(dec[1], dec[2])
    d.bourg        = Vector3(bx, 0, bz)
    d.rade         = Vector3(rx, 0, rz)
    sortie:append(d)
  end
  return sortie
end

function Bridge.limites()
  return Vector2(Archipel.limites.x, Archipel.limites.z)
end

-- Test de terre, utile au moteur pour placer des choses.
function Bridge.est_terre(x, z, marge)
  return Archipel.estTerre(x, z, marge or 0)
end

-- Construit la grille de navigation. À appeler une fois au démarrage.
function Bridge.preparer_navigation()
  return Navigation.construire()
end

-- Route maritime entre deux points, en points de passage successifs.
-- Renvoie un PackedVector3Array vide si aucune route n'existe.
function Bridge.route(depart, arrivee)
  local points = Navigation.route(depart.x, depart.z, arrivee.x, arrivee.z)
  local sortie = PackedVector3Array()
  if not points then return sortie end
  for _, p in ipairs(points) do
    sortie:append(Vector3(p[1], 0, p[2]))
  end
  return sortie
end


-- --- calendrier --------------------------------------------------------------

-- Avance l'horloge de `dt` secondes réelles, renvoie les heures de jeu écoulées.
--
-- C'est ici, et nulle part ailleurs, que l'économie avance : le temps qui passe
-- et les entrepôts qui se remplissent sont le même événement. Les brancher
-- séparément côté moteur laisserait tôt ou tard l'un tourner sans l'autre.
function Bridge.avancer_temps(dt)
  local heures = Calendrier.avancer(dt)
  if heures > 0 then
    local jours = Economie.avancer(heures)
    Compagnie.payer_entretien(jours)
    -- Les marchands avancent en TEMPS CONTINU, pas par journées entières.
    --
    -- Je les faisais naviguer au rythme de l'économie, qui ne tourne qu'aux
    -- changements de date : ils franchissaient neuf cents mètres d'un bond une
    -- fois par jour, au lieu de glisser sur l'eau. On ne les voyait donc jamais
    -- faire la traversée — seulement disparaître d'un port et réapparaître à
    -- l'autre. Les entrepôts, eux, ont raison de ne bouger qu'une fois par jour.
    Marchands.avancer(heures / 24.0)
    -- Les convois automatiques du joueur avancent au même rythme que ceux de l'IA.
    Compagnie.avancer_convois(heures / 24.0)
    -- Les navires en construction au chantier avancent par journées.
    Compagnie.avancer_chantier(jours)
  end
  return heures
end

function Bridge.etat_temps()
  local d = Dictionary()
  d.date       = Calendrier.dateTexte()
  d.heure      = Calendrier.heureTexte()
  d.heure_num  = Calendrier.heure or 0
  d.vitesse    = Calendrier.vitesse()
  d.indice     = Calendrier.indiceVitesse
  d.en_pause   = Calendrier.enPause()
  d.survol     = Calendrier.survol and true or false
  return d
end

function Bridge.definir_vitesse(i)
  Calendrier.definirVitesse(i)
end

function Bridge.basculer_pause()
  Calendrier.basculerPause()
end

function Bridge.definir_survol(actif)
  Calendrier.definirSurvol(actif)
end

-- Durée d'une traversée, en texte, à partir d'une distance en mètres monde.
function Bridge.duree_traversee(metres, noeuds)
  local nm = metres * Bridge.NM_PAR_METRE
  return Calendrier.dureeTexte(nm / noeuds)
end

-- Vitesse d'un navire, convertie en mètres monde par seconde de jeu à x1.
function Bridge.vitesse_monde(noeuds)
  local metres_par_heure = noeuds / Bridge.NM_PAR_METRE
  local heures_par_seconde = 24 / Calendrier.SECONDES_JOUR
  return metres_par_heure * heures_par_seconde
end


-- --- commerce ----------------------------------------------------------------

-- Le marché d'une ville, une ligne par marchandise, dans l'ordre du jeu
-- original. On y joint ce que le joueur en a déjà en cale : l'interface a
-- besoin des deux au même endroit, et un second appel les désynchroniserait
-- dès que le temps avance entre les deux.
function Bridge.marche(cle_ville, lot)
  local sortie = Array()
  local lignes = Economie.marche(cle_ville, lot)
  if not lignes then return sortie end
  for _, l in ipairs(lignes) do
    local d = Dictionary()
    d.cle          = l.cle
    d.nom          = l.nom
    d.categorie    = Marchandises.CATEGORIES[l.categorie] or l.categorie
    d.stock        = math.floor(l.stock + 0.5)
    d.reference    = math.floor(l.reference + 0.5)
    d.achat        = l.achat
    d.vente        = l.vente
    d.achat_lot    = l.achat_lot
    d.vente_lot    = l.vente_lot
    d.solde        = l.solde
    d.barres       = l.barres
    d.en_cale      = Compagnie.quantite(l.cle)
    d.achat_max    = Compagnie.achat_maximum(cle_ville, l.cle)
    sortie:append(d)
  end
  return sortie
end


-- Le cours À L'UNITÉ pour un lot de cette taille.
--
-- `Economie.cotation` déplace le stock de la MOITIÉ de la quantité : le chiffre
-- qu'elle rend est donc un cours moyen sur le lot, et `Economie.acheter` le
-- multiplie ensuite par la quantité. Le comptoir a besoin de deux tailles
-- voisines pour en tirer le coût de la tonne SUIVANTE, qui est le chiffre qu'un
-- négociant regarde en composant son lot.
function Bridge.cotation(cle_ville, cle_m, quantite, sens)
  return Economie.cotation(cle_ville, cle_m, quantite, sens) or 0
end


-- Les barres d'abondance d'une denrée, le stock décalé de `delta`. Sert à
-- montrer ce que l'échange en cours de composition laisserait à la ville.
function Bridge.barres(cle_ville, cle_m, delta)
  return Economie.barres(cle_ville, cle_m, delta or 0)
end


function Bridge.etat_compagnie()
  local d = Dictionary()
  d.or_       = math.floor(Compagnie.or_ + 0.5)
  d.navire    = Compagnie.navire.nom
  d.classe    = Compagnie.navire.classe
  d.modele    = Compagnie.navire.modele or ""
  d.capacite  = Compagnie.navire.capacite
  d.charge    = Compagnie.charge()
  d.libre     = Compagnie.place_libre()
  -- Ce que le navire porte, en clair, pour la fiche de la carte.
  d.cargaison = Marchands.cargaison(Compagnie.navire)
  -- La réputation moyenne du joueur auprès de chaque nation, de 0 à 100 : la
  -- moyenne de ses villes, dont le commerce fait bouger le détail.
  local rep = Dictionary()
  for cle in pairs(Archipel.nations or {}) do
    rep[cle] = math.floor(Compagnie.reputation_nation(cle) + 0.5)
  end
  d.reputation = rep
  return d
end


-- Achat et vente renvoient toujours le même dictionnaire : ce qui a été
-- échangé, à quel prix, et le message d'échec s'il y en a un.
local function resultat(quantite, somme, message)
  local d = Dictionary()
  d.quantite = quantite
  d.somme    = math.floor(somme + 0.5)
  d.message  = message or ""
  d.ok       = quantite > 0
  return d
end


function Bridge.acheter(cle_ville, cle_m, quantite)
  return resultat(Compagnie.acheter(cle_ville, cle_m, quantite))
end


function Bridge.vendre(cle_ville, cle_m, quantite)
  return resultat(Compagnie.vendre(cle_ville, cle_m, quantite))
end


-- Ce que les marchands voient depuis chaque port : diagnostic de leur
-- fonction de décision.
-- Ce dont chaque ville manque le plus, pour l'etiquette de la carte.
--
-- On renvoie TOUT d'un coup plutot qu'une ville a la fois : le rendu en a
-- besoin pour les soixante ports a chaque image, et soixante allers-retours
-- par trame a travers le pont couteraient plus que le calcul lui-meme.
function Bridge.besoins_villes()
  local sortie = Dictionary()
  for _, port in ipairs(Archipel.ports) do
    sortie[port.cle] = Marchands.besoin_prioritaire(port.cle) or ""
  end
  return sortie
end


function Bridge.diag_marchands()
  local sortie = Array()
  for _, d in ipairs(Marchands.diagnostic()) do
    local e = Dictionary()
    e.ville     = d.ville
    e.trouve    = d.trouve
    e.cle       = d.cle
    e.vers      = d.vers
    e.lot       = d.lot
    e.total     = d.total
    e.par_tonne = d.par_tonne
    sortie:append(e)
  end
  return sortie
end


-- Les cinq marchands des nations, pour les dessiner sur la carte.
function Bridge.marchands()
  local sortie = Array()
  for _, m in ipairs(Marchands.liste) do
    local nation = Archipel.nations[m.nation]
    local d = Dictionary()
    d.cle         = m.cle
    d.nom         = m.nom
    d.nation      = nation and nation.nom or m.nation
    d.nation_cle  = m.nation
    d.couleur     = couleur(nation and nation.couleur or { 1, 1, 1 })
    d.position    = Vector2(m.x, m.z)
    d.cap         = m.cap
    d.a_quai      = m.ville ~= nil
    d.ville       = m.ville or ""
    d.destination = m.destination or ""
    d.cargaison   = Marchands.cargaison(m)
    d.or_         = math.floor(m.or_ + 0.5)
    -- Le navire qu'on dessine : le plus gros du convoi, celui que PR3 montre
    -- (« seul le plus gros navire d'un convoi est affiché »).
    local tete = m.navires and m.navires[1]
    d.modele      = tete and tete.modele or ""
    sortie:append(d)
  end
  return sortie
end


-- État d'approvisionnement d'une ville, pour l'infobulle : le chiffre qui dit
-- si elle grandit ou si elle meurt de faim.
function Bridge.etat_ville(cle_ville)
  local v = Economie.ville(cle_ville)
  local d = Dictionary()
  if not v then return d end
  d.habitants   = math.floor(v.habitants + 0.5)
  d.subsistance = v.subsistance or 1.0

  -- La tendance, pas la vitesse : le panneau ne montre qu'une flèche. Elle vient
  -- du signe de la croissance calculée par `jour()`, gradué par la prospérité, et
  -- non plus d'un raccourci sur la faim — flèche et démographie s'accordent.
  d.faim = v.faim or -3
  d.niveau = v.niveau or 5
  d.tendance = v.tendance or 0
  d.fleau = v.fleau and v.fleau.type or ""
  d.reputation = math.floor(Compagnie.reputation_ville(cle_ville) + 0.5)

  local dem = Economie.demographie(cle_ville)
  d.ouvriers   = dem.ouvriers
  d.fabriques  = dem.fabriques
  d.maisons    = dem.maisons
  d.occupation = dem.occupation
  return d
end


-- --- édition des positions ---------------------------------------------------
-- Une ville n'est pas un point libre : c'est un angle sur le pourtour d'une île.
-- Déplacer un port revient donc à chercher le point de côte le plus proche,
-- toutes îles confondues. Le mouillage suit tout seul, et l'invariant « un port
-- est côtier » ne peut pas être cassé à la souris.
-- Déplace le MOUILLAGE d'un port, en le calant sur une case de mer bordant la
-- terre — la définition d'un mouillage chez Port Royale 3.
--
-- L'ancienne version cherchait l'île la plus proche dans `Archipel.iles`, qui
-- décrivait sept îles par des harmoniques. Cette table est vide depuis que la
-- terre est un masque : déplacer une ville ne faisait donc plus rien, et sans
-- le moindre message. Un éditeur qui ne dit pas qu'il a échoué est pire
-- qu'un éditeur absent.
function Bridge.deplacer_port(cle, x, z)
  local port = Archipel.portsParCle[cle]
  if not port then return false end
  local cx, cz = Archipel.mouillageProche(x, z, 60)
  if not cx then return false end
  port.case = { cx, cz }
  port.caseBourg = { Archipel.bourgPres(cx, cz) }
  return true
end


-- Décale l'image d'un port, en mètres monde. Le point réel ne bouge pas.
function Bridge.decaler_port(cle, dx, dz)
  for _, p in ipairs(Archipel.ports) do
    if p.cle == cle then
      p.decalage = { dx, dz }
      return true
    end
  end
  return false
end


-- Les mouillages tels que Port Royale 3 les donne : c'est la reference qui dit
-- si une ville a ete deplacee ou non.
local Origines = {}
for _, p in ipairs(Archipel.ports) do
  Origines[p.cle] = { p.case[1], p.case[2] }
end

-- Les retouches de placement, en Lua, prêtes à devenir `sim/villes_reglages.lua`.
--
-- On n'écrit QUE ce qui diffère des données extraites de Port Royale 3, et dans
-- un fichier à part : `villes_pr3.lua` se régénère d'un bloc, et y écrire
-- reviendrait à perdre son travail à la prochaine extraction.
function Bridge.source_reglages()
  local lignes = {
    "-- Les retouches de placement faites à la main, dans l'éditeur de villes (F2).",
    "--",
    "-- Ce fichier est SÉPARÉ de `sim/villes_pr3.lua` exprès. Celui-là est extrait des",
    "-- archives de Port Royale 3 et se régénère d'un coup ; écrire dedans, c'est",
    "-- perdre son travail à la prochaine extraction. Ici, rien n'est généré : on ne",
    "-- garde que les villes dont on a bougé quelque chose, et l'archipel applique ces",
    "-- retouches par-dessus les données du jeu.",
    "--",
    "--   case      le mouillage, en cases du masque — le point RÉEL du port, celui",
    "--             où le navire s'arrête et où le clic tombe.",
    "--   decalage  ne bouge QUE l'image du village, en unités de monde.",
    "--",
    "-- Réécrit intégralement par l'éditeur : ce qui n'est pas dans la table a repris",
    "-- sa place d'origine.",
    "",
    "return {",
  }
  for _, p in ipairs(Archipel.ports) do
    local dec = p.decalage or { 0, 0 }
    local origine = Origines[p.cle]
    local bouge = (dec[1] ~= 0 or dec[2] ~= 0)
      or (origine and (p.case[1] ~= origine[1] or p.case[2] ~= origine[2]))
    if bouge then
      lignes[#lignes + 1] = string.format(
        '  %s = { case = { %d, %d }, decalage = { %.1f, %.1f } },',
        p.cle, p.case[1], p.case[2], dec[1], dec[2])
    end
  end
  lignes[#lignes + 1] = "}"
  -- string.char(10) plutot qu'un echappement : la chaine traverse plusieurs
  -- outils avant d'arriver ici, et l'echappement s'y perd.
  return table.concat(lignes, string.char(10)) .. string.char(10)
end

-- --- routes commerciales automatiques du joueur -----------------------------

-- Les stratégies proposables au joueur (voir `sim/strategies.lua`).
function Bridge.strategies()
  local a = Array()
  for _, s in ipairs({ "profit", "resources", "construct", "storage",
                       "office", "distribute", "central", "wealth" }) do
    a:append(s)
  end
  return a
end

-- Les types de navires marchands armables, avec prix, cale et entretien.
function Bridge.navires_marchands()
  local a = Array()
  for _, n in ipairs(Navires.marchands) do
    local d = Dictionary()
    d.cle = n.cle
    d.nom = n.nom
    d.cale = n.cale
    d.prix = n.prix
    d.entretien = n.entretien
    a:append(d)
  end
  return a
end

-- Les routes du joueur, pour l'écran de gestion.
function Bridge.routes()
  local sortie = Array()
  for i, m in ipairs(Compagnie.convois) do
    local charge = 0
    for _, q in pairs(m.cale) do charge = charge + q end
    local circ = Array()
    for _, c in ipairs(m.circuit or {}) do
      local p = Archipel.portsParCle[c]
      circ:append(p and p.nom or c)
    end
    local d = Dictionary()
    d.indice      = i
    d.nom         = m.nom
    d.mode        = m.mode or "route"
    d.strategie   = m.strategie
    d.or_         = math.floor(m.or_ + 0.5)
    d.capacite    = m.capacite
    d.charge      = math.floor(charge + 0.5)
    d.navires     = #(m.navires or {})
    -- Les navires du convoi, un par un, pour pouvoir en retirer.
    local noms = Array()
    for _, s in ipairs(m.navires_joueur or {}) do noms:append(s.nom) end
    d.navires_noms = noms
    d.a_quai      = m.ville ~= nil
    d.ville       = m.ville or ""
    d.destination = m.destination or ""
    d.circuit     = circ
    d.cargaison   = Marchands.cargaison(m)
    sortie:append(d)
  end
  return sortie
end

-- Convertit une liste venue de Godot (Array, transmise en userdata, indexée à
-- partir de 0) OU une table Lua (indexée à partir de 1) en table Lua simple.
local function en_table(liste)
  local t = {}
  if not liste then return t end
  local base = (liste[0] ~= nil) and 0 or 1
  local i = base
  while liste[i] ~= nil do
    t[#t + 1] = liste[i]
    i = i + 1
  end
  return t
end

-- Arme une route : `navires` est une liste d'INDICES dans la flotte du joueur (voir
-- `Bridge.flotte`), `circuit` une liste de clés de villes. Renvoie { ok, message }.
function Bridge.armer_route(navires, circuit, strategie, capital)
  local indices = {}
  for _, v in ipairs(en_table(navires)) do indices[#indices + 1] = math.floor(v + 0.5) end
  local m, err = Compagnie.armer_route(indices, en_table(circuit), strategie, capital)
  local d = Dictionary()
  d.ok = m ~= nil
  d.message = err or ""
  return d
end

-- Dissout la route d'indice donné, rend l'or récupéré.
function Bridge.dissoudre_route(indice)
  return math.floor(Compagnie.dissoudre_route(indice) + 0.5)
end

-- Le joueur a-t-il un convoi à quai dans cette ville ? (dock/chantier du radial)
function Bridge.convoi_au_port(cle_ville)
  return Compagnie.convoi_au_port(cle_ville)
end

-- Ajoute des navires de la flotte (indices) au convoi d'indice donné. Renvoie
-- { ok, message }.
function Bridge.ajouter_navire_convoi(indice_convoi, navires)
  local indices = {}
  for _, v in ipairs(en_table(navires)) do indices[#indices + 1] = math.floor(v + 0.5) end
  local ok, err = Compagnie.ajouter_navire_convoi(indice_convoi, indices)
  local d = Dictionary()
  d.ok = ok
  d.message = err or ""
  return d
end

-- Retire le navire à la place donnée dans le convoi, le rend à la flotte. Renvoie
-- { ok, message }.
function Bridge.retirer_navire_convoi(indice_convoi, indice_navire)
  local ok, err = Compagnie.retirer_navire_convoi(indice_convoi, indice_navire)
  local d = Dictionary()
  d.ok = ok
  d.message = err or ""
  return d
end

-- Les convois du joueur avec leur POSITION, pour la carte : elle les dessine,
-- les rend sélectionnables et leur donne des ordres.
function Bridge.convois_joueur()
  local sortie = Array()
  for i, m in ipairs(Compagnie.convois) do
    local d = Dictionary()
    d.indice      = i
    d.nom         = m.nom
    d.mode        = m.mode or "route"
    d.position    = Vector2(m.x, m.z)
    d.cap         = m.cap or 0
    d.a_quai      = m.ville ~= nil
    d.ville       = m.ville or ""
    d.destination = m.destination or ""
    d.navires     = #(m.navires or {})
    d.cargaison   = Marchands.cargaison(m)
    local tete = m.navires and m.navires[1]
    d.modele      = tete and tete.modele or ""
    sortie:append(d)
  end
  return sortie
end

-- Fabrique un convoi manuel depuis des navires de la flotte (indices) à `cle_port`.
function Bridge.creer_convoi(navires, cle_port)
  local indices = {}
  for _, v in ipairs(en_table(navires)) do indices[#indices + 1] = math.floor(v + 0.5) end
  local m, err = Compagnie.creer_convoi(indices, cle_port)
  local d = Dictionary()
  d.ok = m ~= nil
  d.message = err or ""
  return d
end

-- Envoie le convoi manuel d'indice donné vers un port.
function Bridge.ordonner_convoi(indice, cle_port_dest)
  local ok, err = Compagnie.ordonner_convoi(indice, cle_port_dest)
  local d = Dictionary()
  d.ok = ok
  d.message = err or ""
  return d
end

-- La flotte possédée du joueur : les navires à quai, prêts à être affectés à une
-- route. L'indice sert à `armer_route`.
function Bridge.flotte()
  local a = Array()
  for i, s in ipairs(Compagnie.flotte) do
    local n = Navires.get(s.cle)
    local d = Dictionary()
    d.indice    = i
    d.cle       = s.cle
    d.nom       = s.nom
    d.type      = n and n.nom or s.cle
    d.cale      = n and n.cale or 0
    d.entretien = n and n.entretien or 0
    d.attache   = s.attache or ""
    a:append(d)
  end
  return a
end

-- Les navires en construction au chantier, avec le nombre de jours restants.
function Bridge.chantier_file()
  local a = Array()
  for _, b in ipairs(Compagnie.file_chantier) do
    local p = Archipel.portsParCle[b.ville]
    local d = Dictionary()
    d.nom   = b.nom
    d.ville = p and p.nom or (b.ville or "")
    d.jours = math.ceil(b.jours)
    a:append(d)
  end
  return a
end

-- Ce que coûte un type de navire : prix d'achat, coût de construction, délai et
-- matières. Pour peupler la fiche du chantier.
function Bridge.chantier_infos(cle_type)
  local recette = Chantier.recette(cle_type)
  local d = Dictionary()
  if not recette then return d end
  d.prix_achat  = Chantier.prix_achat(cle_type)
  d.cout_construction = recette.or_
  d.jours       = recette.jours
  d.niveau_requis = Chantier.niveau_requis(cle_type)
  local mats = Array()
  for _, mat in ipairs(recette.materiaux) do
    local m = Marchandises.get(mat.cle)
    local e = Dictionary()
    e.cle = mat.cle
    e.nom = m and m.nom or mat.cle
    e.quantite = mat.quantite
    mats:append(e)
  end
  d.materiaux = mats
  return d
end

-- Achète un navire tout fait, à quai dans `cle_ville`. Renvoie { ok, message }.
function Bridge.acheter_navire(cle_ville, cle_type)
  local ok, err = Compagnie.acheter_navire(cle_ville, cle_type)
  local d = Dictionary()
  d.ok = ok
  d.message = err or ""
  return d
end

-- Lance la construction d'un navire à `cle_ville`. Renvoie { ok, message }.
function Bridge.construire_navire(cle_ville, cle_type)
  local ok, err = Compagnie.construire_navire(cle_ville, cle_type)
  local d = Dictionary()
  d.ok = ok
  d.message = err or ""
  return d
end


return Bridge
