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
  corpus_christi = { case = { 120, 173 }, decalage = { -43.8, -32.6 } },
  nouvelle_orleans = { case = { 299, 142 }, decalage = { -75.7, 66.9 } },
  biloxi = { case = { 342, 128 }, decalage = { -4.7, 0.1 } },
  pensacola = { case = { 367, 130 }, decalage = { 38.7, -8.5 } },
  port_saint_joe = { case = { 445, 154 }, decalage = { -12.0, -23.9 } },
  tampa = { case = { 508, 213 }, decalage = { 56.6, 49.4 } },
  keys_de_floride = { case = { 544, 297 }, decalage = { -62.1, 11.2 } },
  tampico = { case = { 65, 360 }, decalage = { -78.9, 51.9 } },
  vera_cruz = { case = { 121, 445 }, decalage = { -115.5, 43.3 } },
  villahermosa = { case = { 160, 473 }, decalage = { 58.0, 115.9 } },
  campeche = { case = { 252, 404 }, decalage = { 72.7, 40.0 } },
  sisal = { case = { 291, 390 }, decalage = { 1.5, 79.7 } },
  cancun = { case = { 361, 402 }, decalage = { -50.8, 108.8 } },
  belize = { case = { 330, 501 }, decalage = { -120.4, 114.1 } },
  roatan = { case = { 396, 547 }, decalage = { -77.1, 21.5 } },
  charleston = { case = { 555, 44 }, decalage = { -43.2, -5.2 } },
  fort_caroline = { case = { 542, 98 }, decalage = { -62.8, 19.4 } },
  st_augustin = { case = { 544, 117 }, decalage = { -49.0, 45.1 } },
  grand_bahama = { case = { 625, 239 }, decalage = { 12.0, 8.2 } },
  eleuthera = { case = { 656, 252 }, decalage = { 42.9, 24.8 } },
  nassau = { case = { 656, 286 }, decalage = { -55.1, 46.6 } },
  ile_cat = { case = { 721, 313 }, decalage = { 35.0, -11.2 } },
  charles_towne = { case = { 743, 310 }, decalage = { 39.3, 65.9 } },
  nombre_de_dios = { case = { 437, 370 }, decalage = { 29.4, 53.0 } },
  evangelista = { case = { 489, 391 }, decalage = { 87.7, 87.6 } },
  la_havane = { case = { 496, 340 }, decalage = { -7.5, 105.1 } },
  trinite = { case = { 577, 401 }, decalage = { 15.6, -11.9 } },
  andros = { case = { 667, 304 }, decalage = { -56.8, 45.6 } },
  gibara = { case = { 707, 409 }, decalage = { -56.5, 62.7 } },
  santiago = { case = { 717, 450 }, decalage = { -8.0, -5.4 } },
  tortuga = { case = { 809, 449 }, decalage = { 69.7, 130.5 } },
  port_au_prince = { case = { 791, 480 }, decalage = { 141.3, 87.6 } },
  iles_turques = { case = { 828, 381 }, decalage = { 10.2, 15.8 } },
  isabela = { case = { 844, 450 }, decalage = { -8.4, 99.4 } },
  saint_domingue = { case = { 899, 503 }, decalage = { -85.4, -6.6 } },
  san_juan = { case = { 1004, 487 }, decalage = { 32.2, 87.0 } },
  saint_thome = { case = { 1037, 487 }, decalage = { 44.3, 104.1 } },
  saint_martin = { case = { 1105, 480 }, decalage = { 40.6, 91.6 } },
  saint_christophe = { case = { 1130, 521 }, decalage = { 29.1, -26.3 } },
  antigua = { case = { 1163, 520 }, decalage = { -75.6, 28.2 } },
  guadeloupe = { case = { 1163, 559 }, decalage = { 10.1, -31.4 } },
  granada = { case = { 1154, 675 }, decalage = { 60.7, 111.8 } },
  sainte_lucie = { case = { 1175, 645 }, decalage = { 57.2, 74.7 } },
  martinique = { case = { 1181, 610 }, decalage = { 115.4, 48.8 } },
  la_barbade = { case = { 1225, 644 }, decalage = { 89.2, 113.6 } },
  providence = { case = { 557, 701 }, decalage = { -17.7, 89.6 } },
  iles_caimans = { case = { 513, 461 }, decalage = { -10.6, 72.2 } },
  port_royale = { case = { 690, 524 }, decalage = { -81.1, 34.5 } },
  carthagene = { case = { 711, 789 }, decalage = { 157.2, 111.4 } },
  santa_marta = { case = { 757, 728 }, decalage = { 94.0, 87.4 } },
  maracaibo = { case = { 865, 733 }, decalage = { -127.8, 43.5 } },
  gibraltar = { case = { 875, 753 }, decalage = { 0.0, 0.0 } },
  coro = { case = { 922, 721 }, decalage = { 24.1, 120.3 } },
  curacao = { case = { 941, 707 }, decalage = { -54.5, -3.3 } },
  puerto_cabello = { case = { 958, 743 }, decalage = { -85.7, 124.1 } },
  caracas = { case = { 993, 746 }, decalage = { 38.8, 99.9 } },
  margarita = { case = { 1106, 709 }, decalage = { 13.8, 7.5 } },
  puerto_santo = { case = { 1151, 721 }, decalage = { -53.5, 75.2 } },
  port_d_espagne = { case = { 1170, 734 }, decalage = { 20.0, 99.3 } },
  georgeville = { case = { 1239, 804 }, decalage = { 0.0, 0.0 } },
}
