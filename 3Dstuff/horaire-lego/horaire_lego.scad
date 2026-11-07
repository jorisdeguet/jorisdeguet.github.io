// =============================================================================
//  horaire_lego.scad — Bibliothèque : horaire modulaire à plots pour porte
//                      de bureau (enseignant·es, Cégep Édouard-Montpetit)
//  Unités : millimètres
// =============================================================================
//
//  Ce fichier ne dessine RIEN par lui-même : il est inclus par
//    horaire.scad                (gabarit à copier pour chaque prof)
//    exemple_pierre-olivier.scad (exemple tiré d'un vrai horaire)
//    test_ajustement.scad        (coupon pour régler les jeux)
//
//  Fixation au choix (paramètre `fixation`) :
//    "tasseau" (défaut) : une petite lèvre en queue d'aronde à 45° par
//        demi-heure, comme un tasseau français (« french cleat »). Le dos des
//        blocs a des rainures assorties : on pose le bloc 2 mm trop haut, on
//        le plaque contre la base et on le laisse descendre ; la gravité le
//        tire contre la porte. Rien à forcer, rien qui s'use.
//    "plots" : plots Ø5 mm et douilles (géométrie originale, pas LEGO).
//  Base au choix (`base_style`) : "grille" (ajourée : cadre, montants entre
//  les jours, une traverse par demi-heure) ou "pleine".
//  Une rangée = 30 minutes, pas de 10 mm.
//
//  Repère de la plaque de base (vue de face, sur la porte) :
//    X vers la droite, Y vers le HAUT, Z sort de la porte vers le lecteur.
//
//      ┌──────────────────────────────────────────┐
//      │  [ plaque nom (plots) ]      [statut]   │  ← zone tête
//      │        Lundi Mardi Mercredi Jeudi Vendr. │  ← en-tête des jours
//      │  8h  ○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ...             │
//      │      ○ ○ ○ ○ ...                         │  ← grille 8h–20h,
//      │  9h  ...        ┌Trou ┐                  │     1 rangée = 30 min
//      │                 │horai│ (mer. 12h–14h,   │
//      │ ...             └re──┘  moulé)           │
//      │ 20h                                      │
//      └──────────────────────────────────────────┘
// =============================================================================

// ── Grille et plots ──────────────────────────────────────────────────────────
pas           = 10;     // pas de la grille (mm) ; en hauteur 1 pas = 30 min
plot_d        = 5.0;    // diamètre d'un plot
plot_h        = 1.8;    // hauteur d'un plot
plot_chanfrein= 0.4;    // chanfrein en tête de plot (aide à l'emboîtement)
jeu_plot      = 0.10;   // jeu DIAMÉTRAL douille − plot (régler avec test_ajustement.scad)
                        //   plus petit = plus serré ; peut être négatif
jeu_bloc      = 0.4;    // espace entre deux blocs voisins (total)
plots_cols    = [1, 2]; // (plots) colonnes d'une journée (0 … jour_l-1) qui portent des plots
                        //   [0,1,2,3] = toutes ; [1,2] = paire centrale, plus sobre

// ── Fixation et style de base ───────────────────────────────────────────────
fixation      = "tasseau"; // "tasseau" | "plots"
base_style    = "grille";  // "grille" (ajourée, économe en plastique) | "pleine"
tas_t         = 2.5;    // épaisseur de la lèvre à sa racine (mm, dans le sens de Y)
tas_h         = 2.0;    // saillie de la lèvre (et profondeur d'accrochage)
jeu_tasseau   = 0.3;    // jeu entre lèvre et rainure (régler avec test_ajustement.scad)
tas_retrait   = 10;     // lèvre plus courte que le bloc de cette valeur (centrage gauche-droite)
tas_jeu_lat   = 0.4;    // jeu gauche-droite de la rainure autour de la lèvre
montant_l     = 5;      // (grille) largeur des montants entre les jours
$fn           = 32;

