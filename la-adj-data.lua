local decl = {}

local lang = require("Module:languages").getByCode("la")
local m_links = require("Module:links")
local m_utilities = require("Module:utilities")

NAMESPACE = NAMESPACE or mw.title.getCurrentTitle().nsText

local function glossary_link(anchor, text)
	text = text or anchor
	return "[[Appendix:Glossary#" .. anchor .. "|" .. text .. "]]"
end

local function decl_link(english_declension, decl_text)
	decl_text = decl_text or english_declension .. "-declension"
	return "[[Appendix:Latin " .. english_declension .. " declension|" .. decl_text .. "]]"
end

decl["1&2"] = function(data, args)
	if data.gender == "F" then
		data.title = decl_link("first") .. " adjective"
	elseif data.gender then
		data.title = decl_link("second") .. " adjective"
	else
		data.title = decl_link("first", "first") .. "/" .. decl_link("second") .. " adjective"
	end

	local stem = args[1]
	local original = nil

	if data.types.er then
		if mw.ustring.match(stem, "er$") then
			table.insert(data.subtitles, "nominative masculine singular in ''-er''")
			table.insert(data.categories, "Latin first and second declension "
				.. data.pos .. " with nominative masculine singular in -er")
		elseif mw.ustring.match(stem, "ur$") then
			table.insert(data.subtitles, "nominative masculine singular in ''-ur''")
			table.insert(data.categories, "Latin first and second declension "
				.. data.pos .. " with nominative masculine singular in -ur")
		else
			error("Unrecognized ''-r'' stem (doesn't end in ''-er'' or ''-ur''): " .. stem)
		end
		original = stem
		stem = args[2] or stem
	end

	local us = "us"
	local a_sf = "a"
	local um = "um"
	local ae_gsf = "ae"
	local am = "am"
	local a_macron = "ā"

	if data.types.greekA or data.types.greekE then
		table.insert(data.subtitles, "Greek-type")
		table.insert(data.categories, "Latin first and second declension " ..
			data.pos .. " with Greek declension")
		if data.types.greekA then
			us = "os"
			um = "on"
			am = "ān"
		else
			us = "os"
			a_sf = "ē"
			um = "on"
			ae_gsf = "ēs"
			am = "ēn"
			a_macron = "ē"
		end
	end

	data.forms["nom_sg_m"] = original or (stem .. us)
	data.forms["nom_sg_f"] = stem .. a_sf
	data.forms["nom_sg_n"] = stem .. um
	data.forms["nom_pl_m"] = stem .. "ī"
	data.forms["nom_pl_f"] = stem .. "ae"
	data.forms["nom_pl_n"] = stem .. "a"

	data.forms["gen_sg_m"] = stem .. "ī"
	data.forms["gen_sg_f"] = stem .. ae_gsf
	data.forms["gen_sg_n"] = stem .. "ī"
	data.forms["gen_pl_m"] = stem .. "ōrum"
	data.forms["gen_pl_f"] = stem .. "ārum"
	data.forms["gen_pl_n"] = stem .. "ōrum"

	data.forms["dat_sg_m"] = stem .. "ō"
	data.forms["dat_sg_f"] = stem .. "ae"
	data.forms["dat_sg_n"] = stem .. "ō"
	data.forms["dat_pl_m"] = stem .. "īs"
	data.forms["dat_pl_f"] = stem .. "īs"
	data.forms["dat_pl_n"] = stem .. "īs"

	data.forms["acc_sg_m"] = stem .. um
	data.forms["acc_sg_f"] = stem .. am
	data.forms["acc_sg_n"] = stem .. um
	data.forms["acc_pl_m"] = stem .. "ōs"
	data.forms["acc_pl_f"] = stem .. "ās"
	data.forms["acc_pl_n"] = stem .. "a"

	data.forms["abl_sg_m"] = stem .. "ō"
	data.forms["abl_sg_f"] = stem .. a_macron
	data.forms["abl_sg_n"] = stem .. "ō"
	data.forms["abl_pl_m"] = stem .. "īs"
	data.forms["abl_pl_f"] = stem .. "īs"
	data.forms["abl_pl_n"] = stem .. "īs"

	data.forms["voc_sg_m"] = original or (stem .. "e")
	data.forms["voc_sg_f"] = stem .. a_sf
	data.forms["voc_sg_n"] = stem .. um
	data.forms["voc_pl_m"] = stem .. "ī"
	data.forms["voc_pl_f"] = stem .. "ae"
	data.forms["voc_pl_n"] = stem .. "a"

	data.forms["loc_sg_m"] = stem .. "ī"
	data.forms["loc_sg_f"] = stem .. "ae"
	data.forms["loc_sg_n"] = stem .. "ī"
	data.forms["loc_pl_m"] = stem .. "īs"
	data.forms["loc_pl_f"] = stem .. "īs"
	data.forms["loc_pl_n"] = stem .. "īs"

	if data.types.ius then
		table.insert(data.subtitles, "pronominal")
		--table.insert(data.subtitles, "with genitive singular in ''-īus'' and dative singular in ''-ī''")
		table.insert(data.categories, "Latin first and second declension " ..
			data.pos .. " with genitive singular in -īus")
		data.forms["gen_sg_m"] = stem .. "īus"
		data.forms["gen_sg_f"] = stem .. "īus"
		data.forms["gen_sg_n"] = stem .. "īus"
		data.forms["dat_sg_m"] = stem .. "ī"
		data.forms["dat_sg_f"] = stem .. "ī"
		data.forms["dat_sg_n"] = stem .. "ī"
	elseif data.types.not_ius then
		table.insert(data.subtitles, "non-pronominal")
		--table.insert(data.subtitles, "with normal genitive and dative singular")
	end
	if stem == "me" then
		data.forms["voc_sg_m"] = "mī"
	end
	if data.types.ic then
		table.insert(data.subtitles, "''hic''-type")
		--table.insert(data.subtitles, "with genitive singular ending in ''-ius'' and dative singular ending in ''-ic''")

		local oc = "oc"
		local oc_macron = "ōc"
		if stem == "ill" then
			oc = "uc"
			oc_macron = "ūc"
		end

		data.forms["nom_sg_m"] = stem .. "ic"
		data.forms["nom_sg_f"] = stem .. "aec"
		data.forms["nom_sg_n"] = stem .. oc
		data.forms["nom_pl_n"] = stem .. "aec"

		data.forms["gen_sg_m"] = {stem .. "uius", stem .. "ujus"}
		data.forms["gen_sg_f"] = {stem .. "uius", stem .. "ujus"}
		data.forms["gen_sg_n"] = {stem .. "uius", stem .. "ujus"}

		data.forms["dat_sg_m"] = stem .. "uic"
		data.forms["dat_sg_f"] = stem .. "uic"
		data.forms["dat_sg_n"] = stem .. "uic"

		data.forms["acc_sg_m"] = stem .. "unc"
		data.forms["acc_sg_f"] = stem .. "anc"
		data.forms["acc_sg_n"] = stem .. oc
		data.forms["acc_pl_n"] = stem .. "aec"

		data.forms["abl_sg_m"] = stem .. "ōc"
		data.forms["abl_sg_f"] = stem .. "āc"
		data.forms["abl_sg_n"] = stem .. oc_macron

		data.voc = false
	end

	table.insert(data.categories, "Latin first and second declension " ..
		data.pos)
