include("imports/imports_pca_global.jl")

# ============================================
# PCA PAR CAUSE DE DÉCÈS
# Analyse rigoureuse: PCA sur environnement, puis corrélation avec décès
# ============================================

println("\n" * "="^70)
println("ANALYSE PCA PAR CAUSE DE DÉCÈS")
println("="^70)

# ============================================
# ÉTAPE 1: Charger les données
# ============================================

function safe_rename!(df::DataFrame, old::String, new::String)
    if old ∈ names(df)
        rename!(df, old => new)
    end
end

# Charger les dataframes
df_pollution = DataFrame(XLSX.readtable("données/pollution/Atteintes santé pollution atmosphérique PM2_5.xlsx", 4, first_row=8))
df_particules_PM10 = DataFrame(XLSX.readtable("données/poussière/Emission poussières fines.xlsx", 4, first_row=8))
df_particules = DataFrame(XLSX.readtable("données/poussière/Immissions poussières fines PM10.xlsx", 4, first_row=8))
df_rad = CSV.read("données/RAD.csv", DataFrame; delim=';', header=5)
df_death = CSV.read("données/grouped_data_mortalité.csv", DataFrame)
df_cancer = CSV.read("output/df_quantity/df_cancer_par_annee.csv", DataFrame)
df_circulatoire = CSV.read("output/df_quantity/df_circulatoire_par_annee.csv", DataFrame)
df_infectieux = CSV.read("output/df_quantity/df_infectieuses_par_annee.csv", DataFrame)
df_respiratoire = CSV.read("output/df_quantity/df_respiratoire_par_annee.csv", DataFrame)

# Renommer les colonnes
safe_rename!(df_rad, "Date/time", "year")
safe_rename!(df_cancer, "annee", "year")
safe_rename!(df_circulatoire, "annee", "year")
safe_rename!(df_infectieux, "annee", "year")
safe_rename!(df_respiratoire, "annee", "year")

rename!(df_cancer, "nombre_medicaments" => "med_cancer")
rename!(df_circulatoire, "nombre_medicaments" => "med_circulatoire")
rename!(df_infectieux, "nombre_medicaments" => "med_infectieux")
rename!(df_respiratoire, "nombre_medicaments" => "med_respiratoire")

# Pivoter df_death
df_death_wide = unstack(df_death, :year, :sector, :deaths_total)
rename!(df_death_wide, 
    "Appareil circulatoire" => "death_circulatoire",
    "Appareil respiratoire" => "death_respiratoire", 
    "Cancer" => "death_cancer",
    "Maladies infectieuses (sans COVID-19)" => "death_infectieux"
)

# Agréger df_rad
df_rad.year = parse.(Int, string.(df_rad.year))
station_cols = names(df_rad)[2:end]
df_rad_agg = DataFrame(
    year = df_rad.year,
    rad_mean = [mean(skipmissing(collect(row[station_cols]))) for row in eachrow(df_rad)]
)

# Préparer pollution et particules
rename!(df_pollution, "Year" => "year", 
    "Premature deaths attributable to particulate matter PM2.5" => "death_pm25")
df_pollution.year = Int64.(df_pollution.year)

rename!(df_particules, "Year" => "year")
df_particules.year = Int64.(df_particules.year)
zone_cols = ["urban, heavy traffic", "urban", "suburban", "rural", "pre-alpine/Jura range"]
df_particules_agg = DataFrame(
    year = df_particules.year,
    pm10_immission = [mean(Float64.(collect(row[zone_cols]))) for row in eachrow(df_particules)]
)

rename!(df_particules_PM10, "Year" => "year", 
    "PM10 Emissionen (territorial)" => "pm10_emission")
df_particules_PM10.year = Int64.(df_particules_PM10.year)

# Fusionner
for df in [df_death_wide, df_cancer, df_circulatoire, df_infectieux, df_respiratoire, df_rad_agg]
    df.year = Int64.(df.year)
end