// ── Plaque de base ───────────────────────────────────────────────────────────
base_e        = 4;      // épaisseur de la plaque de base
marge         = 5;      // bordure autour de tout
coin_r        = 3;      // arrondi des coins
col_heures    = 2;      // largeur de la colonne des heures (en pas)
jour_l        = 4;      // largeur d'une journée (en pas) = largeur d'un bloc
heure_debut   = 8;
heure_fin     = 20;
jours         = ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi"];
entete_jours_h= 15;     // hauteur de la bande des noms de jours (mm)
tete_h        = 4;      // hauteur de la zone nom + statut (en pas)
tete_ecart    = 5;      // espace entre en-tête des jours et zone tête (mm)
nom_rangees   = 4;      // hauteur de la plaque nom (en pas)
nom_plots_rangees = [1, 2]; // rangées de la zone nom qui portent des plots
nom_plots_pas = 5;      // un plot toutes les N colonnes dans la zone nom
lignes_gravees= true;   // traits gravés aux heures et entre les jours
trait_l       = 0.6;    // largeur des traits gravés
trait_p       = 0.4;    // profondeur des traits gravés

// ── Texte ────────────────────────────────────────────────────────────────────
police        = "Liberation Sans:style=Bold";
texte_h       = 0.6;    // relief du texte en saillie (impression multicolore par pause)
car_l         = 0.78;   // largeur moyenne d'un caractère / taille (estimation pour ajuster)
heures_s      = 4.5;    // taille du texte des heures
jours_s       = 5;      // taille du texte des jours

// ── Trou horaire commun (bloc moulé dans la base) ───────────────────────────
trou_actif    = true;
trou_jour     = 2;      // 0 = lundi … 4 = vendredi  → mercredi
trou_debut    = 12;
trou_duree    = 2;
trou_texte    = ["Trou", "horaire"];
trou_bosse    = 2.0;    // le trou horaire est une simple bosse de cette hauteur
trou_retrait  = 3;      // retrait de la bosse par rapport à la case (laisse lever les blocs voisins)

// ── Blocs (cours, dispo, etc.) ───────────────────────────────────────────────
bloc_h        = 6;      // épaisseur d'un bloc (au-dessus de la base)
bloc_r        = 1.5;    // arrondi des coins d'un bloc
bloc_texte_s  = 4.2;    // taille max. du texte d'un bloc
groupe_mode   = "plaquette"; // "plaquette" = poche + plaquette amovible ; "texte" = texte en relief

// ── Plaquettes amovibles (groupe, local) ────────────────────────────────────
plaquette_l   = 30;
plaquette_w   = 9;
plaquette_e   = 1.6;
plaquette_s   = 5;      // taille max. du texte
jeu_poche     = 0.15;   // jeu par côté entre plaquette et poche

// ── Plaque nom ──────────────────────────────────────────────────────────────
plaque_h      = 4;      // épaisseur de la plaque nom
nom_s         = 11;     // taille max. du nom
sous_titre_s  = 5;

// ── Plaque de statut (interchangeable, s'enfiche comme les blocs) ────────────
statut_cols   = 5;      // largeur de la zone statut (en pas), à droite
statut_rangees= 4;      // hauteur (en pas)
statut_plots_cols = [1, 3];
statut_texte_s= 7;
statuts       = [["Dispo"], ["Absent"], ["De retour", "dans", "5 minutes"], ["Au local"]];
statut_local  = 3;      // statut qui reçoit une poche pour la plaquette « local »
statut_affiche= 0;      // aperçu : statut posé sur la base
local_statut  = "E-211";// plaquette « local » de la plaque « Au local »

// ── Couleurs d'aperçu (2 filaments : noir mat + blanc) ──────────────────────
couleur_base       = "#1e1e1e";  // base noir mat
couleur_texte_base = "White";
couleur_bloc       = "White";    // blocs, plaque nom, statuts, plaquettes
couleur_texte_bloc = "#151515";
couleurs_par_cours = false;      // true = utiliser la couleur de chaque entrée d'horaire

