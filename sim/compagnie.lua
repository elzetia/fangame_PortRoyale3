-- La compagnie du joueur : sa caisse et la cale de ses navires.
--
-- Départ de carrière conforme à Port Royale : 1er janvier 1600, vingt mille
-- pièces d'or et un sloop de cinquante tonneaux.
--
-- L'achat et la vente passent obligatoirement par ici, jamais directement par
-- `sim.economie` : c'est le seul endroit qui sache à la fois ce que la ville
-- demande, ce que la caisse contient et ce que la cale peut porter. Une
-- transaction ne doit jamais pouvoir réussir à moitié.

local Economie     = require("sim.economie")
local Marchandises = require("sim.marchandises")

local Compagnie = {}

function Compagnie.reinitialiser()
  Compagnie.or_ = 20000
  Compagnie.navire = {
    nom = "Aurore",
    classe = "Sloop",
    capacite = 50,          -- tonneaux
    cale = {},              -- cle -> tonnes
  }
end


-- Tonnage embarqué.
function Compagnie.charge()
  local t = 0
  for _, q in pairs(Compagnie.navire.cale) do t = t + q end
  return t
end


function Compagnie.place_libre()
  return Compagnie.navire.capacite - Compagnie.charge()
end


function Compagnie.quantite(cle_m)
  return Compagnie.navire.cale[cle_m] or 0
end


-- Combien le joueur PEUT acheter : le minimum de ce que la ville peut céder,
-- de ce que la caisse permet et de ce que la cale peut porter. C'est ce chiffre
-- que l'interface propose comme maximum, pour qu'un bouton « tout acheter » ne
-- puisse jamais échouer.
function Compagnie.achat_maximum(cle_ville, cle_m)
  if not Marchandises.get(cle_m) then return 0 end

  local place = math.floor(Compagnie.place_libre())
  if place <= 0 then return 0 end

  local prix = Economie.cotation(cle_ville, cle_m, 1, "achat") or 0
  if prix <= 0 then return 0 end

  local abordable = math.floor(Compagnie.or_ / prix)
  local cedable = math.floor(Compagnie.disponible(cle_ville, cle_m))
  return math.max(0, math.min(place, abordable, cedable))
end


-- Ce que la ville accepte de céder, avant toute contrainte du joueur.
function Compagnie.disponible(cle_ville, cle_m)
  local lignes = Economie.marche(cle_ville)
  if not lignes then return 0 end
  for _, l in ipairs(lignes) do
    if l.cle == cle_m then
      return math.max(0, l.stock - l.reference * 0.08)
    end
  end
  return 0
end


-- Achète. Renvoie quantite, cout, message.
function Compagnie.acheter(cle_ville, cle_m, quantite)
  quantite = math.floor(quantite or 0)
  if quantite <= 0 then return 0, 0, "Quantité nulle." end
  if quantite > Compagnie.place_libre() then
    quantite = math.floor(Compagnie.place_libre())
  end
  if quantite <= 0 then return 0, 0, "Cale pleine." end

  local prix = Economie.cotation(cle_ville, cle_m, quantite, "achat") or 0
  if prix * quantite > Compagnie.or_ then
    quantite = math.floor(Compagnie.or_ / math.max(prix, 0.01))
  end
  if quantite <= 0 then return 0, 0, "Or insuffisant." end

  -- On prend le coût que l'économie RENVOIE, sans jamais le recalculer.
  -- Le recalculer après coup interrogeait un entrepôt déjà vidé de la
  -- cargaison qu'on venait d'en sortir : le cours y était au plafond, la
  -- facture triplait, et la caisse passait en négatif sur un achat que la
  -- vérification d'avant l'échange avait pourtant jugé abordable.
  local servi, cout = Economie.acheter(cle_ville, cle_m, quantite)
  servi = math.floor(servi)
  if servi <= 0 then return 0, 0, "La ville n'a plus rien à céder." end

  Compagnie.or_ = Compagnie.or_ - cout
  local cale = Compagnie.navire.cale
  cale[cle_m] = (cale[cle_m] or 0) + servi
  return servi, cout, nil
end


-- Vend. Renvoie quantite, recette, message.
function Compagnie.vendre(cle_ville, cle_m, quantite)
  quantite = math.floor(quantite or 0)
  local en_cale = Compagnie.quantite(cle_m)
  if quantite > en_cale then quantite = math.floor(en_cale) end
  if quantite <= 0 then return 0, 0, "Rien de tel en cale." end

  local servi, recette = Economie.vendre(cle_ville, cle_m, quantite)
  Compagnie.or_ = Compagnie.or_ + recette
  local cale = Compagnie.navire.cale
  cale[cle_m] = en_cale - servi
  if cale[cle_m] <= 0.0001 then cale[cle_m] = nil end
  return servi, recette, nil
end


Compagnie.reinitialiser()

return Compagnie
