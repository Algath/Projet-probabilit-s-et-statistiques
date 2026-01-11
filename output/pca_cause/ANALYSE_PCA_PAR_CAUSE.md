# Analyse PCA par Cause de Décès

## Objectif

Réaliser une analyse en composantes principales (PCA) séparée pour chaque cause de décès afin d'identifier l'impact des variables environnementales et des médicaments sur chaque cause.

## Méthodologie

- **Données analysées :**
  - Années : 2000 à 2020
  - Causes : Circulatoire, Respiratoire, Cancer, Infectieux
  - Variables :
    - Décès par cause
    - Médicaments associés
    - Pollution (PM2.5, PM10 immission, PM10 émission)
    - Radiation

- **Étapes :**
  1. Préparation des données (fusion, renommage, filtrage)
  2. Standardisation des variables
  3. PCA séparée pour chaque cause
  4. Visualisation des résultats

## Graphiques générés

- `pca_par_cause_biplots.png` : Biplots PCA pour chaque cause
- `pca_par_cause_loadings.png` : Barres de contribution des variables à PC1
- `pca_par_cause_temporal.png` : Évolution temporelle du score PC1 pour chaque cause
- `pca_par_cause_temporal_detail.png` : Évolution PC1 et PC2 par cause (subplots)
- `pca_par_cause_heatmap_comparison.png` : Heatmap de comparaison de l'impact des variables environnementales

## Interprétation

- **Biplots** : Visualisent la relation entre les années et les variables principales pour chaque cause.
- **Barres de contribution** : Identifient les variables les plus associées (positivement ou négativement) à chaque cause.
- **Évolution temporelle** : Permet de voir comment le score principal (PC1) évolue au fil des années pour chaque cause.
- **Heatmap de comparaison** : Compare l'impact des variables environnementales sur chaque cause.

## Résultats principaux

- Les variables environnementales et les médicaments n'impactent pas toutes les causes de la même façon.
- Les scores PC1 et PC2 permettent d'identifier les années atypiques ou les tendances fortes.
- Les variables les plus associées à chaque cause sont listées dans le résumé du script.

## Fichiers de données

- `pca_par_cause_loadings.csv` : Loadings numériques par cause et variable
- `pca_par_cause_comparison.csv` : Tableau comparatif des loadings environnementaux

## Limites

- Analyse limitée aux variables disponibles et à la période 2000-2020
- Les résultats dépendent de la qualité et de la représentativité des données

## Reproduction

Script principal : `pca_cause.jl`

---

*Dernière mise à jour : 11 janvier 2026*