# Installation des packages nécessaires pour les 3 fichiers Julia
# Exécuter ce script une seule fois pour installer toutes les dépendances

import Pkg

# Packages communs aux 3 fichiers
Pkg.add("CSV")
Pkg.add("DataFrames")

# Packages supplémentaires pour medoc.jl et years_quantity.jl
Pkg.add("HypertextLiteral")
Pkg.add("XLSX")
Pkg.add("PyPlot")
Pkg.add("StatsBase")

println("✓ Tous les packages ont été installés avec succès!")
