local decl_data = {}

local sa_utils = require("Module:sa-utilities")
local SLP_to_IAST = require("Module:sa-utilities/translit/SLP1-to-IAST")
local IAST_to_SLP = require("Module:sa-utilities/translit/IAST-to-SLP1")

local match = mw.ustring.match

decl_data["a"] = {
	detect = function(args)
		if match(args.lemma, "a" .. sa_utils.accent .. "?$") and (args.g == "m" or args.g == "n") then
			args.stem = match(args.lemma, "(.+)a" .. sa_utils.accent .. "?$")
			return true
		else
			return false
		end
	end
}

local function conjugate(args, data, sg, du, pl)
	local cases = {n="nom", a="acc", v="voc", i="ins", d="dat", ab="abl", g="gen", l="loc"}
	local function process_number(endings, tag)
		if not endings then
			return
		end
		for _, case in ipairs(cases) do
			local es = endings[case]
			if es then
				if type(es) == "string" and es:find("^%[") then
					-- copy from another case; skip and handle later
				else
					if type(es) == "string" then
						es = {es}
					end
					local forms = {}
					for i, e in ipairs(es) do
						local stem, mono, note
						if type(e) == "table" then
							stem = e.stem
							mono = e.mono
							note = e.note
							e = e[1]
						end
						if e:find("^%+") then
							if stem then
								error("Internal error: Can't use + in an ending when stem is explicitly given")
							end
							e = e:gsub("^%+", "")
							stem = args.lemma
						elseif not stem then
							stem = args.stem
						end
						forms[i] = sa_utils.internal_sandhi({
							stem = stem, ending = e, has_accent = args.has_accent, recessive = case == "v", mono = mono
						})
						if note then
							forms["note" .. i] = note
						end
					end
					data.forms[cases[case] .. "_" .. tag] = forms
				end
			end
		end

		-- Now handle cases copied from another.
		for _, case in ipairs(cases) do
			local es = endings[case]
			if es then
				if type(es) == "string" and es:find("^%[") then
					-- copy from another case; skip and handle later
					local other_case = es:match("^%[(.*)%]$")
					if not other_case then
						error("Internal error: Unrecognized copy case spec " .. es)
					end
					local other_slot = other_case .. "_" .. tag
					local value = data.forms[other_slot]
					if not value then
						error("Internal error: Slot '" .. other_slot .. "' to copy from is empty")
					end
					local this_slot = cases[case] .. "_" .. tag
					if data.forms[this_slot] then
						error("Internal error: A value already exists for slot '" .. this_slot ..
							"' when copying from '" .. other_slot .. "'")
					end
					data.forms[cases[case] .. "_" .. tag] = value
				end
			end
		end
	end

	process_number(sg, "s")
	process_number(du, "d")
	process_number(pl, "p")
end


setmetatable(decl_data["a"], {
	__call = function(self, args, data)
		local oxy = match(args.lemma, "(" .. sa_utils.accent .. "?)$")
		
		data.decl_type = "a-stem"
		
		if args.g == "m" then
			conjugate(args, data,
				{ n="a" .. oxy .. "s", a="a" .. oxy .. "m", v="a" },
				{ n="O" .. oxy, a="O" .. oxy, v="O" },
				{ n={"A" .. oxy .. "s", {"A" .. oxy .. "sas", note="Vedic"}},
				  a="A" .. oxy .. "n",
				  v={"As", {"Asas", note="Vedic"}}
				})
		else
			conjugate(args, data,
				{ n="a" .. oxy .. "m", a="a" .. oxy .. "m", v="a" },
				{ n="e" .. oxy, a="e" .. oxy, v="e" },
				{ n={"A" .. oxy .. "ni", {"A" .. oxy, note="Vedic"}}, a="[nom]", v={"Ani", {"A", note="Vedic"}}}
				)
		end

		data.forms["ins_s"] = i="e" .. oxy .. "na",
		data.forms["dat_s"] = d="A" .. oxy .. "ya",
		data.forms["abl_s"] = ab="A" .. oxy .. "t",
		data.forms["gen_s"] = g="a" .. oxy .. "sya",
		data.forms["loc_s"] = l="e" .. oxy,
		
		data.forms["ins_d"] = i="A" .. oxy .. "ByAm",
		data.forms["dat_d"] = d="[ins]",
		data.forms["abl_d"] = ab="[ins]",
		data.forms["gen_d"] = g="a" .. oxy .. "yos",
		data.forms["loc_d"] = l="[gen]",
		
		data.forms["ins_p"] = {
			{ "E" .. oxy .. "s" },
			{ "e" .. oxy .. "Bis", note = "Vedic" },
		}
		data.forms["dat_p"] = d="e" .. oxy .. "Byas",
		data.forms["abl_p"] = ab="[dat]",
		data.forms["gen_p"] = g="A" .. oxy .. "nAm",
		data.forms["loc_p"] = l="e" .. oxy .. "zu",
		
		table.insert(data.categories, "Sanskrit a-stem nouns")
	end
})

