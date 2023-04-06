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

for _, pos in ipairs({"nouns", "pronouns", "numerals"}) do
	local sgpos = pos:gsub("s$", "")
	
	local function make_label(label, description, parents, breadcrumb)
		labels[pos .. " " .. label] = {
			description = "Czech " .. pos .. " " .. description,
			breadcrumb = breadcrumb or label,
			parents = parents,
		}
	end

	make_label("by stem type and gender",
		"categorized by stem type and typical gender. " ..
			"Note that \"typical gender\" means the gender that is typical for the " .. sgpos .. "'s ending (e.g. most " .. pos .. " in ''-а'' are " ..
			"feminine, and hence all such " .. pos .. " are considered to be \"typically feminine\"; but some are in fact masculine).",
		{{name = pos .. " by inflection type", sort = "stem type and gender"}}
	)

	make_label("by vowel alternation",
		"categorized according to their vowel alternation pattern (e.g. ''і'' vs. ''о'').",
		{{name = pos, sort = "vowel alternation"}}
	)

	make_label("with reducible stem",
		"with a reducible stem, where an extra vowel is inserted " ..
			"before the last stem consonant in the nominative singular and/or genitive plural.",
		{{name = pos .. " by inflection type", sort = "reducible stem"}}
	)

	make_label("with multiple stems",
		"with multiple stems.",
		{{name = pos .. " by inflection type", sort = "multiple stems"}}
	)

	labels["adjectival " .. pos] = {
		description = "Czech " .. pos .. " with adjectival endings.",
		parents = {pos},
	}

	make_label("with irregular stem",
		"with an irregular stem, which occurs in all cases except the nominative singular and maybe the accusative singular.",
		{{name = "irregular " .. pos, sort = "stem"}}
	)

	make_label("with irregular plural stem",
		"with an irregular plural stem, which occurs in all cases.",
		{{name = "irregular " .. pos, sort = "plural stem"}}
	)
end

local noun_stem_expl = {
	["hard"] = "a hard consonant",
	["velar-stem"] = "a velar (-к, -г or –x)",
	["semisoft"] = "a hushing consonant (-ш, -ж, -ч or -щ)",
	["soft"] = "a soft consonant",
	["c-stem"] = "-ц",
	["j-stem"] = "conceptual -й",
	["n-stem"] = "-м' (with -ен- in some forms)",
	["t-stem"] = "-я or -а (with -т- in most forms)",
	["possessive"] = "-ов, -єв, -ин or -їн",
	["surname"] = "-ов, -ів, -їв, -єв, -ин, -ін or -їн",
}

local noun_stem_to_declension = {
	["third-declension"] = "third",
	["t-stem"] = "fourth",
	["n-stem"] = "fourth",
}

local noun_stem_gender_endings = {
    ["masculine animate"] = {
		["hard"]              = {"a paired hard or unpaired consonant", "''-a''", "''-i'', ''-ové'' or ''-é''"},
		["velar-stem"]        = {"a velar", "''-a''", "''-i'', ''-ové'' or ''-é''"},
		["semisoft"]          = {"''-ius'' or ''-eus''", "''-ia''", "''-іové''"},
		["soft"]              = {"a paired soft or unpaired consonant", "''-e''", "''-i'' or ''-ové''"},
		["hard-о"]            = {"-о", "-и or occasionally -а"},
		["velar-stem-о"]      = {"-о", "-и or occasionally -а"},
		["soft-о"]            = {"-ьо", "-і"},
		["semisoft-о"]        = {"-о", "-и"},
		["semisoft-е"]        = {"-е", "-а"},
	},
    feminine = {
		["hard"]              = {"-а", "-и"},
		["semisoft"]          = {"-а", "-і"},
		["soft"]              = {"-я", "-і"},
		["j-stem"]            = {"-я", "-ї"},
		["third-declension"]  = {"-ь, -р, a labial, or a hushing consonant", "-і"},
		["semisoft-е"]        = {"-е", "-і"},
	},
    neuter = {
		["hard"]              = {"-о", "-а"},
		["velar-stem"]        = {"-о", "-а"},
		["semisoft"]          = {"-е", "-а"},
		["soft"]              = {"-е", "-я"},
		["j-stem"]            = {"-є", "-я"},
		["soft-я"]            = {"-я", "-я"},
		["n-stem"]            = {"-я", "-я"},
		["t-stem"]            = {"-я or -а", "-та"},
	},
}