// ── Impression ──────────────────────────────────────────────────────────────
lit           = 250;    // côté utile du plateau (Kobra X ≈ 250 × 250)
lit_marge     = 10;     // garde au bord du plateau
eclisse_e     = 1.6;    // épaisseur de l'éclisse de jonction (au dos)
eclisse_l     = 24;     // largeur de l'éclisse (de part et d'autre de la coupe)
eclisse_bord  = 12;     // retrait de l'éclisse par rapport aux bords gauche/droit
eclisse_jeu   = 0.3;    // jeu de la poche d'éclisse
ergot_d       = 3;
ergot_h       = 1.2;
ergot_pas     = 40;

// ── Raccourcis pour les jours ───────────────────────────────────────────────
LUN = 0; MAR = 1; MER = 2; JEU = 3; VEN = 4;

// =============================================================================
//  Dimensions dérivées
// =============================================================================
function nb_jours()   = len(jours);
function nb_demi()    = (heure_fin - heure_debut) * 2;
function grille_l()   = nb_jours() * jour_l * pas;
function W()          = 2 * marge + col_heures * pas + grille_l();
function x_grille()   = marge + col_heures * pas;
function y_grille_bas()  = marge;
function y_grille_haut() = marge + nb_demi() * pas;
function y_jours_haut()  = y_grille_haut() + entete_jours_h;
function y_tete_bas()    = y_jours_haut() + tete_ecart;
function y_tete_haut()   = y_tete_bas() + tete_h * pas;
function H()          = y_tete_haut() + marge;
function x_jour(d)    = x_grille() + d * jour_l * pas;
function y_heure(t)   = y_grille_haut() - (t - heure_debut) * 2 * pas;
function nom_cols()   = floor((W() - 2 * marge - statut_cols * pas) / pas) - 1;
function nom_x0()     = marge;
function nom_plots_cols() = let(o = floor(((nom_cols() - 1) % nom_plots_pas) / 2))
    [for (c = [o : nom_plots_pas : nom_cols() - 1]) c];
function nom_y0()     = y_tete_bas() + (tete_h - nom_rangees) / 2 * pas;
function statut_x0()  = W() - marge - statut_cols * pas;
function statut_y0()  = y_tete_bas() + (tete_h - statut_rangees) / 2 * pas;

// Tasseau : hauteur de la rainure et position de la lèvre dans sa rangée.
function tas_vide_h() = 2 * tas_h + tas_t + 4 * jeu_tasseau;
function tas_y0()     = (pas - tas_vide_h()) / 2 + tas_h + 2 * jeu_tasseau;

function dans_trou(d, r) = trou_actif && d == trou_jour
    && r >= (trou_debut - heure_debut) * 2
    && r <  (trou_debut - heure_debut + trou_duree) * 2;

// Découpe en tuiles (coupes horizontales, sur une demi-heure entre deux plots,
// jamais au milieu d'une étiquette d'heure ni du bloc « Trou horaire »).
function lit_utile()  = lit - lit_marge;
function nb_tuiles()  = max(1, ceil(H() / lit_utile()));
function y_trou_bas() = y_heure(trou_debut + trou_duree);
function y_trou_haut()= y_heure(trou_debut);
function coupe_ok(c)  = c > y_grille_bas() && c < y_grille_haut()
    && !(trou_actif && c > y_trou_bas() - 1 && c < y_trou_haut() + 1);
function coupe_k(k)   = let(
        cible = k * H() / nb_tuiles(),
        base0 = y_grille_bas() + (2 * floor((cible - y_grille_bas()) / (2 * pas)) + 1) * pas,
        cands = [for (o = [0, -2, 2, -4, 4, -6, 6]) base0 + o * pas],
        bons  = [for (c = cands) if (coupe_ok(c)) c]
    ) bons[0];
function coupes()     = [0, for (k = [1 : 1 : nb_tuiles() - 1]) coupe_k(k), H()];

// =============================================================================
//  Utilitaires
// =============================================================================
module rrect(l, w, r) {
    if (r <= 0) square([l, w]);
    else translate([r, r]) offset(r = r) square([l - 2 * r, w - 2 * r]);
}

function taille_ajustee(t, s, lmax) = min(s, lmax / (max(1, len(t)) * car_l));

module texte1(t, s, lmax) {
    text(t, size = taille_ajustee(t, s, lmax), font = police,
         halign = "center", valign = "center");
}