decl_data["iu"] = {
	detect = function(args)
		if match(args.lemma, "[iu]" .. sa_utils.accent .. "?$") then
			args.stem = match(args.lemma, "(.+)[iu]" .. sa_utils.accent .. "?$")
			return true
		else
			return false
		end
	end
}

setmetatable(decl_data["iu"], {
	__call = function(self, args, data)
		local oxy = match(args.lemma, "(" .. sa_utils.accent .. "?)$")
		local vowel = match(args.lemma, "([iu])" .. sa_utils.accent .. "?$")
		
		data.decl_type = vowel .. "-stem"
		
		if args.g == "m" then
			data.forms["nom_s"] = n="+s",
			data.forms["acc_s"] = a="+m",
			data.forms["ins_s"] = {
				{ "+nA" },
				{ "+A", note = "Vedic" },
			}
			data.forms["dat_s"] = {
				{ stem = args.stem .. sa_utils.split_diphthong[sa_utils.up_one_grade[vowel .. oxy]], "e" },
				{ "+e", note = "Less common"},
			}
			data.forms["abl_s"] = ab={sa_utils.up_one_grade[vowel .. oxy] .. "s", {"+as", note = "Less common"}},
			data.forms["gen_s"] = g="[abl]",
			data.forms["loc_s"] = l="O" .. oxy,
			data.forms["voc_s"] = v=sa_utils.up_one_grade[vowel .. oxy],
			
			data.forms["nom_d"] = n="+" .. vowel,
			data.forms["acc_d"] = a="[nom]",
			data.forms["ins_d"] = i="+ByAm",
			data.forms["dat_d"] = d="[ins]",
			data.forms["abl_d"] = ab="[ins]",
			data.forms["gen_d"] = g=stem = args.stem .. vowel, "o" .. oxy .. "s",
			data.forms["loc_d"] = l="[gen]",
			data.forms["voc_d"] = v="+" .. vowel,
			
			data.forms["nom_p"] = n=stem = args.stem .. sa_utils.up_one_grade[vowel .. oxy], "as",
			data.forms["acc_p"] = a="+" .. vowel .. "n",
			data.forms["ins_p"] = i="+Bis",
			data.forms["dat_p"] = d="+Byas",
			data.forms["abl_p"] = ab="[dat]",
			data.forms["gen_p"] = g=sa_utils.lengthen[vowel] .. "nA" .. (oxy ~= "" and "/" or "") .. "m",
			data.forms["loc_p"] = l="+su",
			data.forms["voc_p"] = v=stem = args.stem .. sa_utils.up_one_grade[vowel], "as",
		elseif args.g == "f" then
			data.forms["nom_s"] = n="+s",
			data.forms["acc_s"] = a="+m",
			data.forms["ins_s"] = i="+A",
			data.forms["dat_s"] = {
				{ stem = args.stem .. sa_utils.split_diphthong[sa_utils.up_one_grade[vowel .. oxy]], "e" },
				{ "+e", note = "Less common" },
				{ "+E", note = "Later Sanskrit" },
			}
			data.forms["abl_s"] = ab={sa_utils.up_one_grade[vowel .. oxy] .. "s", {"+As", note = "Later Sanskrit"}},
			}
			data.forms["gen_s"] = g="[abl]",
			data.forms["loc_s"] = {
				{ "O" .. oxy },
				{ "+Am", note = "Later Sanskrit" },
			}
			data.forms["voc_s"] = v=sa_utils.up_one_grade[vowel .. oxy],
			
			data.forms["nom_d"] = n="+" .. vowel,
			data.forms["acc_d"] = a="[nom]",
			data.forms["ins_d"] = i="+ByAm",
			data.forms["dat_d"] = d="[ins]",
			data.forms["abl_d"] = ab="[ins]",
			data.forms["gen_d"] = g=stem = args.stem .. vowel, "o" .. oxy .. "s",
			data.forms["loc_d"] = l="[gen]",
			data.forms["voc_d"] = v="+" .. vowel,
			
			data.forms["nom_p"] = n=stem = args.stem .. sa_utils.up_one_grade[vowel .. oxy], "as",
			data.forms["acc_p"] = a="+" .. vowel .. "s",
			data.forms["ins_p"] = i="+Bis",
			data.forms["dat_p"] = d="+Byas",
			data.forms["abl_p"] = ab="[dat]",
			data.forms["gen_p"] = g=sa_utils.lengthen[vowel] .. "nA" .. (oxy ~= "" and "/" or "") .. "m",
			data.forms["loc_p"] = l="+su",
			data.forms["voc_p"] = v=stem = args.stem .. sa_utils.up_one_grade[vowel], "as",
		else
			data.forms["nom_s"] = n="+",
			data.forms["acc_s"] = a="[nom]",
			data.forms["ins_s"] = {
				{ "+nA" },
				{ "+A", note = "Vedic" },
			}
			data.forms["dat_s"] = {
				{ stem = args.stem .. sa_utils.split_diphthong[sa_utils.up_one_grade[vowel .. oxy]], "e" },
				{ "+e", note = "Less common" },
			}
			data.forms["abl_s"] = ab={ sa_utils.up_one_grade[vowel .. oxy] .. "s", { "+nas", note = "Later Sanskrit" }, { "+as", note = "Less common" }},
			data.forms["gen_s"] = g="[abl]",
			data.forms["loc_s"] = { { "+ni" .. oxy }, note1 = "Later Sanskrit", }
			data.forms["voc_s"] = {
				{ "+" },
				{ sa_utils.up_one_grade[vowel .. oxy] },
			}
			
			data.forms["nom_d"] = n="+nI",
			data.forms["acc_d"] = a="[nom]",
			data.forms["ins_d"] = i="+ByAm",
			data.forms["dat_d"] = d="[ins]",
			data.forms["abl_d"] = ab="[ins]",
			data.forms["gen_d"] = g="+nos",
			data.forms["loc_d"] = l="[gen]",
			data.forms["voc_d"] = v="+nI",
			
			data.forms["nom_p"] = {
				{ "+" .. vowel },
				{ "+" },
				{ stem = args.stem .. sa_utils.lengthen[vowel .. oxy], "ni", note = "Later Sanskrit" },
			}
			data.forms["acc_p"] = a="[nom]",
			data.forms["ins_p"] = i="+Bis",
			data.forms["dat_p"] = d="+Byas",
			data.forms["abl_p"] = ab="[dat]",
			data.forms["gen_p"] = g=sa_utils.lengthen[vowel] .. "nA" .. (oxy ~= "" and "/" or "") .. "m",
			data.forms["loc_p"] = l="+su",
			data.forms["voc_p"] = {
				{ "+" .. vowel },
				{ "+" },
				{ stem = args.stem .. sa_utils.lengthen[vowel], "ni", note = "Later Sanskrit" },
			}
		end
		
		table.insert(data.categories, "Sanskrit " .. vowel .. "-stem nouns")
	end
})

