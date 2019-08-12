local decl = {}

local lang = require("Module:languages").getByCode("la")
local m_links = require("Module:links")
local m_utilities = require("Module:utilities")

local rsplit = mw.text.split
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsubn = mw.ustring.gsub

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

local current_title = mw.title.getCurrentTitle().nsText
local NAMESPACE = current_title.nsText
local PAGENAME = current_title.text

decl["1"] = function(data, args)
	local stem = args[1]

	-- normal 1st
	data.forms["nom_sg"] = stem .. "a"
	data.forms["gen_sg"] = stem .. "ae"
	data.forms["dat_sg"] = stem .. "ae"
	data.forms["acc_sg"] = stem .. "am"
	data.forms["abl_sg"] = stem .. "ā"
	data.forms["voc_sg"] = stem .. "a"

	data.forms["nom_pl"] = stem .. "ae"
	data.forms["gen_pl"] = stem .. "ārum"
	data.forms["dat_pl"] = stem .. "īs"
	data.forms["acc_pl"] = stem .. "ās"
	data.forms["abl_pl"] = stem .. "īs"
	data.forms["voc_pl"] = stem .. "ae"

	-- abus
	if data.types.abus then
		table.insert(data.subtitle, "dative/ablative plural in ''-ābus''")

		data.forms["dat_pl"] = stem .. "ābus"
		data.forms["abl_pl"] = stem .. "ābus"
	elseif data.types.not_abus then
		table.insert(data.post_subtitle, "''-īs''")
	end

	-- am
	if data.types.am then
		table.insert(data.subtitle, "nominative/vocative singular in ''-ām''")

		data.forms["nom_sg"] = stem .. "ām"
		data.forms["acc_sg"] = stem .. "ām"
		data.forms["voc_sg"] = stem .. "ām"
		data.forms["abl_sg"] = {stem .. "ām", stem .. "ā"}

	-- all Greek
	elseif data.types.Greek then

		--Greek Ma
		if data.types.Ma then
			table.insert(data.subtitle, "masculine Greek-type with nominative singular in ''-ās''")

			data.forms["nom_sg"] = stem .. "ās"
			data.forms["acc_sg"] = stem .. "ān"
			data.forms["voc_sg"] = stem .. "ā"

		-- Greek Me
		elseif data.types.Me then
			table.insert(data.subtitle, "masculine Greek-type with nominative singular in ''-ēs''")

			data.forms["nom_sg"] = stem .. "ēs"
			data.forms["acc_sg"] = stem .. "ēn"
			data.forms["abl_sg"] = stem .. "ē"
			data.forms["voc_sg"] = stem .. "ē"

		-- Greek
		else
			table.insert(data.subtitle, "Greek-type")

			data.forms["nom_sg"] = stem .. "ē"
			data.forms["gen_sg"] = stem .. "ēs"
			data.forms["acc_sg"] = stem .. "ēn"
			data.forms["abl_sg"] = stem .. "ē"
			data.forms["voc_sg"] = stem .. "ē"
		end
	elseif data.types.not_Greek then
		table.insert(data.subtitle, "non-Greek-type")
	elseif data.types.not_am then
		table.insert(data.subtitle, "''-a''")
	end

	-- with locative
	if data.loc then
		data.forms["loc_sg"] = stem .. "ae"
		data.forms["loc_pl"] = stem .. "īs"
	end
end

