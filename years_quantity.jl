using HypertextLiteral, CSV, DataFrames, XLSX, PyPlot, StatsBase

pygui(false)

df_ListMedicIndic = CSV.read("output\\df_filtre\\df_ListMedicIndic_filtre.csv", DataFrame)
df_MedicDureeLimite = CSV.read("output\\df_filtre\\df_MedicDureeLimite_filtre.csv", DataFrame)

df_ListMedicIndic_cancer = filter(row -> row.cause_mortalite == "cancer", df_ListMedicIndic)
df_ListMedicIndic_infectieuses = filter(row -> row.cause_mortalite == "maladie_infectieuses", df_ListMedicIndic)
df_ListMedicIndic_circulatoire = filter(row -> row.cause_mortalite == "appareil_circulatoire", df_ListMedicIndic)
df_ListMedicIndic_respiratoire = filter(row -> row.cause_mortalite == "appareil_respiratoire", df_ListMedicIndic)

df_MedicDureeLimite_cancer = filter(row -> row.cause_mortalite == "cancer", df_MedicDureeLimite)
df_MedicDureeLimite_infectieuses = filter(row -> row.cause_mortalite == "maladie_infectieuses", df_MedicDureeLimite)
df_MedicDureeLimite_circulatoire = filter(row -> row.cause_mortalite == "appareil_circulatoire", df_MedicDureeLimite)
df_MedicDureeLimite_respiratoire = filter(row -> row.cause_mortalite == "appareil_respiratoire", df_MedicDureeLimite)

# Fonction pour extraire l'année d'une date
function extraire_annee(date_str)
    ismissing(date_str) && return missing
    try
        # Format attendu : YYYY-MM-DD
        parts = split(string(date_str), "-")
        if length(parts) == 3
            annee = parse(Int, parts[1])
            return annee
        end
    catch
        return missing
    end
    return missing
end

# Fonction pour joindre deux DataFrames par année
function joindre_par_annee(df1::DataFrame, df2::DataFrame, annee_min::Int=2000, annee_max::Int=2024)
    # Copier les DataFrames pour ne pas modifier les originaux
    df1_copy = copy(df1)
    df2_copy = copy(df2)
    
    # Ajouter la colonne année et filtrer
    df1_copy.annee = [extraire_annee(date) for date in df1_copy.date_premiere_autorisation]
    df1_copy = filter(row -> !ismissing(row.annee) && (annee_min <= row.annee <= annee_max), df1_copy)
    
    df2_copy.annee = [extraire_annee(date) for date in df2_copy.date_premiere_autorisation]
    df2_copy = filter(row -> !ismissing(row.annee) && (annee_min <= row.annee <= annee_max), df2_copy)
    
    # Grouper par année et compter pour chaque DataFrame
    df1_by_year = combine(groupby(df1_copy, :annee), nrow => :nombre_df1)
    df2_by_year = combine(groupby(df2_copy, :annee), nrow => :nombre_df2)
    
    # Joindre les deux DataFrames par année
    df_join = outerjoin(df1_by_year, df2_by_year, on=:annee)
    replace!(df_join.nombre_df1, missing => 0)
    replace!(df_join.nombre_df2, missing => 0)
    
    # Créer le DataFrame de sortie
    df_result = DataFrame(annee = df_join.annee)
    df_result.nombre_medicaments = df_join.nombre_df1 .+ df_join.nombre_df2
    sort!(df_result, :annee)
    
    return df_result
end

# Utiliser la fonction pour le cancer
df_cancer = joindre_par_annee(df_ListMedicIndic_cancer, df_MedicDureeLimite_cancer)
df_infectieuxes = joindre_par_annee(df_ListMedicIndic_infectieuses, df_MedicDureeLimite_infectieuses)
df_circulatoire = joindre_par_annee(df_ListMedicIndic_circulatoire, df_MedicDureeLimite_circulatoire)
df_respiratoire = joindre_par_annee(df_ListMedicIndic_respiratoire, df_MedicDureeLimite_respiratoire)

CSV.write("output/df_quantity/df_cancer_par_annee.csv", df_cancer)
CSV.write("output/df_quantity/df_infectieuses_par_annee.csv", df_infectieuxes)
CSV.write("output/df_quantity/df_circulatoire_par_annee.csv", df_circulatoire)
CSV.write("output/df_quantity/df_respiratoire_par_annee.csv", df_respiratoire)