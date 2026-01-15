include("imports/imports_medoc.jl")

pygui(false)

function safe_rename!(df, rename_dict, df_name="DataFrame")
	existing_cols = names(df)
	safe_dict = Dict(k => v for (k, v) in rename_dict if k in existing_cols)
	
	if !isempty(safe_dict)
		rename!(df, safe_dict)
		println("✓ $(length(safe_dict)) colonnes renommées avec succès dans $df_name")
	end
	
	# Afficher les colonnes non trouvées
	missing_cols = setdiff(keys(rename_dict), existing_cols)
	if !isempty(missing_cols)
		println("\n⚠ Colonnes non trouvées dans $df_name:")
		for col in missing_cols
			println("  - ", first(col, 50), "...")
		end
	end
end
function print_column_info(df)
	println("Nombre de colonnes: ", length(names(df)))
	println("\nNoms des colonnes:")
	for (i, name) in enumerate(names(df	))
		println("Colonne $i:")
		println("  Longueur: ", length(name))
		println("  Repr: ", repr(name))
		println()
	end
end
# List of descriptions ATC in French
function print_atc_descriptions(df_ATC)
	println("\n========================================")
	println("DESCRIPTIONS ATC ($(length(unique(df_ATC.description_atc))))")
	println("========================================")
	for (i, desc) in enumerate(sort(unique(df_ATC.description_atc)))
		println("  $i. $desc")
	end
	println("========================================\n")
end
# Fonction pour vérifier si un code ATC correspond à un code de référence (correspondance hiérarchique)
function matches_atc_reference(code_medic, codes_ref)
    ismissing(code_medic) && return false
    code_str = strip(string(code_medic))
    
    for ref_code in codes_ref
        ref_str = strip(string(ref_code))
        # Si le code du médicament commence par le code de référence, c'est une correspondance
        if startswith(code_str, ref_str)
            return true
        end
    end
    return false
end

df_ATC_KPA = DataFrame(XLSX.readtable("données/medicament/classification du code ATC et les groupes IT KPA.xlsx", 1, first_row=7))
df_ATC = DataFrame(XLSX.readtable("données/medicament/ATC-Liste.xlsx", 1, first_row=6))
df_ListMedicIndic = DataFrame(XLSX.readtable("données/medicament/Liste médicament avec indication.xlsx", 1, first_row=7))
df_ListMedicOrphan = DataFrame(XLSX.readtable("données/medicament/Liste_OrphanDrug_Internet.xlsx", 1, first_row=4))
df_MedicIndic = DataFrame(XLSX.readtable("données/medicament/Médicament autorisé avec indication.xlsx", 1, first_row=7))
df_MedicDureeLimite = DataFrame(XLSX.readtable("données/medicament/Medicaments à usage humain autorisés pour une durée limitée.xlsx", 1, first_row=4))

rename_dict_1 = Dict(
    "ATC Code\n\n\nCode ATC" => :code_atc,
    "ATC-Beschreibung\n\nDescription selon le système de classification ATC" => :description_atc,
    "Regulatory Manager (RM)\n\nRegulatory Manager (RM)" => :regulatory_manager,
    "Kurzzeichen RM\n\n\nParaphe RM" => :paraphe_rm,
    "Regulatory Associate (RAS)\n\n\nRegulatory Associate (RAS)" => :regulatory_associate,
    "Kurzzeichen RAS\n\n\nParaphe RAS" => :paraphe_ras,
    "Abteilung\n\n\nDivision" => :division
)

