local export = {}


--[=[

Authorship: <benwing2>

]=]

local rmatch = mw.ustring.match

local vowels = "aeiouyäöüAEIOUYÄÖÜ"
local capletters = "A-ZÄÖÜ"
local CAP = "[" .. capletters .. "]"
local V = "[" .. vowels .. "]"
local NV = "[^" .. vowels .. "]"


export.articles = {
	["m"] = {
		ind_nom = "ein", def_nom = "der",
		ind_gen = "eines", def_gen = "des",
		ind_dat = "einem", def_dat = "dem",
		ind_acc = "einen", def_acc = "den",
		ind_abl = "einen", def_abl = "den",
		ind_voc = "einen", def_voc = "den",
	},
	["f"] = {
		ind_nom = "eine", def_nom = "die",
		ind_gen = "einer", def_gen = "der",
		ind_dat = "einer", def_dat = "der",
		ind_acc = "eine", def_acc = "die",
		ind_abl = "eine", def_abl = "die",
		ind_voc = "eine", def_voc = "die",
	},
	["n"] = {
		ind_nom = "ein", def_nom = "das",
		ind_gen = "eines", def_gen = "des",
		ind_dat = "einem", def_dat = "dem",
		ind_acc = "ein", def_acc = "das",
		ind_abl = "ein", def_abl = "das",
		ind_voc = "ein", def_voc = "das",
	},
	["p"] = {
		ind_nom = "([[keine]])", def_nom = "die",
		ind_gen = "([[keiner]])", def_gen = "der",
		ind_dat = "([[keinen]])", def_dat = "den",
		ind_acc = "([[keine]])", def_acc = "die",
		ind_abl = "?", def_abl = "?",
		ind_voc = "?", def_voc = "?",
	},
}


function export.apply_umlaut(term, origterm)
	local stem, after = term:match("^(.*[^e])(e[lmnr]?)$")
	if stem then
		-- Nagel -> Nägel, Garten -> Gärten
		return export.apply_umlaut(stem, term) .. after
	end
	-- Haus -> Häuschen
	local before_v, v, after_v = rmatch(term, "^(.*)([Aa])([Uu]" .. NV .. "-)$")
	if not before_v then
		-- Haar -> Härchen
		before_v, v, after_v = rmatch(term, "^(.*)([Aa])[Aa](" .. NV .. "-)$")
	end
	if not before_v then
		-- Boot -> Bötchen
		before_v, v, after_v = rmatch(term, "^(.*)([Oo])[Oo](" .. NV .. "-)$")
	end
	if not before_v then
		-- regular umlaut
		before_v, v, after_v = rmatch(term, "^(.*)([AaOouU])(" .. NV .. "-)$")
	end
	if before_v then
		return before_v .. umlaut[v] .. after_v
	end
	error("Can't umlaut " .. (origterm or term) .. " because the last vowel isn't a, o, u or au")
end


function export.fetch_footnotes(separated_group, parse_err)
	local footnotes
	for j = 2, #separated_group - 1, 2 do
		if separated_group[j + 1] ~= "" then
			parse_err("Extraneous text after bracketed footnotes: '" .. table.concat(separated_group) .. "'")
		end
		if not footnotes then
			footnotes = {}
		end
		table.insert(footnotes, separated_group[j])
	end
	return footnotes
end


function export.fetch_specs(iut, segments, separator, spectype, allow_blank, parse_err)
	local separated_groups = iut.split_alternating_runs_and_strip_spaces(segments, separator)
	if allow_blank and #separated_groups == 1 and #separated_groups[1] == 1 and
		separated_groups[1][1] == "" then
		return nil
	end
	local specs = {}
	for _, separated_group in ipairs(separated_groups) do
		local form = separated_group[1]
		if form == "" then
			parse_err("Blank form not allowed here, but saw '" ..  table.concat(segments) .. "'")
		end
		local new_spec = {form = form, footnotes = export.fetch_footnotes(separated_group, parse_err)}
		for _, existing_spec in ipairs(specs) do
			if existing_spec.form == new_spec.form then
				parse_err("Duplicate " .. spectype .. " spec '" .. table.concat(separated_group) .. "'")
			end
		end
		table.insert(specs, new_spec)
	end
	return specs
end


return export
