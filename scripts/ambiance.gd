# L'ambiance sonore : le ressac en continu, et la musique en fondu enchaîné.
#
# Deux couches qui ne se ressemblent pas et n'ont pas les mêmes règles.
#
# LE RESSAC tourne en boucle et ne s'arrête jamais. C'est le fond de la carte,
# au même titre que le bleu de la mer : on ne doit pas l'entendre commencer ni
# finir. Un MP3 se boucle mal par nature — l'encodeur ajoute du silence en tête
# et en queue — donc on ne se contente pas de `loop = true` : on relance la
# lecture AVANT la fin, en croisant les deux passages sur une seconde. La
# couture tombe alors au milieu d'un croisement et devient inaudible.
#
# LA MUSIQUE, elle, a un début et une fin, et il faut qu'on l'entende respirer.
# Les morceaux s'enchaînent en fondu de plusieurs secondes, et il y a un SILENCE
# entre deux : une carte qui joue sans interruption fatigue en une heure, et le
# retour de la musique après une accalmie vaut mieux qu'un ruban continu.
class_name Ambiance
extends Node

const DOSSIER := "res://sons/"

# Le ressac : deux lecteurs qui se relaient.
const FONDU_MER := 1.1        # secondes de croisement à la boucle
const VOL_MER := -13.0        # décibels

# La musique.
const FONDU_MUSIQUE := 5.0    # secondes de fondu enchaîné entre deux morceaux
const REPOS := 25.0           # silence entre deux morceaux, en secondes
const VOL_MUSIQUE := -10.0

const MUET := -60.0

var _mer: Array[AudioStreamPlayer] = []
var _mer_actif := 0
var _duree_mer := 0.0

var _musique: Array[AudioStreamPlayer] = []
var _morceaux: Array[AudioStream] = []
var _piste := 0               # lecteur qui joue
var _morceau := -1            # index du morceau en cours
var _attente := 2.0           # avant le premier morceau
var _fondu := 0.0             # secondes de fondu restantes


func _ready() -> void:
	# L'ambiance continue quand le jeu est en pause : c'est le décor, pas
	# l'action. Une mer qui se tait dès qu'on ouvre un comptoir sonne faux.
	process_mode = Node.PROCESS_MODE_ALWAYS

	var ressac := _charger("sea")
	if ressac != null:
		_duree_mer = ressac.get_length()
		for i in 2:
			var p := AudioStreamPlayer.new()
			p.stream = ressac
			p.volume_db = VOL_MER if i == 0 else MUET
			add_child(p)
			_mer.append(p)
		_mer[0].play()

	for nom in ["music_1", "music_2"]:
		var m := _charger(nom)
		if m != null:
			_morceaux.append(m)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = MUET
		add_child(p)
		_musique.append(p)


func _charger(nom: String) -> AudioStream:
	var chemin := DOSSIER + nom + ".mp3"
	if not ResourceLoader.exists(chemin):
		push_warning("son absent : " + chemin)
		return null
	return load(chemin) as AudioStream


func _process(delta: float) -> void:
	_tenir_la_mer(delta)
	_mener_la_musique(delta)


# Le ressac : on relance l'autre lecteur avant la fin et on croise les deux.
func _tenir_la_mer(delta: float) -> void:
	if _mer.size() < 2 or _duree_mer <= 0.0:
		return
	var a := _mer[_mer_actif]
	var b := _mer[1 - _mer_actif]
	if not a.playing:
		a.play()
		return
	var reste := _duree_mer - a.get_playback_position()
	if reste <= FONDU_MER and not b.playing:
		b.play()
		b.volume_db = MUET
		_mer_actif = 1 - _mer_actif
	# Les deux volumes se croisent tant que les deux jouent.
	for p in _mer:
		var cible := VOL_MER if p == _mer[_mer_actif] else MUET
		p.volume_db = move_toward(p.volume_db, cible, (VOL_MER - MUET) * delta / FONDU_MER)
		if p.volume_db <= MUET + 0.5 and p != _mer[_mer_actif]:
			p.stop()


func _mener_la_musique(delta: float) -> void:
	if _morceaux.is_empty():
		return
	var joue := _musique[_piste]
	var autre := _musique[1 - _piste]

	# Le fondu en cours : l'un monte, l'autre descend.
	if _fondu > 0.0:
		_fondu = maxf(0.0, _fondu - delta)
		var t: float = 1.0 - _fondu / FONDU_MUSIQUE
		joue.volume_db = lerpf(MUET, VOL_MUSIQUE, t)
		autre.volume_db = lerpf(VOL_MUSIQUE, MUET, t)
		if _fondu <= 0.0 and autre.playing:
			autre.stop()
		return

	if joue.playing:
		# On enchaîne AVANT la fin s'il reste d'autres morceaux, sinon on laisse
		# finir et l'on marque un repos.
		var reste := joue.stream.get_length() - joue.get_playback_position()
		if reste <= FONDU_MUSIQUE and _morceaux.size() > 1 and REPOS <= 0.0:
			_enchainer()
		elif reste <= 0.05:
			joue.stop()
			_attente = REPOS
		return

	_attente -= delta
	if _attente <= 0.0:
		_enchainer()


# Passe au morceau suivant sur l'autre lecteur, en fondu.
func _enchainer() -> void:
	_morceau = (_morceau + 1) % _morceaux.size()
	_piste = 1 - _piste
	var neuf := _musique[_piste]
	neuf.stream = _morceaux[_morceau]
	neuf.volume_db = MUET
	neuf.play()
	_fondu = FONDU_MUSIQUE
