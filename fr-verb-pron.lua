local pron = {}

-- Combine stem pronunciation and suffix pronunciation. The stem can actually
-- consist of multiple stems separated by /, in which case the suffix will
-- be added to each stem separately and the return value will be a list of
-- pronunciations; otherwise the return value will be a single string. The
-- combination procedure mostly just appends the two, but handles changing
-- ".jj" to "j.j" (moving the syllable boundary) and converting ".C[lʁ]j"
-- to ".C[lʁ]i".
local function add(source,appendix)
	if mw.ustring.match(source,"/") then
		source = mw.text.split(source,"/",true)
		for i,val in ipairs(source) do
			source[i] = mw.ustring.gsub(mw.ustring.gsub(val..appendix, "%.jj", "j.j"),"(%..[lʁ])(j[ɔe]̃?)","%1i.%2")
		end
	else
		return mw.ustring.gsub(mw.ustring.gsub(source..appendix, "%.jj", "j.j"),"(%..[lʁ])(j[ɔe]̃?)","%1i.%2")
	end
	return source
end

-- Construct the pronunciation of the entire present tense (indicative,
-- subjunctive, imperative and participle), plus the imperfect indicative,
-- given three stems:
-- STEM = singular stem of present indicative/imperative;
-- STEM2 = pre-vocalic stem (used for pres indic/subj/imper 1p/2p,
--         entire imperfect, and pres part);
-- STEM3 = 3p stem of pres indicative/subjunctive (also used for singular of
--         pres subj).
--
-- STEM and STEM2 are required but STEM3 defaults to STEM.
--
-- The value of any of these stem arguments can actually consist of multiple
-- stems separated by a /; see add().
--
-- Note that this will not override an already-existing value for the
-- present participle, but will override all the rest.
pron["ind_p"] = function(data, stem, stem2, stem3)
	stem3 = stem3 or stem
	data.prons.ind_p_1s = add(stem,"")
	data.prons.ind_p_2s = add(stem,"")
	data.prons.ind_p_3s = add(stem,"")
	data.prons.ind_p_1p = add(stem2,"ɔ̃")
	data.prons.ind_p_2p = add(stem2,"e")
	data.prons.ind_p_3p = add(stem3,"")
	
	data = pron["ind_i"](data, stem2)
	data = pron["sub_p"](data, stem3, stem2)
	
	data.prons.imp_p_2s = add(stem,"")
	data.prons.imp_p_1p = add(stem2,"ɔ̃")
	data.prons.imp_p_2p = add(stem2,"e")
	
	data.prons.ppr = data.prons.ppr or add(stem2,"ɑ̃")
	
	return data
end

-- Construct the pronunciation of the imperfect indicative given the stem
-- (which may be multipart, see add()).
pron["ind_i"] = function(data, stem)
	data.prons.ind_i_1s = add(stem,"ɛ")
	data.prons.ind_i_2s = add(stem,"ɛ")
	data.prons.ind_i_3s = add(stem,"ɛ")
	data.prons.ind_i_1p = add(stem,"jɔ̃")
	data.prons.ind_i_2p = add(stem,"je")
	data.prons.ind_i_3p = add(stem,"ɛ")
	
	return data
end

-- Construct the pronunciation of the simple past, imperfect subjunctive and
-- past participle given the stem (which should include the final vowel and
-- may be multipart, see add()). This will not override an already-existing
-- value for the past participle, but will override the rest.
pron["ind_ps"] = function(data, stem)
	data.prons.ind_ps_1s = add(stem,"")
	data.prons.ind_ps_2s = add(stem,"")
	data.prons.ind_ps_3s = add(stem,"")
	data.prons.ind_ps_1p = add(stem,"m")
	data.prons.ind_ps_2p = add(stem,"t")
	data.prons.ind_ps_3p = add(stem,"ʁ")
	
	data = pron["sub_pa"](data,stem)
	
	data.prons.pp = data.prons.pp or add(stem,"")
	
	return data
end

