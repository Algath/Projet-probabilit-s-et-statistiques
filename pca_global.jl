include("imports/imports_pca_global.jl")

function safe_rename!(df::DataFrame, old::String, new::String)
    if old ∈ names(df)
        rename!(df, old => new)
    end
end

df_pollution = DataFrame(XLSX.readtable("données/pollution/Atteintes santé pollution atmosphérique PM2_5.xlsx", 4, first_row=8))
df_particules_PM10 = DataFrame(XLSX.readtable("données/poussière/Emission poussières fines.xlsx", 4, first_row=8))
df_particules = DataFrame(XLSX.readtable("données/poussière/Immissions poussières fines PM10.xlsx", 4, first_row=8))
df_rad = CSV.read("données/RAD.csv", DataFrame; delim=';', header=5)
df_death = CSV.read("données/grouped_data_mortalité.csv", DataFrame) # death by year and cause
df_cancer = CSV.read("output/df_quantity/df_cancer_par_annee.csv", DataFrame) # number of cancer Medicaments by year
df_circulatoire = CSV.read("output/df_quantity/df_circulatoire_par_annee.csv", DataFrame) # number of circulatory Medicaments by year
df_infectieux = CSV.read("output/df_quantity/df_infectieuses_par_annee.csv", DataFrame) # number of infectious Medicaments by year
df_respiratoire = CSV.read("output/df_quantity/df_respiratoire_par_annee.csv", DataFrame) # number of respiratory Medicaments by year

"pca pollution, médicament, décès annuels, radiation, particules"

# ============================================
# ÉTAPE 1: Standardiser les noms de colonnes
# ============================================

safe_rename!(df_rad, "Date/time", "year")
safe_rename!(df_cancer, "annee", "year")
safe_rename!(df_circulatoire, "annee", "year")
safe_rename!(df_infectieux, "annee", "year")
safe_rename!(df_respiratoire, "annee", "year")

# Renommer les colonnes de médicaments pour éviter les conflits
rename!(df_cancer, "nombre_medicaments" => "med_cancer")
rename!(df_circulatoire, "nombre_medicaments" => "med_circulatoire")
rename!(df_infectieux, "nombre_medicaments" => "med_infectieux")
rename!(df_respiratoire, "nombre_medicaments" => "med_respiratoire")

# ============================================
# ÉTAPE 2: Pivoter df_death (long → wide)
# ============================================

df_death_wide = unstack(df_death, :year, :sector, :deaths_total)
# Renommer les colonnes de décès
rename!(df_death_wide, 
    "Appareil circulatoire" => "death_circulatoire",
    "Appareil respiratoire" => "death_respiratoire", 
    "Cancer" => "death_cancer",
    "Maladies infectieuses (sans COVID-19)" => "death_infectieux"
)

# ============================================
# ÉTAPE 3: Agréger df_rad (moyenne des stations)
# ============================================

# Convertir year en Int si nécessaire
df_rad.year = parse.(Int, string.(df_rad.year))

# Calculer la moyenne de radiation par année (toutes stations)
station_cols = names(df_rad)[2:end]  # Toutes sauf "year"
df_rad_agg = DataFrame(
    year = df_rad.year,
    rad_mean = [mean(skipmissing(collect(row[station_cols]))) for row in eachrow(df_rad)]
)

# ============================================
# ÉTAPE 4: Préparer df_pollution et df_particules
# ============================================

# df_pollution: décès prématurés attribuables aux PM2.5
rename!(df_pollution, "Year" => "year", 
    "Premature deaths attributable to particulate matter PM2.5" => "death_pm25")
df_pollution.year = Int64.(df_pollution.year)

# df_particules: immissions PM10 par zone
rename!(df_particules, "Year" => "year")
df_particules.year = Int64.(df_particules.year)
# Calculer la moyenne des zones (exclure "Imission limit value")
zone_cols = ["urban, heavy traffic", "urban", "suburban", "rural", "pre-alpine/Jura range"]
df_particules_agg = DataFrame(
    year = df_particules.year,
    pm10_immission_mean = [mean(Float64.(collect(row[zone_cols]))) for row in eachrow(df_particules)]
)

# df_particules_PM10: émissions totales PM10
rename!(df_particules_PM10, "Year" => "year", 
    "PM10 Emissionen (territorial)" => "pm10_emission")
df_particules_PM10.year = Int64.(df_particules_PM10.year)

# ============================================
# ÉTAPE 5: Fusionner tous les DataFrames
# ============================================

