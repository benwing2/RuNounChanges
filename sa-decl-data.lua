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

-- Construct all or part of a given noun's declension. Each of SG, DU and PL is a table, whose keys are
-- as follows:
--
-- n = nominative
-- a = accusative
-- v = vocative
-- i = instrumental
-- d = dative
-- ab = ablative
-- g = genitive
-- l = locative
--
-- The corresponding value is one of the following:
-- 1. a "copy spec" such as "[ins]", meaning to copy from the instrumental of the same number;
-- 2. a single string (specifying an ending); or
-- 3. a list of specs, where a spec is either a string (an ending) or a table of the form
--    {"ENDING", stem = "STEM", mono = TRUE/FALSE, note = "NOTE"}. The latter format lets you explicitly specify what
--    the stem is, whether the form is monosyllabic, and what the footnote is. All named keys are optional.
--
-- In forms 2 and 3, if the ending begins with +, the stem defaults to args.lemma; otherwise it defaults to args.stem.
local function decline(args, data, sg, du, pl)
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
			decline(args, data, {
				n="a" .. oxy .. "s",
				a="a" .. oxy .. "m",
				v="a"
			}, {
				n="O" .. oxy,
				a="[nom]",
				v="O"
			}, {
				n={"A" .. oxy .. "s", {"A" .. oxy .. "sas", note="Vedic"}},
				a="A" .. oxy .. "n",
				v={"As", {"Asas", note="Vedic"}}
			})
		else
			decline(args, data, {
				n="a" .. oxy .. "m",
				a="[nom]",
				v="a"
			}, {
				n="e" .. oxy,
				a="[nom]",
				v="e"
			}, {
				n={"A" .. oxy .. "ni", {"A" .. oxy, note="Vedic"}},
				a="[nom]",
				v={"Ani", {"A", note="Vedic"}}
			})
		end

		decline(args, data, {
			i="e" .. oxy .. "na",
			d="A" .. oxy .. "ya",
			ab="A" .. oxy .. "t",
			g="a" .. oxy .. "sya",
			l="e" .. oxy
		}, {
			i="A" .. oxy .. "ByAm",
			d="[ins]",
			ab="[ins]",
			g="a" .. oxy .. "yos",
			l="[gen]"
		}, {
			i={ "E" .. oxy .. "s", { "e" .. oxy .. "Bis", note = "Vedic" } },
			d="e" .. oxy .. "Byas", ab="[dat]",
			g="A" .. oxy .. "nAm", l="e" .. oxy .. "zu"
		})
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
			decline(args, data, {
				n="+s",
				a="+m",
				i={ "+nA", { "+A", note = "Vedic" } },
				d={ { stem = args.stem .. sa_utils.split_diphthong[sa_utils.up_one_grade[vowel .. oxy]], "e" }, { "+e", note = "Less common"} },
				ab={sa_utils.up_one_grade[vowel .. oxy] .. "s", {"+as", note = "Less common"}},
				g="[abl]",
				l="O" .. oxy,
				v=sa_utils.up_one_grade[vowel .. oxy],
			}, {
				n="+" .. vowel,
				a="[nom]",
				i="+ByAm",
				d="[ins]",
				ab="[ins]",
				g={{stem = args.stem .. vowel, "o" .. oxy .. "s"}},
				l="[gen]",
				v="+" .. vowel,
			}, {
				n={{stem = args.stem .. sa_utils.up_one_grade[vowel .. oxy], "as"}},
				a="+" .. vowel .. "n",
				i="+Bis",
				d="+Byas",
				ab="[dat]",
				g=sa_utils.lengthen[vowel] .. "nA" .. (oxy ~= "" and "/" or "") .. "m",
				l="+su",
				v={{stem = args.stem .. sa_utils.up_one_grade[vowel], "as"}},
			})
		elseif args.g == "f" then
			decline(args, data, {
				n="+s",
				a="+m",
				i="+A",
				d={ { stem = args.stem .. sa_utils.split_diphthong[sa_utils.up_one_grade[vowel .. oxy]], "e" }, { "+e", note = "Less common" }, { "+E", note = "Later Sanskrit" } },
				ab={sa_utils.up_one_grade[vowel .. oxy] .. "s", {"+As", note = "Later Sanskrit"}},
				g="[abl]",
				l={ "O" .. oxy, { "+Am", note = "Later Sanskrit" } },
				v=sa_utils.up_one_grade[vowel .. oxy],
			}, {
				n="+" .. vowel,
				a="[nom]",
				i="+ByAm",
				d="[ins]",
				ab="[ins]",
				g={{stem = args.stem .. vowel, "o" .. oxy .. "s"}},
				l="[gen]",
				v="+" .. vowel,
			}, {
				n={{stem = args.stem .. sa_utils.up_one_grade[vowel .. oxy], "as"}},
				a="+" .. vowel .. "s",
				i="+Bis",
				d="+Byas",
				ab="[dat]",
				g=sa_utils.lengthen[vowel] .. "nA" .. (oxy ~= "" and "/" or "") .. "m",
				l="+su",
				v={{stem = args.stem .. sa_utils.up_one_grade[vowel], "as"}},
			})
		else
			decline(args, data, {
				n="+",
				a="[nom]",
				i={ "+nA", { "+A", note = "Vedic" } },
				d={ { stem = args.stem .. sa_utils.split_diphthong[sa_utils.up_one_grade[vowel .. oxy]], "e" }, { "+e", note = "Less common" } },
				ab={ sa_utils.up_one_grade[vowel .. oxy] .. "s", { "+nas", note = "Later Sanskrit" }, { "+as", note = "Less common" }},
				g="[abl]",
				{ "+ni" .. oxy, note1 = "Later Sanskrit", }
				v={ "+", sa_utils.up_one_grade[vowel .. oxy] },
			}, {
				n="+nI",
				a="[nom]",
				i="+ByAm",
				d="[ins]",
				ab="[ins]",
				g="+nos",
				l="[gen]",
				v="+nI",
			}, {
				n={ "+" .. vowel, "+", { stem = args.stem .. sa_utils.lengthen[vowel .. oxy], "ni", note = "Later Sanskrit" } },
				a="[nom]",
				i="+Bis",
				d="+Byas",
				ab="[dat]",
				g=sa_utils.lengthen[vowel] .. "nA" .. (oxy ~= "" and "/" or "") .. "m",
				l="+su",
				v={ "+" .. vowel, "+", { stem = args.stem .. sa_utils.lengthen[vowel], "ni", note = "Later Sanskrit" } },
			})
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
				decline(args, data, {
					n="+",
					i={ "a" .. oxy .. "yA", { "+", note = "Vedic" } },
					d="+yE",
					ab="+yAs",
					g="[abl]",
					l="+yAm",
					v="e",
				}, {
					n="e" .. oxy,
					a="[nom]",
					g="a" .. oxy .. "yos",
					l="[gen]",
					v="e",
				}, {
					n="+s",
					v="+s",
				})
			elseif vowel == "I" then
				decline(args, data, {
					n="+",
					i="+A",
					d="+E",
					ab="+As",
					g="[abl]",
					l="+Am",
					v=sa_utils.shorten[vowel],
				}, {
					 n={ "+O", { "+", note = "Vedic" } },
					 g="+os",
					 v={ "+O", { "+", note = "Vedic" } },
				}, {
					n={ "+as", { "+s", note = "Vedic" } },
					v={ "+as", { "+s", note = "Vedic" } },
				})
			else
				decline(args, data, {
					n="+s",
					i="+A",
					d="+E",
					ab="+As",
					g="[abl]",
					l="+Am",
					v=sa_utils.shorten[vowel],
				}, {
					n={ "+O", { "+", note = "Vedic" } },
					g="+os",
					v={ "+O", { "+", note = "Vedic" } },
				}, {
					n={ "+as", { "+s", note = "Vedic" } },
					v={ "+as", { "+s", note = "Vedic" } },
				})
			end
			decline(args, data, {
				a="+m",
			}, {
				a="[nom]",
				i="+ByAm",
				d="[ins]",
				ab="[ins]",
				l="[gen]",
			}, {
				a="+s",
				i="+Bis",
				d="+Byas",
				ab="[dat]",
				g="+nAm",
				l="+su",
			})
		elseif vowel == "A" then
			decline(args, data, {
				n="+s",
				a="+m",
				i="+",
				d="e" .. oxy,
				ab="a" .. oxy .. "s",
				g="[abl]",
				l="i" .. oxy,
				v="+s",
			}, {
				n="O" .. oxy,
				a="[nom]",
				i="+ByAm",
				d="[ins]",
				ab="[ins]",
				g="o" .. oxy .. "s",
				l="[gen]",
				v="O",
			}, {
				n="+s",
				a={ "+s", { "a" .. oxy .. "s", note = "Perhaps" } },
				i="+Bis",
				d="+Byas",
				ab="[dat]",
				g={ "+" .. sa_utils.lengthen[vowel] .. "nAm", { "+" .. sa_utils.lengthen[vowel] .. "m", note = "Perhaps" } },
				l="+su",
				v="+s",
			})
		elseif args.compound then
			if match(args.stem, sa_utils.consonant .. sa_utils.consonant .. "$") then
				decline(args, data, {
					a={{"+am", mono = true}},
					i={{"+A", mono = true}},
					d={{"+e", mono = true}},
					ab={{"+as", mono = true}},
					l={{"+i", mono = true}},
				}, {
					n={{"+O", mono = true}},
					g={{"+os", mono = true}},
					v={{"+O", mono = true}},
				}, {
					n={{"+as", mono = true}},
					g={ { "+Am", mono = true }, "+nAm" },
					v={{"+as", mono = true}},
				})
			else
				decline(args, data, {
					a={ { "+am", mono = true }, "+am" },
					i={ { "+A", mono = true }, "+A" },
					d={ { "+e", mono = true }, "+e" },
					ab={ { "+as", mono = true }, "+as" },
					l={ { "+i", mono = true }, { stem = args.stem .. sa_utils.semivowel_to_cons[vowel], "i" .. (oxy ~= "" and "\\" or "") } }, -- weird special case
				}, {
					n={ { "+O", mono = true }, "+O" },
					g={ { "+os", mono = true }, "+os" },
					v={ { "+O", mono = true }, "+O" },
				}, {
					n={ { "+as", mono = true }, "+as" },
					g={ { "+Am", mono = true }, "+nAm", "+Am" },
					v={ { "+as", mono = true }, "+as" },
				})
			end
			decline(args, data, {
				n="+s",
				g="[abl]",
				v="+s",
			}, {
				a="[nom]",
				i="+ByAm",
				d="[ins]",
				ab="[ins]",
				l="[gen]",
			}, {
				a="[nom]",
				i="+Bis",
				d="+Byas",
				ab="[dat]",
				l="+su",
			})
		elseif args.true_mono then
			decline(args, data, {
				n="+s",
				a={{"+am", mono = true}},
				i={{"+A/", mono = true}},
				d={ { "+e/", mono = true }, { "+E/", mono = true, note = "Later Sanskrit" } },
				ab={ { "+a/s", mono = true }, { "+A/s", mono = true, note = "Later Sanskrit" } },
				g="[abl]",
				l={ { "+i/", mono = true }, { "+A/m", mono = true, note = "Later Sanskrit" } },
				v="+s",
			}, {
				n={{"+O", mono = true}},
				a="[nom]",
				i={{"+ByA/m", mono = true}},
				d="[ins]",
				ab="[ins]",
				g={{"+o/s", mono = true}},
				l="[gen]",
				v={{"+O", mono = true}},
			}, {
				n={{"+as", mono = true}},
				a="[nom]",
				i={{"+Bi/s", mono = true}},
				d={{"+Bya/s", mono = true}},
				ab="[dat]",
				g={ { "+A/m", mono = true }, { "+nA/m", mono = true, note = "Later Sanskrit" } },
				l={{"+su/", mono = true}},
				v={{"+as", mono = true}},
			})
		else
			decline(args, data, {
				n="+s",
				a="+am",
				i="+A",
				d="+e",
				ab="+as",
				g="[abl]",
				l="+i",
				v=sa_utils.shorten[vowel],
			}, {
				n="+A",
				a="[nom]",
				i="+ByAm",
				d="[ins]",
				ab="[ins]",
				g="+os",
				l="[gen]",
				v="+A",
			}, {
				n="+as",
				a="[nom]",
				i="+Bis",
				d="+Byas",
				ab="[dat]",
				g="+nAm",
				l="+su",
				v="+as",
			})
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
			decline(args, data, {
				n="f" .. oxy,
				a="[nom]",
				i="+nA",
				d="+ne",
				ab="+nas",
				l="+ni",
				v={ "f", "ar" },
			}, {
				n="+nI",
				g="+nos",
				v="+nI",
			}, {
				n="F" .. oxy .. "ni",
				a="[nom]",
				v="Fni",
			})
		else
			decline(args, data, {
				n="A" .. oxy,
				a=args.r_stem_a .. oxy .. "ram",
				i="rA" .. oxy,
				d="re" .. oxy,
				ab="u" .. oxy .. "r",
				l="a" .. oxy .. "ri",
				v="ar",
			}, {
				n={ args.r_stem_a .. oxy .. "rO", { args.r_stem_a .. oxy .. "rA", note = "Vedic" } },
				g="ro" .. oxy .. "s",
				v={ args.r_stem_a .. "rO", { args.r_stem_a .. "rA", note = "Vedic" } },
			}, {
				n=args.r_stem_a .. oxy .. "ras",
				a=args.g == "f" and "F" .. oxy .. "s" or "F" .. oxy .. "n",
				v=args.r_stem_a .. "ras",
			})
		end
		decline(args, data, {
			g="[abl]",
		}, {
			a="[nom]",
			i="+ByAm",
			d="[ins]",
			ab="[ins]",
			l="[gen]",
		}, {
			i="+Bis",
			d="+Byas",
			ab="[dat]",
			g={{stem = args.stem .. "F", "nA" .. (oxy ~= "" and "/" or "") .. "m"}},
			l="+su",
		})

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
				decline(args, data, {
					n="A" .. oxy .. "s",
					a={ "+am", { "A" .. oxy .. "m", note = "Vedic" } },
				}, nil, {
					n={ "+as", { "A" .. oxy .. "s", note = "Vedic" } },
					v={ "+as", { "A" .. oxy .. "s", note = "Vedic" } },
				})
			else
				decline(args, data, {
					n="+",
					a="+am",
				}, nil, {
					n="+as",
					v="+as",
				})
			end

			decline(args, data, {
				v="+",
			}, {
				n={ "+O", { "+A", note = "Vedic" } },
				a="[nom]",
				v={ "+O", { "+A", note = "Vedic" } },
			})
		else
			decline(args, data, {
				n="+",
				a="[nom]",
				v="+",
			}, {
				n="+I",
				a="[nom]",
				v="+I",
			}, {
				n={{stem = args.stem .. sa_utils.lengthen[vowel] .. oxy .. "n", "si"}},
				v={{stem = args.stem .. sa_utils.lengthen[vowel] .. "n", "si"}},
			})
		end

		decline(args, data, {
			i="+A",
			d="+e",
			ab="+as",
			g="[abl]",
			l="+i",
		}, {
			a="[nom]",
			i="+ByAm",
			d="[ins]",
			ab="[ins]",
			g="+os",
			l="[gen]",
		}, {
			a="[nom]",
			i="+Bis",
			d="+Byas",
			ab="[dat]",
			g="+Am",
			l="+su",
		})

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
			decline(args, data, {
				i="nA" .. oxy,
				d="ne" .. oxy,
				ab="na" .. oxy .. "s",
				g="[abl]",
				l={ "ni" .. oxy, "+i" },
			}, {
				g="no" .. oxy .. "s",
			})

			if args.g ~= "m" then
				decline(args, data, nil, {
					n={ "nI" .. oxy, "+I" },
					v={ "nI", "+I" },
				}, {
					a="A" .. oxy .. "ni",
				})
			else
				decline(args, data, nil, {
					n={ "A" .. oxy .. "nO", { "A" .. oxy .. "nA", note = "Vedic" } },
					v={ "AnO", { "AnA", note = "Vedic" } },
				}, {
					a="na" .. oxy .. "s",
				})
			end
			decline(args, data, nil, nil, {
				g="nA" .. oxy .. "m",
			})
		else
			decline(args, data, {
				i="+A",
				d="+e",
				ab="+as",
				g="[abl]",
				l="+i",
			}, {
				g="+os",
			})

			if args.g ~= "m" then
				decline(args, data, nil, {
					n="+I",
					v="+I",
				}, {
					a="A" .. oxy .. "ni",
				})
			else
				decline(args, data, nil, {
					n={ "A" .. oxy .. "nO", { "A" .. oxy .. "nA", note = "Vedic" } },
					v={ "AnO", { "AnA", note = "Vedic" } },
				}, {
					a="+as",
				})
			end
			decline(args, data, nil, nil, {
				g="+Am",
			})
		end

		if args.g ~= "m" then
			decline(args, data, {
				n="a" .. oxy,
				a="[nom]",
				v={ "+", "a" },
			}, nil, {
				n="A" .. oxy .. "ni",
				v="Ani",
			})
		else
			decline(args, data, {
				n="A" .. oxy,
				a="A" .. oxy .. "nam",
				v="+",
			}, nil, {
				n="A" .. oxy .. "nas",
				v="Anas",
			})
		end

		decline(args, data, nil, {
			a="[nom]",
			a="[nom]",
			i="a" .. oxy .. "ByAm",
			d="[ins]",
			ab="[ins]",
			l="[gen]",
		}, {
			i="a" .. oxy .. "Bis",
			d="a" .. oxy .. "Byas",
			ab="[dat]",
			l="a" .. oxy .. "su",
		})

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
			decline(args, data, {
				n="I" .. oxy,
				a="i" .. oxy .. "nam",
				v="+",
			}, {
				n={ "+O", { "+A", note = "Vedic" } },
				v={ "+O", { "+A", note = "Vedic" } },
			}, {
				n="+as",
				a="[nom]",
				v="+as",
			})
		else
			decline(args, data, {
				n="i" .. oxy,
				a="[nom]",
				v="+i",
			}, {
				n="+I",
				v="+I",
			}, {
				n="I" .. oxy .. "ni",
				a="[nom]",
				v="Ini",
			})
		end

		decline(args, data, {
			i="+A",
			d="+e",
			ab="+as",
			g="[abl]",
			l="+i",
		}, {
			a="[nom]",
			i="i" .. oxy .. "ByAm",
			d="[ins]",
			ab="[ins]",
			g="+os",
			l="[gen]",
		}, {
			i="i" .. oxy .. "Bis",
			d="i" .. oxy .. "Byas",
			ab="[dat]",
			g="+Am",
			l="i" .. oxy .. "zu",
		})

		table.insert(data.categories, "Sanskrit in-stem nouns")
	end
})

return decl_data
