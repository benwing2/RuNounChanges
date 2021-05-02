local decl_data = {}

local sa_utils = require("Module:sa-utilities")
local SLP_to_IAST = require("Module:sa-utilities/translit/SLP1-to-IAST")
local IAST_to_SLP = require("Module:sa-utilities/translit/IAST-to-SLP1")

local match = mw.ustring.match

decl_data["a"] = {
	detect = function(args)
		if match(args.lemma, "a" .. sa_utils.accent .. "?$") and (args.g == 'm' or args.g == 'n') then
			args.stem = match(args.lemma, "(.+)a" .. sa_utils.accent .. "?$")
			return true
		else
			return false
		end
	end
}

setmetatable(decl_data["a"], {
	__call = function(self, args, data)
		local oxytone = match(args.lemma, "(" .. sa_utils.accent .. "?)$")
		
		data.decl_type = "a-stem"
		
		if args.g == 'm' then
			data.forms["nom_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "a" .. oxytone .. "s", has_accent = args.has_accent }) }
			data.forms["acc_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "a" .. oxytone .. "m", has_accent = args.has_accent }) }
			data.forms["voc_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "a", recessive = true, has_accent = args.has_accent }) }
			
			data.forms["nom_d"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "O" .. oxytone, has_accent = args.has_accent }) }
			data.forms["acc_d"] = data.forms["nom_d"]
			data.forms["voc_d"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "O", recessive = true, has_accent = args.has_accent }) }
			
			data.forms["nom_p"] = {
				sa_utils.internal_sandhi({ stem = args.stem, ending = "A" .. oxytone .. "s", has_accent = args.has_accent }),
				sa_utils.internal_sandhi({ stem = args.stem, ending = "A" .. oxytone .. "sas", has_accent = args.has_accent }),
				note2 = 'Vedic',
			}
			data.forms["acc_p"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "A" .. oxytone .. "n", has_accent = args.has_accent }) }
			data.forms["voc_p"] = { 
				sa_utils.internal_sandhi({ stem = args.stem, ending = "As", recessive = true, has_accent = args.has_accent }),
				sa_utils.internal_sandhi({ stem = args.stem, ending = "Asas", recessive = true, has_accent = args.has_accent }),
				note2 = 'Vedic',
			}
		else
			data.forms["nom_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "a" .. oxytone .. "m", has_accent = args.has_accent }) }
			data.forms["acc_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "a" .. oxytone .. "m", has_accent = args.has_accent }) }
			data.forms["voc_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "a", recessive = true, has_accent = args.has_accent }) }
			
			data.forms["nom_d"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "e" .. oxytone, has_accent = args.has_accent }) }
			data.forms["acc_d"] = data.forms["nom_d"]
			data.forms["voc_d"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "e", recessive = true, has_accent = args.has_accent }) }
			
			data.forms["nom_p"] = {
				sa_utils.internal_sandhi({ stem = args.stem, ending = "A" .. oxytone .. "ni", has_accent = args.has_accent }),
				sa_utils.internal_sandhi({ stem = args.stem, ending = "A" .. oxytone, has_accent = args.has_accent }),
				note2 = 'Vedic',
			}
			data.forms["acc_p"] = data.forms["nom_p"]
			data.forms["voc_p"] = {
				sa_utils.internal_sandhi({ stem = args.stem, ending = "Ani", recessive = true, has_accent = args.has_accent }),
				sa_utils.internal_sandhi({ stem = args.stem, ending = "A", recessive = true, has_accent = args.has_accent }),
				note2 = 'Vedic',
			}
		end
		data.forms["ins_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "e" .. oxytone .. "na", has_accent = args.has_accent }) }
		data.forms["dat_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "A" .. oxytone .. "ya", has_accent = args.has_accent }) }
		data.forms["abl_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "A" .. oxytone .. "t", has_accent = args.has_accent }) }
		data.forms["gen_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "a" .. oxytone .. "sya", has_accent = args.has_accent }) }
		data.forms["loc_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "e" .. oxytone, has_accent = args.has_accent }) }
		
		data.forms["ins_d"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "A" .. oxytone .. "ByAm", has_accent = args.has_accent }) }
		data.forms["dat_d"] = data.forms["ins_d"]
		data.forms["abl_d"] = data.forms["ins_d"]
		data.forms["gen_d"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "a" .. oxytone .. "yos", has_accent = args.has_accent }) }
		data.forms["loc_d"] = data.forms["gen_d"]
		
		data.forms["ins_p"] = {
			sa_utils.internal_sandhi({ stem = args.stem, ending = "E" .. oxytone .. "s", has_accent = args.has_accent }),
			sa_utils.internal_sandhi({ stem = args.stem, ending = "e" .. oxytone .. "Bis", has_accent = args.has_accent }),
			note2 = 'Vedic',
		}
		data.forms["dat_p"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "e" .. oxytone .. "Byas", has_accent = args.has_accent }) }
		data.forms["abl_p"] = data.forms["dat_p"]
		data.forms["gen_p"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "A" .. oxytone .. "nAm", has_accent = args.has_accent }) }
		data.forms["loc_p"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "e" .. oxytone .. "zu", has_accent = args.has_accent }) }
		
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
		local oxytone = match(args.lemma, "(" .. sa_utils.accent .. "?)$")
		local vowel = match(args.lemma, "([iu])" .. sa_utils.accent .. "?$")
		
		data.decl_type = vowel .. "-stem"
		
		if args.g == 'm' then
			data.forms["nom_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "s", has_accent = args.has_accent }) }
			data.forms["acc_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "m", has_accent = args.has_accent }) }
			data.forms["ins_s"] = {
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "nA", has_accent = args.has_accent }),
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "A", has_accent = args.has_accent }),
				note2 = 'Vedic',
			}
			data.forms["dat_s"] = {
				sa_utils.internal_sandhi({ stem = args.stem .. sa_utils.split_diphthong[sa_utils.up_one_grade[vowel .. oxytone]], ending = "e", has_accent = args.has_accent }),
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "e", has_accent = args.has_accent }),
				note2 = 'Less common',
			}
			data.forms["abl_s"] = {
				sa_utils.internal_sandhi({ stem = args.stem, ending = sa_utils.up_one_grade[vowel .. oxytone] .. 's', has_accent = args.has_accent }),
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", has_accent = args.has_accent }),
				note2 = 'Less common',
			}
			data.forms["gen_s"] = data.forms["abl_s"]
			data.forms["loc_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "O" .. oxytone, has_accent = args.has_accent }) }
			data.forms["voc_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = sa_utils.up_one_grade[vowel .. oxytone], recessive = true, has_accent = args.has_accent }) }
			
			data.forms["nom_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = vowel, has_accent = args.has_accent }) }
			data.forms["acc_d"] = data.forms["nom_d"]
			data.forms["ins_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "ByAm", has_accent = args.has_accent }) }
			data.forms["dat_d"] = data.forms["ins_d"]
			data.forms["abl_d"] = data.forms["ins_d"]
			data.forms["gen_d"] = { sa_utils.internal_sandhi({ stem = args.stem .. vowel, ending = "o" .. oxytone .. "s", has_accent = args.has_accent }) }
			data.forms["loc_d"] = data.forms["gen_d"]
			data.forms["voc_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = vowel, recessive = true, has_accent = args.has_accent }) }
			
			data.forms["nom_p"] = { sa_utils.internal_sandhi({ stem = args.stem .. sa_utils.up_one_grade[vowel .. oxytone], ending = "as", has_accent = args.has_accent }) }
			data.forms["acc_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = vowel .. "n", has_accent = args.has_accent }) }
			data.forms["ins_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "Bis", has_accent = args.has_accent }) }
			data.forms["dat_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "Byas", has_accent = args.has_accent }) }
			data.forms["abl_p"] = data.forms["dat_p"]
			data.forms["gen_p"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = sa_utils.lengthen[vowel] .. "nA" .. (oxytone ~= '' and '/' or '') .. "m", has_accent = args.has_accent }) }
			data.forms["loc_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "su", has_accent = args.has_accent }) }
			data.forms["voc_p"] = { sa_utils.internal_sandhi({ stem = args.stem .. sa_utils.up_one_grade[vowel], ending = "as", recessive = true, has_accent = args.has_accent }) }
		elseif args.g == 'f' then
			data.forms["nom_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "s", has_accent = args.has_accent }) }
			data.forms["acc_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "m", has_accent = args.has_accent }) }
			data.forms["ins_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "A", has_accent = args.has_accent }) }
			data.forms["dat_s"] = {
				sa_utils.internal_sandhi({ stem = args.stem .. sa_utils.split_diphthong[sa_utils.up_one_grade[vowel .. oxytone]], ending = "e", has_accent = args.has_accent }),
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "e", has_accent = args.has_accent }),
				note2 = 'Less common',
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "E", has_accent = args.has_accent }),
				note3 = 'Later Sanskrit',
			}
			data.forms["abl_s"] = {
				sa_utils.internal_sandhi({ stem = args.stem, ending = sa_utils.up_one_grade[vowel .. oxytone] .. 's', has_accent = args.has_accent }),
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "As", has_accent = args.has_accent }),
				note2 = 'Later Sanskrit',
			}
			data.forms["gen_s"] = data.forms["abl_s"]
			data.forms["loc_s"] = {
				sa_utils.internal_sandhi({ stem = args.stem, ending = "O" .. oxytone, has_accent = args.has_accent }),
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "Am", has_accent = args.has_accent }),
				note2 = 'Later Sanskrit',
			}
			data.forms["voc_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = sa_utils.up_one_grade[vowel .. oxytone], recessive = true, has_accent = args.has_accent }) }
			
			data.forms["nom_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = vowel, has_accent = args.has_accent }) }
			data.forms["acc_d"] = data.forms["nom_d"]
			data.forms["ins_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "ByAm", has_accent = args.has_accent }) }
			data.forms["dat_d"] = data.forms["ins_d"]
			data.forms["abl_d"] = data.forms["ins_d"]
			data.forms["gen_d"] = { sa_utils.internal_sandhi({ stem = args.stem .. vowel, ending = "o" .. oxytone .. "s", has_accent = args.has_accent }) }
			data.forms["loc_d"] = data.forms["gen_d"]
			data.forms["voc_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = vowel, recessive = true, has_accent = args.has_accent }) }
			
			data.forms["nom_p"] = { sa_utils.internal_sandhi({ stem = args.stem .. sa_utils.up_one_grade[vowel .. oxytone], ending = "as", has_accent = args.has_accent }) }
			data.forms["acc_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = vowel .. "s", has_accent = args.has_accent }) }
			data.forms["ins_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "Bis", has_accent = args.has_accent }) }
			data.forms["dat_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "Byas", has_accent = args.has_accent }) }
			data.forms["abl_p"] = data.forms["dat_p"]
			data.forms["gen_p"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = sa_utils.lengthen[vowel] .. "nA" .. (oxytone ~= '' and '/' or '') .. "m", has_accent = args.has_accent }) }
			data.forms["loc_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "su", has_accent = args.has_accent }) }
			data.forms["voc_p"] = { sa_utils.internal_sandhi({ stem = args.stem .. sa_utils.up_one_grade[vowel], ending = "as", recessive = true, has_accent = args.has_accent }) }
		else
			data.forms["nom_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "", has_accent = args.has_accent }) }
			data.forms["acc_s"] = data.forms["nom_s"]
			data.forms["ins_s"] = {
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "nA", has_accent = args.has_accent }),
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "A", has_accent = args.has_accent }),
				note2 = 'Vedic',
			}
			data.forms["dat_s"] = {
				sa_utils.internal_sandhi({ stem = args.stem .. sa_utils.split_diphthong[sa_utils.up_one_grade[vowel .. oxytone]], ending = "e", has_accent = args.has_accent }),
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "e", has_accent = args.has_accent }),
				note2 = 'Less common',
			}
			data.forms["abl_s"] = {
				sa_utils.internal_sandhi({ stem = args.stem, ending = sa_utils.up_one_grade[vowel .. oxytone] .. 's', has_accent = args.has_accent }),
				sa_utils.internal_sandhi({ stem = args.lemma, ending = 'nas', has_accent = args.has_accent }),
				note2 = 'Later Sanskrit',
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", has_accent = args.has_accent }),
				note3 = 'Less common',
			}
			data.forms["gen_s"] = data.forms["abl_s"]
			data.forms["loc_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "ni" .. oxytone, has_accent = args.has_accent }), note1 = 'Later Sanskrit', }
			data.forms["voc_s"] = {
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "", recessive = true, has_accent = args.has_accent }),
				sa_utils.internal_sandhi({ stem = args.stem, ending = sa_utils.up_one_grade[vowel .. oxytone], recessive = true, has_accent = args.has_accent }),
			}
			
			data.forms["nom_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "nI", has_accent = args.has_accent }) }
			data.forms["acc_d"] = data.forms["nom_d"]
			data.forms["ins_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "ByAm", has_accent = args.has_accent }) }
			data.forms["dat_d"] = data.forms["ins_d"]
			data.forms["abl_d"] = data.forms["ins_d"]
			data.forms["gen_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "nos", has_accent = args.has_accent }) }
			data.forms["loc_d"] = data.forms["gen_d"]
			data.forms["voc_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "nI", recessive = true, has_accent = args.has_accent }) }
			
			data.forms["nom_p"] = {
				sa_utils.internal_sandhi({ stem = args.lemma, ending = vowel, has_accent = args.has_accent }),
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "", has_accent = args.has_accent }),
				sa_utils.internal_sandhi({ stem = args.stem .. sa_utils.lengthen[vowel .. oxytone], ending = "ni", has_accent = args.has_accent }),
				note3 = 'Later Sanskrit',
			}
			data.forms["acc_p"] = data.forms["nom_p"]
			data.forms["ins_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "Bis", has_accent = args.has_accent }) }
			data.forms["dat_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "Byas", has_accent = args.has_accent }) }
			data.forms["abl_p"] = data.forms["dat_p"]
			data.forms["gen_p"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = sa_utils.lengthen[vowel] .. "nA" .. (oxytone ~= '' and '/' or '') .. "m", has_accent = args.has_accent }) }
			data.forms["loc_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "su", has_accent = args.has_accent }) }
			data.forms["voc_p"] = {
				sa_utils.internal_sandhi({ stem = args.lemma, ending = vowel, recessive = true, has_accent = args.has_accent }),
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "", recessive = true, has_accent = args.has_accent }),
				sa_utils.internal_sandhi({ stem = args.stem .. sa_utils.lengthen[vowel], ending = "ni", recessive = true, has_accent = args.has_accent }),
				note3 = 'Later Sanskrit',
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
		local oxytone = match(args.lemma, "(" .. sa_utils.accent .. "?)$")
		local vowel = match(args.lemma, "([AIU])" .. sa_utils.accent .. "?$")
		
		data.decl_type = SLP_to_IAST.tr(vowel) .. "-stem"
		
		if not (args.root or args.compound or args.true_mono) then -- derived stem
			if vowel == 'A' then
				data.forms["nom_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "", has_accent = args.has_accent }) }
				data.forms["ins_s"] = {
					sa_utils.internal_sandhi({ stem = args.stem, ending = "a" .. oxytone .. "yA", has_accent = args.has_accent }),
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "", has_accent = args.has_accent }),
					note2 = 'Vedic',
				}
				data.forms["dat_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "yE", has_accent = args.has_accent }) }
				data.forms["abl_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "yAs", has_accent = args.has_accent }) }
				data.forms["gen_s"] = data.forms["abl_s"]
				data.forms["loc_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "yAm", has_accent = args.has_accent }) }
				data.forms["voc_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "e", recessive = true, has_accent = args.has_accent }) }
				
				data.forms["nom_d"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "e" .. oxytone, has_accent = args.has_accent }) }
				data.forms["acc_d"] = data.forms["nom_d"]
				data.forms["gen_d"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "a" .. oxytone .. "yos", has_accent = args.has_accent }) }
				data.forms["loc_d"] = data.forms["gen_d"]
				data.forms["voc_d"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "e", recessive = true, has_accent = args.has_accent }) }
				
				data.forms["nom_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "s", has_accent = args.has_accent }) }
				data.forms["voc_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "s", recessive = true, has_accent = args.has_accent }) }
			elseif vowel == 'I' then
				data.forms["nom_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "", has_accent = args.has_accent }) }
				data.forms["ins_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "A", has_accent = args.has_accent }) }
				data.forms["dat_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "E", has_accent = args.has_accent }) }
				data.forms["abl_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "As", has_accent = args.has_accent }) }
				data.forms["gen_s"] = data.forms["abl_s"]
				data.forms["loc_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "Am", has_accent = args.has_accent }) }
				data.forms["voc_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = sa_utils.shorten[vowel], recessive = true, has_accent = args.has_accent }) }
				
				data.forms["nom_d"] = {
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "O", has_accent = args.has_accent }),
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "", has_accent = args.has_accent }),
					note2 = 'Vedic',
				}
				data.forms["gen_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "os", has_accent = args.has_accent }) }
				data.forms["voc_d"] = {
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "O", recessive = true, has_accent = args.has_accent }),
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "", recessive = true, has_accent = args.has_accent }),
					note2 = 'Vedic',
				}
				
				data.forms["nom_p"] = {
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", has_accent = args.has_accent }),
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "s", has_accent = args.has_accent }),
					note2 = 'Vedic',
				}
				data.forms["voc_p"] = {
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", recessive = true, has_accent = args.has_accent }),
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "s", recessive = true, has_accent = args.has_accent }),
					note2 = 'Vedic',
				}
			else
				data.forms["nom_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "s", has_accent = args.has_accent }) }
				data.forms["ins_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "A", has_accent = args.has_accent }) }
				data.forms["dat_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "E", has_accent = args.has_accent }) }
				data.forms["abl_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "As", has_accent = args.has_accent }) }
				data.forms["gen_s"] = data.forms["abl_s"]
				data.forms["loc_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "Am", has_accent = args.has_accent }) }
				data.forms["voc_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = sa_utils.shorten[vowel], recessive = true, has_accent = args.has_accent }) }
				
				data.forms["nom_d"] = {
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "O", has_accent = args.has_accent }),
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "", has_accent = args.has_accent }),
					note2 = 'Vedic',
				}
				data.forms["gen_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "os", has_accent = args.has_accent }) }
				data.forms["voc_d"] = {
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "O", recessive = true, has_accent = args.has_accent }),
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "", recessive = true, has_accent = args.has_accent }),
					note2 = 'Vedic',
				}
				
				data.forms["nom_p"] = {
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", has_accent = args.has_accent }),
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "s", has_accent = args.has_accent }),
					note2 = 'Vedic',
				}
				data.forms["voc_p"] = {
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", recessive = true, has_accent = args.has_accent }),
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "s", recessive = true, has_accent = args.has_accent }),
					note2 = 'Vedic',
				}
			end
			data.forms["acc_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "m", has_accent = args.has_accent }) }
			
			data.forms["acc_d"] = data.forms["nom_d"]
			data.forms["ins_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "ByAm", has_accent = args.has_accent }) }
			data.forms["dat_d"] = data.forms["ins_d"]
			data.forms["abl_d"] = data.forms["ins_d"]
			data.forms["loc_d"] = data.forms["gen_d"]
			
			data.forms["acc_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "s", has_accent = args.has_accent }) }
			data.forms["ins_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "Bis", has_accent = args.has_accent }) }
			data.forms["dat_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "Byas", has_accent = args.has_accent }) }
			data.forms["abl_p"] = data.forms["dat_p"]
			data.forms["gen_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "nAm", has_accent = args.has_accent }) }
			data.forms["loc_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "su", has_accent = args.has_accent }) }
		
		elseif vowel == 'A' then
			data.forms["nom_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "s", has_accent = args.has_accent }) }
			data.forms["acc_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "m", has_accent = args.has_accent }) }
			data.forms["ins_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "", has_accent = args.has_accent }) }
			data.forms["dat_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "e" .. oxytone, has_accent = args.has_accent }) }
			data.forms["abl_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "a" .. oxytone .. 's', has_accent = args.has_accent }) }
			data.forms["gen_s"] = data.forms["abl_s"]
			data.forms["loc_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "i" .. oxytone, has_accent = args.has_accent }) }
			data.forms["voc_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "s", recessive = true, has_accent = args.has_accent }) }
			
			data.forms["nom_d"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "O" .. oxytone, has_accent = args.has_accent }) }
			data.forms["acc_d"] = data.forms["nom_d"]
			data.forms["ins_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "ByAm", has_accent = args.has_accent }) }
			data.forms["dat_d"] = data.forms["ins_d"]
			data.forms["abl_d"] = data.forms["ins_d"]
			data.forms["gen_d"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "o" .. oxytone .. "s", has_accent = args.has_accent }) }
			data.forms["loc_d"] = data.forms["gen_d"]
			data.forms["voc_d"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "O", recessive = true, has_accent = args.has_accent }) }
			
			data.forms["nom_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "s", has_accent = args.has_accent }) }
			data.forms["acc_p"] = {
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "s", has_accent = args.has_accent }),
				sa_utils.internal_sandhi({ stem = args.stem, ending = "a" .. oxytone .. "s", has_accent = args.has_accent }),
				note2 = 'Perhaps',
			}
			data.forms["ins_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "Bis", has_accent = args.has_accent }) }
			data.forms["dat_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "Byas", has_accent = args.has_accent }) }
			data.forms["abl_p"] = data.forms["dat_p"]
			data.forms["gen_p"] = {
				sa_utils.internal_sandhi({ stem = args.lemma, ending = sa_utils.lengthen[vowel] .. "nAm", has_accent = args.has_accent }),
				sa_utils.internal_sandhi({ stem = args.lemma, ending = sa_utils.lengthen[vowel] .. "m", has_accent = args.has_accent }),
				note2 = 'Perhaps',
			}
			data.forms["loc_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "su", has_accent = args.has_accent }) }
			data.forms["voc_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "s", recessive = true, has_accent = args.has_accent }) }
		elseif args.compound then
			if match(args.stem, sa_utils.consonant .. sa_utils.consonant .. "$") then
				data.forms["acc_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "am", has_accent = args.has_accent, mono = true }) }
				data.forms["ins_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "A", has_accent = args.has_accent, mono = true }) }
				data.forms["dat_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "e", has_accent = args.has_accent, mono = true }) }
				data.forms["abl_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", has_accent = args.has_accent, mono = true }) }
				data.forms["loc_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "i", has_accent = args.has_accent, mono = true }) }
				
				data.forms["nom_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "O", has_accent = args.has_accent, mono = true }) }
				data.forms["gen_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "os", has_accent = args.has_accent, mono = true }) }
				data.forms["voc_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "O", recessive = true, has_accent = args.has_accent, mono = true }) }
				
				data.forms["nom_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", has_accent = args.has_accent, mono = true }) }
				data.forms["gen_p"] = {
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "Am", has_accent = args.has_accent, mono = true }),
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "nAm", has_accent = args.has_accent }),
				}
				data.forms["voc_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", recessive = true, has_accent = args.has_accent, mono = true }) }
			else
				data.forms["acc_s"] = {
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "am", has_accent = args.has_accent, mono = true }),
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "am", has_accent = args.has_accent }),
				}
				data.forms["ins_s"] = {
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "A", has_accent = args.has_accent, mono = true }),
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "A", has_accent = args.has_accent }),
				}
				data.forms["dat_s"] = {
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "e", has_accent = args.has_accent, mono = true }),
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "e", has_accent = args.has_accent }),
				}
				data.forms["abl_s"] = {
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", has_accent = args.has_accent, mono = true }),
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", has_accent = args.has_accent }),
				}
				data.forms["loc_s"] = {
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "i", has_accent = args.has_accent, mono = true }),
					sa_utils.internal_sandhi({ stem = args.stem .. sa_utils.semivowel_to_cons[vowel], ending = "i" .. (oxytone ~= '' and '\\' or ''), has_accent = args.has_accent }), -- weird special case
				}
				
				data.forms["nom_d"] = {
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "O", has_accent = args.has_accent, mono = true }),
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "O", has_accent = args.has_accent }),
				}
				data.forms["gen_d"] = {
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "os", has_accent = args.has_accent, mono = true }),
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "os", has_accent = args.has_accent }),
				}
				data.forms["voc_d"] = {
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "O", recessive = true, has_accent = args.has_accent, mono = true }),
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "O", recessive = true, has_accent = args.has_accent }),
				}
				
				data.forms["nom_p"] = {
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", has_accent = args.has_accent, mono = true }),
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", has_accent = args.has_accent }),
				}
				data.forms["gen_p"] = {
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "Am", has_accent = args.has_accent, mono = true }),
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "nAm", has_accent = args.has_accent }),
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "Am", has_accent = args.has_accent }),
				}
				data.forms["voc_p"] = {
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", recessive = true, has_accent = args.has_accent, mono = true }),
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", recessive = true, has_accent = args.has_accent }),
				}
			end
			data.forms["nom_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "s", has_accent = args.has_accent }) }
			data.forms["gen_s"] = data.forms["abl_s"]
			data.forms["voc_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "s", recessive = true, has_accent = args.has_accent }) }
			
			data.forms["acc_d"] = data.forms["nom_d"]
			data.forms["ins_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "ByAm", has_accent = args.has_accent }) }
			data.forms["dat_d"] = data.forms["ins_d"]
			data.forms["abl_d"] = data.forms["ins_d"]
			data.forms["loc_d"] = data.forms["gen_d"]
			
			
			data.forms["acc_p"] = data.forms["nom_p"]
			data.forms["ins_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "Bis", has_accent = args.has_accent }) }
			data.forms["dat_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "Byas", has_accent = args.has_accent }) }
			data.forms["abl_p"] = data.forms["dat_p"]
			data.forms["loc_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "su", has_accent = args.has_accent }) }
		elseif args.true_mono then
			data.forms["nom_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "s", has_accent = args.has_accent }) }
			data.forms["acc_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "am", has_accent = args.has_accent, mono = true }) }
			data.forms["ins_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "A/", has_accent = args.has_accent, mono = true }) }
			data.forms["dat_s"] = {
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "e/", has_accent = args.has_accent, mono = true }),
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "E/", has_accent = args.has_accent, mono = true }),
				note2 = 'Later Sanskrit',
			}
			data.forms["abl_s"] = {
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "a/s", has_accent = args.has_accent, mono = true }),
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "A/s", has_accent = args.has_accent, mono = true }),
				note2 = 'Later Sanskrit',
			}
			data.forms["gen_s"] = data.forms["abl_s"]
			data.forms["loc_s"] = {
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "i/", has_accent = args.has_accent, mono = true }),
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "A/m", has_accent = args.has_accent, mono = true }),
				note2 = 'Later Sanskrit',
			}
			data.forms["voc_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "s", recessive = true, has_accent = args.has_accent }) }
			
			data.forms["nom_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "O", has_accent = args.has_accent, mono = true }) }
			data.forms["acc_d"] = data.forms["nom_d"]
			data.forms["ins_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "ByA/m", has_accent = args.has_accent, mono = true }) }
			data.forms["dat_d"] = data.forms["ins_d"]
			data.forms["abl_d"] = data.forms["ins_d"]
			data.forms["gen_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "o/s", has_accent = args.has_accent, mono = true }) }
			data.forms["loc_d"] = data.forms["gen_d"]
			data.forms["voc_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "O", recessive = true, has_accent = args.has_accent, mono = true }) }
			
			data.forms["nom_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", has_accent = args.has_accent, mono = true }) }
			data.forms["acc_p"] = data.forms["nom_p"]
			data.forms["ins_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "Bi/s", has_accent = args.has_accent, mono = true }) }
			data.forms["dat_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "Bya/s", has_accent = args.has_accent, mono = true }) }
			data.forms["abl_p"] = data.forms["dat_p"]
			data.forms["gen_p"] = {
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "A/m", has_accent = args.has_accent, mono = true }),
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "nA/m", has_accent = args.has_accent, mono = true }),
				note2 = 'Later Sanskrit',
			}
			data.forms["loc_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "su/", has_accent = args.has_accent, mono = true }) }
			data.forms["voc_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", recessive = true, has_accent = args.has_accent, mono = true }) }
		else
			data.forms["nom_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "s", has_accent = args.has_accent }) }
			data.forms["acc_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "am", has_accent = args.has_accent }) }
			data.forms["ins_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "A", has_accent = args.has_accent }) }
			data.forms["dat_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "e", has_accent = args.has_accent }) }
			data.forms["abl_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", has_accent = args.has_accent }) }
			data.forms["gen_s"] = data.forms["abl_s"]
			data.forms["loc_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "i", has_accent = args.has_accent }) }
			data.forms["voc_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = sa_utils.shorten[vowel], recessive = true, has_accent = args.has_accent }) }
			
			data.forms["nom_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "A", has_accent = args.has_accent }) }
			data.forms["acc_d"] = data.forms["nom_d"]
			data.forms["ins_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "ByAm", has_accent = args.has_accent }) }
			data.forms["dat_d"] = data.forms["ins_d"]
			data.forms["abl_d"] = data.forms["ins_d"]
			data.forms["gen_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "os", has_accent = args.has_accent }) }
			data.forms["loc_d"] = data.forms["gen_d"]
			data.forms["voc_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "A", recessive = true, has_accent = args.has_accent }) }
			
			data.forms["nom_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", has_accent = args.has_accent }) }
			data.forms["acc_p"] = data.forms["nom_p"]
			data.forms["ins_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "Bis", has_accent = args.has_accent }) }
			data.forms["dat_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "Byas", has_accent = args.has_accent }) }
			data.forms["abl_p"] = data.forms["dat_p"]
			data.forms["gen_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "nAm", has_accent = args.has_accent }) }
			data.forms["loc_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "su", has_accent = args.has_accent }) }
			data.forms["voc_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", recessive = true, has_accent = args.has_accent }) }
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
		local oxytone = match(args.lemma, "(" .. sa_utils.accent .. "?)$")
		
		data.decl_type = SLP_to_IAST.tr("f") .. "-stem"
		
		if not args.r_stem_a and args.g ~= 'n' then
			error('Please specify the length of the accusative singular vowel with r_stem_a = "a" or "ā".')
		else
			args.r_stem_a = IAST_to_SLP.tr(args.r_stem_a)
		end
		
		if args.g == 'n' then
			data.forms["nom_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "f" .. oxytone, has_accent = args.has_accent }) }
			data.forms["acc_s"] = data.forms["nom_s"]
			data.forms["ins_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "nA", has_accent = args.has_accent }) }
			data.forms["dat_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "ne", has_accent = args.has_accent }) }
			data.forms["abl_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "nas", has_accent = args.has_accent }) }
			data.forms["loc_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "ni", has_accent = args.has_accent }) }
			data.forms["voc_s"] = {
				sa_utils.internal_sandhi({ stem = args.stem, ending = "f", recessive = true, has_accent = args.has_accent }),
				sa_utils.internal_sandhi({ stem = args.stem, ending = "ar", recessive = true, has_accent = args.has_accent }),
			}
			
			data.forms["nom_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "nI", has_accent = args.has_accent }) }
			data.forms["gen_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "nos", has_accent = args.has_accent }) }
			data.forms["voc_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "nI", recessive = true, has_accent = args.has_accent }) }
			
			data.forms["nom_p"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "F" .. oxytone .. "ni", has_accent = args.has_accent }) }
			data.forms["acc_p"] = data.forms["nom_p"]
			data.forms["voc_p"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "Fni", recessive = true, has_accent = args.has_accent }) }
		else
			data.forms["nom_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "A" .. oxytone, has_accent = args.has_accent }) }
			data.forms["acc_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = args.r_stem_a .. oxytone .. "ram", has_accent = args.has_accent }) }
			data.forms["ins_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "rA" .. oxytone, has_accent = args.has_accent }) }
			data.forms["dat_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "re" .. oxytone, has_accent = args.has_accent }) }
			data.forms["abl_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "u" .. oxytone .. 'r', has_accent = args.has_accent }) }
			data.forms["loc_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "a" .. oxytone .. "ri", has_accent = args.has_accent }) }
			data.forms["voc_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "ar", recessive = true, has_accent = args.has_accent }) }
			
			data.forms["nom_d"] = {
				sa_utils.internal_sandhi({ stem = args.stem, ending = args.r_stem_a .. oxytone .. "rO", has_accent = args.has_accent }),
				sa_utils.internal_sandhi({ stem = args.stem, ending = args.r_stem_a .. oxytone .. "rA", has_accent = args.has_accent }),
				note2 = "Vedic",
			}
			data.forms["gen_d"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "ro" .. oxytone .. "s", has_accent = args.has_accent }) }
			data.forms["voc_d"] = {
				sa_utils.internal_sandhi({ stem = args.stem, ending = args.r_stem_a .. "rO", recessive = true, has_accent = args.has_accent }),
				sa_utils.internal_sandhi({ stem = args.stem, ending = args.r_stem_a .. "rA", recessive = true, has_accent = args.has_accent }),
				note2 = "Vedic",
			}
			
			data.forms["nom_p"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = args.r_stem_a .. oxytone .. "ras", has_accent = args.has_accent }) }
			if args.g == 'f' then
				data.forms["acc_p"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "F" .. oxytone .. "s", has_accent = args.has_accent }) }
			else
				data.forms["acc_p"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "F" .. oxytone .. "n", has_accent = args.has_accent }) }
			end
			data.forms["voc_p"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = args.r_stem_a .. "ras", recessive = true, has_accent = args.has_accent }) }
		end
		data.forms["gen_s"] = data.forms["abl_s"]
		
		data.forms["acc_d"] = data.forms["nom_d"]
		data.forms["ins_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "ByAm", has_accent = args.has_accent }) }
		data.forms["dat_d"] = data.forms["ins_d"]
		data.forms["abl_d"] = data.forms["ins_d"]
		data.forms["loc_d"] = data.forms["gen_d"]
		
		data.forms["ins_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "Bis", has_accent = args.has_accent }) }
		data.forms["dat_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "Byas", has_accent = args.has_accent }) }
		data.forms["abl_p"] = data.forms["dat_p"]
		data.forms["gen_p"] = { sa_utils.internal_sandhi({ stem = args.stem .. "F", ending = "nA" .. (oxytone ~= '' and '/' or '') .. "m", has_accent = args.has_accent }) }
		data.forms["loc_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "su", has_accent = args.has_accent }) }
		
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
		local vowel, oxytone = match(args.lemma, "([aiu])(" .. sa_utils.accent .. "?)s$")
		
		data.decl_type = vowel .. "s-stem"
		
		if args.g == 'm' or args.g == 'f' then
			if vowel == 'a' then
				data.forms["nom_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "A" .. oxytone .. "s", has_accent = args.has_accent }) }
				data.forms["acc_s"] = {
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "am", has_accent = args.has_accent }),
					sa_utils.internal_sandhi({ stem = args.stem, ending = "A" .. oxytone .. "m", has_accent = args.has_accent }),
					note2 = "Vedic"
				}
				
				data.forms["nom_p"] = {
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", has_accent = args.has_accent }),
					sa_utils.internal_sandhi({ stem = args.stem, ending = "A" .. oxytone .. "s", has_accent = args.has_accent }),
					note2 = 'Vedic',
				}
				data.forms["voc_p"] = {
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", recessive = true, has_accent = args.has_accent }),
					sa_utils.internal_sandhi({ stem = args.stem, ending = "A" .. oxytone .. "s", recessive = true, has_accent = args.has_accent }),
					note2 = 'Vedic',
				}
			else
				data.forms["nom_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "", has_accent = args.has_accent }) }
				data.forms["acc_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "am", has_accent = args.has_accent }) }
				
				data.forms["nom_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", has_accent = args.has_accent }) }
				data.forms["voc_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", recessive = true, has_accent = args.has_accent }) }
			end
			
			data.forms["voc_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "", recessive = true, has_accent = args.has_accent }) }
			
			data.forms["nom_d"] = {
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "O", has_accent = args.has_accent }),
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "A", has_accent = args.has_accent }),
				note2 = "Vedic"
			}
			data.forms["acc_d"] = data.forms["nom_d"]
			data.forms["voc_d"] = {
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "O", recessive = true, has_accent = args.has_accent }),
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "A", recessive = true, has_accent = args.has_accent }),
				note2 = "Vedic"
			}
		else
			data.forms["nom_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "", has_accent = args.has_accent }) }
			data.forms["acc_s"] = data.forms["nom_s"]
			data.forms["voc_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "", recessive = true, has_accent = args.has_accent }) }
			
			data.forms["nom_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "I", has_accent = args.has_accent }) }
			data.forms["acc_d"] = data.forms["nom_d"]
			data.forms["voc_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "I", recessive = true, has_accent = args.has_accent }) }
			
			data.forms["nom_p"] = { sa_utils.internal_sandhi({ stem = args.stem .. sa_utils.lengthen[vowel] .. oxytone .. "n", ending = "si", has_accent = args.has_accent }) }
			data.forms["voc_p"] = { sa_utils.internal_sandhi({ stem = args.stem .. sa_utils.lengthen[vowel] .. "n", ending = "si", recessive = true, has_accent = args.has_accent }) }
		end
		
		data.forms["ins_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "A", has_accent = args.has_accent }) }
		data.forms["dat_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "e", has_accent = args.has_accent }) }
		data.forms["abl_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", has_accent = args.has_accent }) }
		data.forms["gen_s"] = data.forms["abl_s"]
		data.forms["loc_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "i", has_accent = args.has_accent }) }
		
		data.forms["acc_d"] = data.forms["nom_d"]
		data.forms["ins_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "ByAm", has_accent = args.has_accent }) }
		data.forms["dat_d"] = data.forms["ins_d"]
		data.forms["abl_d"] = data.forms["ins_d"]
		data.forms["gen_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "os", has_accent = args.has_accent }) }
		data.forms["loc_d"] = data.forms["gen_d"]
		
		data.forms["acc_p"] = data.forms["nom_p"]
		data.forms["ins_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "Bis", has_accent = args.has_accent }) }
		data.forms["dat_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "Byas", has_accent = args.has_accent }) }
		data.forms["abl_p"] = data.forms["dat_p"]
		data.forms["gen_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "Am", has_accent = args.has_accent }) }
		data.forms["loc_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "su", has_accent = args.has_accent }) }
		
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
		local oxytone = match(args.lemma, "a(" .. sa_utils.accent .. "?)n$")
		
		data.decl_type = "an-stem"
		
		if not match(args.stem, sa_utils.consonant .. sa_utils.consonant .. "$") or args.contract then
			data.forms["ins_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "nA" .. oxytone, has_accent = args.has_accent }) }
			data.forms["dat_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "ne" .. oxytone, has_accent = args.has_accent }) }
			data.forms["abl_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "na" .. oxytone .. "s", has_accent = args.has_accent }) }
			data.forms["gen_s"] = data.forms["abl_s"]
			data.forms["loc_s"] = {
				sa_utils.internal_sandhi({ stem = args.stem, ending = "ni" .. oxytone, has_accent = args.has_accent }),
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "i", has_accent = args.has_accent }),
			}
			
			data.forms["gen_d"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "no" .. oxytone .. "s", has_accent = args.has_accent }) }
			
			if args.g ~= 'm' then
				data.forms["nom_d"] = {
					sa_utils.internal_sandhi({ stem = args.stem, ending = "nI" .. oxytone, has_accent = args.has_accent }),
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "I", has_accent = args.has_accent }),
				}
				data.forms["voc_d"] = {
					sa_utils.internal_sandhi({ stem = args.stem, ending = "nI", recessive = true, has_accent = args.has_accent }),
					sa_utils.internal_sandhi({ stem = args.lemma, ending = "I", recessive = true, has_accent = args.has_accent }),
				}
				
				data.forms["acc_p"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "A" .. oxytone .. "ni", has_accent = args.has_accent }) }
			else
				data.forms["nom_d"] = {
					sa_utils.internal_sandhi({ stem = args.stem, ending = "A" .. oxytone .. "nO", has_accent = args.has_accent }),
					sa_utils.internal_sandhi({ stem = args.stem, ending = "A" .. oxytone .. "nA", has_accent = args.has_accent }),
					note2 = "Vedic"
				}
				data.forms["voc_d"] = {
					sa_utils.internal_sandhi({ stem = args.stem, ending = "AnO", recessive = true, has_accent = args.has_accent }),
					sa_utils.internal_sandhi({ stem = args.stem, ending = "AnA", recessive = true, has_accent = args.has_accent }),
					note2 = "Vedic"
				}
				
				data.forms["acc_p"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "na" .. oxytone .. "s", has_accent = args.has_accent }) }
			end
			data.forms["gen_p"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "nA" .. oxytone .. "m", has_accent = args.has_accent }) }
		else
			data.forms["ins_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "A", has_accent = args.has_accent }) }
			data.forms["dat_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "e", has_accent = args.has_accent }) }
			data.forms["abl_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", has_accent = args.has_accent }) }
			data.forms["gen_s"] = data.forms["abl_s"]
			data.forms["loc_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "i", has_accent = args.has_accent }) }
			
			data.forms["gen_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "os", has_accent = args.has_accent }) }
			
			if args.g ~= 'm' then
				data.forms["nom_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "I", has_accent = args.has_accent }) }
				data.forms["voc_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "I", recessive = true, has_accent = args.has_accent }) }
				
				data.forms["acc_p"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "A" .. oxytone .. "ni", has_accent = args.has_accent }) }
			else
				data.forms["nom_d"] = {
					sa_utils.internal_sandhi({ stem = args.stem, ending = "A" .. oxytone .. "nO", has_accent = args.has_accent }),
					sa_utils.internal_sandhi({ stem = args.stem, ending = "A" .. oxytone .. "nA", has_accent = args.has_accent }),
					note2 = "Vedic"
				}
				data.forms["voc_d"] = {
					sa_utils.internal_sandhi({ stem = args.stem, ending = "AnO", recessive = true, has_accent = args.has_accent }),
					sa_utils.internal_sandhi({ stem = args.stem, ending = "AnA", recessive = true, has_accent = args.has_accent }),
					note2 = "Vedic"
				}
				
				data.forms["acc_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", has_accent = args.has_accent }) }
			end
			data.forms["gen_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "Am", has_accent = args.has_accent }) }
		end
		
		if args.g ~= 'm' then
			data.forms["nom_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "a" .. oxytone, has_accent = args.has_accent }) }
			data.forms["acc_s"] = data.forms["nom_s"]
			data.forms["voc_s"] = {
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "", recessive = true, has_accent = args.has_accent }),
				sa_utils.internal_sandhi({ stem = args.stem, ending = "a", recessive = true, has_accent = args.has_accent }),
			}
			
			data.forms["nom_p"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "A" .. oxytone .. "ni", has_accent = args.has_accent }) }
			data.forms["voc_p"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "Ani", recessive = true, has_accent = args.has_accent }) }
		else
			data.forms["nom_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "A" .. oxytone, has_accent = args.has_accent }) }
			data.forms["acc_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "A" .. oxytone .. "nam", has_accent = args.has_accent }) }
			data.forms["voc_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "", recessive = true, has_accent = args.has_accent }) }
			
			data.forms["nom_p"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "A" .. oxytone .. "nas", has_accent = args.has_accent }) }
			data.forms["voc_p"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "Anas", recessive = true, has_accent = args.has_accent }) }
		end
		
		data.forms["acc_d"] = data.forms["nom_d"]
		data.forms["acc_d"] = data.forms["nom_d"]
		data.forms["ins_d"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "a" .. oxytone .. "ByAm", has_accent = args.has_accent }) }
		data.forms["dat_d"] = data.forms["ins_d"]
		data.forms["abl_d"] = data.forms["ins_d"]
		
		data.forms["loc_d"] = data.forms["gen_d"]
		
		data.forms["ins_p"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "a" .. oxytone .. "Bis", has_accent = args.has_accent }) }
		data.forms["dat_p"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "a" .. oxytone .. "Byas", has_accent = args.has_accent }) }
		data.forms["abl_p"] = data.forms["dat_p"]
		data.forms["loc_p"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "a" .. oxytone .. "su", has_accent = args.has_accent }) }
		
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
		local oxytone = match(args.lemma, "i(" .. sa_utils.accent .. "?)n$")
		
		data.decl_type = "in-stem"
		
		if args.g ~= 'n' then
			data.forms["nom_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "I" .. oxytone, has_accent = args.has_accent }) }
			data.forms["acc_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "i" .. oxytone .. "nam", has_accent = args.has_accent }) }
			data.forms["voc_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "", recessive = true, has_accent = args.has_accent }) }
			
			data.forms["nom_d"] = {
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "O", has_accent = args.has_accent }),
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "A", has_accent = args.has_accent }),
				note2 = "Vedic"
			}
			data.forms["voc_d"] = {
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "O", recessive = true, has_accent = args.has_accent }),
				sa_utils.internal_sandhi({ stem = args.lemma, ending = "A", recessive = true, has_accent = args.has_accent }),
				note2 = "Vedic"
			}
			
			data.forms["nom_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", has_accent = args.has_accent }) }
			data.forms["acc_p"] = data.forms["nom_p"]
			data.forms["voc_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", recessive = true, has_accent = args.has_accent }) }
		else
			data.forms["nom_s"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "i" .. oxytone, has_accent = args.has_accent }) }
			data.forms["acc_s"] = data.forms["nom_s"]
			data.forms["voc_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "i", recessive = true, has_accent = args.has_accent }) }
			
			data.forms["nom_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "I", has_accent = args.has_accent }) }
			data.forms["voc_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "I", recessive = true, has_accent = args.has_accent }) }
			
			data.forms["nom_p"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "I" .. oxytone .. "ni", has_accent = args.has_accent }) }
			data.forms["acc_p"] = data.forms["nom_p"]
			data.forms["voc_p"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "Ini", recessive = true, has_accent = args.has_accent }) }
		end
		
		data.forms["ins_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "A", has_accent = args.has_accent }) }
		data.forms["dat_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "e", has_accent = args.has_accent }) }
		data.forms["abl_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "as", has_accent = args.has_accent }) }
		data.forms["gen_s"] = data.forms["abl_s"]
		data.forms["loc_s"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "i", has_accent = args.has_accent }) }
		
		data.forms["acc_d"] = data.forms["nom_d"]
		data.forms["ins_d"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "i" .. oxytone .. "ByAm", has_accent = args.has_accent }) }
		data.forms["dat_d"] = data.forms["ins_d"]
		data.forms["abl_d"] = data.forms["ins_d"]
		data.forms["gen_d"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "os", has_accent = args.has_accent }) }
		data.forms["loc_d"] = data.forms["gen_d"]
		
		data.forms["ins_p"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "i" .. oxytone .. "Bis", has_accent = args.has_accent }) }
		data.forms["dat_p"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "i" .. oxytone .. "Byas", has_accent = args.has_accent }) }
		data.forms["abl_p"] = data.forms["dat_p"]
		data.forms["gen_p"] = { sa_utils.internal_sandhi({ stem = args.lemma, ending = "Am", has_accent = args.has_accent }) }
		data.forms["loc_p"] = { sa_utils.internal_sandhi({ stem = args.stem, ending = "i" .. oxytone .. "zu", has_accent = args.has_accent }) }
		
		table.insert(data.categories, "Sanskrit in-stem nouns")
	end
})

return decl_data