df_combined = innerjoin(df_death_wide, df_cancer, on=:year)
df_combined = innerjoin(df_combined, df_circulatoire, on=:year)
df_combined = innerjoin(df_combined, df_infectieux, on=:year)
df_combined = innerjoin(df_combined, df_respiratoire, on=:year)
df_combined = innerjoin(df_combined, df_rad_agg, on=:year)
df_combined = innerjoin(df_combined, df_pollution, on=:year)
df_combined = innerjoin(df_combined, df_particules_agg, on=:year)
df_combined = innerjoin(df_combined, df_particules_PM10[!, [:year, :pm10_emission]], on=:year)

df_combined = filter(row -> 2000 ≤ row.year ≤ 2020, df_combined)
sort!(df_combined, :year)

println("✓ Données chargées: $(nrow(df_combined)) années (2000-2020)")

# ============================================
# ÉTAPE 2: Définir les analyses par cause
# ============================================

# Variables environnementales communes
env_vars = ["rad_mean", "pm10_immission", "pm10_emission", "death_pm25"]

# Définition des 4 causes
causes = [
    (
        name = "Circulatoire",
        death_var = "death_circulatoire",
        med_var = "med_circulatoire",
        color = :red
    ),
    (
        name = "Respiratoire",
        death_var = "death_respiratoire",
        med_var = "med_respiratoire",
        color = :blue
    ),
    (
        name = "Cancer",
        death_var = "death_cancer",
        med_var = "med_cancer",
        color = :purple
    ),
    (
        name = "Infectieux",
        death_var = "death_infectieux",
        med_var = "med_infectieux",
        color = :green
    )
]

# ============================================
# ÉTAPE 3: PCA pour chaque cause (SANS décès)
# ============================================

results_all = []
correlation_results = []
plots_biplot = []
plots_loadings = []
plots_loadings_pc2 = []
plots_scatter = []
temporal_scores = Dict()