decl["2"] = function(data, args)
	local stem1 = args[1]
	local stem2 = args[2] or ""
	if stem2 == "" then
		stem2 = stem1
	end

	-- normal 2nd
	data.forms["nom_sg"] = stem1 .. "us"
	data.forms["gen_sg"] = stem1 .. "ī"
	data.forms["dat_sg"] = stem1 .. "ō"
	data.forms["acc_sg"] = stem1 .. "um"
	data.forms["abl_sg"] = stem1 .. "ō"
	data.forms["voc_sg"] = stem1 .. "e"

	data.forms["nom_pl"] = stem1 .. "ī"
	data.forms["gen_pl"] = stem1 .. "ōrum"
	data.forms["dat_pl"] = stem1 .. "īs"
	data.forms["acc_pl"] = stem1 .. "ōs"
	data.forms["abl_pl"] = stem1 .. "īs"
	data.forms["voc_pl"] = stem1 .. "ī"

	-- all neuter
	if data.types.N then
		table.insert(data.subtitle, "neuter")

		data.forms["nom_sg"] = stem1 .. "um"
		data.forms["voc_sg"] = stem1 .. "um"

		data.forms["nom_pl"] = stem1 .. "a"
		data.forms["acc_pl"] = stem1 .. "a"
		data.forms["voc_pl"] = stem1 .. "a"

		-- neuter ium
		if data.types.ium then
			data.forms["nom_sg"] = stem1 .. "ium"
			data.forms["gen_sg"] = {stem1 .. "iī", stem1 .. "ī"}
			data.forms["dat_sg"] = stem1 .. "iō"
			data.forms["acc_sg"] = stem1 .. "ium"
			data.forms["abl_sg"] = stem1 .. "iō"
			data.forms["voc_sg"] = stem1 .. "ium"

			data.forms["nom_pl"] = stem1 .. "ia"
			data.forms["gen_pl"] = stem1 .. "iōrum"
			data.forms["dat_pl"] = stem1 .. "iīs"
			data.forms["acc_pl"] = stem1 .. "ia"
			data.forms["abl_pl"] = stem1 .. "iīs"
			data.forms["voc_pl"] = stem1 .. "ia"

			data.notes["gen_sg2"] = "Found in older Latin (until the Augustan Age)."

		-- neuter Greek
		elseif data.types.Greek then
			table.insert(data.subtitle, "Greek-type")

			data.forms["nom_sg"] = stem1 .. "on"
			data.forms["acc_sg"] = stem1 .. "on"
			data.forms["voc_sg"] = stem1 .. "on"

		-- neuter us
		elseif data.types.us then
			table.insert(data.subtitle, "nominative/accusative/vocative in ''-us''")

			data.forms["nom_sg"] = stem1 .. "us"
			data.forms["acc_sg"] = stem1 .. "us"
			data.forms["voc_sg"] = stem1 .. "us"

			data.forms["nom_pl"] = stem1 .. "ī"
			data.forms["acc_pl"] = stem1 .. "ōs"
			data.forms["voc_pl"] = stem1 .. "ī"
		elseif data.types.not_Greek or data.types.not_us then
			table.insert(data.subtitle, "nominative/accusative/vocative in ''-um''")
		end

	-- er
	elseif data.types.er then
		if mw.ustring.match(stem1, "[aiouy]r$") then
			table.insert(data.subtitle, "nominative singular in ''-r''")
		else
			table.insert(data.subtitle, "nominative singular in ''-er''")
		end

		data.forms["nom_sg"] = stem1
		data.forms["gen_sg"] = stem2 .. "ī"
		data.forms["dat_sg"] = stem2 .. "ō"
		data.forms["acc_sg"] = stem2 .. "um"
		data.forms["abl_sg"] = stem2 .. "ō"
		data.forms["voc_sg"] = stem1

		data.forms["nom_pl"] = stem2 .. "ī"
		data.forms["gen_pl"] = stem2 .. "ōrum"
		data.forms["dat_pl"] = stem2 .. "īs"
		data.forms["acc_pl"] = stem2 .. "ōs"
		data.forms["abl_pl"] = stem2 .. "īs"
		data.forms["voc_pl"] = stem2 .. "ī"

	-- ius
	elseif data.types.ius then
		data.forms["nom_sg"] = stem1 .. "ius"
		data.forms["gen_sg"] = {stem1 .. "iī", stem1 .. "ī"}
		data.forms["dat_sg"] = stem1 .. "iō"
		data.forms["acc_sg"] = stem1 .. "ium"
		data.forms["abl_sg"] = stem1 .. "iō"
		if data.types.voci then
			-- Only for proper names and fīlius, genius
			data.forms["voc_sg"] = stem1 .. "ī"
		else
			data.forms["voc_sg"] = stem1 .. "ie"
		end

		data.forms["nom_pl"] = stem1 .. "iī"
		data.forms["gen_pl"] = stem1 .. "iōrum"
		data.forms["dat_pl"] = stem1 .. "iīs"
		data.forms["acc_pl"] = stem1 .. "iōs"
		data.forms["abl_pl"] = stem1 .. "iīs"
		data.forms["voc_pl"] = stem1 .. "iī"

		data.notes["gen_sg2"] = "Found in older Latin (until the Augustan Age)."

	-- vos (servos, etc.)
	elseif data.types.vos then
		table.insert(data.subtitle, "nominative singular in ''-os'' after ''v''")
		data.forms["nom_sg"] = stem1 .. "os"
		data.forms["acc_sg"] = stem1 .. "om"

	-- Greek
	elseif data.types.Greek then
		table.insert(data.subtitle, "Greek-type")

		data.forms["nom_sg"] = stem1 .. "os"
		data.forms["acc_sg"] = {stem1 .. "on"}
	elseif data.types.not_Greek then
		table.insert(data.subtitle, "non-Greek-type")
	end

	-- with -um genitive plural
	if data.types.genplum then
		table.insert(data.subtitle, "contracted genitive plural")
		data.notes["gen_pl2"] = "Contraction found in poetry."
		if data.types.ius or  data.types.ium then
			data.forms["gen_pl"] = {stem2 .. "iōrum", stem2 .. "ium"}
		else
			data.forms["gen_pl"] = {stem2 .. "ōrum", stem2 .. "um"}
		end
	elseif data.types.not_genplum then
		table.insert(data.subtitle, "normal genitive plural")
	end

	-- with locative
	if data.loc then
		if data.types.ius or data.types.ium then
			data.forms["loc_sg"] = stem2 .. "iī"
			data.forms["loc_pl"] = stem2 .. "iīs"
		else
			data.forms["loc_sg"] = stem2 .. "ī"
			data.forms["loc_pl"] = stem2 .. "īs"
		end
	end
end