// Plusieurs lignes centrées autour de l'origine, dans une boîte lmax × hmax.
module lignes_texte(L, s, lmax, hmax) {
    n  = len(L);
    s1 = min([s, hmax / (n * 1.5), for (t = L) taille_ajustee(t, s, lmax)]);
    for (i = [0 : n - 1])
        translate([0, ((n - 1) / 2 - i) * s1 * 1.5]) texte1(L[i], s1, lmax);
}

module plot() {
    cylinder(d = plot_d, h = plot_h - plot_chanfrein);
    translate([0, 0, plot_h - plot_chanfrein])
        cylinder(d1 = plot_d, d2 = plot_d - 2 * plot_chanfrein, h = plot_chanfrein);
}

// Douille (trou borgne depuis le dessous), avec chanfrein d'entrée.
module douille(jeu = jeu_plot) {
    d = plot_d + jeu;
    translate([0, 0, -0.01]) {
        cylinder(d = d, h = plot_h + 0.4);
        cylinder(d1 = d + 0.8, d2 = d, h = 0.4);
    }
}

// Lèvre de tasseau (sur la base), longueur l selon X, racine en y = 0, z = 0.
module levre(l) {
    rotate([90, 0, 90]) linear_extrude(l)
        polygon([[0, -0.01], [tas_t, -0.01], [tas_t + tas_h, tas_h], [0, tas_h]]);
}

// Rainure assortie (dans le dos d'une pièce) : la partie basse sert à
// engager la lèvre avant de laisser descendre la pièce.
module rainure(l, jeu = jeu_tasseau) {
    c = jeu;
    rotate([90, 0, 90]) linear_extrude(l)
        polygon([[-tas_h - 2 * c, -0.01], [tas_t + c, -0.01],
                 [tas_t + 2 * c + tas_h, tas_h + c], [-tas_h - 2 * c, tas_h + c]]);
}

// Plaque nx × ny pas avec sa fixation au dos (origine au coin bas-gauche).
//   plots   : douilles aux colonnes `cols` et rangées `rangs` (toutes par défaut)
//   tasseau : une rainure par rangée
module plaque_fixee(nx, ny, h, r = bloc_r, cols = undef, rangs = undef, jeu = undef) {
    cs = cols  == undef ? [for (i = [0 : nx - 1]) i] : cols;
    rs = rangs == undef ? [for (j = [0 : ny - 1]) j] : rangs;
    l  = nx * pas - jeu_bloc;
    difference() {
        linear_extrude(h) rrect(l, ny * pas - jeu_bloc, r);
        if (fixation == "plots") {
            for (i = cs, j = rs)
                translate([(i + 0.5) * pas - jeu_bloc / 2, (j + 0.5) * pas - jeu_bloc / 2, 0])
                    douille(jeu == undef ? jeu_plot : jeu);
        } else {
            lv = nx * pas - tas_retrait + 2 * tas_jeu_lat;
            for (j = [0 : ny - 1])
                translate([(l - lv) / 2, j * pas + tas_y0() - jeu_bloc / 2, 0])
                    rainure(lv, jeu == undef ? jeu_tasseau : jeu);
        }
    }
}

// =============================================================================
//  Plaque de base
// =============================================================================
module base_textes_2d() {
    // Heures
    for (t = [heure_debut : heure_fin])
        translate([x_grille() - 2, y_heure(t)])
            text(str(t, "h"), size = heures_s, font = police, halign = "right", valign = "center");
    // Jours
    for (d = [0 : nb_jours() - 1])
        translate([x_jour(d) + jour_l * pas / 2, (y_grille_haut() + y_jours_haut()) / 2])
            texte1(jours[d], jours_s, jour_l * pas - 3);
}

module traits_graves() {
  if (base_style == "pleine") {
    for (t = [heure_debut : heure_fin])
        translate([x_grille() - 1, y_heure(t) - trait_l / 2, base_e - trait_p])
            cube([grille_l() + 1, trait_l, trait_p + 0.01]);
    for (d = [0 : nb_jours()])
        translate([x_jour(d) - trait_l / 2, y_grille_bas(), base_e - trait_p])
            cube([trait_l, nb_demi() * pas, trait_p + 0.01]);
  }
}