# Convertir toutes les colonnes year en Int64
for df in [df_death_wide, df_cancer, df_circulatoire, df_infectieux, df_respiratoire, df_rad_agg]
    df.year = Int64.(df.year)
end

# Fusion successive
df_combined = innerjoin(df_death_wide, df_cancer, on=:year)
df_combined = innerjoin(df_combined, df_circulatoire, on=:year)
df_combined = innerjoin(df_combined, df_infectieux, on=:year)
df_combined = innerjoin(df_combined, df_respiratoire, on=:year)
df_combined = innerjoin(df_combined, df_rad_agg, on=:year)
df_combined = innerjoin(df_combined, df_pollution, on=:year)
df_combined = innerjoin(df_combined, df_particules_agg, on=:year)
df_combined = innerjoin(df_combined, df_particules_PM10[!, [:year, :pm10_emission]], on=:year)

# Filtrer pour garder uniquement 2000-2020
df_combined = filter(row -> 2000 ≤ row.year ≤ 2020, df_combined)
sort!(df_combined, :year)

println("\n✓ DataFrame combiné: $(nrow(df_combined)) lignes, $(ncol(df_combined)) colonnes")
println("Colonnes: ", names(df_combined))

# ============================================
# ÉTAPE 6: Préparation des données pour PCA
# ============================================

# Sélectionner uniquement les colonnes numériques (exclure year)
numeric_cols = filter(c -> c != "year", names(df_combined))

# Définir les catégories de variables avec couleurs
variable_categories = Dict(
    "death_circulatoire" => ("Décès", :red),
    "death_respiratoire" => ("Décès", :red),
    "death_cancer" => ("Décès", :red),
    "death_infectieux" => ("Décès", :red),
    "death_pm25" => ("Décès (PM2.5)", :darkred),
    "med_cancer" => ("Médicaments", :blue),
    "med_circulatoire" => ("Médicaments", :blue),
    "med_infectieux" => ("Médicaments", :blue),
    "med_respiratoire" => ("Médicaments", :blue),
    "rad_mean" => ("Radiation", :orange),
    "pm10_immission_mean" => ("Particules (immission)", :purple),
    "pm10_emission" => ("Particules (émission)", :magenta)
)

variable_descriptions = Dict(
    "death_circulatoire" => "Décès maladies circulatoires",
    "death_respiratoire" => "Décès maladies respiratoires",
    "death_cancer" => "Décès par cancer",
    "death_infectieux" => "Décès maladies infectieuses",
    "death_pm25" => "Décès attribuables aux PM2.5",
    "med_cancer" => "Nb médicaments cancer",
    "med_circulatoire" => "Nb médicaments circulatoires",
    "med_infectieux" => "Nb médicaments infectieux",
    "med_respiratoire" => "Nb médicaments respiratoires",
    "rad_mean" => "Radiation solaire (W/m²)",
    "pm10_immission_mean" => "Concentration PM10 (µg/m³)",
    "pm10_emission" => "Émissions PM10"
)

# Convertir en matrice (observations en colonnes pour MultivariateStats)
data_matrix = Matrix(df_combined[!, numeric_cols])'  # Transposer: variables en lignes, observations en colonnes

# Standardisation manuelle (z-score)
data_standardized = (data_matrix .- mean(data_matrix, dims=2)) ./ std(data_matrix, dims=2)

# ============================================
# ÉTAPE 7: PCA sur toutes les données
# ============================================

# Fit PCA sur toutes les données (pas de split train/test)
M = fit(PCA, data_standardized; maxoutdim=4, pratio=0.99)

println("\n========== MODÈLE PCA ==========")
println(M)

# Projeter toutes les données
Y_all = predict(M, data_standardized)
years_all = df_combined.year

# ============================================
# ÉTAPE 8: Analyse des loadings (ce que représente chaque PC)
# ============================================

loadings_matrix = loadings(M)
vars = principalvars(M)
n_pc = size(loadings_matrix, 2)

println("\n" * "="^70)
println("INTERPRÉTATION DES COMPOSANTES PRINCIPALES")
println("="^70)

for pc in 1:n_pc
    var_pct = round(vars[pc] / sum(vars) * 100, digits=1)
    println("\n🔹 PC$pc (explique $var_pct% de la variance)")
    println("-"^50)
    
    # Trier les loadings par valeur absolue
    sorted_idx = sortperm(abs.(loadings_matrix[:, pc]), rev=true)
    
    println("Variables les plus influentes:")
    for (rank, idx) in enumerate(sorted_idx)
        loading = loadings_matrix[idx, pc]
        var_name = numeric_cols[idx]
        cat_name = variable_categories[var_name][1]
        desc = variable_descriptions[var_name]
        
        direction = loading > 0 ? "+" : "-"
        println("  $rank. $var_name ($cat_name): $direction$(round(abs(loading), digits=3)) → $desc")
    end