local acc_sg_i_stem_subtypes = {
	acc_im = {
		-- amussis, basis, buris, cucumis, gummis, mephitis, paraphrasis, poesis, ravis, sitis, tussis, (vis) [abl -ī];
		-- cannabis, senapis, sinapis [abl -e, -ī]
		acc_sg = {"im"},
		title = {"accusative singular in ''-im''"},
	},
	acc_im_in = {
		-- cities, rivers, gods, e.g. Bilbilis, Syrtis, Tiberis, Anubis, Osiris [abl -ī];
		-- Baetis, Tigris [acc -e, -ī]
		acc_sg = {"im", "in"},
		title = {"accusative singular in ''-im'' or ''-in''"},
	},
	acc_im_in_em = {
		-- e.g. tigris, river Līris
		acc_sg = {"im", "in", "em"},
		title = {"accusative singular in ''-im'', ''-in'' or ''-em''"},
	},
	acc_im_em = {
		acc_sg = {"im", "em"},
		title = {"accusative singular in ''-im'' or ''-em''"},
	},
	acc_im_occ_em = {
		-- febris, pelvis, puppis, restis, securis, turris [abl -ī, -e]
		acc_sg = {"im", "em"},
		title = {"accusative singular in ''-im'' or occasionally ''-em''"},
	},
	acc_em_im = {
		-- aqualis, clavis, lens, navis [abl -e, -ī];
		-- cutis, restis [abl -e]
		acc_sg = {"em", "im"},
		title = {"accusative singular in ''-em'' or ''-im''"},
	},
}

local abl_sg_i_stem_subtypes = {
	abl_i = {
		-- amussis, basis, buris, cucumis, gummis, mephitis, paraphrasis, poesis, ravis, sitis, tussis, (vis) [acc -im];
		-- cities, rivers, gods, e.g. Bilbilis, Syrtis, Tiberis, Anubis, Osiris [acc -im or -in];
		-- canalis "water pipe", months in -is or -er, nouns originally i-stem adjectives such as aedilis, affinis, bipennis, familiaris, sodalis, volucris, etc. [acc -em]
		abl_sg = {"ī"},
		title = {"ablative singular in ''-ī''"},
	},
	abl_i_e = {
		-- febris, pelvis, puppis, restis, securis, turris [acc -im, -em]
		abl_sg = {"ī", "e"},
		title = {"ablative singular in ''-ī'' or ''-e''"},
	},
	abl_e_i = {
		-- cannabis, senapis, sinapis [acc -im];
		-- Baetis, Tigris [acc -im, -in];
		-- aqualis, clavis, lens, navis [acc -em, -im];
		-- finis, mugilis, occiput, pugil, rus, supellex, vectis [acc -em]
		abl_sg = {"e", "ī"},
		title = {"ablative singular in ''-e'' or ''-ī''"},
	},
	abl_e_occ_i = {
		-- amnis, anguis, avis, civis, classis, fustis, ignis, imber, orbis, pars, postis, sors, unguis, vesper [acc -em]
		abl_sg = {"e", "ī"},
		title = {"ablative singular in ''-e'' or occasionally ''-ī''"},
	},
}

local function extract_stem(form, ending)
	local base = rmatch(form, "^(.*)" .. ending .. "$")
	if not base then
		error("Form " .. form .. " should end in -" .. ending)
	end
	return base
end

