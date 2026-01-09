include("imports_pollution.jl")

df_pollution = DataFrame(XLSX.readtable("données/pollution/Atteintes santé pollution atmosphérique PM2_5.xlsx", 2, first_row=8))
df_particules_PM10 = DataFrame(XLSX.readtable("données/poussière/Emission poussières fines.xlsx", 2, first_row=8))
df_particules = DataFrame(XLSX.readtable("données/poussière/Immissions poussières fines PM10.xlsx", 2, first_row=8))

"pca pollution, médicament, décès annuels"