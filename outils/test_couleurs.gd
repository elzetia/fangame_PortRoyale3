# Les COULEURS et les INFOBULLES que PR3 declare pour son interface.
#
# Les champs texte d'un .swf sont tous declares en NOIR (#000000) : la couleur
# visible est posee au runtime par l'ActionScript. Or le bytecode ne porte pas
# des litteraux mais des CLES, dans le meme espace `ID_GUI_*` que les libelles.
#
# LES CLES CI-DESSOUS SONT RELEVEES, PAS DEVINEES. Une premiere version de ce
# fichier interrogeait `ID_GUI_HUD_GOLD`, `ID_GUI_RANK_0` et consorts : elles ont
# toutes echoue, ce qui ne prouvait rien sinon que j'avais invente les noms. On
# les prend desormais dans le pool de chaines du DoABC de hud_pc et skinlib_pr3.
#
# Attention a la lecture : `LocaPR3.texte()` REEMET LA CLE quand elle est
# absente. Tester `!= ""` ne detecte donc jamais l'absence -- on compare a la
# cle elle-meme.
#
# Lance : godot --headless --path . --script res://outils/test_couleurs.gd
extends SceneTree

# Relevees dans hud_pc.swf et skinlib_pr3.swf.
const COULEURS := [
	"ID_GUI_DEF_COLOR_DEFAULT",
	"ID_GUI_DEF_COLOR_WHITE",
	"ID_GUI_DEF_COLOR_DARK_BG",
	"ID_GUI_DEF_COLOR_TAB",
	"ID_GUI_DEF_COLOR_TITLE",
	"ID_GUI_DEF_COLOR_TOOLTIP",
	"ID_GUI_DEF_COLOR_POSITIVE",
	"ID_GUI_DEF_COLOR_FILTER",
	"ID_GUI_DEF_COLOR_MAINMENU_DISABLED",
	"ID_GUI_DEF_COLOR_DIALOG_SUBHEADLINE",
	"ID_GUI_DEF_COLOR_PLUNDER_VALUE",
	"ID_GUI_DEF_COLOR_SEABATTLE_SHIPTYPE",
]

# Les INFOBULLES de la planche droite, et les deux boutons d'allure de la gauche.
const INFOBULLES := [
	"ID_GUI_TT_VISUAL_ROUNDBUTTON_CHRONIK",
	"ID_GUI_TT_VISUAL_ROUNDBUTTON_CONVOILIST",
	"ID_GUI_TT_VISUAL_ROUNDBUTTON_ONROUTE",
	"ID_GUI_TT_VISUAL_ROUNDBUTTON_WORLDMAP",
	"ID_GUI_TT_VISUAL_ROUNDBUTTON_OPTIONS",
	"ID_GUI_TT_VISUAL_ROUNDBUTTON_SHIPLIST",
	"ID_GUI_TT_VISUAL_ROUNDBUTTON_MPSTATISTIC",
	"ID_GUI_TT_VISUAL_ROUNDBUTTON_TRADEROUTE",
	"ID_GUI_TT_VISUAL_ICONBUTTON_ANCHOR",
	"ID_GUI_TT_ICON_LOG",
	"ID_GUI_TT_ICON_TOWN",
	"ID_GUI_TT_ICON_HABITANTS",
	"ID_GUI_TT_ICON_REPUTATION",
	"ID_GUI_TT_HUD_BTN_GAMESPEED_INCREASE",
	"ID_GUI_TT_HUD_BTN_GAMESPEED_DECREASE",
	"ID_GUI_TT_BTN_HUD_CONVOY",
	"ID_GUI_PLUS",
	"ID_GUI_MINUS",
]


func _rapport(titre: String, cles: Array) -> void:
	print("\n=== %s ===" % titre)
	var trouves := 0
	for cle in cles:
		var v := LocaPR3.texte(str(cle), "")
		# Absente = la cle est reemise telle quelle.
		if v == str(cle) or v == "":
			print("   %-42s (absente de la table)" % cle)
		else:
			trouves += 1
			print("   %-42s « %s »" % [cle, v])
	print("   -> %d / %d resolues" % [trouves, cles.size()])


func _init() -> void:
	print("loca disponible : ", LocaPR3.disponible())
	_rapport("les COULEURS que PR3 declare", COULEURS)
	_rapport("les INFOBULLES du HUD", INFOBULLES)
	quit()
