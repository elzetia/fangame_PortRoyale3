-- Calendrier de jeu. La partie démarre le 1er janvier 1600, comme un début
-- de carrière dans Port Royale.
--
-- C'est de la simulation : le moteur ne fait qu'afficher la date qu'on lui
-- donne et avancer l'horloge du temps réel écoulé.

local Calendrier = {}

local MOIS = { "janvier", "février", "mars", "avril", "mai", "juin",
               "juillet", "août", "septembre", "octobre", "novembre", "décembre" }

Calendrier.VITESSES       = { 0, 1, 2, 4 }
Calendrier.SECONDES_JOUR  = 12    -- secondes réelles pour une journée en x1

local function bissextile(a)
  return (a % 4 == 0 and a % 100 ~= 0) or a % 400 == 0
end

local function joursDuMois(annee, mois)
  local j = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
  if mois == 2 and bissextile(annee) then return 29 end
  return j[mois]
end

function Calendrier.reinitialiser()
  Calendrier.annee = 1600
  Calendrier.mois = 1
  Calendrier.jour = 1
  Calendrier.heure = 6
  Calendrier.indiceVitesse = 2      -- x1
  Calendrier.derniereVitesse = 2
  Calendrier.joursEcoules = 0
end

function Calendrier.vitesse()
  return Calendrier.VITESSES[Calendrier.indiceVitesse]
end

function Calendrier.enPause()
  return Calendrier.vitesse() == 0
end

function Calendrier.definirVitesse(i)
  if i < 1 then i = 1 elseif i > #Calendrier.VITESSES then i = #Calendrier.VITESSES end
  Calendrier.indiceVitesse = i
end

function Calendrier.basculerPause()
  if Calendrier.enPause() then
    Calendrier.indiceVitesse = Calendrier.derniereVitesse or 2
  else
    Calendrier.derniereVitesse = Calendrier.indiceVitesse
    Calendrier.indiceVitesse = 1
  end
end

-- Avance l'horloge et renvoie les heures de jeu écoulées.
function Calendrier.avancer(dt)
  local heures = dt / Calendrier.SECONDES_JOUR * 24 * Calendrier.vitesse()
  if heures <= 0 then return 0 end
  Calendrier.heure = Calendrier.heure + heures
  while Calendrier.heure >= 24 do
    Calendrier.heure = Calendrier.heure - 24
    Calendrier.jour = Calendrier.jour + 1
    Calendrier.joursEcoules = Calendrier.joursEcoules + 1
    if Calendrier.jour > joursDuMois(Calendrier.annee, Calendrier.mois) then
      Calendrier.jour = 1
      Calendrier.mois = Calendrier.mois + 1
      if Calendrier.mois > 12 then
        Calendrier.mois = 1
        Calendrier.annee = Calendrier.annee + 1
      end
    end
  end
  return heures
end

function Calendrier.dateTexte()
  local j = (Calendrier.jour == 1) and "1er" or tostring(Calendrier.jour)
  return string.format("%s %s %d", j, MOIS[Calendrier.mois], Calendrier.annee)
end

function Calendrier.heureTexte()
  return string.format("%02dh00", math.floor(Calendrier.heure))
end

-- « 2 jours 6 h », pour les estimations d'arrivée
function Calendrier.dureeTexte(heures)
  if heures < 1 then return "moins d'une heure" end
  local j = math.floor(heures / 24)
  local h = math.floor(heures % 24)
  if j == 0 then return string.format("%d h", h) end
  if h == 0 then return string.format("%d jour%s", j, j > 1 and "s" or "") end
  return string.format("%d jour%s %d h", j, j > 1 and "s" or "", h)
end

Calendrier.reinitialiser()

return Calendrier
