// Maquette de la porte relevable : le même modèle à l'échelle 0,4.
// Deux planches de 260 x 260 : planche_1 (cadre + couvercle), planche_2 (le reste).
// Les épaisseurs ne descendent pas sous les minimums imprimables (voir porte_rebord.scad).
include <porte_rebord.scad>

part = "planche_1"; // [assembled, eclate, planche_1, planche_2, cadre, couvercle, porte, levier_avant, levier_arriere, coulisseau_avant, coulisseau_arriere, rebord]
echelle = 0.4;