traductions_1 = Dict(
	    "Alimentäres System und Stoffwechsel" => "Système alimentaire et métabolisme",
	    "Andere Dermatika" => "Autres médicaments dermatologiques",
	    "Andere Gynäkologika" => "Autres médicaments gynécologiques",
	    "Andere Lipidmodifizierende Mittel" => "Autres agents hypolipémiants",
	    "Andere Mittel für das alimentäre System und den Stoffwechsel" => "Autres médicaments pour le système alimentaire et le métabolisme",
	    "Andere Mittel für den Respirationstrakt" => "Autres médicaments pour le système respiratoire",
	    "Andere Mittel gegen Arthritis und rheumatische Krankheiten" => "Autres médicaments contre l'arthrite et les maladies rhumatismales",
	    "Antiadiposita, exkl. Diätetika" => "Anti-obésité, excl. diététiques",
	    "Antibiotika und Chemotherapeutika zur dermatologischen Anwendung" => "Antibiotiques et chimiothérapie à usage dermatologique",
	    "Antidementiva" => "Anti-démentiels",
	    "Antidepressiva" => "Antidépresseurs",
	    "Antidiarrhoika und intestinale Antiphlogistika/Antiinfektiva" => "Antidiarrhéiques et anti-inflammatoires/anti-infectieux intestinaux",
	    "Antiemetika und Mittel gegen Übelkeit" => "Antiémétiques et médicaments contre les nausées",
	    "Antiphlogistika und Antirheumatika" => "Anti-inflammatoires et antirhumatismaux",
	    "Antivirale Mittel" => "Antiviraux",
	    "Anxiolytika" => "Anxiolytiques",
	    "Appetitstimulierende Mittel" => "Stimulants de l'appétit",
	    "Dermatika" => "Médicaments dermatologiques",
	    "Emollientia und Protektiva" => "Émollients et protecteurs",
	    "Gallen- und Lebertherapie" => "Thérapie biliaire et hépatique",
	    "Hals- und Rachentherapeutika" => "Médicaments pour la gorge et le pharynx",
	    "Herztherapie" => "Thérapie cardiaque",
	    "Husten- und Erkältungspräparate" => "Préparations contre la toux et le rhume",
	    "Hypnotika und Sedativa" => "Hypnotiques et sédatifs",
	    "Kardiovaskuläres System" => "Système cardiovasculaire",
	    "Mittel bei funktionellen gastrointestinalen Störungen" => "Médicaments pour troubles gastro-intestinaux fonctionnels",
	    "Mittel gegen Verstopfung" => "Laxatifs",
	    "Muskel- und Skelettsystem" => "Système musculo-squelettique",
	    "Muskelrelaxanzien" => "Myorelaxants",
	    "Nervensystem" => "Système nerveux",
	    "Ophthalmika" => "Médicaments ophtalmiques",
	    "Respirationstrakt" => "Système respiratoire",
	    "Sinnesorgane" => "Organes sensoriels",
	    "Stomatologika" => "Médicaments stomatologiques",
	    "Tonika" => "Toniques",
	    "Topische Mittel gegen Gelenk- und Muskelschmerzen" => "Médicaments topiques contre les douleurs articulaires et musculaires",
	    "Urogenitalsystem und Sexualhormone" => "Système uro-génital et hormones sexuelles",
	    "Urologika" => "Médicaments urologiques",
	    "Vasoprotektoren" => "Vasoprotecteurs",
	    "Zubereitungen zur Behandlung von Wunden und Geschwüren" => "Préparations pour le traitement des plaies et ulcères"
	)
safe_rename!(df_ATC_KPA, rename_dict_1, "df_ATC_KPA")

# Méthode 1 : Remplacer directement dans le DataFrame
df_ATC_KPA.description_atc = [get(traductions_1, desc, desc) for desc in df_ATC_KPA.description_atc]
# Créer un Set des codes ATC de référence


rename_dict_2 = Dict(
    "Zulassungs-\nnummer\n\nN° d'autorisation" => :numero_autorisation,
    "Dosisstärke-nummer \n\nN° de dosage" => :numero_dosage,
    "Bezeichnung des Arzneimittels\n\n\nDénomination du médicament" => :denomination_medicament,
    "Zulassungsinhaberin\n\n\nTitulaire de l'autorisation" => :titulaire_autorisation,
    "Zulassungsart\n\n\nType d'autorisation" => :type_autorisation,
    "Heilmittelcode\n\n\nCatégorie du médicament " => :categorie_medicament,
    "Verfahren nach Art. 14 Abs. 1 Bst. abis-quater HMG\n\nProcédures selon l'art.14, al.1, let.abis-quater LPTh" => :procedure_art14,
    "IT-Nummer\n\n\nNo IT " => :numero_it,
    "ATC-Code\n\n\nCode ATC" => :code_atc,
    "Erstzulassungs-datum Arzneimittel\nDate de première autorisation du médicament" => :date_premiere_autorisation,
    "Zul.datum Dosisstärke \n\nDate d'autorisation du dosage" => :date_autorisation_dosage,
    "Gültigkeitsdauer der Zulassung * \n\nDurée de validité de l'AMM *" => :duree_validite_amm,
    "Abgabekategorie Dosisstärke \n\nCat. de remise du dosage" => :categorie_remise_dosage,
    "Abgabekategorie Arzneimittel\n\nCat. de remise du médicament" => :categorie_remise_medicament,
    "Wirkstoff(e)\n\n\nPrincipe(s) actif(s)" => :principes_actifs,
    "Zusammensetzung\n\n\nComposition" => :composition,
    "Volldeklaration rev. AMZV umgesetzt\n\nDéclaration complète OEMéd rév. implémentée" => :declaration_complete,
    "Anwendungsgebiet Arzneimittel\n\n\nChamp d'application du médicament" => :champ_application_medicament,
    "Anwendungsgebiet Dosisstärke\n\n\nChamp d'application du dosage" => :champ_application_dosage,
    "Gentechnisch hergestellte Wirkstoffe\n\nPrincipes actifs produits par génie génétique" => :principes_actifs_genie_genetique,
    "Kategorie bei Insulinen\n\n\nCatégorie en cas d'insuline" => :categorie_insuline,
    "Verz. bei betäubungsmittelhaltigen Arzneimitteln **\n\nN° du tabl. Si médicaments à base de stupéfiants **" => :numero_stupefiants,
    "Besondere Angaben\n\n\nIndications particulières" => :indications_particulieres,
    "Zulassungsstatus\n\n\nStatut d'autorisation" => :statut_autorisation,
    "Befristet zugelassene Indikation(en) / Ablauf Datum\n\nIndication(s) autorisée(s) pour une durée limitée / date d’expiration" => :indications_duree_limitee
)
	
# Utiliser avec votre dictionnaire
safe_rename!(df_ListMedicIndic, rename_dict_2, "df_ListMedicIndic")