for cause in causes
    println("\n" * "-"^50)
    println("📊 Analyse: $(cause.name)")
    println("-"^50)
    
    # Variables pour PCA: médicaments + environnement (SANS décès)
    vars_for_pca = [cause.med_var, env_vars...]
    
    # Extraire et standardiser
    local data_matrix = Matrix(df_combined[!, vars_for_pca])'
    data_std = (data_matrix .- mean(data_matrix, dims=2)) ./ std(data_matrix, dims=2)
    
    # PCA
    local M = fit(PCA, data_std; maxoutdim=3, pratio=0.99)
    Y = predict(M, data_std)
    loadings_mat = loadings(M)
    vars_explained = principalvars(M)
    
    temporal_scores[cause.name] = (Y=Y, vars_explained=vars_explained)
    
    println("Variance expliquée: PC1=$(round(vars_explained[1]/sum(vars_explained)*100, digits=1))%, PC2=$(round(vars_explained[2]/sum(vars_explained)*100, digits=1))%")
    
    # Loadings
    println("\nLoadings PC1:")
    for (i, v) in enumerate(vars_for_pca)
        loading = loadings_mat[i, 1]
        bar = loading > 0 ? "+" * repeat("█", Int(round(abs(loading)*20))) : "-" * repeat("█", Int(round(abs(loading)*20)))
        println("  $v: $(round(loading, digits=3)) $bar")
    end
    
    # Stocker les résultats
    for (i, v) in enumerate(vars_for_pca)
        push!(results_all, (
            Cause = cause.name,
            Variable = v,
            PC1 = round(loadings_mat[i, 1], digits=4),
            PC2 = round(loadings_mat[i, 2], digits=4)
        ))
    end
    
    # ============================================
    # CORRÉLATIONS: Décès vs PC
    # ============================================
    
    println("\n[CORRÉLATIONS DÉCÈS ↔ COMPOSANTES PRINCIPALES]")
    
    deaths = df_combined[!, cause.death_var]
    
    # Corrélation avec PC1
    cor_pc1 = cor(deaths, Y[1, :])
    r2_pc1 = cor_pc1^2
    
    # Corrélation avec PC2
    cor_pc2 = cor(deaths, Y[2, :])
    r2_pc2 = cor_pc2^2
    
    println("  Décès ↔ PC1: r=$(round(cor_pc1, digits=3)), R²=$(round(r2_pc1, digits=3))")
    println("  Décès ↔ PC2: r=$(round(cor_pc2, digits=3)), R²=$(round(r2_pc2, digits=3))")
    
    push!(correlation_results, (
        Cause = cause.name,
        cor_PC1 = round(cor_pc1, digits=4),
        R2_PC1 = round(r2_pc1, digits=4),
        cor_PC2 = round(cor_pc2, digits=4),
        R2_PC2 = round(r2_pc2, digits=4)
    ))
    
    # ============================================
    # BIPLOT
    # ============================================
    
    local p_biplot = plot(
        xlabel="PC1 ($(round(vars_explained[1]/sum(vars_explained)*100, digits=1))%) | Décès R²=$(round(r2_pc1, digits=2))",
        ylabel="PC2 ($(round(vars_explained[2]/sum(vars_explained)*100, digits=1))%) | Décès R²=$(round(r2_pc2, digits=2))",
        title="PCA - Décès $(cause.name)",
        size=(600, 500),
        legend=:outertopright,
        left_margin=10Plots.mm,
        bottom_margin=10Plots.mm
    )
    
    # Points années
    scatter!(p_biplot, Y[1,:], Y[2,:],
        label="Années",
        marker=:circle,
        markersize=6,
        markercolor=:gray,
        alpha=0.6
    )
    
    # Annoter années
    for (i, yr) in enumerate(df_combined.year)
        annotate!(p_biplot, Y[1,i], Y[2,i], text(string(yr), 6, :bottom))
    end
    
    # Vecteurs variables
    scale = 2
    var_colors = Dict(
        cause.med_var => :blue,
        "rad_mean" => :orange,
        "pm10_immission" => :purple,
        "pm10_emission" => :magenta,
        "death_pm25" => :darkred
    )
    
    for (i, v) in enumerate(vars_for_pca)
        col = get(var_colors, v, :black)
        quiver!(p_biplot, [0], [0],
            quiver=([loadings_mat[i,1]*scale], [loadings_mat[i,2]*scale]),
            color=col,
            linewidth=2,
            label=""
        )
        short_name = replace(v, "med_" => "M:", "_mean" => "", "pm10_" => "PM10:")
        annotate!(p_biplot, 
            loadings_mat[i,1]*scale*1.15, 
            loadings_mat[i,2]*scale*1.15,
            text(short_name, 7, col)
        )
    end
    
    push!(plots_biplot, p_biplot)
    
    # ============================================
    # BAR PLOT des loadings PC1
    # ============================================
    
    sorted_idx = sortperm(loadings_mat[:, 1])
    sorted_loadings = loadings_mat[sorted_idx, 1]
    sorted_names = [vars_for_pca[i] for i in sorted_idx]
    colors = [get(var_colors, n, :gray) for n in sorted_names]
    short_names = [replace(replace(n, "med_" => "Méd: "), "_mean" => "") for n in sorted_names]
    short_names = [replace(n, "pm10_immission" => "PM10 immission") for n in short_names]
    short_names = [replace(n, "pm10_emission" => "PM10 émission") for n in short_names]
    
    p_loading = bar(sorted_loadings,
        orientation=:horizontal,
        yticks=(1:length(short_names), short_names),
        xlabel="Loading PC1",
        title="$(cause.name) - Contribution à PC1\nDécès R²=$(round(r2_pc1, digits=2))",
        color=colors,
        legend=false,
        size=(550, 400),
        left_margin=15Plots.mm,
        right_margin=10Plots.mm,
        xlims=(-0.8, 0.8)
    )
    vline!(p_loading, [0], color=:black, linewidth=1, label="")
    
    push!(plots_loadings, p_loading)
    
    # ============================================
    # BAR PLOT des loadings PC2
    # ============================================
    
    sorted_idx_pc2 = sortperm(loadings_mat[:, 2])
    sorted_loadings_pc2 = loadings_mat[sorted_idx_pc2, 2]
    sorted_names_pc2 = [vars_for_pca[i] for i in sorted_idx_pc2]
    colors_pc2 = [get(var_colors, n, :gray) for n in sorted_names_pc2]
    short_names_pc2 = [replace(replace(n, "med_" => "Méd: "), "_mean" => "") for n in sorted_names_pc2]
    short_names_pc2 = [replace(n, "pm10_immission" => "PM10 immission") for n in short_names_pc2]
    short_names_pc2 = [replace(n, "pm10_emission" => "PM10 émission") for n in short_names_pc2]
    
    p_loading_pc2 = bar(sorted_loadings_pc2,
        orientation=:horizontal,
        yticks=(1:length(short_names_pc2), short_names_pc2),
        xlabel="Loading PC2",
        title="$(cause.name) - Contribution à PC2\nDécès R²=$(round(r2_pc2, digits=2))",
        color=colors_pc2,
        legend=false,
        size=(550, 400),
        left_margin=15Plots.mm,
        right_margin=10Plots.mm,
        xlims=(-0.8, 0.8)
    )
    vline!(p_loading_pc2, [0], color=:black, linewidth=1, label="")
    
    push!(plots_loadings_pc2, p_loading_pc2)
    
    # ============================================
    # SCATTER: Décès vs PC1
    # ============================================
    
    years = df_combined.year
    
    p_scatter = scatter(Y[1, :], deaths,
        xlabel="Score PC1 (profil environnemental)",
        ylabel="Nombre de décès",
        title="$(cause.name): Décès vs PC1\nR²=$(round(r2_pc1, digits=3))",
        label="",
        color=cause.color,
        markersize=6,
        alpha=0.7,
        size=(500, 400),
        left_margin=10Plots.mm
    )
    
    # Ligne de tendance
    x_vals = Y[1, :]
    coeffs = [ones(length(x_vals)) x_vals] \ deaths
    y_pred = coeffs[1] .+ coeffs[2] .* x_vals
    plot!(p_scatter, x_vals, y_pred, 
        color=cause.color, 
        linewidth=2, 
        linestyle=:dash,
        label="Tendance linéaire"
    )
    
    # Annoter années clés
    for (i, yr) in enumerate(years)
        if yr in [2000, 2010, 2020]
            annotate!(p_scatter, Y[1,i], deaths[i], text(string(yr), 7, :top))
        end
    end
    
    push!(plots_scatter, p_scatter)