decl["3"] = function(data, args)
	local stem1 = args[1]
	local stem2 = args[2] or ""

	if stem2 == "" then
		stem2 = require("Module:la-utilities").make_stem2(stem1)
	end

	--normal 3rd
	data.forms["nom_sg"] = stem1
	data.forms["gen_sg"] = stem2 .. "is"
	data.forms["dat_sg"] = stem2 .. "ī"
	data.forms["acc_sg"] = stem2 .. "em"
	data.forms["abl_sg"] = stem2 .. "e"
	data.forms["voc_sg"] = stem1

	data.forms["nom_pl"] = stem2 .. "ēs"
	data.forms["gen_pl"] = stem2 .. "um"
	data.forms["dat_pl"] = stem2 .. "ibus"
	data.forms["acc_pl"] = stem2 .. "ēs"
	data.forms["abl_pl"] = stem2 .. "ibus"
	data.forms["voc_pl"] = stem2 .. "ēs"

	local acc_sg_i_stem_subtype = false
	local not_acc_sg_i_stem_subtype = false
	for subtype, _ in pairs(data.types) do
		if acc_sg_i_stem_subtypes[subtype] then
			acc_sg_i_stem_subtype = true
			break
		end
	end
	for acc_sg_subtype, _ in pairs(acc_sg_i_stem_subtypes) do
		if subtypes["not_" .. acc_sg_subtype] then
			not_acc_sg_i_stem_subtype = true
			break
		end
	end
	local abl_sg_i_stem_subtype = false
	local not_abl_sg_i_stem_subtype = false
	for subtype, _ in pairs(data.types) do
		if abl_sg_i_stem_subtypes[subtype] then
			abl_sg_i_stem_subtype = true
			break
		end
	end
	for abl_sg_subtype, _ in pairs(abl_sg_i_stem_subtypes) do
		if subtypes["not_" .. abl_sg_subtype] then
			not_abl_sg_i_stem_subtype = true
			break
		end
	end

	-- all Greek
	if data.types.Greek then
		table.insert(data.subtitle, "Greek-type")

		-- Greek er
		if data.types.er then
			table.insert(data.subtitle, "nominative singular in ''-ēr''")
			stem1 = extract_stem(stem1, "ēr")

			data.forms["nom_sg"] = stem1 .. "ēr"
			data.forms["gen_sg"] = stem1 .. "eris"
			data.forms["dat_sg"] = stem1 .. "erī"
			data.forms["acc_sg"] = {stem1 .. "era", stem1 .. "erem"}
			data.forms["abl_sg"] = stem1 .. "ere"
			data.forms["voc_sg"] = stem1 .. "ēr"

			data.forms["nom_pl"] = stem1 .. "erēs"
			data.forms["gen_pl"] = stem1 .. "erum"
			data.forms["dat_pl"] = stem1 .. "eribus"
			data.forms["acc_pl"] = stem1 .. "erēs"
			data.forms["abl_pl"] = stem1 .. "eribus"
			data.forms["voc_pl"] = stem1 .. "erēs"

		-- Greek on
		elseif data.types.on then
			table.insert(data.subtitle, "nominative singular in ''-ōn''")
			stem1 = extract_stem(stem1, "ōn")

			data.forms["nom_sg"] = stem1 .. "ōn"
			data.forms["gen_sg"] = {stem1 .. "ontis", stem1 .. "ontos"}
			data.forms["dat_sg"] = stem1 .. "ontī"
			data.forms["acc_sg"] = stem1 .. "onta"
			data.forms["abl_sg"] = stem1 .. "onte"
			data.forms["voc_sg"] = stem1 .. "ōn"

			data.forms["nom_pl"] = stem1 .. "ontēs"
			data.forms["gen_pl"] = {stem1 .. "ontum", stem1 .. "ontium"}
			data.forms["dat_pl"] = stem1 .. "ontibus"
			data.forms["acc_pl"] = {stem1 .. "ontēs", stem1 .. "ontās"}
			data.forms["abl_pl"] = stem1 .. "ontibus"
			data.forms["voc_pl"] = stem1 .. "ontēs"

		-- Greek i-stem
		elseif data.types.I then
			table.insert(data.subtitle, "i-stem")
			data.forms["gen_sg"] = {stem2 .. "is", stem2 .. "eōs", stem2 .. "ios"}
			data.forms["acc_sg"] = {stem2 .. "im", stem2 .. "in", stem2 .. "em"}
			data.forms["abl_sg"] = {stem2 .. "ī", stem2 .. "e"}
			data.forms["voc_sg"] = {stem2 .. "is", stem2 .. "i"}

			data.notes["acc_sg3"] = "Found sometimes in Medieval and New Latin."
			data.notes["abl_sg2"] = "Found sometimes in Medieval and New Latin."

			data.forms["nom_pl"] = {stem2 .. "ēs", stem2 .. "eis"}
			data.forms["gen_pl"] = {stem2 .. "ium", stem2 .. "eōn"}
			data.forms["acc_pl"] = {stem2 .. "ēs", stem2 .. "eis"}
			data.forms["voc_pl"] = {stem2 .. "ēs", stem2 .. "eis"}

			if data.types.poetic_esi then
				data.forms["dat_pl"] = {stem2 .. "ibus", stem2 .. "esi"}
				data.forms["abl_pl"] = {stem2 .. "ibus", stem2 .. "esi"}
				data.notes["dat_pl2"] = "Primarily in poetry."
				data.notes["abl_pl2"] = "Primarily in poetry."
			end

		-- normal Greek
		else
			data.forms["gen_sg"] = stem2 .. "os"
			if stem2:find("y$") then
				data.forms["acc_sg"] = stem2 .. "n"
			else
				data.forms["acc_sg"] = stem2 .. "a"
			end

			data.forms["nom_pl"] = stem2 .. "es"
			data.forms["acc_pl"] = stem2 .. "as"
			data.forms["voc_pl"] = stem2 .. "es"
			if rfind(stem1, "[iyï]s$") then
				-- Per Hiley, words in -is and -ys have a poetic vocative
				-- without the -s, but otherwise the vocative is the same
				-- as the nominative.
				data.forms["voc_sg"] = {stem1, rsub(stem1, "s", "")}
				data.notes["voc_sg2"] = "In poetry."
			end
		end
	elseif data.types.not_Greek then
		table.insert(data.subtitle, "non-Greek-type")
	end

	-- polis
	if data.types.polis then
		stem1 = extract_stem(stem1, "polis")
		table.insert(data.subtitle, "i-stem, partially Greek-type")

		data.forms["nom_sg"] = stem1 .. "polis"
		data.forms["gen_sg"] = stem1 .. "polis"
		data.forms["dat_sg"] = stem1 .. "polī"
		data.forms["acc_sg"] = {stem1 .. "polim", stem1 .. "polin"}
		data.forms["abl_sg"] = stem1 .. "polī"
		data.forms["voc_sg"] = {stem1 .. "polis", stem1 .. "polī"}
	elseif data.types.not_polis then
		table.insert(data.subtitle, "non-i-stem")
	end

	-- all neuter
	if data.types.N then
		table.insert(data.subtitle, "neuter")

		data.forms["acc_sg"] = stem1

		-- neuter I stem
		if data.types.I then

			-- pure variety
			if data.types.pure then
				table.insert(data.subtitle, "“pure” i-stem")
				data.forms["abl_sg"] = stem2 .. "ī"

				data.forms["nom_pl"] = stem2 .. "ia"
				data.forms["gen_pl"] = stem2 .. "ium"
				data.forms["acc_pl"] = stem2 .. "ia"
				data.forms["voc_pl"] = stem2 .. "ia"

			-- non-pure variety (rare)
			else
				table.insert(data.subtitle, "i-stem")
				data.forms["nom_pl"] = stem2 .. "a"
				data.forms["gen_pl"] = {stem2 .. "ium", stem2 .. "um"}
				data.forms["acc_pl"] = stem2 .. "a"
				data.forms["voc_pl"] = stem2 .. "a"
			end

		-- normal neuter
		else
			table.insert(data.subtitle, "non-i-stem")
			data.forms["nom_pl"] = stem2 .. "a"
			data.forms["acc_pl"] = stem2 .. "a"
			data.forms["voc_pl"] = stem2 .. "a"
		end

	-- I stem
	elseif data.types.I or acc_sg_i_stem_subtype or abl_sg_i_stem_subtype then
		if data.types.not_N then
			table.insert(data.subtitle, "non-neuter i-stem")
		else
			table.insert(data.subtitle, "i-stem")
		end

		data.forms["gen_pl"] = stem2 .. "ium"
		-- Per Allen and Greenough, Hiley and others, the acc_pl in -īs
		-- applied originally to all i-stem nouns, and was current as an
		-- alternative form up through Caesar.
		data.forms["acc_pl"] = {stem2 .. "ēs", stem2 .. "īs"}

		for subtype, _ in pairs(data.types) do
			local acc_sg_i_stem_props = acc_sg_i_stem_subtypes[subtype]
			if acc_sg_i_stem_props then
				data.forms["acc_sg"] = {}
				for _, ending in ipairs(acc_sg_i_stem_props.acc_sg) do
					table.insert(data.forms["acc_sg"], stem2 .. ending)
				end
				if data.num ~= "pl" then
					for _, t in ipairs(acc_sg_i_stem_props.title) do
						table.insert(data.subtitle, t)
					end
				end
				break
			end
		end

		for subtype, _ in pairs(data.types) do
			local abl_sg_i_stem_props = abl_sg_i_stem_subtypes[subtype]
			if abl_sg_i_stem_props then
				data.forms["abl_sg"] = {}
				for _, ending in ipairs(abl_sg_i_stem_props.abl_sg) do
					table.insert(data.forms["abl_sg"], stem2 .. ending)
				end
				if data.num ~= "pl" then
					for _, t in ipairs(abl_sg_i_stem_props.title) do
						table.insert(data.subtitle, t)
					end
				end
				break
			end
		end
	elseif data.types.not_N and data.types.not_I then
		table.insert(data.subtitle, "non-neuter non-i-stem")
	elseif data.types.not_N then
		table.insert(data.subtitle, "non-neuter")
	elseif data.types.not_I then
		table.insert(data.subtitle, "non-i-stem")
	end

	-- with locative
	if data.loc then
		-- As far as I can tell, in general both dative singular and
		-- ablative singular could be used for the third-declension locative,
		-- with different time periods preferring different forms.
		-- http://dcc.dickinson.edu/grammar/latin/3rd-declension-locative-case
		-- mentions rūrī along with either Carthāginī or Carthāgine.
		-- Wikipedia in https://en.wikipedia.org/wiki/Locative_case#Latin
		-- says this:
		--
		-- In archaic times, the locative singular of third declension nouns
		-- was still interchangeable between ablative and dative forms, but in
		-- the Augustan Period the use of the ablative form became fixed.
		-- Therefore, both forms "rūrī" and "rūre" may be encountered.
		--
		-- Lewis and Short confirm this.
		local loc_sg = data.forms["dat_sg"]
		if type(loc_sg) ~= "table" then
			loc_sg = {loc_sg}
		end
		loc_sg = require("Module:utils").clone(loc_sg)
		local abl_sg = data.forms["abl_sg"]
		if type(abl_sg) ~= "table" then
			abl_sg = {abl_sg}
		end
		for _, form in ipairs(abl_sg) do
			require("Module:utils").insert_if_not(loc_sg, form)
		end
		data.forms["loc_sg"] = loc_sg
		data.forms["loc_pl"] = data.forms["abl_pl"]
		--The following is what we used to have, but I simply cannot believe it.
		--if data.types.Greek and not data.types.s then
		--	data.forms["loc_pl"] = stem2 .. "ēs"
		--end
	end