decl_data["AIU"] = {
	detect = function(args)
		if match(args.lemma, "[AIU]" .. sa_utils.accent .. "?$") then
			args.stem = match(args.lemma, "(.+)[AIU]" .. sa_utils.accent .. "?$")
			args.true_mono = sa_utils.is_monosyllabic(args.lemma)
			return true
		else
			return false
		end
	end
}

setmetatable(decl_data["AIU"], {
	__call = function(self, args, data)
		local oxy = match(args.lemma, "(" .. sa_utils.accent .. "?)$")
		local vowel = match(args.lemma, "([AIU])" .. sa_utils.accent .. "?$")
		
		data.decl_type = SLP_to_IAST.tr(vowel) .. "-stem"
		
		if not (args.root or args.compound or args.true_mono) then -- derived stem
			if vowel == "A" then
				data.forms["nom_s"] = n="+",
				data.forms["ins_s"] = {
					{ "a" .. oxy .. "yA" },
					{ "+", note = "Vedic" },
				}
				data.forms["dat_s"] = d="+yE",
				data.forms["abl_s"] = ab="+yAs",
				data.forms["gen_s"] = g="[abl]",
				data.forms["loc_s"] = l="+yAm",
				data.forms["voc_s"] = v="e",
				
				data.forms["nom_d"] = n="e" .. oxy,
				data.forms["acc_d"] = a="[nom]",
				data.forms["gen_d"] = g="a" .. oxy .. "yos",
				data.forms["loc_d"] = l="[gen]",
				data.forms["voc_d"] = v="e",
				
				data.forms["nom_p"] = n="+s",
				data.forms["voc_p"] = v="+s",
			elseif vowel == "I" then
				data.forms["nom_s"] = n="+",
				data.forms["ins_s"] = i="+A",
				data.forms["dat_s"] = d="+E",
				data.forms["abl_s"] = ab="+As",
				data.forms["gen_s"] = g="[abl]",
				data.forms["loc_s"] = l="+Am",
				data.forms["voc_s"] = v=sa_utils.shorten[vowel],
				
				data.forms["nom_d"] = {
					{ "+O" },
					{ "+", note = "Vedic" },
				}
				data.forms["gen_d"] = g="+os",
				data.forms["voc_d"] = {
					{ "+O" },
					{ "+", note = "Vedic" },
				}
				
				data.forms["nom_p"] = {
					{ "+as" },
					{ "+s", note = "Vedic" },
				}
				data.forms["voc_p"] = {
					{ "+as" },
					{ "+s", note = "Vedic" },
				}
			else
				data.forms["nom_s"] = n="+s",
				data.forms["ins_s"] = i="+A",
				data.forms["dat_s"] = d="+E",
				data.forms["abl_s"] = ab="+As",
				data.forms["gen_s"] = g="[abl]",
				data.forms["loc_s"] = l="+Am",
				data.forms["voc_s"] = v=sa_utils.shorten[vowel],
				
				data.forms["nom_d"] = {
					{ "+O" },
					{ "+", note = "Vedic" },
				}
				data.forms["gen_d"] = g="+os",
				data.forms["voc_d"] = {
					{ "+O" },
					{ "+", note = "Vedic" },
				}
				
				data.forms["nom_p"] = {
					{ "+as" },
					{ "+s", note = "Vedic" },
				}
				data.forms["voc_p"] = {
					{ "+as" },
					{ "+s", note = "Vedic" },
				}
			end
			data.forms["acc_s"] = a="+m",
			
			data.forms["acc_d"] = a="[nom]",
			data.forms["ins_d"] = i="+ByAm",
			data.forms["dat_d"] = d="[ins]",
			data.forms["abl_d"] = ab="[ins]",
			data.forms["loc_d"] = l="[gen]",
			
			data.forms["acc_p"] = a="+s",
			data.forms["ins_p"] = i="+Bis",
			data.forms["dat_p"] = d="+Byas",
			data.forms["abl_p"] = ab="[dat]",
			data.forms["gen_p"] = g="+nAm",
			data.forms["loc_p"] = l="+su",
		
		elseif vowel == "A" then
			data.forms["nom_s"] = n="+s",
			data.forms["acc_s"] = a="+m",
			data.forms["ins_s"] = i="+",
			data.forms["dat_s"] = d="e" .. oxy,
			data.forms["abl_s"] = ab="a" .. oxy .. "s",
			data.forms["gen_s"] = g="[abl]",
			data.forms["loc_s"] = l="i" .. oxy,
			data.forms["voc_s"] = v="+s",
			
			data.forms["nom_d"] = n="O" .. oxy,
			data.forms["acc_d"] = a="[nom]",
			data.forms["ins_d"] = i="+ByAm",
			data.forms["dat_d"] = d="[ins]",
			data.forms["abl_d"] = ab="[ins]",
			data.forms["gen_d"] = g="o" .. oxy .. "s",
			data.forms["loc_d"] = l="[gen]",
			data.forms["voc_d"] = v="O",
			
			data.forms["nom_p"] = n="+s",
			data.forms["acc_p"] = {
				{ "+s" },
				{ "a" .. oxy .. "s", note = "Perhaps" },
			}
			data.forms["ins_p"] = i="+Bis",
			data.forms["dat_p"] = d="+Byas",
			data.forms["abl_p"] = ab="[dat]",
			data.forms["gen_p"] = {
				{ "+" .. sa_utils.lengthen[vowel] .. "nAm" },
				{ "+" .. sa_utils.lengthen[vowel] .. "m", note = "Perhaps" },
			}
			data.forms["loc_p"] = l="+su",
			data.forms["voc_p"] = v="+s",
		elseif args.compound then
			if match(args.stem, sa_utils.consonant .. sa_utils.consonant .. "$") then
				data.forms["acc_s"] = a="+am", mono = true,
				data.forms["ins_s"] = i="+A", mono = true,
				data.forms["dat_s"] = d="+e", mono = true,
				data.forms["abl_s"] = ab={{"+as", mono = true}},
				data.forms["loc_s"] = l="+i", mono = true,
				
				data.forms["nom_d"] = n="+O", mono = true,
				data.forms["gen_d"] = g="+os", mono = true,
				data.forms["voc_d"] = v="+O", mono = true,
				
				data.forms["nom_p"] = n="+as", mono = true,
				data.forms["gen_p"] = {
					{ "+Am", mono = true },
					{ "+nAm" },
				}
				data.forms["voc_p"] = v="+as", mono = true,
			else
				data.forms["acc_s"] = {
					{ "+am", mono = true },
					{ "+am" },
				}
				data.forms["ins_s"] = {
					{ "+A", mono = true },
					{ "+A" },
				}
				data.forms["dat_s"] = {
					{ "+e", mono = true },
					{ "+e" },
				}
				data.forms["abl_s"] = ab={ { "+as", mono = true }, "+as" },
				data.forms["loc_s"] = {
					{ "+i", mono = true },
					{ stem = args.stem .. sa_utils.semivowel_to_cons[vowel], "i" .. (oxy ~= "" and "\\" or "") }, -- weird special case
				}
				
				data.forms["nom_d"] = {
					{ "+O", mono = true },
					{ "+O" },
				}
				data.forms["gen_d"] = {
					{ "+os", mono = true },
					{ "+os" },
				}
				data.forms["voc_d"] = {
					{ "+O", mono = true },
					{ "+O" },
				}
				
				data.forms["nom_p"] = {
					{ "+as", mono = true },
					{ "+as" },
				}
				data.forms["gen_p"] = {
					{ "+Am", mono = true },
					{ "+nAm" },
					{ "+Am" },
				}
				data.forms["voc_p"] = {
					{ "+as", mono = true },
					{ "+as" },
				}
			end
			data.forms["nom_s"] = n="+s",
			data.forms["gen_s"] = g="[abl]",
			data.forms["voc_s"] = v="+s",
			
			data.forms["acc_d"] = a="[nom]",
			data.forms["ins_d"] = i="+ByAm",
			data.forms["dat_d"] = d="[ins]",
			data.forms["abl_d"] = ab="[ins]",
			data.forms["loc_d"] = l="[gen]",
			
			
			data.forms["acc_p"] = a="[nom]",
			data.forms["ins_p"] = i="+Bis",
			data.forms["dat_p"] = d="+Byas",
			data.forms["abl_p"] = ab="[dat]",
			data.forms["loc_p"] = l="+su",
		elseif args.true_mono then
			data.forms["nom_s"] = n="+s",
			data.forms["acc_s"] = a="+am", mono = true,
			data.forms["ins_s"] = i="+A/", mono = true,
			data.forms["dat_s"] = {
				{ "+e/", mono = true },
				{ "+E/", mono = true, note = "Later Sanskrit" },
			}
			data.forms["abl_s"] = ab={ { "+a/s", mono = true }, { "+A/s", mono = true, note = "Later Sanskrit" } },
			data.forms["gen_s"] = g="[abl]",
			data.forms["loc_s"] = {
				{ "+i/", mono = true },
				{ "+A/m", mono = true, note = "Later Sanskrit" },
			}
			data.forms["voc_s"] = v="+s",
			
			data.forms["nom_d"] = n="+O", mono = true,
			data.forms["acc_d"] = a="[nom]",
			data.forms["ins_d"] = i="+ByA/m", mono = true,
			data.forms["dat_d"] = d="[ins]",
			data.forms["abl_d"] = ab="[ins]",
			data.forms["gen_d"] = g="+o/s", mono = true,
			data.forms["loc_d"] = l="[gen]",
			data.forms["voc_d"] = v="+O", mono = true,
			
			data.forms["nom_p"] = n="+as", mono = true,
			data.forms["acc_p"] = a="[nom]",
			data.forms["ins_p"] = i="+Bi/s", mono = true,
			data.forms["dat_p"] = d="+Bya/s", mono = true,
			data.forms["abl_p"] = ab="[dat]",
			data.forms["gen_p"] = {
				{ "+A/m", mono = true },
				{ "+nA/m", mono = true, note = "Later Sanskrit" },
			}
			data.forms["loc_p"] = l="+su/", mono = true,
			data.forms["voc_p"] = v="+as", mono = true,
		else
			data.forms["nom_s"] = n="+s",
			data.forms["acc_s"] = a="+am",
			data.forms["ins_s"] = i="+A",
			data.forms["dat_s"] = d="+e",
			data.forms["abl_s"] = ab="+as",
			data.forms["gen_s"] = g="[abl]",
			data.forms["loc_s"] = l="+i",
			data.forms["voc_s"] = v=sa_utils.shorten[vowel],
			
			data.forms["nom_d"] = n="+A",
			data.forms["acc_d"] = a="[nom]",
			data.forms["ins_d"] = i="+ByAm",
			data.forms["dat_d"] = d="[ins]",
			data.forms["abl_d"] = ab="[ins]",
			data.forms["gen_d"] = g="+os",
			data.forms["loc_d"] = l="[gen]",
			data.forms["voc_d"] = v="+A",
			
			data.forms["nom_p"] = n="+as",
			data.forms["acc_p"] = a="[nom]",
			data.forms["ins_p"] = i="+Bis",
			data.forms["dat_p"] = d="+Byas",
			data.forms["abl_p"] = ab="[dat]",
			data.forms["gen_p"] = g="+nAm",
			data.forms["loc_p"] = l="+su",
			data.forms["voc_p"] = v="+as",
		end
		
		table.insert(data.categories, "Sanskrit " .. SLP_to_IAST.tr(vowel) .. "-stem nouns")
	end
})

