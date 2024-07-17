local labels = {}
local handlers = {}

local rfind = mw.ustring.find
local rmatch = mw.ustring.match


--------------------------------- Adjectives --------------------------------

local adj_like_poses = {"adjective", "pronoun", "determiner", "numeral", "suffix"}
for _, pos in ipairs(adj_like_poses) do
	local plpos = require("Module:string utilities").pluralize(pos)
	labels["hard " .. plpos] = {
		description = "{{{langname}}} hard-stem " .. plpos .. ".",
		breadcrumb = "hard",
		parents = {{name = plpos .. " by inflection type", sort = "hard-stem"}},
	}
	labels["soft " .. plpos] = {
		description = "{{{langname}}} soft-stem " .. plpos .. ".",
		breadcrumb = "soft",
		parents = {{name = plpos .. " by inflection type", sort = "soft-stem"}},
	}
	labels[plpos .. " with short forms"] = {
		description = "{{{langname}}} " .. plpos .. " with short-form inflections.",
		breadcrumb = "with short forms",
		parents = {{name = plpos .. " by inflection type", sort = "short forms"}},
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

	make_label("adjectival POS",
		"with adjectival endings.",
		{parents = {pos}}
	)

	make_label("by stem type and gender",
		"categorized by stem type and gender.",
		{parents = {name = pos .. " by inflection type", sort = "stem type and gender"}}
	)

	make_label("that change gender in the plural",
		"with a different gender in the singular vs. the plural, as determined by adjective concord.",
		{
			breadcrumb = "changing gender in the plural",
			parents = {
				{name = pos .. " by stem type and gender", sort = "changing gender in the plural"},
				{name = "irregular " .. pos, sort = "changing gender in the plural"},
			},
		}
	)

	make_label("adjectival POS by stem type and gender",
		"adjectival POS categorized by stem type and gender.",
		{
			parents = {
				{name = pos .. " by inflection type", sort = "stem type and gender"},
				{name = "adjectival " .. pos, sort = "stem type and gender"},
			}
		}
	)

	for _, gender in ipairs(possible_genders) do
		make_label(gender .. " POS by stem type",
			("%s POS categorized by stem type."):format(gender),
			{
				breadcrumb = gender,
				parents = {pos .. " by stem type and gender"},
			}
		)
		make_label(gender .. " adjectival POS by stem type",
			("%s adjectival POS categorized by stem type."):format(gender),
			{
				breadcrumb = gender,
				parents = {"adjectival " .. pos .. " by stem type and gender"},
			}
		)
		make_label("indeclinable " .. gender .. " POS",
			("indeclinable %s POS. Currently only POS with multiple declensions including at least one that is "
				.. "declinable are included."):format(gender),
			{
				breadcrumb = gender,
				parents = {"indeclinable " .. pos},
			}
		)
		make_label("mostly indeclinable " .. gender .. " POS",
			("mostly indeclinable %s POS, i.e. indeclinable in all but a few case/number combinations."
				):format(gender),
			{
				breadcrumb = "mostly indeclinable",
				parents = {"indeclinable " .. gender .. " " .. pos},
			}
		)
	end

	make_label("with quantitative vowel alternation",
		"with stem alternation between a long vowel (''á'', ''é'', ''í'', ''ou'' or ''ů'') and the corresponding " ..
		"short vowel (''a'', ''e'', ''i'', ''o'' or ''u''), depending on the form.",
		{
			additional = ("See also [[:Category:Czech %s with í-ě alternation]]."):format(pos),
			parents = {name = pos, sort = "quantitative vowel alternation"},
		}
	)

	make_label("with í-ě alternation",
		"with stem alternation between ''í'' and ''ě'', depending on the form.",
		{
			additional = ("See also [[:Category:Czech %s with quantitative vowel alternation]]."):format(pos),
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

	make_label("masculine animate POS",
		"masculine animate POS, i.e. POS referring (mostly) to male beings or animals.",
		{
			breadcrumb = "animate",
			parents = {{name = "masculine " .. pos, sort = "animate"}},
		}
	)

	make_label("masculine inanimate POS",
		"masculine inanimate POS, i.e. POS referring to inanimate objects that have masculine agreement patterns.",
		{
			breadcrumb = "inanimate",
			parents = {{name = "masculine " .. pos, sort = "inanimate"}},
		}
	)

	make_label("with regular foreign declension",
		"with a foreign ending such as ''-us'', ''-os'', ''-es'', ''-um'', ''-on'' or silent ''-e'', which is dropped in " ..
		"all cases except the nominative singular and maybe the accusative singular and vocative singular.",
		{parents = {name = pos .. " by inflection type", sort = "regular foreign declension"}}
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
		["-ee"]               = {"''-ee''", "''-eeho''", "''-eeové''"},
		["-i/-y"]             = {"''-i''/''-y''", "''-iho''/''-yho''", "''-iové''/''-yové'' or ''-i''/''-y''"},
		["-í/-ý"]             = {"''-i''/''-y''", "''-ího''/''-ýho''", "''-íové''/''-ýové'' or ''-í''/''-ý''"},
		["-ie"]               = {"''-ie''", "''-ieho''", "''-iové'' or ''-ies''"},
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
		["-e"]                = {"''-e''", "''-e''", "''-e''"},
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
		["-i"]                = {"''-i''", "''-i'' or ''eře'' (archaic)", "nonexistent"},
		["-ia"]               = {"''-ia''", "''-ie''",  "''-ie''"},
		["-oa/-ua"]           = {"''-oa''/''-ua''", "''-oy''/''-uy''",  "''-oy''/''-uy''"},
	},
    neuter = {
		["hard"]              = {"''-o''", "''-a''", "''-a''"},
		["velar-stem"]        = {"a velar + ''-o''", "''-a''", "''-a''"},
		["semisoft"]          = {"''-io''/''-ium'', ''-eo''/''-eum'' or ''-ion''", "''-ia'' or ''-ea''",  "''-ia'' or ''-ea''"},
		["soft"]              = {"''-e''/''-ě''", "''-e''/''-ě''", "''-e''/''-ě''"},
		["-í/-ý"]             = {"''-í''/''-ý''", "''-í''/''-ý''", "''-í''/''-ý''"},
		["n-stem"]            = {"''-eno'' or ''-ě''", "''-ena'' or ''-ene''", "''-ena''"},
		["t-stem"]            = {"''-e''/''-ě''", "''-ete''/''-ěte''", "''-ata''"},
		["ma-stem"]           = {"''-ma''", "''-matu''", "''-mata''"},
	},
}

local adj_noun_stem_gender_endings = {
    ["masculine animate"] = {
		["hard"]              = {"''-ý''", "''-ého''", "''-í''"},
		["soft"]              = {"''-í''", "''-ího''", "''-í''"},
		["possessive-ův"]     = {"''-ův''", "''-ova''", "''-ovi''"},
		["possessive-in"]     = {"''-in''", "''-ina''", "''-ini''"},
	},
    ["masculine inanimate"] = {
		["hard"]              = {"''-ý''", "''-ého''", "''-é''"},
		["soft"]              = {"''-í''", "''-ího''", "''-í''"},
		["possessive-ův"]     = {"''-ův''", "''-ova''", "''-ovy''"},
		["possessive-in"]     = {"''-in''", "''-ina''", "''-iny''"},
	},
    feminine = {
		["hard"]              = {"''-á''", "''-é''", "''-é''"},
		["soft"]              = {"''-í''", "''-í''", "''-í''"},
		["possessive-ova"]    = {"''-ova''", "''-ovy''", "''-ovy''"},
		["possessive-ina"]    = {"''-ina''", "''-iny''", "''-iny''"},
	},
    neuter = {
		["hard"]              = {"''-é''", "''-ého''", "''-á''"},
		["soft"]              = {"''-í''", "''-ího''", "''-í''"},
		["possessive-ovo"]    = {"''-ovo''", "''-ova''", "''-ova''"},
		["possessive-ino"]    = {"''-ino''", "''-ina''", "''-ina''"},
	},
}

table.insert(handlers, function(data)
	for _, gender in ipairs(possible_genders) do
		local in_ending = "in (%-[aeiouyůvn]+)"
		local breadcrumb
		-- check for e.g. 'Czech possessive feminine adjectival nouns in -ova'
		local stemtype, pos, ending = rmatch(data.label, "^(.-) " .. gender .. " adjectival (.*)s " .. in_ending .. "$")
		if stemtype then
			stemtype = stemtype .. ending
			breadcrumb = stemtype .. " in " .. ending
		end
		if not stemtype then
			-- check for e.g. 'Czech hard masculine animate adjectival nouns'
			stemtype, pos = rmatch(data.label, "^(.-) " .. gender .. " adjectival (.*)s$")
			breadcrumb = stemtype
		end
		if stemtype then
			if adj_noun_stem_gender_endings[gender] then
				local endings = adj_noun_stem_gender_endings[gender][stemtype]
				if endings then
					local nom_s, gen_s, nom_p = unpack(endings)
					local additional =
						("This type declines like an adjective. It normally ends in %s in the nominative singular; %s in the genitive singular; and %s in the nominative plural."):
						format(nom_s, gen_s, nom_p)
					return {
						description = "Czech " .. data.label .. ".",
						additional = additional,
						breadcrumb = breadcrumb,
						parents = {
							{name = gender .. " adjectival " .. pos .. "s by stem type", sort = stemtype:gsub("%-", "")}
						},
					}
				end
			end
		end
	end

	local pos, mixed_istem_type = rmatch(data.label, "^mixed i%-stem feminine (.*)s %(type '(.*)'%)$")
	if mixed_istem_type then
		return {
			description = "Czech mixed i-stem feminine " .. pos .. "s, declined like {{m|cs|" .. mixed_istem_type .. "}}.",
			additional = "These nouns have a mixture of soft-stem and i-stem endings in the genitive singular, " ..
				"nominative/accusative/vocative plural, dative plural, instrumental plural and locative plural. The particular endings used depend on the subtype.",
			breadcrumb = mixed_istem_type,
			parents = {
				{name = "mixed i-stem feminine " .. pos .. "s", sort = mixed_istem_type}
			},
		}
	end
		
	for _, gender in ipairs(possible_genders) do
		local in_ending = "in (%-[aeiouyíý/%-]+)"
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
				breadcrumb = " in " .. ending
			end
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
						breadcrumb = breadcrumb,
						parents = {
							{name = gender .. " " .. pos .. "s by stem type", sort = stemtype:gsub("%-", "")}
						},
					}
				end
			end
		end
	end
end)

return {LABELS = labels, HANDLERS = handlers}
