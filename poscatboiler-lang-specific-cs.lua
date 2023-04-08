local labels = {}
local handlers = {}


--------------------------------- Adjectives --------------------------------

local adj_like_poses = {"adjective", "pronoun", "determiner", "numeral", "suffix"}
for _, pos in ipairs(adj_like_poses) do
	local plpos = require("Module:string utilities").pluralize(pos)
	labels["hard " .. plpos] = {
		description = "Czech hard-stem " .. plpos .. ".",
		parents = {{name = plpos .. " by inflection type", sort = "hard-stem"}},
	}
	labels["soft " .. plpos] = {
		description = "Czech soft-stem " .. plpos .. ".",
		parents = {{name = plpos .. " by inflection type", sort = "soft-stem"}},
	}
	labels[plpos .. " with short form"] = {
		description = "Czech " .. plpos .. " with short-form inflections.",
		parents = {{name = plpos .. " by inflection type", sort = "short form"}},
	}
end


--------------------------------- Nouns/Pronouns/Numerals --------------------------------

local possible_genders = {"masculine animate", "masculine inanimate", "feminine", "neuter"}

for _, pos in ipairs({"nouns", "pronouns", "numerals"}) do
	local sgpos = pos:gsub("s$", "")
	
	local function make_label(label, description, props)
		local full_label
		if rfind(label, "POS") then
			full_label = label:gsub("POS", pos)
		else
			full_label = pos .. " " .. label
		end
		local full_description
		if rfind(description, "POS") then
			full_description = description:gsub("POS", pos)
		else
			full_description = pos .. " " .. description
		end
		full_description = "Czech " .. full_description
		props.description = full_description
		if not props.breadcrumb then
			props.breadcrumb = label:gsub(" *POS *", " ")
			props.breadcrumb = mw.text.trim(props.breadcrumb)
		end
		labels[full_label] = props
	end

	make_label("by stem type and gender",
		"categorized by stem type and gender.",
		{parents = {name = pos .. " by inflection type", sort = "stem type and gender"}}
	)

	for _, gender in ipairs(possible_genders) do
		make_label(gender .. " POS by stem type",
			("%s POS categorized by stem type."):format(gender),
			{
				breadcrumb = gender,
				parents = {pos .. " by stem type and gender"},
			}
		)
	end

	make_label("with quantitative vowel alternation",
		"with stem alternation between a long vowel (''á'', ''é'', ''í'', ''ou'' or ''ů'') and the corresponding " ..
		"short vowel (''a'', ''e'', ''i'', ''o'' or ''u''), depending on the form.",
		{
			additional = "See also [[:Category:Czech %s with í-ě alternation]].",
			parents = {name = pos, sort = "quantitative vowel alternation"},
		}
	)

	make_label("with í-ě alternation",
		"with stem alternation between ''í'' and ''ě'', depending on the form.",
		{
			additional = "See also [[:Category:Czech %s with quantitative vowel alternation]].",
			parents = {name = pos, sort = "í-ě alternation"},
		}
	)

	make_label("with reducible stem",
		"with a reducible stem, where an extra vowel is inserted " ..
			"before the last stem consonant in the nominative singular and/or genitive plural.",
		{parents = {name = pos .. " by inflection type", sort = "reducible stem"}}
	)

	make_label("with multiple stems",
		"with multiple stems.",
		{parents = {name = pos .. " by inflection type", sort = "multiple stems"}}
	)

	make_label("adjectival POS",
		"with adjectival endings.",
		{parents = {pos}}
	)

	make_label("with irregular stem",
		"with an irregular stem, which occurs in all cases except the nominative singular and maybe the accusative "
		.. "singular and vocative singular.",
		{parents = {name = "irregular " .. pos, sort = "stem"}}
	)
end

