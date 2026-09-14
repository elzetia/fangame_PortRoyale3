-- JSON pour la simulation : encoder et relire, en Lua pur.
--
-- POURQUOI CE MODULE EXISTE. La sauvegarde doit traverser la frontière entre la
-- simulation (Lua) et le moteur (Godot). Le pont ne sait transporter que ce qu'il
-- construit à la main — `Dictionary` et `Array`, un champ à la fois — et rien
-- n'assure qu'une table profonde s'y convertisse toute seule dans les DEUX sens.
-- Plutôt que de parier là-dessus, on ne fait traverser qu'une CHAÎNE : un type
-- qui passe sans ambiguïté.
--
-- Et ça sert le but du projet : une sauvegarde en JSON est un fichier lisible,
-- qu'on ouvre et qu'on modifie à la main. Un Port Royale éditable commence par
-- des données qu'on peut voir.
--
-- CE QU'IL COUVRE, et rien de plus : les valeurs que produit `sim/sauvegarde.lua`
-- — nil, booléens, nombres, chaînes, tables (liste ou dictionnaire). Pas de
-- fonctions, pas d'`inf`/`nan`, pas de références cycliques. Une table vide est
-- écrite `{}` : on ne peut pas deviner si elle serait devenue liste ou
-- dictionnaire, et `{}` se relit correctement dans les deux cas.
--
-- Lua pur : ce fichier ne connaît pas Godot.

local Json = {}

-- --- écriture -----------------------------------------------------------------

local ECHAPPE = {
  ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f',
  ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t',
}

local function chaine(s)
  local out = s:gsub('[%c"\\]', function(c)
    return ECHAPPE[c] or string.format('\\u%04x', c:byte())
  end)
  return '"' .. out .. '"'
end

local function nombre(n)
  if n ~= n or n == math.huge or n == -math.huge then
    -- Un nombre non fini n'a pas de représentation JSON. On écrit 0 plutôt que
    -- de produire un fichier que personne ne saura relire.
    return "0"
  end
  if n == math.floor(n) and math.abs(n) < 1e15 then
    return string.format("%d", n)
  end
  return string.format("%.10g", n)
end

-- Une table est une LISTE si ses clés sont exactement 1..n. Sinon c'est un
-- dictionnaire. Le test compte les clés : une table à trous (1, 2, 4) est donc
-- écrite en dictionnaire, ce qui la préserve au lieu de la tronquer.
local function est_liste(t)
  local n = 0
  for k in pairs(t) do
    if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then return false end
    n = n + 1
  end
  for i = 1, n do
    if t[i] == nil then return false end
  end
  return true, n
end

local ecrire