decl_data["f"] = {
	detect = function(args)
		if match(args.lemma, "f" .. sa_utils.accent .. "?$") then
			args.stem = match(args.lemma, "(.+)f" .. sa_utils.accent .. "?$")
			return true
		else
			return false
		end
	end
}

setmetatable(decl_data["f"], {
	__call = function(self, args, data)
		local oxy = match(args.lemma, "(" .. sa_utils.accent .. "?)$")
		
		data.decl_type = SLP_to_IAST.tr("f") .. "-stem"
		
		if not args.r_stem_a and args.g ~= "n" then
			error('Please specify the length of the accusative singular vowel with r_stem_a = "a" or "ā".')
		else
			args.r_stem_a = IAST_to_SLP.tr(args.r_stem_a)
		end
		
		if args.g == "n" then
			data.forms["nom_s"] = n="f" .. oxy,
			data.forms["acc_s"] = a="[nom]",
			data.forms["ins_s"] = i="+nA",
			data.forms["dat_s"] = d="+ne",
			data.forms["abl_s"] = ab="+nas",
			data.forms["loc_s"] = l="+ni",
			data.forms["voc_s"] = {
				{ "f" },
				{ "ar" },
			}
			
			data.forms["nom_d"] = n="+nI",
			data.forms["gen_d"] = g="+nos",
			data.forms["voc_d"] = v="+nI",
			
			data.forms["nom_p"] = n="F" .. oxy .. "ni",
			data.forms["acc_p"] = a="[nom]",
			data.forms["voc_p"] = v="Fni",
		else
			data.forms["nom_s"] = n="A" .. oxy,
			data.forms["acc_s"] = a=args.r_stem_a .. oxy .. "ram",
			data.forms["ins_s"] = i="rA" .. oxy,
			data.forms["dat_s"] = d="re" .. oxy,
			data.forms["abl_s"] = ab="u" .. oxy .. "r",
			data.forms["loc_s"] = l="a" .. oxy .. "ri",
			data.forms["voc_s"] = v="ar",
			
			data.forms["nom_d"] = {
				{ args.r_stem_a .. oxy .. "rO" },
				{ args.r_stem_a .. oxy .. "rA", note = "Vedic" },
			}
			data.forms["gen_d"] = g="ro" .. oxy .. "s",
			data.forms["voc_d"] = {
				{ args.r_stem_a .. "rO" },
				{ args.r_stem_a .. "rA", note = "Vedic" },
			}
			
			data.forms["nom_p"] = n=args.r_stem_a .. oxy .. "ras",
			if args.g == "f" then
				data.forms["acc_p"] = a="F" .. oxy .. "s",
			else
				data.forms["acc_p"] = a="F" .. oxy .. "n",
			end
			data.forms["voc_p"] = v=args.r_stem_a .. "ras",
		end
		data.forms["gen_s"] = g="[abl]",
		
		data.forms["acc_d"] = a="[nom]",
		data.forms["ins_d"] = i="+ByAm",
		data.forms["dat_d"] = d="[ins]",
		data.forms["abl_d"] = ab="[ins]",
		data.forms["loc_d"] = l="[gen]",
		
		data.forms["ins_p"] = i="+Bis",
		data.forms["dat_p"] = d="+Byas",
		data.forms["abl_p"] = ab="[dat]",
		data.forms["gen_p"] = g=stem = args.stem .. "F", "nA" .. (oxy ~= "" and "/" or "") .. "m",
		data.forms["loc_p"] = l="+su",
		
		table.insert(data.categories, "Sanskrit " .. SLP_to_IAST.tr("f") .. "-stem nouns")
	end
})

