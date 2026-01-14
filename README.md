# Projet Analyse Santé

## Présentation
Ce projet vise à analyser les données de santé, notamment la mortalité, la pollution, les médicaments et d'autres indicateurs, sur plusieurs années. L'objectif est d'explorer les relations entre différentes causes de mortalité, la consommation de médicaments, la pollution et d'autres facteurs, à l'aide d'analyses statistiques et de méthodes telles que l'ACP (Analyse en Composantes Principales).

## Structure du projet

```
├── analyse_annees.jl                # Analyse des données par années
├── medoc.jl                         # Analyse des données liées aux médicaments
├── pca_cause.jl                     # ACP par cause de mortalité
├── pca_global.jl                    # ACP globale sur l'ensemble des données
├── setup.jl                         # Script de configuration et d'import des données
├── years_quantity.jl                # Analyse des quantités par année
├── données/                         # Dossier contenant les données brutes et groupées
│   ├── causes_mortalité.csv         # Causes de mortalité
│   ├── grouped_data_mortalité.csv   # Données groupées sur la mortalité
│   ├── RAD.csv                      # Données RAD
│   ├── medicament/                  # Données sur les médicaments
│   ├── pollution/                   # Données sur la pollution
│   └── poussière/                   # Données sur la poussière
├── imports/                         # Scripts d'importation pour chaque analyse
│   ├── imports_analyse_annees.jl
│   ├── imports_medoc.jl
│   ├── imports_pca_global.jl
│   └── imports_years_quantity.jl
├── output/                          # Résultats des analyses
│   ├── df_filtre/                   # Fichiers filtrés
│   ├── df_quantity/                 # Quantités par année et par cause
│   ├── pca_cause/                   # Résultats ACP par cause
│   └── pca_global/                  # Résultats ACP globale
└── Sujet 8 - Santé-20251014/        # Données complémentaires du sujet
    ├── causes_mortalité.csv
    ├── esp_vie.csv
    └── taux_mortalité.csv
```

## Détails
- **Scripts Julia** : Réalisent les analyses statistiques et l'import des données.
- **Dossier `données/`** : Contient toutes les données sources nécessaires aux analyses.
- **Dossier `imports/`** : Scripts pour charger et préparer les données pour chaque analyse spécifique.
- **Dossier `output/`** : Stocke les résultats des analyses, rapports et fichiers intermédiaires.
- **Dossier `Sujet 8 - Santé-20251014/`** : Données complémentaires fournies pour le projet.

## Auteur
Projet réalisé dans le cadre du cours de probabilité/statistiques à la HES-SO.
