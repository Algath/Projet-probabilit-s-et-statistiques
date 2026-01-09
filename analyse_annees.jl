include("imports_analyse_annees.jl")

# Fonction pour extraire l'année d'une date
function extraire_annee(date_str)
    ismissing(date_str) && return missing
    try
        parts = split(string(date_str), "-")
        if length(parts) == 3
            return parse(Int, parts[1])
        end
    catch
        return missing
    end
    return missing
end

# Charger les DataFrames filtrés
df_ListMedicIndic_filtre = CSV.read("output\\df_filtre\\df_ListMedicIndic_filtre.csv", DataFrame)
df_MedicDureeLimite_filtre = CSV.read("output\\df_filtre\\df_MedicDureeLimite_filtre.csv", DataFrame)

# Extraire les années
annees1 = [extraire_annee(d) for d in df_ListMedicIndic_filtre.date_premiere_autorisation]
annees1 = filter(!ismissing, annees1)

annees2 = [extraire_annee(d) for d in df_MedicDureeLimite_filtre.date_premiere_autorisation]
annees2 = filter(!ismissing, annees2)

# Afficher les résultats
println("=" ^ 60)
println("ANNÉES MINIMALES ET MAXIMALES DISPONIBLES")
println("=" ^ 60)
println()

println("📊 df_ListMedicIndic_filtre:")
println("   • Année minimale: ", minimum(annees1))
println("   • Année maximale: ", maximum(annees1))
println("   • Nombre d'entrées avec date: ", length(annees1))
println()

println("📊 df_MedicDureeLimite_filtre:")
println("   • Année minimale: ", minimum(annees2))
println("   • Année maximale: ", maximum(annees2))
println("   • Nombre d'entrées avec date: ", length(annees2))
println()

println("=" ^ 60)
println("ANNÉE MINIMALE GLOBALE: ", min(minimum(annees1), minimum(annees2)))
println("ANNÉE MAXIMALE GLOBALE: ", max(maximum(annees1), maximum(annees2)))
println("=" ^ 60)