end

decl["4"] = function(data, args)
	local stem = args[1]

	-- normal 4th
	data.forms["nom_sg"] = stem .. "us"
	data.forms["gen_sg"] = stem .. "ūs"
	data.forms["dat_sg"] = stem .. "uī"
	data.forms["acc_sg"] = stem .. "um"
	data.forms["abl_sg"] = stem .. "ū"
	data.forms["voc_sg"] = stem .. "us"

	data.forms["nom_pl"] = stem .. "ūs"
	data.forms["gen_pl"] = stem .. "uum"
	data.forms["dat_pl"] = stem .. "ibus"
	data.forms["acc_pl"] = stem .. "ūs"
	data.forms["abl_pl"] = stem .. "ibus"
	data.forms["voc_pl"] = stem .. "ūs"

	if data.types.echo then
		table.insert(data.subtitle, "nominative/vocative singular in ''-ō''")
		data.forms["nom_sg"] = stem .. "ō"
		data.forms["voc_sg"] = stem .. "ō"
	elseif data.types.argo then
		table.insert(data.subtitle, "nominative/accusative/vocative singular in ''-ō'', ablative singular in ''-uī''")
		data.forms["nom_sg"] = stem .. "ō"
		data.forms["acc_sg"] = stem .. "ō"
		data.forms["abl_sg"] = stem .. "uī"
		data.forms["voc_sg"] = stem .. "ō"
	elseif data.types.Callisto then
		table.insert(data.subtitle, "all cases except the genitive singular in ''-ō''")
		data.forms["nom_sg"] = stem .. "ō"
		data.forms["dat_sg"] = stem .. "ō"
		data.forms["acc_sg"] = stem .. "ō"
		data.forms["abl_sg"] = stem .. "ō"
		data.forms["voc_sg"] = stem .. "ō"
	end

	-- neuter
	if data.types.N then
		table.insert(data.subtitle, "neuter")

		data.forms["nom_sg"] = stem .. "ū"
		data.forms["dat_sg"] = stem .. "ū"
		data.forms["acc_sg"] = stem .. "ū"
		data.forms["voc_sg"] = stem .. "ū"

		data.forms["nom_pl"] = stem .. "ua"
		data.forms["acc_pl"] = stem .. "ua"
		data.forms["voc_pl"] = stem .. "ua"
	end

	-- ubus
	if data.types.ubus then
		table.insert(data.subtitle, "dative/ablative plural in ''-ubus''")

		data.forms["dat_pl"] = stem .. "ubus"
		data.forms["abl_pl"] = stem .. "ubus"
	elseif data.types.not_ubus then
		table.insert(data.subtitle, "''-ibus''")
	end

	-- with locative
	if data.loc then
		data.forms["loc_sg"] = data.forms["abl_sg"]
		data.forms["loc_pl"] = data.forms["abl_pl"]
	end