rename_dict_5 = Dict(
    "Zulassungs-\nnummer\n\nN° d'autorisation" => :numero_autorisation,
    "Dosisstärke-nummer \n\nN° de dosage" => :numero_dosage,
    "Bezeichnung des Arzneimittels\n\n\nDénomination du médicament" => :denomination_medicament,
    "Zulassungsinhaberin\n\n\nTitulaire de l'autorisation" => :titulaire_autorisation,
    "Heilmittelcode\n\n\nCatégorie du médicament" => :categorie_medicament,
    "IT-Nummer\n\n\nNo IT " => :numero_it,
    "ATC-Code\n\n\nCode ATC" => :code_atc,
    "Erstzulassungs-datum Arzneimittel\nDate de première autorisation du médicament" => :date_premiere_autorisation,
    "Zul.datum Dosisstärke \n\nDate d'autorisation du dosage" => :date_autorisation_dosage,
    "Gültigkeitsdauer der Zulassung * \n\nDurée de validité de l'AMM *" => :duree_validite_amm,
    "Abgabekategorie Dosisstärke \n\nCat. de remise du dosage" => :categorie_remise_dosage,
    "Abgabekategorie Arzneimittel\n\nCat. de remise du médicament" => :categorie_remise_medicament,
    "Wirkstoff(e)\n\n\nPrincipe(s) actif(s)" => :principes_actifs,
    "Anwendungsgebiet Arzneimittel\n\n\nChamp d'application du médicament" => :champ_application_medicament,
    "Anwendungsgebiet Dosisstärke\n\n\nChamp d'application du dosage" => :champ_application_dosage,
    "Besondere Angaben\n\n\nIndications particulières" => :indications_particulieres
)
safe_rename!(df_MedicDureeLimite, rename_dict_5, "df_MedicDureeLimite")

rename_dict_6 = Dict(
	"ATC Code\n\n\nCode ATC" => :code_atc,
	"ATC-Beschreibung\n\nDescription selon le système de classification ATC" => :description_atc,
	"Regulatory Manager (RM)\n\nRegulatory Manager (RM)" => :regulatory_manager,
	"Kurzzeichen RM\n\nParaphe RM" => :paraphe_rm,
	"Regulatory Associate (RAS)\n\nRegulatory Associate (RAS)" => :regulatory_associate,
	"Kurzzeichen RAS\n\nParaphe RAS" => :paraphe_ras,
	"RA Einheit\n\nUnité RA" => :unite_ra,
)
safe_rename!(df_ATC, rename_dict_6, "df_ATC")