end

# ============================================
# ÉTAPE 4: Sauvegarder les résultats
# ============================================

# CSV des loadings et corrélations
df_results = DataFrame(results_all)
df_correlations = DataFrame(correlation_results)

CSV.write("output/pca_cause/pca_par_cause_loadings.csv", df_results)
CSV.write("output/pca_cause/pca_correlations_deaths_vs_pc.csv", df_correlations)

println("\n✓ Loadings sauvegardés dans output/pca_cause/pca_par_cause_loadings.csv")
println("✓ Corrélations sauvegardées dans output/pca_cause/pca_correlations_deaths_vs_pc.csv")

# Graphiques combinés
p_biplots_combined = plot(plots_biplot..., layout=(2, 2), size=(1200, 1000))
savefig(p_biplots_combined, "output/pca_cause/pca_par_cause_biplots.png")
println("✓ Biplots sauvegardés dans output/pca_cause/pca_par_cause_biplots.png")

p_loadings_combined = plot(plots_loadings..., layout=(2, 2), size=(1000, 800))
savefig(p_loadings_combined, "output/pca_cause/pca_par_cause_loadings_pc1.png")
println("✓ Loadings PC1 sauvegardés dans output/pca_cause/pca_par_cause_loadings_pc1.png")

p_loadings_pc2_combined = plot(plots_loadings_pc2..., layout=(2, 2), size=(1000, 800))
savefig(p_loadings_pc2_combined, "output/pca_cause/pca_par_cause_loadings_pc2.png")
println("✓ Loadings PC2 sauvegardés dans output/pca_cause/pca_par_cause_loadings_pc2.png")