end

decl["5"] = function(data, args)
	local stem = args[1]

	-- ies
	if data.types.i then
		stem = stem .. "i"
	end

	data.forms["nom_sg"] = stem .. "ēs"
	data.forms["gen_sg"] = stem .. "eī"
	data.forms["dat_sg"] = stem .. "eī"
	data.forms["acc_sg"] = stem .. "em"
	data.forms["abl_sg"] = stem .. "ē"
	data.forms["voc_sg"] = stem .. "ēs"

	data.forms["nom_pl"] = stem .. "ēs"
	data.forms["gen_pl"] = stem .. "ērum"
	data.forms["dat_pl"] = stem .. "ēbus"
	data.forms["acc_pl"] = stem .. "ēs"
	data.forms["abl_pl"] = stem .. "ēbus"
	data.forms["voc_pl"] = stem .. "ēs"

	-- ies
	if data.types.i then
		data.forms["gen_sg"] = stem .. "ēī"
		data.forms["dat_sg"] = stem .. "ēī"
	end

	--with locative
	if data.loc then
		data.forms["loc_sg"] = stem .. "ē"
		data.forms["loc_pl"] = stem .. "ēbus"
	end
end

decl["0"] = function(data, args)
	local stem = args[1]

	data.forms["nom_sg"] = stem
	data.forms["gen_sg"] = stem
	data.forms["dat_sg"] = stem
	data.forms["acc_sg"] = stem
	data.forms["abl_sg"] = stem
	data.forms["voc_sg"] = stem

	data.forms["nom_pl"] = stem
	data.forms["gen_pl"] = stem
	data.forms["dat_pl"] = stem
	data.forms["acc_pl"] = stem
	data.forms["abl_pl"] = stem
	data.forms["voc_pl"] = stem

	-- with locative
	if data.loc then
		data.forms["loc_sg"] = stem
		data.forms["loc_pl"] = stem
	end
end

decl["indecl"] = function(data, args)
	local title = {}
	data.title = "Not declined; used only in the nominative and accusative singular."

	local stem = args[1]

	data.forms["nom_sg"] = "-"
	data.forms["gen_sg"] = "-"
	data.forms["dat_sg"] = "-"
	data.forms["acc_sg"] = "-"
	data.forms["abl_sg"] = "-"
	data.forms["voc_sg"] = "-"

	data.forms["nom_pl"] = "-"
	data.forms["gen_pl"] = "-"
	data.forms["dat_pl"] = "-"
	data.forms["acc_pl"] = "-"
	data.forms["abl_pl"] = "-"
	data.forms["voc_pl"] = "-"

	data.forms["nom_sg"] = stem
	data.forms["acc_sg"] = stem
	data.num = "sg"