-- Construct the pronunciation of future and conditional for verbs where a
-- schwa needs to be inserted before the endings (e.g. 'montrer'). The stem
-- passed in should not include the schwa and may be multipart (see add()).
pron["future_with_schwa"] = function(data, stem)
	data.prons.ind_f_1s = add(stem,"ə.ʁe")
	data.prons.ind_f_2s = add(stem,"ə.ʁa")
	data.prons.ind_f_3s = add(stem,"ə.ʁa")
	data.prons.ind_f_1p = add(stem,"ə.ʁɔ̃")
	data.prons.ind_f_2p = add(stem,"ə.ʁe")
	data.prons.ind_f_3p = add(stem,"ə.ʁɔ̃")
	
	data = pron["cond_p"](data, mw.ustring.match(stem,"/") and table.concat(add(stem,"ə."),"/") or add(stem,"ə."))
	
	return data
end

-- Construct the pronunciation of future and conditional. The stem
-- passed in may be multipart (see add()).
pron["ind_f"] = function(data, stem)
	data.prons.ind_f_1s = add(stem, "ʁe")
	data.prons.ind_f_2s = add(stem, "ʁa")
	data.prons.ind_f_3s = add(stem, "ʁa")
	data.prons.ind_f_1p = add(stem, "ʁɔ̃")
	data.prons.ind_f_2p = add(stem, "ʁe")
	data.prons.ind_f_3p = add(stem, "ʁɔ̃")
	
	data = pron["cond_p"](data, stem)
	
	return data
end

-- Construct the pronunciation of the conditional. The stem
-- passed in may be multipart (see add()).
pron["cond_p"] = function(data, stem)
	data.prons.cond_p_1s = add(stem,"ʁɛ")
	data.prons.cond_p_2s = add(stem,"ʁɛ")
	data.prons.cond_p_3s = add(stem,"ʁɛ")
	data.prons.cond_p_1p = add(stem,"ʁjɔ̃")
	data.prons.cond_p_2p = add(stem,"ʁje")
	data.prons.cond_p_3p = add(stem,"ʁɛ")
	
	return data
end

-- Construct the pronunciation of the present subjunctive given two stems
-- (which may be multipart, see add()). STEM is used for the singular and 3p,
-- and STEM2 is used for 1p and 2p (i.e. when followed by a vowel).
pron["sub_p"] = function(data, stem, stem2)
	data.prons.sub_p_1s = add(stem,"")
	data.prons.sub_p_2s = add(stem,"")
	data.prons.sub_p_3s = add(stem,"")
	data.prons.sub_p_1p = add(stem2,"jɔ̃")
	data.prons.sub_p_2p = add(stem2,"je")
	data.prons.sub_p_3p = add(stem,"")
	
	return data
end

-- Construct the pronunciation of the imperfect subjunctive given the stem
-- (which may be multipart, see add()).
pron["sub_pa"] = function(data, stem)
	data.prons.sub_pa_1s = add(stem,"s")
	data.prons.sub_pa_2s = add(stem,"s")
	data.prons.sub_pa_3s = add(stem,"")
	data.prons.sub_pa_1p = add(stem,".sjɔ̃")
	data.prons.sub_pa_2p = add(stem,".sje")
	data.prons.sub_pa_3p = add(stem,"s")
	
	return data
end

-- Construct the pronunciation of all verb parts for -er verbs given two stems
-- (which may be multipart, see add()). STEM is used for the singular and 3p
-- of the present indicative/subjunctive/imperative. STEM2 is used for all
-- other forms.
pron["er"] = function(data, stem, stem2)
	data.prons.ppr = data.prons.ppr or add(stem2,"ɑ̃")
	data.prons.pp = data.prons.pp or add(stem2,"e")
	
	data = pron.ind_p(data, stem, stem2, stem)
	
	data = pron.ind_i(data, stem2)
	
	data = pron.future_with_schwa(data, stem2)
	
	data = pron.ind_ps_a(data, stem2)
	
	return data
end

-- Construct the pronunciation of the simple past and imperfect subjunctive
-- for -er verbs, given the stem (which may be multipart, see add()).
pron["ind_ps_a"] = function(data, stem)
	data.prons.ind_ps_1s = add(stem,"e")
	data.prons.ind_ps_2s = add(stem,"a")
	data.prons.ind_ps_3s = add(stem,"a")
	data.prons.ind_ps_1p = add(stem,"am")
	data.prons.ind_ps_2p = add(stem,"at")
	data.prons.ind_ps_3p = add(stem,"ɛʁ")
	
	data = pron.sub_pa(data, mw.ustring.match(stem,"/") and table.concat(add(stem,"a"),"/") or add(stem,"a"))
	
	return data
end

return pron