traductions_2 = Dict(
    "Additiva zu i.v.-Lösungen" => "Additifs pour solutions i.v.",
    "Aknemittel" => "Antiacnéiques",
    "Alimentäres System und Stoffwechsel" => "Système alimentaire et métabolisme",
    "Alkylierende Mittel" => "Agents alkylants",
    "Alle übrigen nichttherapeutischen Mittel" => "Tous les autres agents non thérapeutiques",
    "Alle übrigen therapeutischen Mittel" => "Tous les autres agents thérapeutiques",
    "Allergene" => "Allergènes",
    "Allgemeinanästhetika" => "Anesthésiques généraux",
    "Aminosäure und Derivate" => "Acides aminés et dérivés",
    "Anabolika zur systemischen Anwendung" => "Stéroïdes anabolisants pour usage systémique",
    "Analgetika" => "Analgésiques",
    "Andere Analgetika und Antipyretika" => "Autres analgésiques et antipyrétiques",
    "Andere Antidiarrhoika" => "Autres antidiarrhéiques",
    "Andere Dermatika" => "Autres dermatologiques",
    "Andere Gynäkologika" => "Autres gynécologiques",
    "Andere Herzmittel" => "Autres médicaments cardiaques",
    "Andere Hämatologika" => "Autres hématologiques",
    "Andere Immunstimulanzien" => "Autres immunostimulants",
    "Andere Immunsuppressiva" => "Autres immunosuppresseurs",
    "Andere Mittel für das Nervensystem" => "Autres médicaments pour le système nerveux",
    "Andere Mittel für den Respirationstrakt" => "Autres médicaments pour le système respiratoire",
    "Andere Sexualhormone und Modulatoren des Genitalsystems" => "Autres hormones sexuelles et modulateurs du système génital",
    "Andere antineoplastische Mittel" => "Autres agents antinéoplasiques",
    "Andere therapeutische Mittel" => "Autres agents thérapeutiques",
    "Androgene" => "Androgènes",
    "Androgene und weibliche Sexualhormone in Kombination" => "Androgènes et hormones sexuelles féminines en association",
    "Anthelmintika" => "Anthelminthiques",
    "Antiadiposita, exkl. Diätetika" => "Anti-obésité, excl. diététiques",
    "Antiandrogene" => "Antiandrogènes",
    "Antianämika" => "Antianémiques",
    "Antiarrhythmika, Klasse I + III" => "Antiarythmiques, classe I + III",
    "Antibiotika und Chemotherapeutika zur dermatologischen Anwendun" => "Antibiotiques et chimiothérapiques à usage dermatologique",
    "Antibiotika zur systemischen Anwendung" => "Antibiotiques pour usage systémique",
    "Antidementiva" => "Antidementiels",
    "Antidepressiva" => "Antidépresseurs",
    "Antidiabetika" => "Antidiabétiques",
    "Antidiabetika, exkl. Insuline" => "Antidiabétiques, excl. insulines",
    "Antidiarrhoika und intestinale Antiphlogistika / Antiinfektiva" => "Antidiarrhéiques et anti-inflammatoires/anti-infectieux intestinaux",
    "Antidote" => "Antidotes",
    "Antiemetika und Mittel gegen Übelkeit" => "Antiémétiques et médicaments contre les nausées",
    "Antiepileptika" => "Antiépileptiques",
    "Antihistaminika zur systemischen Anwendung" => "Antihistaminiques pour usage systémique",
    "Antihypertonika" => "Antihypertenseurs",
    "Antihämorrhagika" => "Antihémorragiques",
    "Antiinfektiva zur systemischen Anwendung" => "Anti-infectieux pour usage systémique",
    "Antimetabolite" => "Antimétabolites",
    "Antimykotika zur dermatologischen Anwendung" => "Antifongiques à usage dermatologique",
    "Antimykotika zur systemischen Anwendung" => "Antifongiques pour usage systémique",
    "Antimykotika zur topischen Anwendung" => "Antifongiques à usage topique",
    "Antimykotika, systemisch" => "Antifongiques, systémiques",
    "Antineoplastische Mittel" => "Agents antinéoplasiques",
    "Antineoplastische und immunmodulierende Mittel" => "Agents antinéoplasiques et immunomodulateurs",
    "Antiparasitäre Mittel, Insektizide und Repellenzien" => "Agents antiparasitaires, insecticides et répulsifs",
    "Antiparkinsonmittel" => "Antiparkinsoniens",
    "Antiphlogistika und Antirheumatika" => "Anti-inflammatoires et antirhumatismaux",
    "Antipruriginosa, inkl. Antihistaminika, Anästhetika, etc." => "Antiprurigineux, incl. antihistaminiques, anesthésiques, etc.",
    "Antipsoriatika" => "Antipsoriasiques",
    "Antipsychotika" => "Antipsychotiques",
    "Antiseptika und Desinfektionsmittel" => "Antiseptiques et désinfectants",
    "Antithrombotische Mittel" => "Agents antithrombotiques",
    "Antivarikosa" => "Médicaments contre les varices",
    "Antivertiginosa" => "Antivertigineux",
    "Antivirale Mittel zur systemischen Anwendung" => "Antiviraux pour usage systémique",
    "Anxiolytika" => "Anxiolytiques",
    "Anästhetika" => "Anesthésiques",
    "Barbiturate, rein" => "Barbituriques, purs",
    "Bei Herzerkrankungen eingesetzte Vasodilatatoren" => "Vasodilatateurs utilisés dans les maladies cardiaques",
    "Beta-Adrenorezeptor-Antagonisten" => "Antagonistes des récepteurs bêta-adrénergiques",
    "Beta-Adrenorezeptor-Antagonisten und Thiazide" => "Antagonistes des récepteurs bêta-adrénergiques et thiazides",
    "Beta-Adrenorezeptor-Antagonisten und andere Diuretika" => "Antagonistes des récepteurs bêta-adrénergiques et autres diurétiques",
    "Beta-Adrenorezeptor-Antagonisten, andere Kombinationen" => "Antagonistes des récepteurs bêta-adrénergiques, autres associations",
    "Blut und Blut bildende Organe" => "Sang et organes hématopoïétiques",
    "Blut und verwandte Produkte" => "Sang et produits apparentés",
    "Blutersatzmittel und Perfusionslösungen" => "Substituts du sang et solutions de perfusion",
    "Calcineurin-Inhibitoren" => "Inhibiteurs de la calcineurine",
    "Calciumhomöostase" => "Homéostasie calcique",
    "Calciumkanalblocker" => "Inhibiteurs des canaux calciques",
    "Corticosteroide zur systemischen Anwendung" => "Corticostéroïdes pour usage systémique",
    "Corticosteroide, dermatologische Zubereitungen" => "Corticostéroïdes, préparations dermatologiques",
    "Cytarabin und Daunorubicin" => "Cytarabine et daunorubicine",
    "Dermatika" => "Dermatologiques",
    "Diagnostika" => "Diagnostics",
    "Digestiva, inkl. Enzyme" => "Digestifs, incl. enzymes",
    "Dihydrooratat Dehydrogenase (DHODH) Inhibitoren" => "Inhibiteurs de la dihydroorotate déshydrogénase (DHODH)",
    "Diuretika" => "Diurétiques",
    "Diverse Mittel für das alimentäre System und den Stoffwechsel" => "Divers médicaments pour le système alimentaire et le métabolisme",
    "Eisen-Chelatbildner" => "Chélateurs du fer",
    "Elektrolyte mit Kohlenhydraten" => "Électrolytes avec glucides",
    "Emollientia und Protektiva" => "Émollients et protecteurs",
    "Endokrine Therapie" => "Thérapie endocrine",
    "Entgiftungsmittel für die Behandlung mit Zytostatika" => "Agents de détoxification pour le traitement par cytostatiques",
    "Enzyme" => "Enzymes",
    "Estrogene" => "Œstrogènes",
    "Gallen- und Lebertherapie" => "Thérapie biliaire et hépatique",
    "Gestagene" => "Progestatifs",
    "Gestagene und Estrogene in Kombination" => "Progestatifs et œstrogènes en association",
    "Gichtmittel" => "Médicaments contre la goutte",
    "Gonadotropine und andere Ovulationsauslöser" => "Gonadotrophines et autres inducteurs d'ovulation",
    "Gynäkologische Antiinfektiva und Antiseptika" => "Anti-infectieux et antiseptiques gynécologiques",
    "Halogenierte Kohlenwasserstoffe" => "Hydrocarbures halogénés",
    "Hals- und Rachentherapeutika" => "Médicaments pour la gorge et le pharynx",
    "Herzglykoside" => "Glycosides cardiaques",
    "Herztherapie" => "Thérapie cardiaque",
    "Hormonantagonisten und verwandte Mittel" => "Antagonistes hormonaux et agents apparentés",
    "Hormone und verwandte Mittel" => "Hormones et agents apparentés",
    "Hormonelle Kontrazeptiva zur systemischen Anwendung" => "Contraceptifs hormonaux pour usage systémique",
    "Husten- und Erkältungspräparate" => "Préparations contre la toux et le rhume",
    "Hypnotika und Sedativa" => "Hypnotiques et sédatifs",
    "Hypophysen- und Hypothalamushormone" => "Hormones hypophysaires et hypothalamiques",
    "Hypophysen-Vorderlappen-Hormone und Analoga" => "Hormones de l'antéhypophyse et analogues",
    "Hypophysenhinterlappenhormone" => "Hormones de la posthypophyse",
    "Hypothalamushormone" => "Hormones hypothalamiques",
    "Hämodialysekonzentrate und Hämofiltrate" => "Concentrés d'hémodialyse et hémofiltrés",
    "I.V.-Lösungen" => "Solutions i.v.",
    "Immunglobuline" => "Immunoglobulines",
    "Immunsera" => "Immunosérums",
    "Immunstimulanzien" => "Immunostimulants",
    "Immunsuppressiva" => "Immunosuppresseurs",
    "Impfstoffe" => "Vaccins",
    "Insuline und Analoga" => "Insulines et analogues",
    "Interferone" => "Interférons",
    "Interleukin-Rezeptor-Inhibitoren" => "Inhibiteurs des récepteurs de l'interleukine",
    "Interleukine" => "Interleukines",
    "Intestinale Absorbenzien" => "Absorbants intestinaux",
    "Intestinale Antiinfektiva" => "Anti-infectieux intestinaux",
    "Intestinale Antiphlogistika" => "Anti-inflammatoires intestinaux",
    "JAK-Inhibitoren" => "Inhibiteurs de JAK",
    "Kapillarstabilisierende Mittel" => "Agents stabilisateurs capillaires",
    "Kardiostimulanzien, exkl. Herzglykoside" => "Cardiostimulants, excl. glycosides cardiaques",
    "Kardiovaskuläres System" => "Système cardiovasculaire",
    "Koloniestimulierende Faktoren CSF" => "Facteurs stimulant les colonies (CSF)",
    "Kombinierte antineoplastische Mittel" => "Agents antinéoplasiques combinés",
    "Komplement Inhibitoren" => "Inhibiteurs du complément",
    "Kontrastmittel" => "Produits de contraste",
    "Lokalanästhetika" => "Anesthésiques locaux",
    "Lösungen mit Wirkung auf den Elektrolythaushalt" => "Solutions agissant sur l'équilibre électrolytique",
    "Lösungen zur Peritonealdialyse," => "Solutions pour dialyse péritonéale",
    "Lösungen zur parenteralen Ernährung" => "Solutions pour nutrition parentérale",
    "Medizinische Gase" => "Gaz médicaux",
    "Medizinische Verbände" => "Pansements médicaux",
    "Methylhydrazine" => "Méthylhydrazines",
    "Migränemittel" => "Antimigraineux",
    "Mikrobielle Antiphlogistika" => "Anti-inflammatoires microbiens",
    "Mineralstoffe" => "Minéraux",
    "Mittel bei Säure bedingten Erkrankungen" => "Médicaments pour les maladies liées à l'acidité",
    "Mittel bei benigner Prostatahyperplasie" => "Médicaments pour l'hyperplasie bénigne de la prostate",
    "Mittel bei funktionellen gastrointestinalen Störungen" => "Médicaments pour les troubles gastro-intestinaux fonctionnels",
    "Mittel bei obstruktiven Atemwegserkrankungen" => "Médicaments pour les maladies obstructives des voies respiratoires",
    "Mittel gegen Ektoparasiten" => "Médicaments contre les ectoparasites",
    "Mittel gegen Mykobakterien" => "Médicaments contre les mycobactéries",
    "Mittel gegen Protozoen-Erkrankungen" => "Médicaments contre les maladies à protozoaires",
    "Mittel gegen Verstopfung" => "Médicaments contre la constipation",
    "Mittel mit Wirkung auf das Renin-Angiotensin-System" => "Médicaments agissant sur le système rénine-angiotensine",
    "Mittel zur Behandlung der Alkoholabhängigkeit" => "Médicaments pour le traitement de la dépendance à l'alcool",
    "Mittel zur Behandlung der Hyperkaliämie und Hyperphosphatämie" => "Médicaments pour le traitement de l'hyperkaliémie et de l'hyperphosphatémie",
    "Mittel zur Behandlung der Hypoglykämie" => "Médicaments pour le traitement de l'hypoglycémie",
    "Mittel zur Behandlung der Nikotinabhängigkeit" => "Médicaments pour le traitement de la dépendance à la nicotine",
    "Mittel zur Behandlung der Opiatabhängigkeit" => "Médicaments pour le traitement de la dépendance aux opiacés",
    "Mittel zur Behandlung von Hämorrhoiden und Analfissuren zur topischen Anwendung" => "Médicaments pour le traitement des hémorroïdes et fissures anales à usage topique",
    "Mittel zur Behandlung von Knochenerkrankungen" => "Médicaments pour le traitement des maladies osseuses",
    "Mittel zur Behandlung von Suchterkrankungen" => "Médicaments pour le traitement des addictions",
    "Mittel, die den Lipidstoffwechsel beeinflussen" => "Médicaments influençant le métabolisme lipidique",
    "Monoklonale Antikörper" => "Anticorps monoclonaux",
    "Motilitätshemmer" => "Inhibiteurs de la motilité",
    "Muskel- und Skelettsystem" => "Système musculo-squelettique",
    "Muskelrelaxanzien" => "Myorelaxants",
    "Nervensystem" => "Système nerveux",
    "Ophthalmika" => "Ophtalmiques",
    "Opioidanalgetika" => "Analgésiques opioïdes",
    "Opioide" => "Opioïdes",
    "Osmodiuretika" => "Diurétiques osmotiques",
    "Otologika" => "Otologiques",
    "Pankreashormone" => "Hormones pancréatiques",
    "Parasympathomimetika" => "Parasympathomimétiques",
    "Periphere Vasodilatatoren" => "Vasodilatateurs périphériques",
    "Pertuzumab und Trastuzumab" => "Pertuzumab et trastuzumab",
    "Pflanzliche Alkaloide und andere natürliche Mittel" => "Alcaloïdes végétaux et autres agents naturels",
    "Platin-Verbindungen" => "Composés du platine",
    "Proteinkinase Inhibitoren" => "Inhibiteurs de protéine kinase",
    "Psychoanaleptika" => "Psychoanaleptiques",
    "Psycholeptika" => "Psycholeptiques",
    "Psycholeptika und Psychoanaleptika in Kombination" => "Psycholeptiques et psychoanaleptiques en association",
    "Psychostimulanzien, Mittel für die ADHD und Nootropika" => "Psychostimulants, médicaments pour le TDAH et nootropes",
    "Radiodiagnostika" => "Radiodiagnostics",
    "Radiotherapeutika" => "Radiothérapeutiques",
    "Respirationstrakt" => "Système respiratoire",
    "Rhinologika" => "Rhinologiques",
    "Schilddrüsentherapie" => "Thérapie thyroïdienne",
    "Selektive Immunsuppressiva" => "Immunosuppresseurs sélectifs",
    "Sensibilisatoren für die photodynamische/Radio-Therapie" => "Sensibilisateurs pour la thérapie photodynamique/radiothérapie",
    "Sexualhormone und Modulatoren des Genitalsystems" => "Hormones sexuelles et modulateurs du système génital",
    "Shingosin-1-phosphat (SP1) Rezeptormodulatoren" => "Modulateurs des récepteurs de la sphingosine-1-phosphate (SP1)",
    "Sinnesorgane" => "Organes sensoriels",
    "Spüllösungen" => "Solutions d'irrigation",
    "Stomatologika" => "Stomatologiques",
    "Systemische Hormonpräparate, exkl. Sexualhormone und Insuline" => "Préparations hormonales systémiques, excl. hormones sexuelles et insulines",
    "Tonika" => "Toniques",
    "Topische Mittel gegen Gelenk- und Muskelschmerzen" => "Médicaments topiques contre les douleurs articulaires et musculaires",
    "Tumornektrosefaktor alpha-Inhibitoren" => "Inhibiteurs du facteur de nécrose tumorale alpha",
    "Urogenitalsystem und Sexualhormone" => "Système génito-urinaire et hormones sexuelles",
    "Urologika" => "Urologiques",
    "Varia" => "Divers",
    "Vasoprotektoren" => "Vasoprotecteurs",
    "Vitamine" => "Vitamines",
    "Zubereitungen zur Behandlung von Wunden und Geschwüren" => "Préparations pour le traitement des plaies et ulcères",
    "Zytotoxische Antibiotika und verwandte Substanzen" => "Antibiotiques cytotoxiques et substances apparentées",
    "alle übrigen therapeutischen Mittel" => "Tous les autres agents thérapeutiques",
    "allgemeine Diätetika" => "Diététiques généraux",
    "andere Allgemeinanästhetika" => "Autres anesthésiques généraux",
    "andere Antidiabetika" => "Autres antidiabétiques",
    "andere Mittel gegen Störungen des Muskel- und Skelettsystems" => "Autres médicaments pour les troubles du système musculo-squelettique",
    "mTOR Kinase Inhibitoren" => "Inhibiteurs de la mTOR kinase"
)