end

decl["1-1"] = function(data, args)
	data.title = decl_link("first") .. " adjective"
	table.insert(data.subtitles, "masculine forms identical to feminine forms, no neuter forms")

	local stem = args[1]

	data.forms["nom_sg_m"] = stem .. "a"
	data.forms["nom_pl_m"] = stem .. "ae"

	data.forms["gen_sg_m"] = stem .. "ae"
	data.forms["gen_pl_m"] = stem .. "ārum"

	data.forms["dat_sg_m"] = stem .. "ae"
	data.forms["dat_pl_m"] = stem .. "īs"

	data.forms["acc_sg_m"] = stem .. "am"
	data.forms["acc_pl_m"] = stem .. "ās"

	data.forms["abl_sg_m"] = stem .. "ā"
	data.forms["abl_pl_m"] = stem .. "īs"

	data.forms["loc_sg_m"] = stem .. "ae"
	data.forms["loc_pl_m"] = stem .. "īs"

	data.forms["voc_sg_m"] = stem .. "a"
	data.forms["voc_pl_m"] = stem .. "ae"

	data.noneut = true

	table.insert(data.categories, "Latin first declension " .. data.pos)
end

decl["2-2"] = function(data, args)
	data.title = decl_link("second") .. " adjective"
	table.insert(data.subtitles, "feminine forms identical to masculine forms")

	local stem = args[1]

	local us = "us"
	local um = "um"
	local i_pl = "ī"

	if data.types.greek then
		table.insert(data.subtitles, "Greek-type")
		table.insert(data.categories, "Latin second declension " .. data.pos ..
			" with Greek declension")
		us = "os"
		um = "on"
		i_pl = "oe"
	end

	data.forms["nom_sg_m"] = stem .. us
	data.forms["nom_sg_n"] = stem .. um
	data.forms["nom_pl_m"] = stem .. i_pl
	data.forms["nom_pl_n"] = stem .. "a"

	data.forms["gen_sg_m"] = stem .. "ī"
	data.forms["gen_sg_n"] = stem .. "ī"
	data.forms["gen_pl_m"] = stem .. "ōrum"
	data.forms["gen_pl_n"] = stem .. "ōrum"

	data.forms["dat_sg_m"] = stem .. "ō"
	data.forms["dat_sg_n"] = stem .. "ō"
	data.forms["dat_pl_m"] = stem .. "īs"
	data.forms["dat_pl_n"] = stem .. "īs"

	data.forms["acc_sg_m"] = stem .. um
	data.forms["acc_sg_n"] = stem .. um
	data.forms["acc_pl_m"] = stem .. "ōs"
	data.forms["acc_pl_n"] = stem .. "a"

	data.forms["abl_sg_m"] = stem .. "ō"
	data.forms["abl_sg_n"] = stem .. "ō"
	data.forms["abl_pl_m"] = stem .. "īs"
	data.forms["abl_pl_n"] = stem .. "īs"

	data.forms["loc_sg_m"] = stem .. "ī"
	data.forms["loc_sg_n"] = stem .. "ī"
	data.forms["loc_pl_m"] = stem .. "īs"
	data.forms["loc_pl_n"] = stem .. "īs"

	data.forms["voc_sg_m"] = stem .. "e"
	data.forms["voc_sg_n"] = stem .. um
	data.forms["voc_pl_m"] = stem .. i_pl
	data.forms["voc_pl_n"] = stem .. "a"

	table.insert(data.categories, "Latin second declension " .. data.pos)