p_scatter_combined = plot(plots_scatter..., layout=(2, 2), size=(1000, 800))
savefig(p_scatter_combined, "output/pca_cause/pca_deaths_vs_pc1_scatter.png")
println("✓ Scatter décès vs PC1 sauvegardé dans output/pca_cause/pca_deaths_vs_pc1_scatter.png")

# ============================================
# Évolution temporelle PC1 pour chaque cause
# ============================================

years = df_combined.year
p_temporal = plot(
    xlabel="Année",
    ylabel="Score PC1",
    title="Évolution temporelle PC1 par cause de décès",
    size=(900, 500),
    legend=:outertopright,
    left_margin=10Plots.mm,
    bottom_margin=10Plots.mm
)

cause_colors = Dict("Circulatoire" => :red, "Respiratoire" => :blue, "Cancer" => :purple, "Infectieux" => :green)

for cause in causes
    scores = temporal_scores[cause.name]
    plot!(p_temporal, years, scores.Y[1, :],
        label=cause.name,
        color=cause_colors[cause.name],
        linewidth=2,
        marker=:circle,
        markersize=4
    )
end

hline!(p_temporal, [0], color=:gray, linestyle=:dash, label="", linewidth=1)
savefig(p_temporal, "output/pca_cause/pca_par_cause_temporal.png")
println("✓ Évolution temporelle sauvegardée dans output/pca_cause/pca_par_cause_temporal.png")

# Évolution temporelle PC1 + PC2 (subplots par cause)
plots_temporal_detail = []
for cause in causes
    scores = temporal_scores[cause.name]
    var_pc1 = round(scores.vars_explained[1]/sum(scores.vars_explained)*100, digits=1)
    var_pc2 = round(scores.vars_explained[2]/sum(scores.vars_explained)*100, digits=1)
    
    p = plot(
        xlabel="Année",
        ylabel="Score",
        title="$(cause.name)",
        legend=:topright,
        size=(500, 350),
        left_margin=10Plots.mm
    )
    plot!(p, years, scores.Y[1, :], label="PC1 ($var_pc1%)", color=cause_colors[cause.name], linewidth=2)
    plot!(p, years, scores.Y[2, :], label="PC2 ($var_pc2%)", color=cause_colors[cause.name], linewidth=2, linestyle=:dash)
    hline!(p, [0], color=:gray, linestyle=:dot, label="", linewidth=1)
    push!(plots_temporal_detail, p)
end

p_temporal_all = plot(plots_temporal_detail..., layout=(2, 2), size=(1000, 700))
savefig(p_temporal_all, "output/pca_cause/pca_par_cause_temporal_detail.png")
println("✓ Évolution temporelle détaillée sauvegardée dans output/pca_cause/pca_par_cause_temporal_detail.png")

# ============================================
# ÉTAPE 5: Comparaison entre causes
# ============================================

println("\n" * "="^70)
println("COMPARAISON DES LOADINGS PC1 PAR CAUSE")
println("="^70)

# Créer une matrice de comparaison
comparison_vars = ["death_pm25", "pm10_immission", "pm10_emission", "rad_mean"]
comparison_data = []

for var in comparison_vars
    row = Dict{String, Any}("Variable" => var)
    for cause in causes
        subset = filter(r -> r.Cause == cause.name && r.Variable == var, df_results)
        if nrow(subset) > 0
            row[cause.name] = subset[1, :PC1]
        end
    end
    push!(comparison_data, row)
end

df_comparison = DataFrame(comparison_data)
println("\nLoadings PC1 des variables environnementales par cause:")
println(df_comparison)

CSV.write("output/pca_cause/pca_par_cause_comparison.csv", df_comparison)
println("\n✓ Comparaison sauvegardée dans output/pca_cause/pca_par_cause_comparison.csv")

# Heatmap de comparaison
cause_names = [c.name for c in causes]
var_labels = ["PM2.5 (décès)", "PM10 immis.", "PM10 émis.", "Radiation"]