decl_data["[aiu]s"] = {
	detect = function(args)
		if match(args.lemma, "[aiu]" .. sa_utils.accent .. "?s$") then
			args.stem = match(args.lemma, "(.+)[aiu]" .. sa_utils.accent .. "?s$")
			return true
		else
			return false
		end
	end
}

setmetatable(decl_data["[aiu]s"], {
	__call = function(self, args, data)
		local vowel, oxy = match(args.lemma, "([aiu])(" .. sa_utils.accent .. "?)s$")
		
		data.decl_type = vowel .. "s-stem"
		
		if args.g == "m" or args.g == "f" then
			if vowel == "a" then
				data.forms["nom_s"] = n="A" .. oxy .. "s",
				data.forms["acc_s"] = {
					{ "+am" },
					{ "A" .. oxy .. "m", note = "Vedic" },
				}
				
				data.forms["nom_p"] = {
					{ "+as" },
					{ "A" .. oxy .. "s", note = "Vedic" },
				}
				data.forms["voc_p"] = {
					{ "+as" },
					{ "A" .. oxy .. "s", note = "Vedic" },
				}
			else
				data.forms["nom_s"] = n="+",
				data.forms["acc_s"] = a="+am",
				
				data.forms["nom_p"] = n="+as",
				data.forms["voc_p"] = v="+as",
			end
			
			data.forms["voc_s"] = v="+",
			
			data.forms["nom_d"] = {
				{ "+O" },
				{ "+A", note = "Vedic" },
			}
			data.forms["acc_d"] = a="[nom]",
			data.forms["voc_d"] = {
				{ "+O" },
				{ "+A", note = "Vedic" },
			}
		else
			data.forms["nom_s"] = n="+",
			data.forms["acc_s"] = a="[nom]",
			data.forms["voc_s"] = v="+",
			
			data.forms["nom_d"] = n="+I",
			data.forms["acc_d"] = a="[nom]",
			data.forms["voc_d"] = v="+I",
			
			data.forms["nom_p"] = n=stem = args.stem .. sa_utils.lengthen[vowel] .. oxy .. "n", "si",
			data.forms["voc_p"] = v=stem = args.stem .. sa_utils.lengthen[vowel] .. "n", "si",
		end
		
		data.forms["ins_s"] = i="+A",
		data.forms["dat_s"] = d="+e",
		data.forms["abl_s"] = ab="+as",
		data.forms["gen_s"] = g="[abl]",
		data.forms["loc_s"] = l="+i",
		
		data.forms["acc_d"] = a="[nom]",
		data.forms["ins_d"] = i="+ByAm",
		data.forms["dat_d"] = d="[ins]",
		data.forms["abl_d"] = ab="[ins]",
		data.forms["gen_d"] = g="+os",
		data.forms["loc_d"] = l="[gen]",
		
		data.forms["acc_p"] = a="[nom]",
		data.forms["ins_p"] = i="+Bis",
		data.forms["dat_p"] = d="+Byas",
		data.forms["abl_p"] = ab="[dat]",
		data.forms["gen_p"] = g="+Am",
		data.forms["loc_p"] = l="+su",
		
		table.insert(data.categories, "Sanskrit " .. vowel .. "s-stem nouns")
	end
})