end

# ============================================
# ÉTAPE 9: Matrice de corrélation (Décès vs Autres)
# ============================================

println("\n" * "="^70)
println("MATRICE DE CORRÉLATION - Décès vs Autres variables")
println("="^70)

# Variables de décès
death_vars = ["death_circulatoire", "death_respiratoire", "death_cancer", "death_infectieux", "death_pm25"]
# Autres variables
other_vars = ["med_cancer", "med_circulatoire", "med_infectieux", "med_respiratoire", "rad_mean", "pm10_immission_mean", "pm10_emission"]

# Calculer la matrice de corrélation complète
data_for_cor = Matrix(df_combined[!, numeric_cols])
cor_matrix = cor(data_for_cor)

# Créer un DataFrame de corrélation Décès vs Autres
println("\nCorrélations entre DÉCÈS et autres variables:")
println("-"^70)

cor_results = []
for dvar in death_vars
    d_idx = findfirst(==(dvar), numeric_cols)
    for ovar in other_vars
        o_idx = findfirst(==(ovar), numeric_cols)
        r = cor_matrix[d_idx, o_idx]
        push!(cor_results, (
            Décès = dvar,
            Variable = ovar,
            Corrélation = round(r, digits=3),
            Force = abs(r) > 0.7 ? "FORTE" : (abs(r) > 0.4 ? "Modérée" : "Faible")
        ))
    end
end

df_correlations = DataFrame(cor_results)
sort!(df_correlations, :Corrélation, rev=true)
CSV.write("output/pca_global/correlations_deces_autres.csv", df_correlations)
println("✓ Corrélations sauvegardées dans output/pca_global/correlations_deces_autres.csv")

# Afficher les corrélations les plus fortes
println("\n📊 TOP 10 CORRÉLATIONS LES PLUS FORTES:")
for (i, row) in enumerate(eachrow(first(df_correlations, 10)))
    println("  $i. $(row.Décès) ↔ $(row.Variable): $(row.Corrélation) ($(row.Force))")
end

println("\n📊 TOP 10 CORRÉLATIONS LES PLUS NÉGATIVES:")
df_neg = sort(df_correlations, :Corrélation)
for (i, row) in enumerate(eachrow(first(df_neg, 10)))
    println("  $i. $(row.Décès) ↔ $(row.Variable): $(row.Corrélation) ($(row.Force))")
end

# ============================================
# ÉTAPE 10: Visualisations
# ============================================

# 10.1 Heatmap des corrélations Décès vs Autres
death_indices = [findfirst(==(v), numeric_cols) for v in death_vars]
other_indices = [findfirst(==(v), numeric_cols) for v in other_vars]
cor_subset = cor_matrix[death_indices, other_indices]

# Labels courts pour lisibilité
death_labels = ["Circulatoire", "Respiratoire", "Cancer", "Infectieux", "PM2.5"]
other_labels = ["Med.Cancer", "Med.Circ.", "Med.Infect.", "Med.Resp.", "Radiation", "PM10.Immis.", "PM10.Emis."]

p_heatmap = heatmap(other_labels, death_labels, cor_subset,
    title="Corrélations: Décès vs Médicaments/Pollution/Radiation",
    color=:RdBu,
    clim=(-1, 1),
    size=(900, 550),
    xrotation=45,
    bottom_margin=15Plots.mm,
    left_margin=10Plots.mm,
    annotate=[(j, i, text(string(round(cor_subset[i,j], digits=2)), 8, :black)) 
              for i in 1:length(death_labels), j in 1:length(other_labels)]
)
savefig(p_heatmap, "output/pca_global/correlation_heatmap.png")
println("\n✓ Heatmap des corrélations sauvegardée dans output/pca_global/correlation_heatmap.png")

# 10.2 Biplot avec interprétation des PC
p_biplot = plot(
    xlabel="PC1 ($(round(vars[1]/sum(vars)*100, digits=1))% variance)\n← Moins de décès/pollution | Plus de décès/pollution →",
    ylabel="PC2 ($(round(vars[2]/sum(vars)*100, digits=1))% variance)\n← Moins de médicaments | Plus de médicaments →",
    title="PCA Biplot - Relations entre Décès, Médicaments et Pollution",
    size=(1200, 900),
    legend=:outertopright,
    left_margin=15Plots.mm,
    bottom_margin=15Plots.mm,
    top_margin=10Plots.mm,
    right_margin=10Plots.mm,
    tickfontsize=10,
    guidefontsize=11,
    titlefontsize=13
)