df_ATC.description_atc = [get(traductions_2, desc, desc) for desc in df_ATC.description_atc]

codes_atc_reference = Set(vcat(df_ATC_KPA.code_atc, df_ATC.code_atc))

# Filtrer avec correspondance hiérarchique
df_ListMedicIndic_filtre = subset(df_ListMedicIndic, 
									:code_atc => ByRow(x -> matches_atc_reference(x, codes_atc_reference)))
# df_ListMedicOrphan_filtre = subset(df_ListMedicOrphan, :code_atc => ByRow(x -> matches_atc_reference(x, codes_atc_reference)))
# df_MedicIndic_filtre = subset(df_MedicIndic, :code_atc => ByRow(x -> matches_atc_reference(x, codes_atc_reference)))
df_MedicDureeLimite_filtre = subset(df_MedicDureeLimite, 
									:code_atc => ByRow(x -> matches_atc_reference(x, codes_atc_reference)))

println("$(nrow(df_ListMedicIndic_filtre)) médicaments correspondent aux codes ATC de référence dans df_ListMedicIndic_filtre")
#println("$(nrow(df_ListMedicOrphan_filtre)) médicaments correspondent aux codes ATC de référence")
#println("$(nrow(df_MedicIndic_filtre)) médicaments correspondent aux codes ATC de référence")
println("$(nrow(df_MedicDureeLimite_filtre)) médicaments correspondent aux codes ATC de référence dans df_MedicDureeLimite_filtre")

