# Analyse PCA : Corrélations entre Décès, Médicaments, Pollution et Radiation

## 📋 Table des matières
1. [Objectif de l'analyse](#objectif)
2. [Données utilisées](#données)
3. [Méthodologie](#méthodologie)
4. [Lecture des résultats](#résultats)
5. [Interprétation des graphiques](#graphiques)
6. [Conclusions](#conclusions)

---

## 1. Objectif de l'analyse {#objectif}

L'objectif est de déterminer s'il existe des **corrélations** entre :
- Le **nombre de décès annuels** (par cause : circulatoire, respiratoire, cancer, infectieux)
- La **production/autorisation de médicaments** (par catégorie thérapeutique)
- La **pollution atmosphérique** (particules fines PM10, PM2.5)
- La **radiation solaire**

### Questions de recherche
- Les années avec plus de pollution ont-elles plus de décès ?
- Y a-t-il un lien entre le nombre de médicaments autorisés et les décès ?
- La radiation solaire influence-t-elle les taux de mortalité ?

---

## 2. Données utilisées {#données}

### Période d'analyse
**2000 - 2020** (21 années d'observations)

### Variables analysées

| Catégorie | Variable | Description |
|-----------|----------|-------------|
| 🔴 **Décès** | `death_circulatoire` | Décès par maladies circulatoires |
| 🔴 **Décès** | `death_respiratoire` | Décès par maladies respiratoires |
| 🔴 **Décès** | `death_cancer` | Décès par cancer |
| 🔴 **Décès** | `death_infectieux` | Décès par maladies infectieuses |
| 🟤 **Décès (PM2.5)** | `death_pm25` | Décès attribuables aux PM2.5 |
| 🔵 **Médicaments** | `med_cancer` | Nb médicaments cancer autorisés |
| 🔵 **Médicaments** | `med_circulatoire` | Nb médicaments circulatoires autorisés |
| 🔵 **Médicaments** | `med_infectieux` | Nb médicaments infectieux autorisés |
| 🔵 **Médicaments** | `med_respiratoire` | Nb médicaments respiratoires autorisés |
| 🟠 **Radiation** | `rad_mean` | Radiation solaire moyenne (W/m²) |
| 🟣 **Particules** | `pm10_immission_mean` | Concentration PM10 dans l'air (µg/m³) |
| 🩷 **Particules** | `pm10_emission` | Émissions PM10 territoriales |

---

## 3. Méthodologie {#méthodologie}

### 3.1 Préparation des données

1. **Chargement** des données depuis différentes sources (CSV, Excel)
2. **Fusion** des dataframes sur l'année commune
3. **Standardisation** (z-score) : centrage et réduction des variables
   - Permet de comparer des variables avec des échelles différentes
   - Formule : `z = (x - moyenne) / écart-type`

### 3.2 Analyse en Composantes Principales (PCA)

La PCA est une technique de **réduction de dimensionnalité** qui :
- Transforme les 12 variables originales en nouvelles variables (Composantes Principales)
- Les PC sont **non corrélées** entre elles
- Chaque PC capture une partie de la **variance totale**
- PC1 capture le maximum de variance, PC2 le maximum restant, etc.

### 3.3 Analyse des corrélations

Calcul de la **matrice de corrélation de Pearson** entre :
- Les variables de décès (cibles)
- Les autres variables (explicatives)

Interprétation du coefficient de corrélation (r) :
| Valeur de r | Interprétation |
|-------------|----------------|
| 0.7 à 1.0 | Corrélation **forte** positive |
| 0.4 à 0.7 | Corrélation **modérée** positive |
| 0.0 à 0.4 | Corrélation **faible** positive |
| -0.4 à 0.0 | Corrélation **faible** négative |
| -0.7 à -0.4 | Corrélation **modérée** négative |
| -1.0 à -0.7 | Corrélation **forte** négative |

---

## 4. Lecture des résultats {#résultats}

### 4.1 Variance expliquée par les PC

Le modèle PCA génère typiquement 3-4 composantes principales :

| Composante | Variance expliquée | Cumulative |
|------------|-------------------|------------|
| PC1 | ~60-70% | ~60-70% |
| PC2 | ~15-20% | ~75-85% |
| PC3 | ~5-10% | ~85-95% |
| PC4 | <5% | >90% |

**Interprétation** : Si PC1 + PC2 expliquent >80% de la variance, ces deux composantes suffisent pour comprendre les principales relations entre variables.

### 4.2 Signification des Composantes Principales

Chaque PC est une **combinaison linéaire** des variables originales. Les **loadings** indiquent le poids de chaque variable dans la composante :

- **Loading positif élevé** (>0.3) : La variable contribue positivement à la PC
- **Loading négatif élevé** (<-0.3) : La variable contribue négativement à la PC
- **Loading proche de 0** : La variable n'influence pas cette PC

#### Exemple d'interprétation :
- Si PC1 a des loadings positifs pour décès ET particules → **Les années avec plus de pollution ont plus de décès**
- Si PC2 a des loadings positifs pour médicaments → **PC2 représente la tendance d'autorisation de médicaments**

---

## 5. Interprétation des graphiques {#graphiques}

### 📊 `correlation_heatmap.png`

**Description** : Matrice de corrélation entre les variables de décès (lignes) et les autres variables (colonnes).

**Comment lire** :
- Couleur **rouge** = corrélation positive (quand l'un augmente, l'autre aussi)
- Couleur **bleu** = corrélation négative (quand l'un augmente, l'autre diminue)
- Valeur **proche de ±1** = corrélation forte
- Valeur **proche de 0** = pas de corrélation

**Ce qu'il faut chercher** :
- Cases rouges foncées entre décès et pollution → La pollution pourrait causer des décès
- Cases bleues entre décès et médicaments → Plus de médicaments = moins de décès ?

---

### 📊 `pca_biplot_interpretation.png`

**Description** : Projection des années et des variables dans l'espace PC1-PC2.

**Comment lire** :
- **Points gris** = années (2000-2020)
- **Flèches colorées** = direction et force de chaque variable
- **Variables proches** = corrélées positivement
- **Variables opposées** = corrélées négativement
- **Variables perpendiculaires** = non corrélées

**Interprétation des positions** :
- Si décès (rouge) et particules (violet) pointent dans la **même direction** → Corrélation positive
- Si médicaments (bleu) pointe dans la **direction opposée** aux décès → Corrélation négative
- La **longueur** de la flèche indique l'importance de la variable

**Interprétation des années** :
- Années proches = comportement similaire
- Années éloignées = comportement différent
- Tendance temporelle visible si les années se déplacent progressivement

---

### 📊 `pca_temporal_evolution.png`

**Description** : Évolution des scores PCA au fil des années (2000-2020).

**Comment lire** :
- Axe X = années
- Axe Y = score de la composante principale
- Ligne pointillée à 0 = moyenne

**Ce qu'il faut chercher** :
- **Tendance croissante/décroissante** → Évolution systématique
- **Pics ou creux** → Années atypiques
- **Stabilité** → Pas de changement significatif

**Interprétation selon le titre du graphique** :
- Si le titre indique "Décès + Particules" et la courbe descend → Diminution des décès ET de la pollution au fil du temps

---

### 📊 `pca_loadings_bars.png`

**Description** : Contribution de chaque variable à chaque composante principale (barres horizontales).

**Comment lire** :
- Barres vers la **droite** (positives) = contribution positive à la PC
- Barres vers la **gauche** (négatives) = contribution négative à la PC
- **Longueur** de la barre = force de la contribution
- **Couleur** = catégorie de la variable

**Ce qu'il faut chercher** :
- Variables de la **même couleur** du même côté → Ces variables évoluent ensemble
- Variables de **couleurs différentes** du même côté → Corrélation entre catégories
- Variables **opposées** → Évolution inverse

---

### 📊 Fichiers CSV de sortie

| Fichier | Contenu | Utilisation |
|---------|---------|-------------|
| `correlations_deces_autres.csv` | Toutes les corrélations calculées | Identifier les relations significatives |
| `pca_loadings.csv` | Poids de chaque variable dans les PC | Interpréter les composantes |
| `pca_projections.csv` | Coordonnées de chaque année dans l'espace PCA | Identifier les années atypiques |

---

## 6. Conclusions {#conclusions}

### Comment interpréter les résultats ?

#### ✅ Corrélation POSITIVE forte (r > 0.7) entre décès et pollution :
→ **Les années avec plus de pollution ont significativement plus de décès**
→ Suggère un impact de la pollution sur la mortalité

#### ✅ Corrélation NÉGATIVE forte (r < -0.7) entre décès et médicaments :
→ **Plus de médicaments autorisés = moins de décès**
→ Suggère une efficacité des traitements

#### ⚠️ Corrélation FAIBLE (|r| < 0.4) :
→ **Pas de relation linéaire significative**
→ La variable n'explique pas directement les décès

### ⚠️ Limitations importantes

1. **Corrélation ≠ Causalité**
   - Une corrélation ne prouve pas que A cause B
   - Il peut y avoir des variables confondantes

2. **Petit échantillon**
   - 21 observations (années) = résultats indicatifs
   - Intervalles de confiance larges

3. **Décalage temporel**
   - La pollution de l'année N peut affecter la santé en N+1, N+2...
   - Non pris en compte dans cette analyse

4. **Variables confondantes possibles**
   - Vieillissement de la population
   - Amélioration des soins médicaux
   - Changements de mode de vie

---

## Annexe : Code couleur des graphiques

| Couleur | Catégorie | Variables concernées |
|---------|-----------|---------------------|
| 🔴 Rouge | Décès | death_circulatoire, death_respiratoire, death_cancer, death_infectieux |
| 🟤 Rouge foncé | Décès (PM2.5) | death_pm25 |
| 🔵 Bleu | Médicaments | med_cancer, med_circulatoire, med_infectieux, med_respiratoire |
| 🟠 Orange | Radiation | rad_mean |
| 🟣 Violet | Particules (immission) | pm10_immission_mean |
| 🩷 Magenta | Particules (émission) | pm10_emission |

---

*Rapport généré automatiquement - Analyse PCA Julia*