decl_data["an"] = {
	detect = function(args)
		if match(args.lemma, "a" .. sa_utils.accent .. "?n$") then
			args.stem = match(args.lemma, "(.+)a" .. sa_utils.accent .. "?n$")
			return true
		else
			return false
		end
	end
}

setmetatable(decl_data["an"], {
	__call = function(self, args, data)
		local oxy = match(args.lemma, "a(" .. sa_utils.accent .. "?)n$")
		
		data.decl_type = "an-stem"
		
		if not match(args.stem, sa_utils.consonant .. sa_utils.consonant .. "$") or args.contract then
			data.forms["ins_s"] = i="nA" .. oxy,
			data.forms["dat_s"] = d="ne" .. oxy,
			data.forms["abl_s"] = ab="na" .. oxy .. "s",
			data.forms["gen_s"] = g="[abl]",
			data.forms["loc_s"] = {
				{ "ni" .. oxy },
				{ "+i" },
			}
			
			data.forms["gen_d"] = g="no" .. oxy .. "s",
			
			if args.g ~= "m" then
				data.forms["nom_d"] = {
					{ "nI" .. oxy },
					{ "+I" },
				}
				data.forms["voc_d"] = {
					{ "nI" },
					{ "+I" },
				}
				
				data.forms["acc_p"] = a="A" .. oxy .. "ni",
			else
				data.forms["nom_d"] = {
					{ "A" .. oxy .. "nO" },
					{ "A" .. oxy .. "nA", note = "Vedic" },
				}
				data.forms["voc_d"] = {
					{ "AnO" },
					{ "AnA", note = "Vedic" },
				}
				
				data.forms["acc_p"] = a="na" .. oxy .. "s",
			end
			data.forms["gen_p"] = g="nA" .. oxy .. "m",
		else
			data.forms["ins_s"] = i="+A",
			data.forms["dat_s"] = d="+e",
			data.forms["abl_s"] = ab="+as",
			data.forms["gen_s"] = g="[abl]",
			data.forms["loc_s"] = l="+i",
			
			data.forms["gen_d"] = g="+os",
			
			if args.g ~= "m" then
				data.forms["nom_d"] = n="+I",
				data.forms["voc_d"] = v="+I",
				
				data.forms["acc_p"] = a="A" .. oxy .. "ni",
			else
				data.forms["nom_d"] = {
					{ "A" .. oxy .. "nO" },
					{ "A" .. oxy .. "nA", note = "Vedic" },
				}
				data.forms["voc_d"] = {
					{ "AnO" },
					{ "AnA", note = "Vedic" },
				}
				
				data.forms["acc_p"] = a="+as",
			end
			data.forms["gen_p"] = g="+Am",
		end
		
		if args.g ~= "m" then
			data.forms["nom_s"] = n="a" .. oxy,
			data.forms["acc_s"] = a="[nom]",
			data.forms["voc_s"] = {
				{ "+" },
				{ "a" },
			}
			
			data.forms["nom_p"] = n="A" .. oxy .. "ni",
			data.forms["voc_p"] = v="Ani",
		else
			data.forms["nom_s"] = n="A" .. oxy,
			data.forms["acc_s"] = a="A" .. oxy .. "nam",
			data.forms["voc_s"] = v="+",
			
			data.forms["nom_p"] = n="A" .. oxy .. "nas",
			data.forms["voc_p"] = v="Anas",
		end
		
		data.forms["acc_d"] = a="[nom]",
		data.forms["acc_d"] = a="[nom]",
		data.forms["ins_d"] = i="a" .. oxy .. "ByAm",
		data.forms["dat_d"] = d="[ins]",
		data.forms["abl_d"] = ab="[ins]",
		
		data.forms["loc_d"] = l="[gen]",
		
		data.forms["ins_p"] = i="a" .. oxy .. "Bis",
		data.forms["dat_p"] = d="a" .. oxy .. "Byas",
		data.forms["abl_p"] = ab="[dat]",
		data.forms["loc_p"] = l="a" .. oxy .. "su",
		
		table.insert(data.categories, "Sanskrit an-stem nouns")
	end
})