# Table de correspondance ATC → Causes de mortalité
correspondance_atc_mortalite = Dict(
    # Maladies infectieuses (sans COVID-19)
    "maladie_infectieuses" => ["J", "J01", "J02", "J04", "J05", "P01", "P02", "P03", "D06", "S01A"],
    
    # Cancer (tumeurs)
    "cancer" => ["L", "L01", "L02", "L03", "L04"],
    
    # Appareil circulatoire
    "appareil_circulatoire" => ["C", "C01", "C02", "C03", "C04", "C05", "C07", "C08", "C09", "C10", "B01"],
    
    # Appareil respiratoire
    "appareil_respiratoire" => ["R", "R01", "R02", "R03", "R05", "R06", "R07"]
)

# Fonction pour classifier un médicament selon sa cause de mortalité
function get_cause_mortalite(code_atc, correspondance)
    ismissing(code_atc) && return missing
    code_str = strip(string(code_atc))
    
    for (cause, codes_atc) in correspondance
        for ref_code in codes_atc
            if startswith(code_str, ref_code)
                return cause
            end
        end
    end
    return "autre"
end

# Ajouter la cause de mortalité aux DataFrames filtrés
df_ListMedicIndic_filtre.cause_mortalite = [get_cause_mortalite(code, correspondance_atc_mortalite) 
                                             for code in df_ListMedicIndic_filtre.code_atc]