// Le trou horaire : une bosse basse (trou_bosse) avec le texte, pas un bloc.
module bloc_trou() {
    L = trou_duree * 2 * pas - 2 * trou_retrait;
    l = jour_l * pas - 2 * trou_retrait;
    translate([x_jour(trou_jour) + trou_retrait, y_trou_bas() + trou_retrait, base_e - 0.01]) {
        color(couleur_base) linear_extrude(trou_bosse + 0.01) rrect(l, L, 2);
        color(couleur_texte_base) translate([l / 2, L / 2, trou_bosse])
            linear_extrude(texte_h + 0.01) lignes_texte(trou_texte, bloc_texte_s + 1, l - 4, L - 4);
    }
}

// Zones qui reçoivent des pièces : [x0, nx, y0, ny, cols, rangs]
function zones() = [
    for (d = [0 : nb_jours() - 1]) [x_jour(d), jour_l, y_grille_bas(), nb_demi(), plots_cols, undef, d],
    [nom_x0(), nom_cols(), nom_y0(), nom_rangees, nom_plots_cols(), nom_plots_rangees, -1],
    [statut_x0(), statut_cols, statut_y0(), statut_rangees, statut_plots_cols, nom_plots_rangees, -1]
];

// Rangée j d'une zone (j = 0 en bas) : est-ce qu'elle porte une fixation ?
function rang_ok(z, j) = let(r = nb_demi() - 1 - j)
    !(z[6] >= 0 && dans_trou(z[6], r))
    && (fixation == "tasseau" ? true
        : z[5] == undef ? true
        : len([for (k = z[5]) if (k == j) k]) > 0);

// Fixations de la base (lèvres ou plots), filtrées sur [y0, y1] (accélère le rendu).
module attaches_base(y0 = -1e9, y1 = 1e9) {
    for (z = zones(), j = [0 : z[3] - 1]) {
        yb = z[2] + j * pas;
        if (rang_ok(z, j) && yb > y0 - 2 * pas && yb < y1 + pas) {
            if (fixation == "tasseau")
                translate([z[0] + tas_retrait / 2, yb + tas_y0(), base_e - 0.01])
                    levre(z[1] * pas - tas_retrait);
            else
                for (c = z[4])
                    translate([z[0] + (c + 0.5) * pas, yb + pas / 2, base_e]) plot();
        }
    }
}

// Ossature : plaque pleine, ou grille = plaque ajourée + une traverse par rangée.
function traverse_y() = fixation == "tasseau"
    ? [tas_y0(), tas_t]
    : [pas / 2 - plot_d / 2 - 1, plot_d + 2];

module ossature() {
    if (base_style == "pleine")
        linear_extrude(base_e) rrect(W(), H(), coin_r);
    else {
        difference() {
            linear_extrude(base_e) rrect(W(), H(), coin_r);
            for (z = zones())
                translate([z[0] + montant_l / 2, z[2], -1])
                    cube([z[1] * pas - montant_l, z[3] * pas, base_e + 2]);
        }
        ty = traverse_y();
        for (z = zones(), j = [0 : z[3] - 1])
            translate([z[0], z[2] + j * pas + ty[0], 0])
                cube([z[1] * pas, ty[1], base_e]);
    }
}

module base_brute(y0 = -1e9, y1 = 1e9, deco = true) {
    difference() {
        ossature();
        traits_graves();
    }
    attaches_base(y0, y1);
    if (deco) {
        translate([0, 0, base_e - 0.01]) linear_extrude(texte_h + 0.01) base_textes_2d();
        if (trou_actif) bloc_trou();
    }
}

// Positions des ergots d'une éclisse : dans la colonne des heures et sur les montants.
function ergots_x() = [(marge + x_grille()) / 2, for (d = [1 : nb_jours() - 1]) x_jour(d)];

