local labels = {}
local raw_categories = {}
local handlers = {}

local names_module = "Module:names"
local en_utilities_module = "Module:en-utilities"
local pluralize = require(en_utilities_module).pluralize


-----------------------------------------------------------------------------
--                                                                         --
--                                  LABELS                                 --
--                                                                         --
-----------------------------------------------------------------------------


labels["names"] = {
	description = "{{{langname}}} terms that are used to refer to specific individuals or groups.",
	additional = "Place names, demonyms and other kinds of names can be found in [[:Category:Names]].",
	umbrella_parents = {name = "terms by semantic function", is_label = true, sort = " "},
	parents = {"terms by semantic function", "proper nouns"},
}

------------------------------------------- given names -------------------------------------------

local human_genders = {
	["male"] = "to male individuals",
	["female"] = "to female individuals",
	["unisex"] = "either to male or to female individuals",
}


for gender, props in pairs(require(names_module).given_name_genders) do
	if gender ~= "unknown-gender" then
		local is_animal = props.type == "animal"
		local cat = is_animal and gender .. " names" or gender .. " given names"
		local desc = is_animal and " given to " .. pluralize(gender) or " given " .. human_genders[gender]
		local function do_cat(cat, desc, breadcrumb, parents)
			labels[cat] = {
				description = "{{{langname}}} " .. desc .. ".",
				breadcrumb = breadcrumb,
				parents = parents,
			}
		end
	
		for _, dimaug in ipairs { "diminutive", "augmentative" } do
			do_cat(dimaug .. "s of " .. cat, dimaug .. " names " .. desc, dimaug,
				{gender .. " given names", dimaug .. " nouns"})
		end
		do_cat(cat, "names " .. desc, gender, is_animal and (gender == "animal" and "names" or is_animal and
			"animal names") or "given names")
		if not is_animal then
			do_cat(gender .. " skin names", "skin names " .. desc, gender, {"skin names"})
		end
	end
end

labels["given names"] = {
	description = "{{{langname}}} names given to individuals.",
	parents = {"names"},
}

labels["skin names"] = {
	description = "{{{langname}}} terms given at birth that are used to refer to individuals from specific marital classes.",
	parents = {"proper nouns", "names"},
}

------------------------------------------- surnames -------------------------------------------

labels["common-gender surnames"] = {
	description = "{{{langname}}} names shared by both male and female family members, in languages that distinguish male and female surnames.",
	breadcrumb = "common-gender",
	parents = {"surnames"},
}

labels["female surnames"] = {
	description = "{{{langname}}} names shared by female family members.",
	breadcrumb = "female",
	parents = {"surnames"},
}

labels["male surnames"] = {
	description = "{{{langname}}} names shared by male family members.",
	breadcrumb = "male",
	parents = {"surnames"},
}

labels["surnames"] = {
	description = "{{{langname}}} names shared by family members.",
	parents = {"names"},
}

labels["matronymics"] = {
	description = "{{{langname}}} names indicating a person's mother, grandmother or earlier female ancestor.",
	parents = {"names"},
}

labels["patronymics"] = {
	description = "{{{langname}}} names indicating a person's father, grandfather or earlier male ancestor.",
	parents = {"names"},
}

labels["nomina gentilia"] = {
	description = "A Roman [[nomen gentile]] was the \"[[family name]]\" in the [[w:Roman naming convention|convential Roman name]].",
	parents = {"names"},
}

------------------------------------------- misc -------------------------------------------

labels["exonyms"] = {
	description = "{{{langname}}} [[exonym]]s, i.e. terms for toponyms whose name in {{{langname}}} is different from the name in the source language.",
	parents = {"names"},
}

labels["renderings of foreign personal names"] = {
	description = "{{{langname}}} transliterations, respellings or other renderings of foreign personal names.",
	parents = {"names"},
}


-- Add 'umbrella_parents' key if not already present.
for key, data in pairs(labels) do
	if not data.umbrella_parents then
		data.umbrella_parents = "Names subcategories by language"
	end
end



-----------------------------------------------------------------------------
--                                                                         --
--                              RAW CATEGORIES                             --
--                                                                         --
-----------------------------------------------------------------------------


raw_categories["Names subcategories by language"] = {
	description = "Umbrella categories covering topics related to names.",
	additional = "{{{umbrella_meta_msg}}}",
	parents = {
		"Umbrella metacategories",
		{name = "names", is_label = true, sort = " "},
	},
}


-----------------------------------------------------------------------------
--                                                                         --
--                                 HANDLERS                                --
--                                                                         --
-----------------------------------------------------------------------------