table.insert(handlers, function(data)
	local in_ending = "in %-([оея])"

	local function get_stem_gender_text(stem, genderspec, pos)
		local gender = genderspec
		local ending = rmatch(gender, in_ending .. "$")
		local stemindex = stem
		if ending then
			gender = rsub(gender, " " .. in_ending .. "$", "")
			stemindex = stemindex .. "-" .. ending
		end
		if not noun_stem_gender_endings[gender] then
			return nil
		end
		local endings = noun_stem_gender_endings[gender][stemindex]
		if not endings then
			return nil
		end
		local sgending, plending = endings[1], endings[2]
		local stemtext = noun_stem_expl[stem] and " The stem ends in " .. noun_stem_expl[stem] .. "." or ""
		local genderdesc
		if rfind(genderspec, in_ending .. "$") then
			genderdesc = gender .. " " .. pos .. "s"
		else
			genderdesc = "usually " .. gender .. " " .. pos .. "s"
		end
		return stem .. ", " .. genderdesc .. ", normally ending in " .. sgending .. " in the nominative singular " ..
			" and " .. plending .. " in the nominative plural." .. stemtext
	end

	stem, gender, pos = rmatch(data.label, "^(.*) (.-) adjectival (.*)s$")
	if stem and noun_stem_expl[stem] then
		local stemspec = stem
		local endings = adj_decl_endings[stemspec]
		if endings then
			local stemtext = " The stem ends in " .. noun_stem_expl[stem] .. "."
			local accentdesc = accent == "a" and
				"This " .. pos .. " is stressed according to accent pattern a (stress on the stem)." or
				accent == "b" and
				"This " .. pos .. " is stressed according to accent pattern b (stress on the ending)." or
				"All " .. pos .. "s of this class are stressed according to accent pattern a (stress on the stem)."
			local accenttext = accent and " accent-" .. accent or ""
			local m, f, n, pl = unpack(endings)
			local sg =
				gender == "masculine" and m or
				gender == "feminine" and f or
				gender == "neuter" and n or
				nil
			return {
				description = "Czech " .. stem .. " " .. gender .. " " .. pos ..
				"s, with adjectival endings, ending in " .. (sg and sg .. " in the nominative singular and " or "") ..
				pl .. " in the nominative plural." .. stemtext .. " " .. accentdesc,
				breadcrumb = stem .. " " .. gender .. accenttext,
				parents = {
					{name = "adjectival " .. pos .. "s", sort = stem .. " " .. gender .. accenttext},
					pos .. "s by stem type, gender and accent pattern",
				}
			}
		end
	end

	local part1, stem, gender, accent, part2, pos = rmatch(data.label, "^((.-) (.-)%-form) accent%-(.-)( (.*)s)$")
	local ending
	if not stem then
		-- check for e.g. 'Czech hard masculine accent-a nouns in -о'
		part1, stem, gender, accent, part2, pos, ending = rmatch(data.label, "^((.-) ([a-z]+ine)) accent%-(.-)( (.*)s " .. in_ending .. ")$")
		if stem then
			gender = gender .. " in -" .. ending
		end
	end
	if not stem then
		-- check for e.g. 'Czech soft neuter accent-a nouns in -я'
		part1, stem, gender, accent, part2, pos, ending = rmatch(data.label, "^((.-) (neuter)) accent%-(.-)( (.*)s " .. in_ending .. ")$")
		if stem then
			gender = gender .. " in -" .. ending
		end
	end
	if stem then
		local stem_gender_text = get_stem_gender_text(stem, gender, pos)
		if stem_gender_text then
			local accent_text = " This " .. pos .. " is stressed according to accent pattern " ..
				escape_accent(accent) .. " (see {{tl|cs-ndecl}})."
			return {
				description = "Czech " .. stem_gender_text .. accent_text,
				breadcrumb = "Accent-" .. escape_accent(accent),
				parents = {
					{name = part1 .. part2, sort = accent},
					pos .. "s by stem type, gender and accent pattern",
				}
			}
		end
	end

	local stem, gender, pos = rmatch(data.label, "^(.-) (.-)%-form (.*)s$")
	if not stem then
		-- check for e.g. 'Czech hard masculine nouns in -о'
		stem, gender, pos, ending = rmatch(data.label, "^(.-) ([a-z]+ine) (.*)s " .. in_ending .. "$")
		if stem then
			gender = gender .. " in -" .. ending
		end
	end
	if not stem then
		-- check for e.g. 'Czech soft neuter nouns in -я'
		stem, gender, pos, ending = rmatch(data.label, "^(.-) (neuter) (.*)s " .. in_ending .. "$")
		if gender then
			gender = gender .. " in -" .. ending
		end
	end
	if stem then
		local stem_gender_text = get_stem_gender_text(stem, gender, pos)
		if stem_gender_text then
			return {
				description = "Czech " .. stem_gender_text,
				breadcrumb = ending and stem .. " " .. gender or stem .. " " .. gender .. "-form",
				parents = {pos .. "s by stem type and gender"},
			}
		end
	end

	local pos, accent = rmatch(data.label, "^(.*)s with accent pattern (.*)$")
	if accent then
		return {
			description = "Czech " .. pos .. "s with accent pattern " .. escape_accent(accent) ..
				" (see {{tl|cs-ndecl}}).",
			breadcrumb = {name = escape_accent(accent), nocap = true},
			parents = {{name = pos .. "s by accent pattern", sort = accent}},
		}
	end

	local pos, fromto, altfrom, altto = rmatch(data.label, "^(.*)s with ((.*)%-(.*)) alternation$")
	if altfrom then
		return {
			description = "Czech " .. pos .. "s with vowel alternation between " .. altfrom ..
				" in the lemma and " .. altto .. " in the last syllable of some or all remaining forms.",
			breadcrumb = {name = fromto, nocap = true},
			parents = {{name = pos .. "s by vowel alternation", sort = fromto}},
		}
	end
end)

return {LABELS = labels, HANDLERS = handlers}
