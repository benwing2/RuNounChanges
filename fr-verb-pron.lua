local pron = {}

-- Combine stem pronunciation and suffix pronunciation. The stem can actually
-- consist of multiple stems separated by /, in which case the suffix will
-- be added to each stem separately and the return value will be a list of
-- pronunciations (unless CONCAT is true, in which case the return value will
-- be a string with separate pronunciations separated by /); otherwise the
-- return value will be a single string. The combination procedure mostly
-- just appends the two, but handles changing ".jj" to "j.j" (moving the
-- syllable boundary) and converting ".C[lʁ]j" to ".C[lʁ]i".
local function add(source, appendix, concat)
	if mw.ustring.match(source,"/") then
		source = mw.text.split(source,"/",true)
		for i,val in ipairs(source) do
			source[i] = mw.ustring.gsub(mw.ustring.gsub(val..appendix, "%.jj", "j.j"),"(%..[lʁ])(j[ɔe]̃?)","%1i.%2")
		end
		if concat then
			source = table.concat(source, "/")
		end
		return source
	else
		return mw.ustring.gsub(mw.ustring.gsub(source..appendix, "%.jj", "j.j"),"(%..[lʁ])(j[ɔe]̃?)","%1i.%2")
	end
end

-- Construct the pronunciation of the entire present tense (indicative,
-- subjunctive, imperative and participle), plus the imperfect indicative,
-- given up to four stems:
-- STEM = short pre-final stem (used for pres indic/imper 1s/2s/3s, required);
-- STEM2 = pre-vocalic stem (used for pres indic/imper 1p/2p,
--         impf indic 1s/2s/3s/3p, pres part) (required);
-- STEM3 = long pre-final stem (used for pres indic 3p and pres subj 1s/2s/3s/3p,
--         defaults to STEM);
-- STEM4 = pre-/j/ stem (used for 1p/2p of pres subj and impf indic,
--         defaults to STEM2).
--
-- The value of any of these stem arguments can actually consist of multiple
-- stems separated by a /; see add().
--
-- Note that this will not override an already-existing value for the
-- present participle, but will override all the rest.
pron["ind_p"] = function(data, stem, stem2, stem3, stem4)
	stem3 = stem3 or stem
	stem4 = stem4 or stem2
	data.prons.ind_p_1s = add(stem,"")
	data.prons.ind_p_2s = add(stem,"")
	data.prons.ind_p_3s = add(stem,"")
	data.prons.ind_p_1p = add(stem2,"ɔ̃")
	data.prons.ind_p_2p = add(stem2,"e")
	data.prons.ind_p_3p = add(stem3,"")
	
	data = pron["ind_i"](data, stem2, stem4)
	data = pron["sub_p"](data, stem3, stem4)
	
	data.prons.imp_p_2s = add(stem,"")
	data.prons.imp_p_1p = add(stem2,"ɔ̃")
	data.prons.imp_p_2p = add(stem2,"e")
	
	data.prons.ppr = add(stem2,"ɑ̃")
	
	return data
end

-- Construct the pronunciation of the imperfect indicative given STEM
-- (used for the 1s/2s/3s/3p parts) and STEM2 (used for the 1p/2p parts).
-- STEM2 defaults to STEM, and either or both may be multipart, see add().
pron["ind_i"] = function(data, stem, stem2)
	stem2 = stem2 or stem
	data.prons.ind_i_1s = add(stem,"ɛ")
	data.prons.ind_i_2s = add(stem,"ɛ")
	data.prons.ind_i_3s = add(stem,"ɛ")
	data.prons.ind_i_1p = add(stem2,"jɔ̃")
	data.prons.ind_i_2p = add(stem2,"je")
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
	
	data.prons.pp = add(stem,"")
	
	return data
end

-- Construct the pronunciation of future and conditional. STEM is used for
-- all parts but 1p/2p of the conditional, which uses STEM2 (which defaults to
-- STEM). Either or both stems may be multipart (see add()).
pron["ind_f"] = function(data, stem, stem2)
	data.prons.ind_f_1s = add(stem, "ʁe")
	data.prons.ind_f_2s = add(stem, "ʁa")
	data.prons.ind_f_3s = add(stem, "ʁa")
	data.prons.ind_f_1p = add(stem, "ʁɔ̃")
	data.prons.ind_f_2p = add(stem, "ʁe")
	data.prons.ind_f_3p = add(stem, "ʁɔ̃")
	
	data = pron["cond_p"](data, stem, stem2)
	
	return data
end

-- Construct the pronunciation of the conditional. The stem
-- passed in may be multipart (see add()).
pron["cond_p"] = function(data, stem, stem2)
	stem2 = stem2 or stem
	data.prons.cond_p_1s = add(stem,"ʁɛ")
	data.prons.cond_p_2s = add(stem,"ʁɛ")
	data.prons.cond_p_3s = add(stem,"ʁɛ")
	data.prons.cond_p_1p = add(stem2,"ʁjɔ̃")
	data.prons.cond_p_2p = add(stem2,"ʁje")
	data.prons.cond_p_3p = add(stem,"ʁɛ")
	
	return data
end

-- Construct the pronunciation of future and conditional for verbs where a
-- schwa needs to be inserted before the endings (e.g. 'montrer'). The stem
-- passed in should not include the schwa and may be multipart (see add()).
pron["future_with_schwa"] = function(data, stem)
	return pron["ind_f"](data, add(stem,"ə.", "concat"))
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

-- Construct the pronunciation of all verb parts for -er verbs given the
-- following stems (which may be multipart, see add()):
--   STEM_FINAL is used for those forms without a syllabic suffix (singular
--     and 3p of the present indicative/subjunctive/imperative);
--   STEM_NONFINAL is used for the remaining forms, except that:
--   STEM_NONFINAL_I is used for those forms beginning with /j/ (1p and 2p of
--     present subjunctive and imperfect indicative), and should not contain
--     a final /j/;
--   STEM_FUT is used for the future and conditional (and should not contain
--     a final /ʁ/), except that:
--   STEM_FUT_I is used for 1p and 2p of the conditional (and should not
--     contain a final /ʁj/).
pron["er"] = function(data, stem_final, stem_nonfinal, stem_nonfinal_i, stem_fut, stem_fut_i)
	stem_fut = stem_fut or add(stem_nonfinal, "ə.", "concat")
	data.prons.ppr = add(stem_nonfinal,"ɑ̃")
	data.prons.pp = add(stem_nonfinal,"e")

	data = pron.ind_p(data, stem_final, stem_nonfinal, stem_final, stem_nonfinal_i)
	data = pron.ind_f(data, stem_fut, stem_fut_i)
	data = pron.ind_ps_a(data, stem_nonfinal)

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
	
	data = pron.sub_pa(data, add(stem, "a", "concat"))
	
	return data
end

return pron