local noun_stem_gender_endings = {
    ["masculine animate"] = {
		["hard"]              = {"a paired hard or unpaired consonant", "''-a''", "''-i'', ''-ové'' or ''-é''"},
		["velar-stem"]        = {"a velar", "''-a''", "''-i'', ''-ové'' or ''-é''"},
		["semisoft"]          = {"''-ius'' or ''-eus''", "''-ia''", "''-іové''"},
		["soft"]              = {"a paired soft or unpaired consonant", "''-e''/''-ě''", "''-i'' or ''-ové''"},
		["mixed"]             = {"''-l'', ''-n'' or ''-t''", "''-a'' or ''-e''/''-ě''", "''-i'' or ''-ové''"},
		["-a"]                = {"''-a''", "''-y'' (''-i'' after a soft consonant)", "''-é'' or ''-ové''"},
		["-e"]                = {"''-e''", "''-e''", "''-i'' or ''-ové''"},
		["-i/-y"]             = {"''-i''/''-y''", "''-iho''/''-yho''", "''-iové''/''-yové'' or ''-i''/''-y''"},
		["-o"]                = {"''-o''", "''-a''", "''-ové''"},
		["-u"]                = {"''-u''", "''-ua''", "''-uové''"},
		["t-stem"]            = {"''-e''/''-ě''", "''-ete''/''-ěte''", "''-ata''"},
	},
    ["masculine inanimate"] = {
		["hard"]              = {"a paired hard or unpaired consonant", "''-u'' or occasionally ''-a''", "''-y''"},
		["velar-stem"]        = {"a velar", "''-u'' or occasionally ''-a''", "''-y''"},
		["semisoft"]          = {"''-ius''", "''-a''", "''-e''"},
		["soft"]              = {"a paired soft or unpaired consonant", "''-e''", "''-e''"},
		["mixed"]             = {"''-l'', ''-n'' or ''-t''", "''-u'' or ''-e''", "''-e'' or ''-y''"},
		["-o"]                = {"''-o''", "''-a''", "''-ové''"},
	},
    feminine = {
		["hard"]              = {"''-a''", "''-y'' (''-i'' after a soft consonant)", "''-y'' (''-i'' after a soft consonant)"},
		["soft"]              = {"''-e''/'-ě''", "''-e''/''-ě''", "''-e''/''-ě''"},
		["mixed"]             = {"''-a''", "''i'' or ''-e''/''-ě''", "''i'' or ''-e''/''-ě''"},
		["soft zero-ending"]  = {"a paired soft or unpaired consonant", "''-e''/''-ě''", "''-e''/''-ě''"},
		["i-stem"]            = {"a paired soft or unpaired consonant", "''-i''", "''-i''"},
		["mixed i-stem"]      = {"a paired soft or unpaired consonant", "''-i'' or sometimes ''-e''/''-ě''", "''-i'' or sometimes ''-e''/''-ě''"},
		["-ea"]               = {"''-ea''", "''-ey'' or (if non-technical) ''-eje''",  "''-ey'' or (if non-technical) ''-eje''"},
		["technical-ea"]      = {"''-ea''", "''-ey''",  "''-ey''"},
		["-oa/-ua"]           = {"''-oa''/''-ua''", "''-oy''/''-uy''",  "''-oy''/''-uy''"},
		["-ia"]               = {"''-ia''", "''-ie''",  "''-ie''"},
	},
    neuter = {
		["hard"]              = {"''-o''", "''-a''", "''-a''"},
		["velar-stem"]        = {"a velar + ''-o''", "''-a''", "''-a''"},
		["semisoft"]          = {"''-io''/''-ium'', ''-eo''/''-eum'' or ''-ion''", "''-ia'' or ''-ea''",  "''-ia'' or ''-ea''"},
		["soft"]              = {"''-e''/''-ě''", "''-e''/''-ě''", "''-e''/''-ě''"},
		["-í"]                = {"''-í''", "''-í''", "''-í''"},
		["n-stem"]            = {"''-eno'' or ''-ě''", "''-ena'' or ''-ene''", "''-ena''"},
		["t-stem"]            = {"''-e''/''-ě''", "''-ete''/''-ěte''", "''-ata''"},
		["ma-stem"]           = {"''-ma''", "''-matu''", "''-mata''"},
	},
}

table.insert(handlers, function(data)
	--[=[
	Implement me!

	stem, gender, pos = rmatch(data.label, "^(.*) (.-) adjectival (.*)s$")
	if stem and noun_stem_expl[stem] then
		local stemspec = stem
		local endings = adj_decl_endings[stemspec]
		if endings then
			local stemtext = " The stem ends in " .. noun_stem_expl[stem] .. "."
			local m, f, n, pl = unpack(endings)
			local sg =
				gender == "masculine" and m or
				gender == "feminine" and f or
				gender == "neuter" and n or
				nil
			return {
				description = "Czech " .. stem .. " " .. gender .. " " .. pos ..
				"s, with adjectival endings, ending in " .. (sg and sg .. " in the nominative singular and " or "") ..
				pl .. " in the nominative plural." .. stemtext,
				breadcrumb = stem .. " " .. gender,
				parents = {
					{name = "adjectival " .. pos .. "s", sort = stem .. " " .. gender},
					pos .. "s by stem type and gender",
				}
			}
		end
	end
	]=]

	for _, gender in ipairs(possible_genders) do
		local in_ending = "in (%-[aeiouí/%-]+)"
		local breadcrumb
		-- check for e.g. 'Czech technical feminine nouns in -ea'
		local stemtype, pos, ending = rmatch(data.label, "^(.-) " .. gender .. " (.*)s " .. in_ending .. "$")
		if stemtype then
			stemtype = stemtype .. ending
			breadcrumb = stemtype .. " in " .. ending
		end
		if not stemtype then
			-- check for e.g. 'Czech masculine animate nouns in -u' or 'Czech feminine nouns in -oa/-ua'
			pos, ending = rmatch(data.label, "^" .. gender .. " (.*)s " .. in_ending .. "$")
			if pos then
				stemtype = ending
			end
			breadcrumb = " in " .. ending
		end
		if not stemtype then
			-- check for e.g. 'Czech soft masculine animate nouns' or 'Czech soft zero-ending feminine nouns'
			stemtype, pos = rmatch(data.label, "^(.-) " .. gender .. " (.*)s$")
			breadcrumb = stemtype
		end
		if stemtype then
			if noun_stem_gender_endings[gender] then
				local endings = noun_stem_gender_endings[gender][stemtype]
				if endings then
					local nom_s, gen_s, nom_p = unpack(endings)
					local additional =
						("This type normally ends in %s in the nominative singular; %s in the genitive singular; and %s in the nominative plural."):
						format(nom_s, gen_s, nom_p)
						return {
							description = "Czech " .. data.label .. ".",
							additional = additional,
							breadcrumb = ending and stem .. " " .. gender or stem .. " " .. gender .. "-form",
							parents = {
								{name = gender .. " " .. pos .. "s by stem type", sort = stemtype:gsub("%-", "")}
							},
						}
					end
				end
			end
		end
	end
)

return {LABELS = labels, HANDLERS = handlers}