end

decl["3-1"] = function(data, args)
	if data.gender then
		data.title = decl_link("third") .. " adjective"
	else
		data.title = decl_link("third") .. " one-termination adjective"
	end

	local stem1 = args[1]
	local stem2 = args[2] or ""

	if stem2 == "" then
		stem2 = require("Module:la-utilities").make_stem2(stem1)
	end

	data.forms["nom_sg_m"] = stem1
	data.forms["nom_sg_n"] = stem1
	data.forms["nom_pl_m"] = stem2 .. "ēs"
	data.forms["nom_pl_n"] = stem2 .. "ia"

	data.forms["gen_sg_m"] = stem2 .. "is"
	data.forms["gen_sg_n"] = stem2 .. "is"
	data.forms["gen_pl_m"] = stem2 .. "ium"
	data.forms["gen_pl_n"] = stem2 .. "ium"

	data.forms["dat_sg_m"] = stem2 .. "ī"
	data.forms["dat_sg_n"] = stem2 .. "ī"
	data.forms["dat_pl_m"] = stem2 .. "ibus"
	data.forms["dat_pl_n"] = stem2 .. "ibus"

	data.forms["acc_sg_m"] = stem2 .. "em"
	data.forms["acc_sg_n"] = stem1
	data.forms["acc_pl_m"] = stem2 .. "ēs"
	data.forms["acc_pl_n"] = stem2 .. "ia"

	data.forms["abl_sg_m"] = stem2 .. "ī"
	data.forms["abl_sg_n"] = stem2 .. "ī"
	data.forms["abl_pl_m"] = stem2 .. "ibus"
	data.forms["abl_pl_n"] = stem2 .. "ibus"

	data.forms["loc_sg_m"] = stem2 .. "ī"
	data.forms["loc_sg_n"] = stem2 .. "ī"
	data.forms["loc_pl_m"] = stem2 .. "ibus"
	data.forms["loc_pl_n"] = stem2 .. "ibus"

	data.forms["voc_sg_m"] = stem1
	data.forms["voc_sg_n"] = stem1
	data.forms["voc_pl_m"] = stem2 .. "ēs"
	data.forms["voc_pl_n"] = stem2 .. "ia"

	if data.types.par then
		table.insert(data.subtitles, "non-i-stem")
		data.forms["nom_pl_n"] = stem2 .. "a"
		data.forms["gen_pl_m"] = stem2 .. "um"
		data.forms["gen_pl_n"] = stem2 .. "um"
		data.forms["abl_sg_m"] = stem2 .. "e"
		data.forms["abl_sg_n"] = stem2 .. "e"
		data.forms["loc_sg_m"] = {stem2 .. "ī", stem2 .. "e"}
		data.forms["loc_sg_n"] = {stem2 .. "ī", stem2 .. "e"}
		data.forms["acc_pl_n"] = stem2 .. "a"
		data.forms["voc_pl_n"] = stem2 .. "a"
	elseif data.types.not_par then
		table.insert(data.subtitles, "i-stem")
	end

	table.insert(data.categories, "Latin third declension " .. data.pos)