module poches_eclisse() {
    cs = coupes();
    for (k = [1 : 1 : len(cs) - 2]) {
        yc = cs[k];
        translate([eclisse_bord - eclisse_jeu, yc - eclisse_l / 2 - eclisse_jeu, -0.01])
            cube([W() - 2 * eclisse_bord + 2 * eclisse_jeu, eclisse_l + 2 * eclisse_jeu, eclisse_e + 0.11]);
        for (x = ergots_x(), s = [-1, 1])
            translate([x, yc + s * eclisse_l / 4, 0])
                cylinder(d = ergot_d + 0.3, h = eclisse_e + ergot_h + 0.3);
    }
}

// Plaque de base entière (tuile = -1) ou une tuile, ramenée à y = 0.
module base(tuile = -1, deco = true) {
    cs = coupes();
    if (tuile < 0) {
        difference() { base_brute(deco = deco); poches_eclisse(); }
    } else {
        y0 = cs[tuile]; y1 = cs[tuile + 1];
        translate([0, -y0, 0])
            difference() {
                intersection() {
                    base_brute(y0, y1, deco);
                    translate([-1, y0, -1]) cube([W() + 2, y1 - y0, 100]);
                }
                poches_eclisse();
            }
    }
}

module eclisse() {
    cube([W() - 2 * eclisse_bord, eclisse_l, eclisse_e]);
    for (x = ergots_x(), s = [-1, 1])
        translate([x - eclisse_bord, eclisse_l / 2 + s * eclisse_l / 4, eclisse_e - 0.01])
            cylinder(d1 = ergot_d, d2 = ergot_d - 0.4, h = ergot_h);
}

// =============================================================================
//  Plaquette amovible (groupe ou local)
// =============================================================================
module plaquette(t) {
    color(couleur_bloc) linear_extrude(plaquette_e) rrect(plaquette_l, plaquette_w, 1);
    color(couleur_texte_bloc) translate([plaquette_l / 2, plaquette_w / 2, plaquette_e - 0.01])
        linear_extrude(texte_h + 0.01) texte1(t, plaquette_s, plaquette_l - 3);
}

module poche_plaquette(prof) {
    // poche + encoche pour l'ongle à droite
    translate([-jeu_poche, -jeu_poche, -prof])
        cube([plaquette_l + 2 * jeu_poche, plaquette_w + 2 * jeu_poche, prof + 1]);
    translate([plaquette_l - 1, plaquette_w / 2 - 2, -prof])
        cube([3.5, 4, prof + 1]);
}

// =============================================================================
//  Bloc (cours, dispo, centre d'aide…)
//   duree     : en heures, multiple de 0,5 (2, 2.5, 3 … ; 1 et 1.5 aussi)
//   lignes    : textes en relief, de haut en bas (ex. ["420-5N6-EM"])
//   plaq      : texte de la plaquette (groupe ou local) ; "" = aucune
//   apercu    : true = dessine aussi la plaquette dans sa poche
//  Origine : coin bas-gauche de l'empreinte (le haut du bloc = début du cours).
// =============================================================================
function bloc_L(duree) = duree * 2 * pas - jeu_bloc;
function bloc_l()      = jour_l * pas - jeu_bloc;
function bloc_a_poche(duree, plaq) =
    groupe_mode == "plaquette" && plaq != "" && bloc_L(duree) >= plaquette_w + 2 * jeu_poche + 11;

module bloc(duree, lignes, plaq = "", apercu = false, couleur = couleur_bloc, couleur_texte = couleur_texte_bloc) {
    assert(duree >= 0.5 && duree * 2 == round(duree * 2),
           str("Durée ", duree, " h : il faut un multiple de 0,5 h"));
    L = bloc_L(duree);
    l = bloc_l();
    poche = bloc_a_poche(duree, plaq);
    tous  = (plaq != "" && !poche) ? concat(lignes, [plaq]) : lignes;
    py    = 3;                                   // bas de la poche
    zone0 = poche ? py + plaquette_w + 2 * jeu_poche + 1.5 : 2;
    px    = (l - plaquette_l) / 2;
    color(couleur) difference() {
        plaque_fixee(jour_l, duree * 2, bloc_h, cols = plots_cols);
        if (poche) translate([px, py, bloc_h]) poche_plaquette(plaquette_e);
    }
    color(couleur_texte)
        translate([l / 2, (zone0 + L - 2) / 2, bloc_h - 0.01])
            linear_extrude(texte_h + 0.01) lignes_texte(tous, bloc_texte_s, l - 4, L - 2 - zone0);
    if (poche && apercu)
        translate([px, py, bloc_h - plaquette_e]) plaquette(plaq);
}