local function source_name_to_source(nametype, source_name)
	local special_sources
	if nametype:find("given names") then
		special_sources = require("Module:table").listToSet {
			"surnames", "place names", "coinages", "the Bible", "month names"
		}
	elseif nametype:find("surnames") then
		special_sources = require("Module:table").listToSet {
			"given names", "place names", "occupations", "patronymics", "matronymics",
			"common nouns", "nicknames", "ethnonyms"
		}
	else
		special_sources = {}
	end
	if special_sources[source_name] then
		return source_name
	else
		return require("Module:languages").getByCanonicalName(source_name, nil,
			"allow etym langs", "allow families")
	end
end

local function get_source_text(source)
	if type(source) == "table" then
		return source:getDisplayForm()
	else
		return source
	end
end

local function get_description(lang, nametype, source)
	local origintext, addltext
	if source == "surnames" then
		origintext = "transferred from surnames"
	elseif source == "given names" then
		origintext = "transferred from given names"
	elseif source == "nicknames" then
		origintext = "transferred from nicknames"
	elseif source == "place names" then
		origintext = "transferred from place names"
		addltext = " For place names that are also surnames, see " .. (
			lang and "[[:Category:{{{langname}}} " .. nametype .. " from surnames]]" or
			"[[:Category:" .. mw.getContentLanguage():ucfirst(nametype) .. " from surnames by language]]"
		) .. "."
	elseif source == "common nouns" then
		origintext = "transferred from common nouns"
	elseif source == "month names" then
		origintext = "transferred from month names"
	elseif source == "coinages" then
		origintext = "originating as coinages"
		addltext = " These are names of artificial origin, names based on fictional characters, combinations of two words or names or backward spellings. Names of uncertain origin can also be placed here if there is a strong suspicion that they are coinages."
	elseif source == "occupations" then
		origintext = "originating as occupations"
	elseif source == "patronymics" then
		origintext = "originating as patronymics"
	elseif source == "matronymics" then
		origintext = "originating as matronymics"
	elseif source == "ethnonyms" then
		origintext = "originating as ethnonyms"
	elseif source == "the Bible" then
		-- Hack esp. for Hawaiian names. We should consider changing them to
		-- have the source as Biblical Hebrew and mention the derivation from
		-- the Bible some other way.
		origintext = "originating from the Bible"
	elseif type(source) == "string" then
		error("Internal error: Unrecognized string source \"" .. source .. "\", should be special-cased")
	else
		origintext = "of " .. source:makeCategoryLink() .. " origin"
		if lang and source:getCode() == lang:getCode() then
			addltext = " These are names derived from common nouns, local mythology, etc."
		end
	end
	local introtext
	if lang then
		introtext = "{{{langname}}} "
	else
		introtext = "Categories with "
	end
	return introtext .. nametype .. " " .. origintext ..
		". (This includes names derived at an older stage of the language.)" .. (addltext or "")
end