local function ecrire_liste(t, n, morceaux)
  morceaux[#morceaux + 1] = "["
  for i = 1, n do
    if i > 1 then morceaux[#morceaux + 1] = "," end
    ecrire(t[i], morceaux)
  end
  morceaux[#morceaux + 1] = "]"
end

local function ecrire_dico(t, morceaux)
  -- Clés triées : deux sauvegardes du même état donnent le même fichier, ce qui
  -- rend les différences lisibles et les tests reproductibles.
  local cles = {}
  for k in pairs(t) do
    if type(k) == "string" or type(k) == "number" then cles[#cles + 1] = tostring(k) end
  end
  table.sort(cles)
  morceaux[#morceaux + 1] = "{"
  for i, k in ipairs(cles) do
    if i > 1 then morceaux[#morceaux + 1] = "," end
    morceaux[#morceaux + 1] = chaine(k)
    morceaux[#morceaux + 1] = ":"
    ecrire(t[k] ~= nil and t[k] or t[tonumber(k)], morceaux)
  end
  morceaux[#morceaux + 1] = "}"
end

ecrire = function(v, morceaux)
  local tv = type(v)
  if v == nil then
    morceaux[#morceaux + 1] = "null"
  elseif tv == "boolean" then
    morceaux[#morceaux + 1] = v and "true" or "false"
  elseif tv == "number" then
    morceaux[#morceaux + 1] = nombre(v)
  elseif tv == "string" then
    morceaux[#morceaux + 1] = chaine(v)
  elseif tv == "table" then
    local liste, n = est_liste(v)
    if liste and n > 0 then ecrire_liste(v, n, morceaux) else ecrire_dico(v, morceaux) end
  else
    morceaux[#morceaux + 1] = "null"
  end
end

function Json.encoder(valeur)
  local morceaux = {}
  ecrire(valeur, morceaux)
  return table.concat(morceaux)
end


-- --- lecture ------------------------------------------------------------------

local function erreur(txt, i, quoi)
  error(string.format("JSON : %s à la position %d", quoi, i), 0)
end

local function sauter(txt, i)
  local _, fin = txt:find("^[ \t\r\n]*", i)
  return (fin or i - 1) + 1
end

local DESECHAPPE = {
  ['"'] = '"', ['\\'] = '\\', ['/'] = '/', b = '\b', f = '\f',
  n = '\n', r = '\r', t = '\t',
}

local lire

local function lire_chaine(txt, i)
  i = i + 1                                   -- le guillemet ouvrant
  local out = {}
  while true do
    local c = txt:sub(i, i)
    if c == "" then erreur(txt, i, "chaîne non terminée") end
    if c == '"' then return table.concat(out), i + 1 end
    if c == "\\" then
      local e = txt:sub(i + 1, i + 1)
      if e == "u" then
        local hex = txt:sub(i + 2, i + 5)
        local n = tonumber(hex, 16) or 63
        -- On ne gère que le plan latin ; au-delà, un point d'interrogation vaut
        -- mieux qu'un octet invalide au milieu du fichier.
        out[#out + 1] = (n < 128) and string.char(n) or "?"
        i = i + 6
      else
        out[#out + 1] = DESECHAPPE[e] or e
        i = i + 2
      end
    else
      out[#out + 1] = c
      i = i + 1
    end
  end
end

local function lire_nombre(txt, i)
  local s, e = txt:find("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
  if not s then erreur(txt, i, "nombre attendu") end
  local n = tonumber(txt:sub(s, e))
  if not n then erreur(txt, i, "nombre illisible") end
  return n, e + 1
end

lire = function(txt, i)
  i = sauter(txt, i)
  local c = txt:sub(i, i)
  if c == "" then erreur(txt, i, "fin de texte inattendue") end
  if c == "{" then
    local t = {}
    i = sauter(txt, i + 1)
    if txt:sub(i, i) == "}" then return t, i + 1 end
    while true do
      i = sauter(txt, i)
      if txt:sub(i, i) ~= '"' then erreur(txt, i, "clé attendue") end
      local k; k, i = lire_chaine(txt, i)
      i = sauter(txt, i)
      if txt:sub(i, i) ~= ":" then erreur(txt, i, "« : » attendu") end
      local v; v, i = lire(txt, i + 1)
      t[k] = v
      i = sauter(txt, i)
      local d = txt:sub(i, i)
      if d == "}" then return t, i + 1 end
      if d ~= "," then erreur(txt, i, "« , » ou « } » attendu") end
      i = i + 1
    end
  elseif c == "[" then
    local t = {}
    i = sauter(txt, i + 1)
    if txt:sub(i, i) == "]" then return t, i + 1 end
    while true do
      local v; v, i = lire(txt, i)
      t[#t + 1] = v
      i = sauter(txt, i)
      local d = txt:sub(i, i)
      if d == "]" then return t, i + 1 end
      if d ~= "," then erreur(txt, i, "« , » ou « ] » attendu") end
      i = i + 1
    end
  elseif c == '"' then
    return lire_chaine(txt, i)
  elseif txt:sub(i, i + 3) == "true" then
    return true, i + 4
  elseif txt:sub(i, i + 4) == "false" then
    return false, i + 5
  elseif txt:sub(i, i + 3) == "null" then
    return nil, i + 4
  else
    return lire_nombre(txt, i)
  end
end

-- Rend `valeur` ou `nil, message`. On ne laisse JAMAIS une erreur de lecture
-- remonter jusqu'au moteur : une sauvegarde abîmée doit donner un message, pas
-- un plantage.
function Json.decoder(txt)
  if type(txt) ~= "string" or txt == "" then
    return nil, "texte vide"
  end
  local ok, v = pcall(function()
    local valeur = lire(txt, 1)
    return valeur
  end)
  if not ok then return nil, tostring(v) end
  return v
end


return Json