end

decl["3-C"] = function(data, args)
	local stem = args[1]

	if args[2] and args[2] ~= "" then
		stem = stem .. args[2]
	else
		stem = stem .. "i"
	end

	data.types.par = true
	decl["3-1"](data, {stem .. "or"})

	data.title = decl_link("third") .. " comparative adjective"
	data.subtitles = {}

	data.forms["nom_sg_n"] = stem .. "us"
	data.forms["acc_sg_n"] = stem .. "us"
	data.forms["voc_sg_n"] = stem .. "us"
end

decl["3-P"] = function(data, args)
	local stem1 = args[1]
	local stem2 = args[2] or ""

	decl["3-1"](data, args)
	data.title = decl_link("third") .. " participle"

	if stem2 == "" then
		stem2 = require("Module:la-utilities").make_stem2(stem1)
	end

	data.forms["abl_sg_m"] = {stem2 .. "e", stem2 .. "ī"}
	data.notes["abl_sg_m2"] = "When used purely as an adjective."
	data.forms["abl_sg_n"] = {stem2 .. "e", stem2 .. "ī"}
	data.notes["abl_sg_n2"] = "When used purely as an adjective."
	data.forms["acc_pl_m"] = {stem2 .. "ēs", stem2 .. "īs"}
end

decl["3-2"] = function(data, args)
	if data.gender then
		data.title = decl_link("third") .. " adjective"
	else
		data.title = decl_link("third") .. " two-termination adjective"
	end

	local stem = args[1]
	local stem2 = args[2] or ""
	if stem2 ~= "" then
		error("Can't provide second stem with third-declension two-termination adjectives: " .. stem2)
	end

	data.forms["nom_sg_m"] = stem .. "is"
	data.forms["nom_sg_n"] = stem .. "e"
	data.forms["nom_pl_m"] = stem .. "ēs"
	data.forms["nom_pl_n"] = stem .. "ia"

	data.forms["gen_sg_m"] = stem .. "is"
	data.forms["gen_sg_n"] = stem .. "is"
	data.forms["gen_pl_m"] = stem .. "ium"
	data.forms["gen_pl_n"] = stem .. "ium"

	data.forms["dat_sg_m"] = stem .. "ī"
	data.forms["dat_sg_n"] = stem .. "ī"
	data.forms["dat_pl_m"] = stem .. "ibus"
	data.forms["dat_pl_n"] = stem .. "ibus"

	data.forms["acc_sg_m"] = stem .. "em"
	data.forms["acc_sg_n"] = stem .. "e"
	data.forms["acc_pl_m"] = {stem .. "ēs", stem .. "īs"}
	data.forms["acc_pl_n"] = stem .. "ia"

	data.forms["abl_sg_m"] = stem .. "ī"
	data.forms["abl_sg_n"] = stem .. "ī"
	data.forms["abl_pl_m"] = stem .. "ibus"
	data.forms["abl_pl_n"] = stem .. "ibus"

	data.forms["loc_sg_m"] = stem .. "ī"
	data.forms["loc_sg_n"] = stem .. "ī"
	data.forms["loc_pl_m"] = stem .. "ibus"
	data.forms["loc_pl_n"] = stem .. "ibus"

	data.forms["voc_sg_m"] = stem .. "is"
	data.forms["voc_sg_n"] = stem .. "e"
	data.forms["voc_pl_m"] = stem .. "ēs"
	data.forms["voc_pl_n"] = stem .. "ia"

	table.insert(data.categories, "Latin third declension " .. data.pos)