# Points pour chaque année
scatter!(p_biplot, Y_all[1,:], Y_all[2,:],
    label="Années",
    marker=:circle,
    markersize=8,
    markercolor=:gray,
    alpha=0.6
)

# Annoter avec les années
for (i, yr) in enumerate(years_all)
    annotate!(p_biplot, Y_all[1,i], Y_all[2,i], text(string(yr), 8, :bottom))
end

# Ajouter les vecteurs des variables avec couleurs par catégorie
scale_factor = 3
categories_drawn = Set{String}()

for (i, col) in enumerate(numeric_cols)
    cat_info = variable_categories[col]
    cat_name = cat_info[1]
    cat_color = cat_info[2]
    
    show_label = !(cat_name in categories_drawn)
    if show_label
        push!(categories_drawn, cat_name)
    end
    
    # Flèche
    quiver!(p_biplot, [0], [0], 
        quiver=([loadings_matrix[i,1] * scale_factor], [loadings_matrix[i,2] * scale_factor]),
        color=cat_color,
        linewidth=2,
        label=show_label ? cat_name : ""
    )
    
    # Label de la variable (version courte)
    short_name = replace(col, "death_" => "D:", "med_" => "M:", "_mean" => "", "pm10_" => "PM10:")
    annotate!(p_biplot, 
        loadings_matrix[i,1] * scale_factor * 1.15, 
        loadings_matrix[i,2] * scale_factor * 1.15, 
        text(short_name, 7, cat_color)
    )
end

savefig(p_biplot, "output/pca_global/pca_biplot_interpretation.png")
println("✓ Biplot interprété sauvegardé dans output/pca_global/pca_biplot_interpretation.png")

# 10.3 Évolution temporelle des PC
p_temporal = plot(layout=(n_pc, 1), size=(1200, 350*n_pc), 
    left_margin=20Plots.mm,
    bottom_margin=10Plots.mm,
    top_margin=5Plots.mm,
    legend=:outertopright
)

for pc in 1:n_pc
    var_pct = round(vars[pc]/sum(vars)*100, digits=1)
    
    # Trouver les variables dominantes pour ce PC
    sorted_idx = sortperm(abs.(loadings_matrix[:, pc]), rev=true)
    top_vars = [numeric_cols[idx] for idx in sorted_idx[1:3]]
    top_cats = [variable_categories[v][1] for v in top_vars]
    
    plot!(p_temporal[pc], years_all, Y_all[pc, :],
        label="PC$pc ($var_pct%)",
        xlabel= pc == n_pc ? "Année" : "",
        ylabel="Score PC$pc",
        title="PC$pc: $(join(unique(top_cats), " + "))",
        linewidth=2,
        marker=:circle,
        markersize=5,
        tickfontsize=10,
        guidefontsize=11,
        titlefontsize=12
    )
    hline!(p_temporal[pc], [0], linestyle=:dash, color=:gray, label="")
end

savefig(p_temporal, "output/pca_global/pca_temporal_evolution.png")
println("✓ Évolution temporelle sauvegardée dans output/pca_global/pca_temporal_evolution.png")

# 10.4 Graphique de contribution des variables à chaque PC
p_loadings = plot(layout=(1, n_pc), size=(500*n_pc, 700), 
    bottom_margin=10Plots.mm, 
    left_margin=15Plots.mm,
    top_margin=10Plots.mm
)

for pc in 1:n_pc
    var_pct = round(vars[pc]/sum(vars)*100, digits=1)
    
    # Préparer les données
    sorted_idx = sortperm(loadings_matrix[:, pc])
    sorted_loadings = loadings_matrix[sorted_idx, pc]
    sorted_names = [numeric_cols[i] for i in sorted_idx]
    colors = [variable_categories[n][2] for n in sorted_names]
    
    # Labels plus courts pour lisibilité
    short_names = [replace(replace(replace(n, "death_" => "Décès: "), "med_" => "Méd: "), "_mean" => "") for n in sorted_names]
    short_names = [replace(n, "pm10_immission" => "PM10 immission") for n in short_names]
    short_names = [replace(n, "pm10_emission" => "PM10 émission") for n in short_names]
    short_names = [replace(n, "rad" => "Radiation") for n in short_names]
    
    bar!(p_loadings[pc], sorted_loadings,
        orientation=:horizontal,
        yticks=(1:length(short_names), short_names),
        xlabel="Coefficient de loading\n(contribution à la composante)",
        ylabel= pc == 1 ? "Variables" : "",
        title="PC$pc ($var_pct% variance)",
        color=colors,
        legend=false,
        tickfontsize=9,
        guidefontsize=10,
        titlefontsize=11,
        xlims=(-0.6, 0.6)
    )
    vline!(p_loadings[pc], [0], color=:black, linewidth=1, label="")