// =============================================================================
//  Plaque nom
// =============================================================================
module plaque_nom(nom, sous_titre = "") {
    l = nom_cols() * pas - jeu_bloc;
    h = nom_rangees * pas - jeu_bloc;
    color(couleur_bloc) plaque_fixee(nom_cols(), nom_rangees, plaque_h, r = 2,
                                         cols = nom_plots_cols(), rangs = nom_plots_rangees);
    color(couleur_texte_bloc) translate([l / 2, 0, plaque_h - 0.01]) linear_extrude(texte_h + 0.01) {
        if (sous_titre == "")
            translate([0, h / 2]) texte1(nom, nom_s, l - 8);
        else {
            translate([0, h * 0.62]) texte1(nom, nom_s, l - 8);
            translate([0, h * 0.22]) texte1(sous_titre, sous_titre_s, l - 8);
        }
    }
}

// =============================================================================
//  Plaque de statut k (statuts[k]) : s'enfiche sur la zone statut, on la
//  remplace par une autre selon la situation.
// =============================================================================
module plaque_statut(k, apercu = false) {
    l = statut_cols * pas - jeu_bloc;
    h = statut_rangees * pas - jeu_bloc;
    poche = k == statut_local && groupe_mode == "plaquette";
    L = (k == statut_local && !poche && local_statut != "") ? concat(statuts[k], [local_statut]) : statuts[k];
    px = (l - plaquette_l) / 2;
    py = 3;
    zone0 = poche ? py + plaquette_w + 2 * jeu_poche + 1.5 : 2;
    color(couleur_bloc) difference() {
        plaque_fixee(statut_cols, statut_rangees, bloc_h, r = 2,
                        cols = statut_plots_cols, rangs = nom_plots_rangees);
        if (poche) translate([px, py, bloc_h]) poche_plaquette(plaquette_e);
    }
    color(couleur_texte_bloc) translate([l / 2, (zone0 + h - 2) / 2, bloc_h - 0.01])
        linear_extrude(texte_h + 0.01) lignes_texte(L, statut_texte_s, l - 5, h - 2 - zone0);
    if (poche && apercu)
        translate([px, py, bloc_h - plaquette_e]) plaquette(local_statut);
}

module statuts_a_plat() {
    for (k = [0 : len(statuts) - 1])
        translate([(k % 2) * (statut_cols * pas + 5), floor(k / 2) * (statut_rangees * pas + 5), 0])
            plaque_statut(k);
}

// =============================================================================
//  Horaire : validation et placement
//  entrée = [jour, debut, duree, lignes, plaquette, couleur]
// =============================================================================
function chevauche(a, b) = a[0] == b[0] && a[1] < b[1] + b[2] && b[1] < a[1] + a[2];

module verifier_horaire(hor) {
    for (i = [0 : len(hor) - 1]) {
        e = hor[i];
        assert(e[1] >= heure_debut && e[1] + e[2] <= heure_fin,
               str("Bloc ", i, " : hors de la plage ", heure_debut, "h–", heure_fin, "h"));
        assert(e[1] * 2 == round(e[1] * 2), str("Bloc ", i, " : début pas sur une demi-heure"));
        if (trou_actif)
            assert(!chevauche(e, [trou_jour, trou_debut, trou_duree]),
                   str("Bloc ", i, " (", e[3][0], ") chevauche le trou horaire"));
        for (j = [0 : len(hor) - 1])
            if (j > i) assert(!chevauche(e, hor[j]), str("Blocs ", i, " et ", j, " se chevauchent"));
    }
}

module placer_bloc(e) {
    translate([x_jour(e[0]) + jeu_bloc / 2, y_heure(e[1] + e[2]) + jeu_bloc / 2, base_e])
        bloc(e[2], e[3], e[4], apercu = true, couleur = couleurs_par_cours ? e[5] : couleur_bloc);
}