end

decl["3-3"] = function(data, args)
	if data.gender then
		data.title = decl_link("third") .. " adjective"
	else
		data.title = decl_link("third") .. " three-termination adjective"
	end

	local stem1 = args[1]
	local stem2 = args[2] or ""

	if stem2 == "" then
		stem2 = require("Module:la-utilities").make_stem2(stem1)
	end

	data.forms["nom_sg_m"] = stem1
	data.forms["nom_sg_f"] = stem2 .. "is"
	data.forms["nom_sg_n"] = stem2 .. "e"
	data.forms["nom_pl_m"] = stem2 .. "ēs"
	data.forms["nom_pl_f"] = stem2 .. "ēs"
	data.forms["nom_pl_n"] = stem2 .. "ia"

	data.forms["gen_sg_m"] = stem2 .. "is"
	data.forms["gen_sg_f"] = stem2 .. "is"
	data.forms["gen_sg_n"] = stem2 .. "is"
	data.forms["gen_pl_m"] = stem2 .. "ium"
	data.forms["gen_pl_f"] = stem2 .. "ium"
	data.forms["gen_pl_n"] = stem2 .. "ium"

	data.forms["dat_sg_m"] = stem2 .. "ī"
	data.forms["dat_sg_f"] = stem2 .. "ī"
	data.forms["dat_sg_n"] = stem2 .. "ī"
	data.forms["dat_pl_m"] = stem2 .. "ibus"
	data.forms["dat_pl_f"] = stem2 .. "ibus"
	data.forms["dat_pl_n"] = stem2 .. "ibus"

	data.forms["acc_sg_m"] = stem2 .. "em"
	data.forms["acc_sg_f"] = stem2 .. "em"
	data.forms["acc_sg_n"] = stem2 .. "e"
	data.forms["acc_pl_m"] = stem2 .. "ēs"
	data.forms["acc_pl_f"] = stem2 .. "ēs"
	data.forms["acc_pl_n"] = stem2 .. "ia"

	data.forms["abl_sg_m"] = stem2 .. "ī"
	data.forms["abl_sg_f"] = stem2 .. "ī"
	data.forms["abl_sg_n"] = stem2 .. "ī"
	data.forms["abl_pl_m"] = stem2 .. "ibus"
	data.forms["abl_pl_f"] = stem2 .. "ibus"
	data.forms["abl_pl_n"] = stem2 .. "ibus"

	data.forms["loc_sg_m"] = stem2 .. "ī"
	data.forms["loc_sg_f"] = stem2 .. "ī"
	data.forms["loc_sg_n"] = stem2 .. "ī"
	data.forms["loc_pl_m"] = stem2 .. "ibus"
	data.forms["loc_pl_f"] = stem2 .. "ibus"
	data.forms["loc_pl_n"] = stem2 .. "ibus"

	data.forms["voc_sg_m"] = stem1
	data.forms["voc_sg_f"] = stem2 .. "is"
	data.forms["voc_sg_n"] = stem2 .. "e"
	data.forms["voc_pl_m"] = stem2 .. "ēs"
	data.forms["voc_pl_f"] = stem2 .. "ēs"
	data.forms["voc_pl_n"] = stem2 .. "ia"

	table.insert(data.categories, "Latin third declension " .. data.pos)
end