end

# Ajouter une légende générale pour les couleurs
p_legend_colors = plot(
    framestyle=:none,
    legend=:topleft,
    legendfontsize=10,
    size=(300, 200)
)
scatter!(p_legend_colors, [], [], color=:red, label="Décès", markersize=10)
scatter!(p_legend_colors, [], [], color=:blue, label="Médicaments", markersize=10)
scatter!(p_legend_colors, [], [], color=:orange, label="Radiation", markersize=10)
scatter!(p_legend_colors, [], [], color=:purple, label="Particules (immission)", markersize=10)
scatter!(p_legend_colors, [], [], color=:magenta, label="Particules (émission)", markersize=10)

# Combiner le graphique principal avec la légende
p_loadings_final = plot(p_loadings, p_legend_colors, 
    layout=@layout([a{0.85w} b{0.15w}]),
    size=(500*n_pc + 200, 700)
)

savefig(p_loadings_final, "output/pca_global/pca_loadings_bars.png")
println("✓ Graphique des loadings sauvegardé dans output/pca_global/pca_loadings_bars.png")

# ============================================
# ÉTAPE 11: Sauvegarder les résultats
# ============================================

# Loadings avec interprétation
df_loadings = DataFrame(
    Variable = numeric_cols,
    Catégorie = [variable_categories[col][1] for col in numeric_cols],
    Description = [variable_descriptions[col] for col in numeric_cols]
)
for pc in 1:n_pc
    df_loadings[!, "PC$pc"] = round.(loadings_matrix[:, pc], digits=4)
end
CSV.write("output/pca_global/pca_loadings.csv", df_loadings)
println("✓ Loadings sauvegardés dans output/pca_global/pca_loadings.csv")

# Projections par année
df_projections = DataFrame(year = years_all)
for pc in 1:n_pc
    df_projections[!, "PC$pc"] = Y_all[pc, :]
end
CSV.write("output/pca_global/pca_projections.csv", df_projections)
println("✓ Projections sauvegardées dans output/pca_global/pca_projections.csv")

# Résumé des PC
println("\n" * "="^70)
println("RÉSUMÉ: CE QUE REPRÉSENTE CHAQUE COMPOSANTE PRINCIPALE")
println("="^70)

for pc in 1:n_pc
    var_pct = round(vars[pc]/sum(vars)*100, digits=1)
    sorted_idx = sortperm(abs.(loadings_matrix[:, pc]), rev=true)
    
    # Variables positives et négatives dominantes
    pos_vars = [(numeric_cols[i], variable_categories[numeric_cols[i]][1]) 
                for i in sorted_idx if loadings_matrix[i, pc] > 0.2]
    neg_vars = [(numeric_cols[i], variable_categories[numeric_cols[i]][1]) 
                for i in sorted_idx if loadings_matrix[i, pc] < -0.2]
    
    println("\n🔹 PC$pc ($var_pct% de variance):")
    if !isempty(pos_vars)
        pos_cats = unique([v[2] for v in pos_vars])
        println("   (+) Corrélé positivement avec: $(join(pos_cats, ", "))")
    end
    if !isempty(neg_vars)
        neg_cats = unique([v[2] for v in neg_vars])
        println("   (-) Corrélé négativement avec: $(join(neg_cats, ", "))")
    end
end

println("\n" * "="^70)
println("FICHIERS GÉNÉRÉS DANS output/")
println("="^70)
println("  • correlation_heatmap.png      - Heatmap Décès vs Autres")
println("  • correlations_deces_autres.csv - Tableau des corrélations")
println("  • pca_biplot_interpretation.png - Biplot avec catégories colorées")
println("  • pca_temporal_evolution.png   - Évolution des PC par année")
println("  • pca_loadings_bars.png        - Contribution des variables")
println("  • pca_loadings.csv             - Loadings numériques")
println("  • pca_projections.csv          - Scores PCA par année")