df_MedicDureeLimite_filtre.cause_mortalite = [get_cause_mortalite(code, correspondance_atc_mortalite) 
                                               for code in df_MedicDureeLimite_filtre.code_atc]

# Afficher la répartition par cause de mortalité
println("\n========================================")
println("RÉPARTITION DES MÉDICAMENTS PAR CAUSE DE MORTALITÉ")
println("========================================")
println("\ndf_ListMedicIndic_filtre:")
for (cause, count) in sort(collect(pairs(countmap(df_ListMedicIndic_filtre.cause_mortalite))), by=x->x[2], rev=true)
    println("  • $cause: $count médicaments")
end

println("\ndf_MedicDureeLimite_filtre:")
for (cause, count) in sort(collect(pairs(countmap(df_MedicDureeLimite_filtre.cause_mortalite))), by=x->x[2], rev=true)
    println("  • $cause: $count médicaments")
end
println("========================================\n")


#= CSV.write("output/df_filtre/df_ListMedicIndic_filtre.csv", df_ListMedicIndic_filtre)
CSV.write("output/df_filtre/df_MedicDureeLimite_filtre.csv", df_MedicDureeLimite_filtre) =#

atc_ListMedicIndic = nrow(df_ListMedicIndic) - nrow(df_ListMedicIndic_filtre)
atc_MedicDureeLimite = nrow(df_MedicDureeLimite) - nrow(df_MedicDureeLimite_filtre)

causes_ListMedicIndic = countmap(df_ListMedicIndic_filtre.cause_mortalite)
causes_MedicDureeLimite = countmap(df_MedicDureeLimite_filtre.cause_mortalite)

pct_exclu_ListMedicIndic = round(100 * atc_ListMedicIndic / nrow(df_ListMedicIndic), digits=2)
pct_exclu_MedicDureeLimite = round(100 * atc_MedicDureeLimite / nrow(df_MedicDureeLimite), digits=2)

println("Nombre de médicaments exclus de df_ListMedicIndic en raison de l'absence de correspondance ATC: $atc_ListMedicIndic ($pct_exclu_ListMedicIndic%)")
println("Nombre de médicaments exclus de df_MedicDureeLimite en raison de l'absence de correspondance ATC: $atc_MedicDureeLimite ($pct_exclu_MedicDureeLimite%)")

