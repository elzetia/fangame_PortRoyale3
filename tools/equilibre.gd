# L'économie tient-elle sur la durée ?
#   godot --headless --path <projet> --script res://tools/equilibre.gd -- [annees]
#
# Un déséquilibre met des mois de jeu à se voir : une denrée légèrement
# déficitaire vide les entrepôts un à un, puis la population fond. Ni une
# capture ni `--marche` sur soixante villes ne le montrent d'un coup d'oeil.
# Cette sonde fait avancer la simulation par le même chemin que le jeu, et
# résume chaque année en quelques lignes : population, villes en disette, et
# pour chaque denrée le remplissage des entrepôts et l'activité des ateliers.
extends SceneTree

const RESUME := """
local Economie     = require("sim.economie")
local Marchandises = require("sim.marchandises")
local Archipel     = require("sim.archipel")

local l = {}
local pop, n, disette, mini, maxi = 0, 0, 0, math.huge, 0
for _, v in pairs(Economie.villes) do
  pop = pop + v.habitants ; n = n + 1
  if (v.subsistance or 1) < 0.97 then disette = disette + 1 end
  if v.habitants < mini then mini = v.habitants end
  if v.habitants > maxi then maxi = v.habitants end
end
l[#l + 1] = string.format("  population %d sur %d villes (min %d, max %d), en disette : %d",
  pop, n, mini, maxi, disette)
l[#l + 1] = "  denree        stock/ref  vides(0-1 barre)  pleines(4)  ateliers"
for _, m in ipairs(Marchandises.liste) do
  local s, r, vides, pleines, rend, cap = 0, 0, 0, 0, 0, 0
  for cle, v in pairs(Economie.villes) do
    s = s + (v.stock[m.cle] or 0)
    local ligne = Economie.ligne(cle, m.cle)
    r = r + ligne.reference
    if ligne.barres <= 1 then vides = vides + 1 end
    if ligne.barres >= 4 then pleines = pleines + 1 end
    if m.recette then
      cap = cap + (v.production[m.cle] or 0)
      rend = rend + ((v.rendement or {})[m.cle] or 0)
    end
  end
  local atel = m.recette and string.format("%4.0f %%", cap > 0 and rend / cap * 100 or 0) or "   -"
  l[#l + 1] = string.format("  %-12s %8.2f  %10d  %12d  %s", m.cle, s / r, vides, pleines, atel)
end

-- Les convois : s'ils sont a court d'or ou de cale, c'est la logistique qui
-- bride l'economie, pas la production.
local Marchands = require("sim.marchands")
local nc, orl, charge, cap, longs, navires = 0, 0, 0, 0, 0, 0
for _, m in ipairs(Marchands.liste) do
  nc = nc + 1 ; orl = orl + m.or_ ; cap = cap + m.capacite
  navires = navires + #(m.navires or {})
  if m.genre == "long_cours" then longs = longs + 1 end
  for _, q in pairs(m.cale) do charge = charge + q end
end
l[#l + 1] = string.format("  convois %d dont %d long-courriers, %d navires, %d t de cale : or moyen %.0f, cales pleines a %.0f %%",
  nc, longs, navires, cap, orl / math.max(nc, 1), charge / math.max(cap, 1) * 100)
return table.concat(l, string.char(10))
"""

# Pour essayer une autre logistique sans toucher au jeu :
#   `-- <annees> <cale par habitant, en centiemes>`
# Les flottes sont réarmées d'après ce coefficient avant la première journée.
const SURCHARGE := """
local Marchands = require("sim.marchands")
Marchands.CALE_PAR_HABITANT = %d / 100
Marchands.reinitialiser()
"""


func _init() -> void:
	var annees := 5
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0].is_valid_int():
		annees = int(args[0])

	var lua = ClassDB.instantiate("LuaState")
	lua.open_libraries()
	var b = lua.do_file("res://sim/bridge.lua")
	if b is LuaError:
		printerr("ECHEC chargement sim/bridge.lua : ", b)
		quit(1)
		return
	b.get("preparer_navigation").invoke()
	# L'indice 2 est x1. Le 1 est la PAUSE : la première version de cette sonde
	# le posait, et imprimait cinq années rigoureusement identiques — une
	# économie parfaitement stable, en apparence.
	b.get("definir_vitesse").invoke(2)
	var avancer = b.get("avancer_temps")
	if args.size() >= 2 and args[1].is_valid_int():
		lua.do_string(SURCHARGE % int(args[1]))
		print("convois : %s centiemes de tonneau de cale par habitant" % args[1])

	var debut := Time.get_ticks_msec()
	print("=== annee 0 ===")
	print(lua.do_string(RESUME))
	for an in range(1, annees + 1):
		# 12 s réelles = une journée à x1, comme `--marche`.
		for _j in 365:
			avancer.invoke(12.0)
		print("=== annee %d (%.0f s) ===" % [an, (Time.get_ticks_msec() - debut) / 1000.0])
		print(lua.do_string(RESUME))
	quit(0)