decl_data["in"] = {
	detect = function(args)
		if match(args.lemma, "i" .. sa_utils.accent .. "?n$") then
			args.stem = match(args.lemma, "(.+)i" .. sa_utils.accent .. "?n$")
			return true
		else
			return false
		end
	end
}

setmetatable(decl_data["in"], {
	__call = function(self, args, data)
		local oxy = match(args.lemma, "i(" .. sa_utils.accent .. "?)n$")
		
		data.decl_type = "in-stem"
		
		if args.g ~= "n" then
			data.forms["nom_s"] = n="I" .. oxy,
			data.forms["acc_s"] = a="i" .. oxy .. "nam",
			data.forms["voc_s"] = v="+",
			
			data.forms["nom_d"] = {
				{ "+O" },
				{ "+A", note = "Vedic" },
			}
			data.forms["voc_d"] = {
				{ "+O" },
				{ "+A", note = "Vedic" },
			}
			
			data.forms["nom_p"] = n="+as",
			data.forms["acc_p"] = a="[nom]",
			data.forms["voc_p"] = v="+as",
		else
			data.forms["nom_s"] = n="i" .. oxy,
			data.forms["acc_s"] = a="[nom]",
			data.forms["voc_s"] = v="+i",
			
			data.forms["nom_d"] = n="+I",
			data.forms["voc_d"] = v="+I",
			
			data.forms["nom_p"] = n="I" .. oxy .. "ni",
			data.forms["acc_p"] = a="[nom]",
			data.forms["voc_p"] = v="Ini",
		end
		
		data.forms["ins_s"] = i="+A",
		data.forms["dat_s"] = d="+e",
		data.forms["abl_s"] = ab="+as",
		data.forms["gen_s"] = g="[abl]",
		data.forms["loc_s"] = l="+i",
		
		data.forms["acc_d"] = a="[nom]",
		data.forms["ins_d"] = i="i" .. oxy .. "ByAm",
		data.forms["dat_d"] = d="[ins]",
		data.forms["abl_d"] = ab="[ins]",
		data.forms["gen_d"] = g="+os",
		data.forms["loc_d"] = l="[gen]",
		
		data.forms["ins_p"] = i="i" .. oxy .. "Bis",
		data.forms["dat_p"] = d="i" .. oxy .. "Byas",
		data.forms["abl_p"] = ab="[dat]",
		data.forms["gen_p"] = g="+Am",
		data.forms["loc_p"] = l="i" .. oxy .. "zu",
		
		table.insert(data.categories, "Sanskrit in-stem nouns")
	end
})

return decl_data
