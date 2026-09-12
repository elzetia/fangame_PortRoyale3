-- Les retouches de placement faites à la main, dans l'éditeur de villes (F2).
--
-- Ce fichier est SÉPARÉ de `sim/villes_pr3.lua` exprès. Celui-là est extrait des
-- archives de Port Royale 3 et se régénère d'un coup ; écrire dedans, c'est
-- perdre son travail à la prochaine extraction. Ici, rien n'est généré : on ne
-- garde que les villes dont on a bougé quelque chose, et l'archipel applique ces
-- retouches par-dessus les données du jeu.
--
--   case      le mouillage, en cases du masque — le point RÉEL du port, celui
--             où le navire s'arrête et où le clic tombe.
--   decalage  ne bouge QUE l'image du village, en unités de monde.
--
-- Réécrit intégralement par l'éditeur : ce qui n'est pas dans la table a repris
-- sa place d'origine.

return {
  corpus_christi = { case = { 118, 174 }, decalage = { -0.5, 126.4 } },
  nouvelle_orleans = { case = { 299, 142 }, decalage = { 25.5, 83.6 } },
  biloxi = { case = { 345, 129 }, decalage = { 3.3, 117.1 } },
  pensacola = { case = { 378, 138 }, decalage = { 62.2, 50.7 } },
  port_saint_joe = { case = { 426, 146 }, decalage = { 108.0, 123.5 } },
  tampa = { case = { 486, 212 }, decalage = { 0.0, 0.0 } },
  keys_de_floride = { case = { 542, 308 }, decalage = { -24.3, 162.1 } },
  tampico = { case = { 65, 360 }, decalage = { -67.7, 276.3 } },
  vera_cruz = { case = { 69, 486 }, decalage = { -36.6, 145.5 } },
  villahermosa = { case = { 200, 507 }, decalage = { 79.8, 270.9 } },
  campeche = { case = { 242, 435 }, decalage = { -14.2, 219.8 } },
  sisal = { case = { 259, 396 }, decalage = { 157.0, 222.9 } },
  cancun = { case = { 361, 433 }, decalage = { -95.5, 198.0 } },
  belize = { case = { 326, 542 }, decalage = { -27.4, 158.2 } },
  roatan = { case = { 372, 595 }, decalage = { -103.6, 113.6 } },
  charleston = { case = { 562, 41 }, decalage = { -5.7, 126.6 } },
  st_augustin = { case = { 546, 130 }, decalage = { 0.0, 0.0 } },
  grand_bahama = { case = { 625, 239 }, decalage = { -4.0, 150.5 } },
  eleuthera = { case = { 668, 260 }, decalage = { -71.0, 185.4 } },
  nassau = { case = { 638, 314 }, decalage = { -72.5, 159.9 } },
  ile_cat = { case = { 712, 305 }, decalage = { 12.8, 266.2 } },
  charles_towne = { case = { 746, 324 }, decalage = { 70.1, 271.2 } },
  nombre_de_dios = { case = { 440, 374 }, decalage = { 121.9, 70.4 } },
  evangelista = { case = { 483, 402 }, decalage = { 0.0, 0.0 } },
  la_havane = { case = { 502, 352 }, decalage = { -92.0, 230.9 } },
  trinite = { case = { 588, 404 }, decalage = { 29.3, 130.3 } },
  andros = { case = { 651, 332 }, decalage = { -78.4, 251.9 } },
  gibara = { case = { 707, 409 }, decalage = { 2.2, 224.0 } },
  santiago = { case = { 691, 451 }, decalage = { -10.8, 132.9 } },
  tortuga = { case = { 798, 470 }, decalage = { 132.9, 288.3 } },
  port_au_prince = { case = { 782, 515 }, decalage = { 121.9, 257.2 } },
  iles_turques = { case = { 808, 408 }, decalage = { 8.9, 140.1 } },
  isabela = { case = { 839, 467 }, decalage = { -79.1, 289.1 } },
  saint_domingue = { case = { 898, 521 }, decalage = { 0.0, 0.0 } },
  san_juan = { case = { 1017, 513 }, decalage = { -20.8, 190.3 } },
  saint_thome = { case = { 1031, 512 }, decalage = { 9.4, 109.9 } },
  saint_martin = { case = { 1065, 522 }, decalage = { 54.9, 177.2 } },
  saint_christophe = { case = { 1136, 551 }, decalage = { -108.4, 161.7 } },
  antigua = { case = { 1138, 553 }, decalage = { -15.8, 112.8 } },
  guadeloupe = { case = { 1147, 574 }, decalage = { 46.4, 146.6 } },
  granada = { case = { 1142, 716 }, decalage = { -13.4, 207.8 } },
  sainte_lucie = { case = { 1158, 672 }, decalage = { -45.9, 180.7 } },
  martinique = { case = { 1177, 654 }, decalage = { 24.6, 92.7 } },
  la_barbade = { case = { 1197, 656 }, decalage = { -50.5, 246.8 } },
  providence = { case = { 527, 751 }, decalage = { -79.0, 231.1 } },
  iles_caimans = { case = { 507, 484 }, decalage = { -88.3, 169.1 } },
  port_royale = { case = { 678, 535 }, decalage = { -9.3, 168.1 } },
  carthagene = { case = { 714, 798 }, decalage = { 38.4, 190.8 } },
  santa_marta = { case = { 762, 746 }, decalage = { 20.3, 70.1 } },
  maracaibo = { case = { 814, 768 }, decalage = { 4.9, 204.9 } },
  gibraltar = { case = { 822, 866 }, decalage = { 61.0, 162.7 } },
  coro = { case = { 901, 747 }, decalage = { -27.5, 159.7 } },
  curacao = { case = { 932, 749 }, decalage = { 14.5, 86.8 } },
  puerto_cabello = { case = { 948, 776 }, decalage = { -101.9, 30.2 } },
  caracas = { case = { 961, 762 }, decalage = { -24.4, 226.4 } },
  margarita = { case = { 1085, 765 }, decalage = { -16.5, 119.6 } },
  puerto_santo = { case = { 1130, 766 }, decalage = { 8.0, 123.5 } },
  port_d_espagne = { case = { 1170, 774 }, decalage = { 82.6, 242.3 } },
  georgeville = { case = { 1191, 866 }, decalage = { 0.0, 0.0 } },
}