// Tous les blocs d'un horaire, disposés à plat pour l'impression (4 par rangée).
module blocs_a_plat(hor, par_rangee = 4) {
    Lmax = max([for (e = hor) bloc_L(e[2])]);
    for (i = [0 : len(hor) - 1])
        translate([(i % par_rangee) * (jour_l * pas + 5), floor(i / par_rangee) * (Lmax + 5), 0])
            bloc(hor[i][2], hor[i][3], hor[i][4]);
}

module plaquettes_a_plat(hor) {
    P = [for (e = hor) if (e[4] != "" && bloc_a_poche(e[2], e[4])) e[4]];
    tous = concat(P, [local_statut]);
    for (i = [0 : len(tous) - 1])
        translate([(i % 4) * (plaquette_l + 4), floor(i / 4) * (plaquette_w + 4), 0])
            plaquette(tous[i]);
}

// Vue assemblée.
module assemblage(hor, nom, sous_titre = "") {
    color(couleur_base) base(-1, deco = false);
    color(couleur_texte_base) translate([0, 0, base_e]) linear_extrude(texte_h) base_textes_2d();
    if (trou_actif) bloc_trou();
    for (e = hor) placer_bloc(e);
    translate([nom_x0() + jeu_bloc / 2, nom_y0() + jeu_bloc / 2, base_e])
        plaque_nom(nom, sous_titre);
    translate([statut_x0() + jeu_bloc / 2, statut_y0() + jeu_bloc / 2, base_e])
        plaque_statut(statut_affiche, apercu = true);
}

// Informations utiles pour l'impression (affichées dans la console).
module infos() {
    cs = coupes();
    echo(str("Plaque de base : ", W(), " × ", H(), " mm, ", nb_tuiles(), " tuile(s)"));
    for (k = [0 : len(cs) - 2])
        echo(str("  tuile ", k, " : y ", cs[k], " → ", cs[k + 1], "  (", W(), " × ", cs[k + 1] - cs[k], " mm)"));
    relief = fixation == "tasseau" ? tas_h : plot_h;
    echo(str("Base : ", base_style, ", fixation : ", fixation));
    echo(str("Pauses couleur base : Z=", base_e, " (texte), Z=", base_e + texte_h,
             " (retour), Z=", base_e + trou_bosse, " (texte du trou horaire)"));
    if (trou_bosse < relief)
        echo("ATTENTION : trou_bosse < relief des fixations, la 3e pause colorera leur sommet");
    if (fixation == "tasseau")
        assert(tas_vide_h() < pas - 1.5, "Rainure trop haute pour le pas : réduire tas_t / tas_h");
    echo(str("Pause couleur blocs et statuts : Z=", bloc_h, " ; plaque nom : Z=", plaque_h,
             " ; plaquettes : Z=", plaquette_e));
    assert(W() <= lit_utile(), str("Largeur ", W(), " mm > plateau : réduire pas/jour_l/marge"));
}

// Sélecteur de pièce commun.
module rendu(part, hor, nom, sous_titre = "", index = 0, tuile = 0,
             duree = 3, lignes = ["420-5N6-EM"], plaq = "Gr. 1010") {
    infos();
    if (len(hor) > 0) verifier_horaire(hor);
    if      (part == "assemblage")  assemblage(hor, nom, sous_titre);
    else if (part == "base")        base(-1);
    else if (part == "tuile")       base(tuile);
    else if (part == "eclisse")     eclisse();
    else if (part == "bloc")        bloc(hor[index][2], hor[index][3], hor[index][4]);
    else if (part == "blocs")       blocs_a_plat(hor);
    else if (part == "module")      bloc(duree, lignes, plaq);
    else if (part == "dispo")       bloc(duree, ["Dispo"], plaq);
    else if (part == "plaquette")   plaquette(plaq);
    else if (part == "plaquettes")  plaquettes_a_plat(hor);
    else if (part == "plaque_nom")  plaque_nom(nom, sous_titre);
    else if (part == "statut")      plaque_statut(index);
    else if (part == "statuts")     statuts_a_plat();
    else echo(str("Pièce inconnue : ", part));
}