decl["irreg"] = function(data,args)
	if args[1] == "duo" or args[1] == "ambō" then
		data.title = stem == "amb" and glossary_link("irregular") .. " adjective" or "numeral"
		local stem = args[1] == "duo" and "du" or "amb"
		data.num = "pl"

		local stem_with_o = stem .. (stem == "amb" and "ō" or "o")

		data.forms["nom_pl_m"] = stem_with_o
		data.forms["nom_pl_f"] = stem .. "ae"
		data.forms["nom_pl_n"] = stem_with_o

		data.forms["gen_pl_m"] = stem .. "ōrum"
		data.forms["gen_pl_f"] = stem .. "ārum"
		data.forms["gen_pl_n"] = stem .. "ōrum"

		data.forms["dat_pl_m"] = stem .. "ōbus"
		data.forms["dat_pl_f"] = stem .. "ābus"
		data.forms["dat_pl_n"] = stem .. "ōbus"

		data.forms["acc_pl_m"] = {stem .. "ōs", stem_with_o}
		data.forms["acc_pl_f"] = stem .. "ās"
		data.forms["acc_pl_n"] = stem_with_o

		data.forms["abl_pl_m"] = stem .. "ōbus"
		data.forms["abl_pl_f"] = stem .. "ābus"
		data.forms["abl_pl_n"] = stem .. "ōbus"

		data.forms["voc_pl_m"] = stem_with_o
		data.forms["voc_pl_f"] = stem .. "ae"
		data.forms["voc_pl_n"] = stem_with_o

		if stem == "du" then
			data.footnote = "Note: The genitive masculine and neuter can also be found in the contracted form ''[[duum]]'' (also spelt ''[[duûm]]'')."
		end

	elseif args[1] == "mīlle" then
		data.title = "semi-" .. glossary_link("indeclinable") .. " numeral"
		data.forms["nom_sg_m"] = "mīlle"
		data.forms["nom_pl_m"] = {"mīlia", "mīllia"}

		data.forms["gen_sg_m"] = "mīlle"
		data.forms["gen_pl_m"] = {"mīlium", "mīllium"}

		data.forms["dat_sg_m"] = "mīlle"
		data.forms["dat_pl_m"] = {"mīlibus", "mīllibus"}

		data.forms["acc_sg_m"] = "mīlle"
		data.forms["acc_pl_m"] = {"mīlia", "mīllia"}

		data.forms["abl_sg_m"] = "mīlle"
		data.forms["abl_pl_m"] = {"mīlibus", "mīllibus"}

		data.forms["voc_sg_m"] = "mīlle"
		data.forms["voc_pl_m"] = {"mīlia", "mīllia"}
	elseif args[1] == "plūs" then
		data.title = glossary_link("irregular") .. " " .. decl_link("third") .. " comparative adjective"

		data.forms["nom_sg_m"] = ""
		data.forms["nom_sg_n"] = "plūs"
		data.forms["nom_pl_m"] = "plūrēs"
		data.forms["nom_pl_n"] = "plūra"

		data.forms["gen_sg_m"] = ""
		data.forms["gen_sg_n"] = "plūris"
		data.forms["gen_pl_m"] = "plūrium"
		data.forms["gen_pl_n"] = "plūrium"

		data.forms["dat_sg_m"] = ""
		data.forms["dat_sg_n"] = ""
		data.forms["dat_pl_m"] = "plūribus"
		data.forms["dat_pl_n"] = "plūribus"

		data.forms["acc_sg_m"] = ""
		data.forms["acc_sg_n"] = "plūs"
		data.forms["acc_pl_m"] = "plūrēs"
		data.forms["acc_pl_n"] = "plūra"

		data.forms["abl_sg_m"] = ""
		data.forms["abl_sg_n"] = "plūre"
		data.forms["abl_pl_m"] = "plūribus"
		data.forms["abl_pl_n"] = "plūribus"

		data.forms["voc_sg_m"] = ""
		data.forms["voc_sg_n"] = "plūs"
		data.forms["voc_pl_m"] = "plūrēs"
		data.forms["voc_pl_n"] = "plūra"

		data.footnote = "Note: Singular forms take the genitive of the whole and do not function as adjectives."

		table.insert(data.categories, "Latin third declension " .. data.pos)
	elseif args[1] == "is" or args[1] == "īdem" then
		data.title = glossary_link("demonstrative") .. " pronoun"

		local m = "m"
		local i = "i"
		if args[1] == "īdem" then
			m = "n"
			i = ""
		end

		data.forms["nom_sg_m"] = "is"
		data.forms["nom_sg_f"] = "ea"
		data.forms["nom_sg_n"] = "id"
		data.forms["nom_pl_m"] = {"eī", "iī"}
		data.forms["nom_pl_f"] = "eae"
		data.forms["nom_pl_n"] = "ea"

		data.forms["gen_sg_m"] = {"eius", "ejus"}
		data.forms["gen_sg_f"] = {"eius", "ejus"}
		data.forms["gen_sg_n"] = {"eius", "ejus"}
		data.forms["gen_pl_m"] = "eōru"..m
		data.forms["gen_pl_f"] = "eāru"..m
		data.forms["gen_pl_n"] = "eōru"..m

		data.forms["dat_sg_m"] = "eī"
		data.forms["dat_sg_f"] = "eī"
		data.forms["dat_sg_n"] = "eī"
		data.forms["dat_pl_m"] = {"eīs", i.."īs"}
		data.forms["dat_pl_f"] = {"eīs", i.."īs"}
		data.forms["dat_pl_n"] = {"eīs", i.."īs"}

		data.forms["acc_sg_m"] = "eu"..m
		data.forms["acc_sg_f"] = "ea"..m
		data.forms["acc_sg_n"] = "id"
		data.forms["acc_pl_m"] = "eōs"
		data.forms["acc_pl_f"] = "eās"
		data.forms["acc_pl_n"] = "ea"

		data.forms["abl_sg_m"] = "eō"
		data.forms["abl_sg_f"] = "eā"
		data.forms["abl_sg_n"] = "eō"
		data.forms["abl_pl_m"] = {"eīs", i.."īs"}
		data.forms["abl_pl_f"] = {"eīs", i.."īs"}
		data.forms["abl_pl_n"] = {"eīs", i.."īs"}

		data.voc = false

		if args[1] == "īdem" then
			data.forms["nom_sg_m"] = "ī"
			data.forms["nom_sg_n"] = "i"
			data.forms["nom_pl_m"] = "ī"

			data.forms["gen_sg_m"] = "eius"
			data.forms["gen_sg_f"] = "eius"
			data.forms["gen_sg_n"] = "eius"

			data.forms["acc_sg_n"] = "i"
		end
	elseif args[1] == "ille" then
		data.types.ius = true

		decl["1&2"](data, {"ill"})

		data.title = glossary_link("demonstrative") .. " pronoun"

		data.forms["nom_sg_m"] = "ille"
		data.forms["nom_sg_n"] = "illud"

		data.forms["acc_sg_n"] = "illud"

		data.voc = false

		data.categories = {}
	elseif args[1] == "iste" then
		data.types.ius = true

		decl["1&2"](data, {"ist"})

		data.title = glossary_link("demonstrative") .. " pronoun"

		data.forms["nom_sg_m"] = "iste"
		data.forms["nom_sg_n"] = "istud"

		data.forms["acc_sg_n"] = "istud"

		data.voc = false

		data.categories = {}
	elseif args[1] == "ipse" then
		data.types.ius = true

		decl["1&2"](data, {"ips"})

		data.title = glossary_link("demonstrative") .. " pronoun"

		data.forms["nom_sg_m"] = "ipse"
		data.forms["nom_sg_n"] = "ipsum"

		data.forms["acc_sg_n"] = "ipsum"

		data.voc = false

		data.categories = {}
	elseif args[1] == "quis" or args[1] == "quī" then
		local id = "id"
		local em = "em"
		local o = "ō"
		if args[1] == "quī" then
			id = "od"
			em = "am"
			o = "ā"
		end
		data.title = glossary_link("relative") .. "/" .. glossary_link("interrogative") .. " pronoun"

		data.forms["nom_sg_m"] = "quis"
		data.forms["nom_sg_f"] = "quis"
		data.forms["nom_sg_n"] = "qu"..id
		data.forms["nom_pl_m"] = "quī"
		data.forms["nom_pl_f"] = "quae"
		data.forms["nom_pl_n"] = "quae"

		data.forms["gen_sg_m"] = {"cuius", "cujus"}
		data.forms["gen_sg_f"] = {"cuius", "cujus"}
		data.forms["gen_sg_n"] = {"cuius", "cujus"}
		data.forms["gen_pl_m"] = "quōrum"
		data.forms["gen_pl_f"] = "quārum"
		data.forms["gen_pl_n"] = "quōrum"

		data.forms["dat_sg_m"] = "cui"
		data.forms["dat_sg_f"] = "cui"
		data.forms["dat_sg_n"] = "cui"
		data.forms["dat_pl_m"] = "quibus"
		data.forms["dat_pl_f"] = "quibus"
		data.forms["dat_pl_n"] = "quibus"

		data.forms["acc_sg_m"] = "quem"
		data.forms["acc_sg_f"] = "qu"..em
		data.forms["acc_sg_n"] = "qu"..id
		data.forms["acc_pl_m"] = "quōs"
		data.forms["acc_pl_f"] = "quās"
		data.forms["acc_pl_n"] = "quae"

		data.forms["abl_sg_m"] = "quō"
		data.forms["abl_sg_f"] = "qu"..o
		data.forms["abl_sg_n"] = "quō"
		data.forms["abl_pl_m"] = "quibus"
		data.forms["abl_pl_f"] = "quibus"
		data.forms["abl_pl_n"] = "quibus"

		data.voc = false

		if args[1] == "quī" then
			data.forms["nom_sg_m"] = "quī"
			data.forms["nom_sg_f"] = "quae"
		end

	elseif args[1] == "quisquis" then
		data.title = glossary_link("relative") .. "/" .. glossary_link("interrogative") .. " pronoun"

		data.forms["nom_sg_m"] = "quisquis"
		data.forms["nom_sg_f"] = "quisquis"
		data.forms["nom_sg_n"] = {"quidquid", "quicquid"}
		data.forms["nom_pl_m"] = "quīquī"
		data.forms["nom_pl_f"] = "quaequae"
		data.forms["nom_pl_n"] = "quaequae"

		data.forms["gen_sg_m"] = {"cuiuscuius", "cujuscujus"}
		data.forms["gen_sg_f"] = {"cuiuscuius", "cujuscujus"}
		data.forms["gen_sg_n"] = {"cuiuscuius", "cujuscujus"}
		data.forms["gen_pl_m"] = "quōrumquōrum"
		data.forms["gen_pl_f"] = "quārumquārum"
		data.forms["gen_pl_n"] = "quōrumquōrum"

		data.forms["dat_sg_m"] = "cuicui"
		data.forms["dat_sg_f"] = "cuicui"
		data.forms["dat_sg_n"] = "cuicui"
		data.forms["dat_pl_m"] = "quibusquibus"
		data.forms["dat_pl_f"] = "quibusquibus"
		data.forms["dat_pl_n"] = "quibusquibus"

		data.forms["acc_sg_m"] = "quemquem"
		data.forms["acc_sg_f"] = "quamquam"
		data.forms["acc_sg_n"] = {"quidquid", "quicquid"}
		data.forms["acc_pl_m"] = "quōsquōs"
		data.forms["acc_pl_f"] = "quāsquās"
		data.forms["acc_pl_n"] = "quaequae"

		data.forms["abl_sg_m"] = "quōquō"
		data.forms["abl_sg_f"] = "quāquā"
		data.forms["abl_sg_n"] = "quōquō"
		data.forms["abl_pl_m"] = "quibusquibus"
		data.forms["abl_pl_f"] = "quibusquibus"
		data.forms["abl_pl_n"] = "quibusquibus"

		data.forms["voc_sg_m"] = "quisquis"
		data.forms["voc_sg_f"] = "quisquis"
		data.forms["voc_sg_n"] = {"quidquid", "quicquid"}
		data.forms["voc_pl_m"] = "quīquī"
		data.forms["voc_pl_f"] = "quaequae"
		data.forms["voc_pl_n"] = "quaequae"

		data.voc = true
	else
		error('adjective ' .. args[1] .. ' not recognized')
	end
end

return decl

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