end

decl["irreg"] = function(data, args)
	local title = {}

	local stem = args[1]

	data.forms["nom_sg"] = "-"
	data.forms["gen_sg"] = "-"
	data.forms["dat_sg"] = "-"
	data.forms["acc_sg"] = "-"
	data.forms["abl_sg"] = "-"
	data.forms["voc_sg"] = "-"

	data.forms["nom_pl"] = "-"
	data.forms["gen_pl"] = "-"
	data.forms["dat_pl"] = "-"
	data.forms["acc_pl"] = "-"
	data.forms["abl_pl"] = "-"
	data.forms["voc_pl"] = "-"

	if stem == "bōs" then
		table.insert(title, "[[Appendix:Latin third declension|Third declension]], irregular")

		data.forms["nom_sg"] = "bōs"
		data.forms["gen_sg"] = "bovis"
		data.forms["dat_sg"] = "bovī"
		data.forms["acc_sg"] = "bovem"
		data.forms["abl_sg"] = "bove"
		data.forms["voc_sg"] = "bōs"

		data.forms["nom_pl"] = "bovēs"
		data.forms["gen_pl"] = "boum"
		data.forms["dat_pl"] = {"bōbus", "būbus"}
		data.forms["acc_pl"] = "bovēs"
		data.forms["abl_pl"] = {"bōbus", "būbus"}
		data.forms["voc_pl"] = "bovēs"

	elseif stem == "cherub" then
		table.insert(title, "Borrowed from Hebrew with its plural, otherwise indeclinable")

		data.forms["nom_sg"] = "cherub"
		data.forms["gen_sg"] = "cherub"
		data.forms["dat_sg"] = "cherub"
		data.forms["acc_sg"] = "cherub"
		data.forms["abl_sg"] = "cherub"
		data.forms["voc_sg"] = "cherub"

		data.forms["nom_pl"] = {"cherubim", "cherubin"}
		data.forms["gen_pl"] = {"cherubim", "cherubin"}
		data.forms["dat_pl"] = {"cherubim", "cherubin"}
		data.forms["acc_pl"] = {"cherubim", "cherubin"}
		data.forms["abl_pl"] = {"cherubim", "cherubin"}
		data.forms["voc_pl"] = {"cherubim", "cherubin"}

	elseif stem == "deus" then
		table.insert(title, "[[Appendix:Latin second declension|Second declension]], with several irregular plural forms")

		data.forms["nom_sg"] = "deus"
		data.forms["gen_sg"] = "deī"
		data.forms["dat_sg"] = "deō"
		data.forms["acc_sg"] = "deum"
		data.forms["abl_sg"] = "deō"
		data.forms["voc_sg"] = {"deus", "dee"}

		data.forms["nom_pl"] = {"dī", "diī", "deī"}
		data.forms["gen_pl"] = {"deōrum", "deûm"}
		data.forms["dat_pl"] = {"dīs", "diīs", "deīs"}
		data.forms["acc_pl"] = "deōs"
		data.forms["abl_pl"] = {"dīs", "diīs", "deīs"}
		data.forms["voc_pl"] = {"dī", "diī", "deī"}

	elseif stem == "Deus" then
		table.insert(title, "[[Appendix:Latin second declension|Second declension]], with irregular vocative")

		data.forms["nom_sg"] = "Deus"
		data.forms["gen_sg"] = "Deī"
		data.forms["dat_sg"] = "Deō"
		data.forms["acc_sg"] = "Deum"
		data.forms["abl_sg"] = "Deō"
		data.forms["voc_sg"] = {"Deus", "Dee"}
		data.num = "sg"

	elseif stem == "domus" then
		table.insert(title, "[[Appendix:Latin fourth declension|Fourth declension]] with locative, some alternative forms from the [[Appendix:Latin second declension|second declension]]")

		data.forms["nom_sg"] = "domus"
		data.forms["gen_sg"] = {"domūs", "domī"}
		data.forms["dat_sg"] = {"domuī", "domō", "domū"}
		data.forms["acc_sg"] = "domum"
		data.forms["abl_sg"] = {"domū", "domō"}
		data.forms["voc_sg"] = "domus"
		data.forms["loc_sg"] = "domī"

		data.forms["nom_pl"] = "domūs"
		data.forms["gen_pl"] = {"domuum", "domōrum"}
		data.forms["dat_pl"] = "domibus"
		data.forms["acc_pl"] = {"domūs", "domōs"}
		data.forms["abl_pl"] = "domibus"
		data.forms["voc_pl"] = "domūs"
		data.forms["loc_pl"] = "domibus"

		data.loc = true

	elseif stem == "Iēsus" or stem == "Jēsus" then
		ij = stem == "Iēsus" and "I" or "J"
		table.insert(title, "Highly irregular, but often considered to belong to the [[Appendix:Latin fourth declension|fourth declension]]")

		data.forms["nom_sg"] = ij .. "ēsus"
		data.forms["gen_sg"] = ij .. "ēsū"
		data.forms["dat_sg"] = ij .. "ēsū"
		data.forms["acc_sg"] = ij .. "ēsum"
		data.forms["abl_sg"] = ij .. "ēsū"
		data.forms["voc_sg"] = ij .. "ēsū"
		data.num = "sg"

	elseif stem == "iūgerum" or stem == "jūgerum" then
		ij = stem == "iūgerum" and "i" or "j"
		table.insert(title, "[[Appendix:Latin second declension|Second]]–[[Appendix:Latin third declension|third-declension]] hybrid neuter")

		data.forms["nom_sg"] = ij .. "ūgerum"
		data.forms["gen_sg"] = ij .. "ūgerī"
		data.forms["dat_sg"] = ij .. "ūgerō"
		data.forms["acc_sg"] = ij .. "ūgerum"
		data.forms["abl_sg"] = ij .. "ūgerō"
		data.forms["voc_sg"] = ij .. "ūgerum"
		data.forms["nom_pl"] = ij .. "ūgera"
		data.forms["gen_pl"] = ij .. "ūgerum"
		data.forms["dat_pl"] = ij .. "ūgeribus"
		data.forms["acc_pl"] = ij .. "ūgera"
		data.forms["abl_pl"] = {ij .. "ūgeribus", ij .. "ūgerīs"}
		data.forms["voc_pl"] = ij .. "ūgera"

		data.notes["abl_pl2"] = "Once only, in:<br/>M. Terentius Varro, ''Res Rusticae'', bk I, ch. x"

	elseif stem == "sūs" then
		table.insert(title, "[[Appendix:Latin third declension|Third declension]], irregular")

		data.forms["nom_sg"] = "sūs"
		data.forms["gen_sg"] = "suis"
		data.forms["dat_sg"] = "suī"
		data.forms["acc_sg"] = "suem"
		data.forms["abl_sg"] = "sue"
		data.forms["voc_sg"] = "sūs"

		data.forms["nom_pl"] = "suēs"
		data.forms["gen_pl"] = "suum"
		data.forms["dat_pl"] = {"suibus", "sūbus", "subus"}
		data.forms["acc_pl"] = "suēs"
		data.forms["abl_pl"] = {"suibus", "sūbus", "subus"}
		data.forms["voc_pl"] = "suēs"

	elseif stem == "ēthos" then
		table.insert(title, "[[Appendix:Latin third declension|Third declension]], irregular, Greek type")

		data.forms["nom_sg"] = "ēthos"
		data.forms["gen_sg"] = "ētheos"
		data.forms["acc_sg"] = "ēthos"
		data.forms["voc_sg"] = "ēthos"

		data.forms["nom_pl"] = {"ēthea", "ēthē"}
		data.forms["dat_pl"] = {"ēthesi", "ēthesin"}
		data.forms["acc_pl"] = {"ēthea", "ēthē"}
		data.forms["abl_pl"] = {"ēthesi", "ēthesin"}
		data.forms["voc_pl"] = {"ēthea", "ēthē"}

	elseif stem == "lexis" then
		table.insert(title, "[[Appendix:Latin third declension|Third declension]], irregular, Greek type")

		data.forms["nom_sg"] = "lexis"
		data.forms["gen_sg"] = "lexeōs"
		data.forms["acc_pl"] = "lexeis"

	elseif stem == "Athōs" then
		table.insert(title, "Highly irregular, but often considered to belong to the [[Appendix:Latin second declension|second declension]]; Greek type")

		data.forms["nom_sg"] = "Athōs"
		data.forms["gen_sg"] = "Athō"
		data.forms["dat_sg"] = "Athō"
		data.forms["acc_sg"] = {"Athō", "Athōn"}
		data.forms["abl_sg"] = "Athō"
		data.forms["voc_sg"] = "Athōs"
		data.num = "sg"

	elseif stem == "vēnum" then
		table.insert(title, "[[Appendix:Latin fourth declension|Fourth]] or [[Appendix:Latin second declension|second declension]]. Attested only in the dative and accusative singular forms")

		data.forms["dat_sg"] = {"vēnuī", "vēnō"}
		data.forms["acc_sg"] = "vēnum"
		data.num = "sg"

	elseif stem == "vīs" then
		table.insert(title, "[[Appendix:Latin third declension|Third declension]], but with shortened stem in the singular. The genitive and dative singular forms are rarely used")

		data.forms["nom_sg"] = "vīs"
		data.forms["gen_sg"] = "*vīs"
		data.forms["dat_sg"] = "*vī"
		data.forms["acc_sg"] = "vim"
		data.forms["abl_sg"] = "vī"
		data.forms["voc_sg"] = "vīs"

		data.forms["nom_pl"] = "vīrēs"
		data.forms["gen_pl"] = "vīrium"
		data.forms["dat_pl"] = "vīribus"
		data.forms["acc_pl"] = {"vīrēs", "vīrīs"}
		data.forms["abl_pl"] = "vīribus"
		data.forms["voc_pl"] = "vīrēs"

	else
		error("Stem " .. stem .. " not recognized.")
	end
end

return decl

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