-- If one of the following families occurs in any of the ancestral families
-- of a given language, use it instead of the three-letter parent
-- (or immediate parent if no three-letter parent).
local high_level_families = require("Module:table").listToSet {
	-- Indo-European
	"gem", -- Germanic (for gme, gmq, gmw)
	"inc", -- Indic (for e.g. pra = Prakrit)
	"ine-ana", -- Anatolian (don't keep going to ine)
	"ine-toc", -- Tocharian (don't keep going to ine)
	"ira", -- Iranian (for e.g. xme = Median, xsc = Scythian)
	"sla", -- Slavic (for zle, zls, zlw)
	-- Other
	"ath", -- Athabaskan (for e.g. apa = Apachean)
	"poz", -- Malayo-Polynesian (for e.g. pqe = Eastern Malayo-Polynesian)
	"cau-nwc", -- Northwest Caucasian
	"cau-nec", -- Northeast Caucasian
}

local function find_high_level_family(lang)
	local family = lang:getFamily()
	-- (1) If no family, return nil (e.g. for Pictish).
	if not family then
		return nil
	end
	-- (2) See if any ancestor family is in `high_level_families`.
	-- if so, return it.
	local high_level_family = family
	while high_level_family do
		local high_level_code = high_level_family:getCode()
		if high_level_code == "qfa-not" then
			-- "not a family"; its own parent, causing an infinite loop.
			-- Break rather than return so we get categories like
			-- [[Category:English female given names from sign languages]] and
			-- [[Category:English female given names from constructed languages]].
			break
		end
		if high_level_families[high_level_code] then
			return high_level_family
		end
		high_level_family = high_level_family:getFamily()
	end
	-- (3) If the family is of the form 'FOO-BAR', see if 'FOO' is a family.
	-- If so, return it.
	local basic_family = family:getCode():match("^(.-)%-.*$")
	if basic_family then
		basic_family = require("Module:families").getByCode(basic_family)
		if basic_family then
			return basic_family
		end
	end
	-- (4) Fall back to just the family itself.
	return family
end

local function match_gendered_nametype(nametype)
	local gender, label = nametype:match("^(f?e?male) (given names)$")
	if not gender then
		gender, label = nametype:match("^(unisex) (given names)$")
	end
	if gender then
		return gender, label
	end
end

local function get_parents(lang, nametype, source)
	local parents = {}

	if lang then
		table.insert(parents, {name = nametype, sort = get_source_text(source)})
		if type(source) == "table" then
			table.insert(parents, {name = "terms derived from " .. source:getDisplayForm(), sort = " "})
			-- If the source is a regular language, put it in a parent category for the high-level language family, e.g. for
			-- "Russian female given names from German", put it in a parent category "Russian female given names from Germanic languages"
			-- (skipping over West Germanic languages).
			--
			-- If the source is an etymology language, put it in a parent category for the parent full language, e.g. for
			-- "French male given names from Gascon", put it in a parent category "French male given names from Occitan".
			--
			-- If the source is a family, put it in a parent category for the parent family.
			if source:hasType("family") then
				local parent_family = source:getFamily()
				if parent_family and parent_family:getCode() ~= "qfa-not" then
					table.insert(parents, {
						name = nametype .. " from " .. parent_family:getDisplayForm(),
						sort = source:getCanonicalName()
					})
				end
			elseif source:hasType("etymology-only") then
				local source_parent = source:getFull()
				if source_parent and source_parent:getCode() ~= "und" then
					table.insert(parents, {
						name = nametype .. " from " .. source_parent:getDisplayForm(),
						sort = source:getCanonicalName()
					})
				end
			else
				local high_level_family = find_high_level_family(source)
				if high_level_family then -- may not exist, e.g. for Pictish
					table.insert(parents,
						{name = nametype .. " from " .. high_level_family:getDisplayForm(),
						sort = source:getCanonicalName()
					})
				end
			end
		end
	
		local gender, label = match_gendered_nametype(nametype)
		if gender then
			table.insert(parents, {name = label .. " from " .. get_source_text(source), sort = gender})
		end
	else
		local gender, label = match_gendered_nametype(nametype)
		if gender then
			table.insert(parents, {name = label .. " from " .. get_source_text(source), is_label = true, sort = " "})
		elseif type(source) == "table" then
			-- FIXME! This is duplicated in [[Module:category tree/poscatboiler/data/terms by etymology]] in the
			-- handler for umbrella categories 'Terms derived from SOURCE'.
			local first_umbrella_parent =
				source:hasType("family") and {name = source:getCategoryName(), raw = true, sort = " "} or
				source:hasType("etymology-only") and {name = "Category:" .. source:getCategoryName(), sort = nametype} or
				{name = source:getCategoryName(), raw = true, sort = nametype}
			table.insert(parents, first_umbrella_parent)
		end
		table.insert(parents, "Names subcategories by language")
	end
	
	return parents
end

table.insert(handlers, function(data)
	local nametype, source_name = data.label:match("^(.*names) from (.+)$")
	if nametype then
		local personal_name_type_set = require(names_module).personal_name_type_set
		if not personal_name_type_set[nametype] then
			return nil
		end
		local source = source_name_to_source(nametype, source_name)
		if not source then
			return nil
		end
		return {
			description = get_description(data.lang, nametype, source),
			breadcrumb = "from " .. get_source_text(source),
			parents = get_parents(data.lang, nametype, source),
			umbrella = {
				description = get_description(nil, nametype, source),
				parents = get_parents(nil, nametype, source),
			},
		}
	end
end)

-- Handler for e.g. 'English renderings of Russian male given names'.
table.insert(handlers, function(data)
	local label = data.label:match("^renderings of (.*)$")
	if label then
		local personal_name_types = require(names_module).personal_name_types
		for _, nametype in ipairs(personal_name_types) do
			local sourcename = label:match("^(.+) " .. nametype .. "$")
			
			if sourcename then
				local source = require("Module:languages").getByCanonicalName(sourcename, nil, "allow etym")
				if source then
					return {
						description = "Transliterations, respellings or other renderings of " .. source:makeCategoryLink() .. " " .. nametype .. " into {{{langlink}}}.",
						lang = data.lang,
						breadcrumb = sourcename .. " " .. nametype,
						parents = {
							{ name = "renderings of foreign personal names", sort = sourcename },
							{ name = nametype, lang = source:getCode(), sort = "{{{langname}}}" },
						},
						umbrella = {
							description = "Transliterations, respellings or other renderings of " .. source:makeCategoryLink() .. " " .. nametype .. " into various languages.",
							parents = {{name = "renderings of foreign personal names", is_label = true, sort = label}},
						},
					}
				end
			end
		end
	end
end)


return {LABELS = labels, RAW_CATEGORIES = raw_categories, HANDLERS = handlers}