println("\nRépartition des causes de mortalité dans df_ListMedicIndic_filtre:")
total_ListMedicIndic = nrow(df_ListMedicIndic_filtre)
for (cause, count) in sort(collect(pairs(causes_ListMedicIndic)), by=x->x[2], rev=true)
    pct = round(100 * count / total_ListMedicIndic, digits=2)
    println("  • $cause: $count médicaments ($pct%)")
end
println("\nRépartition des causes de mortalité dans df_MedicDureeLimite_filtre:")
total_MedicDureeLimite = nrow(df_MedicDureeLimite_filtre)

# Fonction pour extraire l'année de la date
function get_year(row)
    if !ismissing(row.date_premiere_autorisation)
        return year(Date(row.date_premiere_autorisation))
    elseif !ismissing(row.date_autorisation_dosage)
        return year(Date(row.date_autorisation_dosage))
    else
        return missing
    end
end

# CORRECTION 1: Harmoniser les colonnes avant la fusion
common_cols = intersect(names(df_ListMedicIndic_filtre), names(df_MedicDureeLimite_filtre))
df_ListMedicIndic_common = select(df_ListMedicIndic_filtre, common_cols)
df_MedicDureeLimite_common = select(df_MedicDureeLimite_filtre, common_cols)

# CORRECTION 2: Fusionner les DataFrames
df_medicaments = vcat(df_ListMedicIndic_common, df_MedicDureeLimite_common)
println("\n✓ Fusion des deux DataFrames terminée. Total: ", nrow(df_medicaments))

# CORRECTION 3: Ajouter la colonne année
df_medicaments.annee = [get_year(row) for row in eachrow(df_medicaments)]

# CORRECTION 4: Filtrer les médicaments par année
df_2000 = subset(df_medicaments, :annee => ByRow(x -> !ismissing(x) && x == 2000))
df_2020 = subset(df_medicaments, :annee => ByRow(x -> !ismissing(x) && x == 2020))

println("\nMédicaments validés en 2000: ", nrow(df_2000))
println("Médicaments validés en 2020: ", nrow(df_2020))

# CORRECTION 5: Fonction pour compter par catégorie
function count_by_categorie(df, year_label)
    return DataFrame(
        annee = year_label,
        cancer = count(x -> !ismissing(x) && x == "cancer", df.cause_mortalite),
        appareil_circulatoire = count(x -> !ismissing(x) && x == "appareil_circulatoire", df.cause_mortalite),
        maladie_infectieuses = count(x -> !ismissing(x) && x == "maladie_infectieuses", df.cause_mortalite),
        appareil_respiratoire = count(x -> !ismissing(x) && x == "appareil_respiratoire", df.cause_mortalite),
        autres = count(x -> !ismissing(x) && x == "autre", df.cause_mortalite),
        total = nrow(df)
    )
end

# CORRECTION 6: Créer les résumés
df_2000_summary = count_by_categorie(df_2000, 2000)
df_2020_summary = count_by_categorie(df_2020, 2020)

# Afficher les résumés
println("\n========================================")
println("RÉSUMÉ DES MÉDICAMENTS VALIDÉS EN 2000")
println("========================================")
println(df_2000_summary)

println("\n========================================")
println("RÉSUMÉ DES MÉDICAMENTS VALIDÉS EN 2020")
println("========================================")
println(df_2020_summary)

# CORRECTION 7: Créer un DataFrame combiné pour comparaison
df_summary_combined = vcat(df_2000_summary, df_2020_summary)

# CORRECTION 8: Exporter les fichiers
# Créer les dossiers si nécessaire
mkpath("output/df_2000")
mkpath("output/df_2020")
mkpath("output/comparaison")

# Exporter les fichiers individuels
CSV.write("output/df_2000/medicaments_2000_summary.csv", df_2000_summary)
CSV.write("output/df_2020/medicaments_2020_summary.csv", df_2020_summary)
CSV.write("output/comparaison/medicaments_2000_2020_combined.csv", df_summary_combined)

# Optionnel: Exporter aussi les données détaillées
CSV.write("output/df_2000/medicaments_2000_detail.csv", df_2000)
CSV.write("output/df_2020/medicaments_2020_detail.csv", df_2020)

println("\n✓ Fichiers exportés avec succès:")
println("  - output/df_2000/medicaments_2000_summary.csv")
println("  - output/df_2000/medicaments_2000_detail.csv")
println("  - output/df_2020/medicaments_2020_summary.csv")
println("  - output/df_2020/medicaments_2020_detail.csv")
println("  - output/comparaison/medicaments_2000_2020_combined.csv")

# BONUS: Afficher les pourcentages
println("\n========================================")
println("COMPARAISON EN POURCENTAGES")
println("========================================")
for year_df in [df_2000, df_2020]
    year_val = first(year_df.annee)
    total = nrow(year_df)
    println("\nAnnée $year_val (Total: $total):")
    
    counts = countmap(skipmissing(year_df.cause_mortalite))
    for (cause, count) in sort(collect(counts), by=x->x[2], rev=true)
        pct = round(100 * count / total, digits=2)
        println("  • $cause: $count médicaments ($pct%)")
    end
end
println("========================================\n")