comparison_matrix = zeros(length(comparison_vars), length(causes))
for (i, var) in enumerate(comparison_vars)
    for (j, cause) in enumerate(causes)
        subset = filter(r -> r.Cause == cause.name && r.Variable == var, df_results)
        if nrow(subset) > 0
            comparison_matrix[i, j] = subset[1, :PC1]
        end
    end
end

p_comparison = heatmap(cause_names, var_labels, comparison_matrix,
    title="Impact des variables environnementales par cause de décès\n(Loading PC1)",
    color=:RdBu,
    clim=(-0.6, 0.6),
    size=(750, 500),
    annotate=[(j, i, text(string(round(comparison_matrix[i,j], digits=2)), 10, :black)) 
              for i in 1:length(var_labels), j in 1:length(cause_names)],
    left_margin=10Plots.mm,
    right_margin=15Plots.mm,
    bottom_margin=10Plots.mm
)
savefig(p_comparison, "output/pca_cause/pca_par_cause_heatmap_comparison.png")
println("✓ Heatmap de comparaison sauvegardée dans output/pca_cause/pca_par_cause_heatmap_comparison.png")

# ============================================
# ÉTAPE 6: Résumé
# ============================================

println("\n" * "="^70)
println("RÉSUMÉ: CORRÉLATIONS DÉCÈS ↔ PROFILS ENVIRONNEMENTAUX")
println("="^70)

println("\nTableau des corrélations:")
println(df_correlations)

println("\n" * "="^70)
println("INTERPRÉTATION")
println("="^70)

for row in eachrow(df_correlations)
    println("\n🔹 $(row.Cause):")
    println("   • PC1 explique $(round(row.R2_PC1*100, digits=1))% de la variance des décès")
    if abs(row.cor_PC1) > 0.7
        direction = row.cor_PC1 > 0 ? "positivement" : "négativement"
        println("   • Corrélation FORTE $direction (r=$(row.cor_PC1))")
    elseif abs(row.cor_PC1) > 0.4
        direction = row.cor_PC1 > 0 ? "positivement" : "négativement"
        println("   • Corrélation MODÉRÉE $direction (r=$(row.cor_PC1))")
    else
        println("   • Corrélation FAIBLE avec PC1 (r=$(row.cor_PC1))")
    end
end

println("\n" * "="^70)
println("QUELLE VARIABLE IMPACTE QUELLE CAUSE ?")
println("="^70)

for cause in causes
    println("\n🔹 $(cause.name):")
    subset = filter(r -> r.Cause == cause.name, df_results)
    sorted = sort(subset, :PC1, rev=true)
    
    # Top 2 positifs
    println("   Variables les plus associées (+):")
    for row in eachrow(first(sorted, 2))
        println("     • $(row.Variable): $(row.PC1)")
    end
    
    # Top 2 négatifs
    println("   Variables inversement associées (-):")
    sorted_neg = sort(subset, :PC1)
    for row in eachrow(first(sorted_neg, 2))
        println("     • $(row.Variable): $(row.PC1)")
    end
end

println("\n" * "="^70)
println("FICHIERS GÉNÉRÉS")
println("="^70)
println("  • pca_par_cause_biplots.png            - Biplots avec R² décès")
println("  • pca_par_cause_loadings_pc1.png       - Barres de contribution PC1")
println("  • pca_par_cause_loadings_pc2.png       - Barres de contribution PC2")
println("  • pca_deaths_vs_pc1_scatter.png        - Scatter décès vs PC1 (R²)")
println("  • pca_par_cause_temporal.png           - Évolution PC1 toutes causes")
println("  • pca_par_cause_temporal_detail.png    - Évolution PC1+PC2 par cause")
println("  • pca_par_cause_heatmap_comparison.png - Comparaison entre causes")
println("  • pca_par_cause_loadings.csv           - Loadings numériques")
println("  • pca_correlations_deaths_vs_pc.csv    - Corrélations décès ↔ PC")
println("  • pca_par_cause_comparison.csv         - Tableau comparatif")
println("="^70)