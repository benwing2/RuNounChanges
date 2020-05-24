local export = {}

local iut = require("Module:inflection utilities")

--[=[

Authorship: Ben Wing <benwing2>

]=]


-- Person/number suffixes for non-gendered slot prefixes.
local pers_num_suffixes = {"1sg", "2sg", "3sg", "1pl", "2pl", "3pl"}

-- Person/number/gender suffixes for gendered slot prefixes.
local gendered_pers_num_suffixes = {
	"m_1sg", "f_1sg", "n_1sg", "m_2sg", "f_2sg", "n_2sg", "m_3sg", "f_3sg", "n_3sg",
	"1pl", "2pl", "3pl"
}

-- Non-gendered slot prefixes.
local pers_num_prefixes = {
	-- indicative
	"fut_pos", "fut_neg", "futip_pos", "futip_neg",
	"ren_fut_neg", "dub_fut_neg", "conc_fut_neg",
}

-- Gendered slot prefixes.
local gendered_pers_num_prefixes = {
	-- indicative
	"prespf", "pastpf", "futpf_pos", "futpf_neg", "futpfip_pos", "futpfip_neg",
	"ren_pres", "ren_aor", "ren_fut_pos", "ren_prespf", "ren_futpf_pos", "ren_futpf_neg",
	"dub_pres", "dub_aor", "dub_fut_pos", "dub_futpf_pos", "dub_futpf_neg", -- no dub_prespf
	"conc_pres", "conc_aor", "conc_fut_pos", "conc_prespf", "conc_futpf_pos", "conc_futpf_neg",
	"cond",
}


export.verb_compound_slots = {}

for _, non_gendered_prefix in ipairs(pers_num_prefixes) do
	for _, suffix in ipairs(pers_num_suffixes) do
		table.insert(export.verb_compound_slots, non_gendered_prefix .. "_" .. suffix)
	end
end
for _, gendered_prefix in ipairs(gendered_pers_num_prefixes) do
	for _, suffix in ipairs(gendered_pers_num_suffixes) do
		table.insert(export.verb_compound_slots, gendered_prefix .. "_" .. suffix)
	end
end


local function concat(prefix, suffix)
	if not prefix then
		return suffix
	elseif not suffix then
		return prefix
	else
		return prefix .. " " .. suffix
	end
end


local function concn(a, b, c, d)
	local vals = {}
	if a then
		table.insert(vals, a)
	end
	if b then
		table.insert(vals, b)
	end
	if c then
		table.insert(vals, c)
	end
	if d then
		table.insert(vals, d)
	end
	return table.concat(vals, " ")
end


local function concat_tables(prefixes, suffixes, combine)
	combine = combine or concat
	if type(prefixes) == "string" and type(suffixes) == "string" then
		error("Either prefixes or suffixes should be a table")
	end
	local len
	if type(prefixes) == "table" and type(suffixes) == "table" then
		len = #prefixes
		if len ~= #suffixes then
			error("Length of prefixes is " .. len .. " but length of suffixes is " .. #suffixes ..
				", they should be equal")
		end
	elseif type(prefixes) == "table" then
		len = #prefixes
	else
		len = #suffixes
	end
	local retval = {}
	for i=1,len do
		local prefix = type(prefixes) == "table" and prefixes[i] or prefixes
		local suffix = type(suffixes) == "table" and suffixes[i] or suffixes
		if (type(prefix) == "table" and not prefix.form) or
			(type(suffix) == "table" and not suffix.form) then
			table.insert(retval, concat_tables(prefix, suffix))
		else
			table.insert(retval, combine(prefix, suffix))
		end
	end
	return retval
end

local function gender_cross_person(fn)
	local retval = {}
	for person=1,3 do
		for gender=1,3 do
			table.insert(retval, fn(gender, person, (person - 1) * 3 + gender))
		end
	end
	for person=4,6 do
		table.insert(retval, fn(4, person, person + 6))
	end
	return retval
end

local sam_pres = {"[[съм]]", "[[си]]", "[[е]]", "[[сме]]", "[[сте]]", "[[са]]"}
local sam_pres_no3 = {"[[съм]]", "[[си]]", false, "[[сме]]", "[[сте]]", false}
local sam_impf = {"[[бях]]", {"[[бе]]", "[[бе́ше]]"}, {"[[бе]]", "[[бе́ше]]"}, "[[бя́хме]]", "[[бя́хте]]", "[[бя́ха]]"}
local sam_paip = {"[[бил]]", "[[била́]]", "[[било́]]", "[[били́]]"}
local shta_impf = {"[[щях]]", "[[ще́ше]]", "[[ще́ше]]", "[[щя́хме]]", "[[щя́хте]]", "[[щя́ха]]"}
local shta_paip = {"[[щял]]", "[[щя́ла]]", "[[щя́ло]]", "[[ще́ли]]"}
-- local bada_pres = {"[[бъ́да]]", "[[бъ́деш]]", "[[бъ́де]]", "[[бъ́дем]]", "[[бъ́дете]]", "[[бъ́дат]]"}
local bada_aor1 = {"[[бих]]", "[[би]]", "[[би]]", "[[би́хме]]", "[[би́хте]]", "[[би́ха]]"}

function export.conjugate_all_compound(base)
	local forms = base.forms

	local function addpref(dest_slot, pref, source_slot)
		if type(pref) ~= "table" then
			pref = {pref}
		end
		for _, p in ipairs(pref) do
			iut.insert_forms(forms, dest_slot,
				iut.map_forms(forms[source_slot], function(form) return concat(p, "[[" .. form .. "]]") end)
			)
		end
	end

	local function addsuf(dest_slot, suf, source_slot)
		if type(suf) ~= "table" then
			suf = {suf}
		end
		for _, s in ipairs(suf) do
			iut.insert_forms(forms, dest_slot,
				iut.map_forms(forms[source_slot], function(form) return concat("[[" .. form .. "]]", s) end)
			)
		end
	end

	-- Add non-gendered PREFIXTEXT to the forms in the non-gendered source slot row identified by
	-- SOURCE_SLOT_PREFIX and store the results in the (non-gendered) destination slot row identified
	-- by DEST_SLOT_PREFIX. A "non-gendered slot row" is a row of slots that differ in person and
	-- number, with no gender differences. For example, the present indicative (slot prefix "pres")
	-- is a non-gendered slot row. "Non-gendered PREFIXTEXT" can be either a string (the same for all
	-- slots) or a 6-element table corresponding to 1sg, 2sg, 3sg, 1pl, 2pl, 3pl respectively, where
	-- each element of the table is either a string or a table of alternants, each of which is a
	-- string. A case where PREFIXTEXT should be a string is the negative future-in-the-past
	-- indicative, which prefixes "ня́маше да" to the present indicative. A case where PREFIXTEXT
	-- should be a table is the positive future-in-the-past indicative, which prefixes the imperfect
	-- of ща + "да" to the present indicative.
	local function ngen_prefix_to_ngen(dest_slot_prefix, prefixtext, source_slot_prefix)
		local x1sg, x2sg, x3sg, x1pl, x2pl, x3pl
		if type(prefixtext) == "string" then
			x1sg, x2sg, x3sg, x1pl, x2pl, x3pl = prefixtext, prefixtext, prefixtext, prefixtext, prefixtext, prefixtext
		else
			x1sg, x2sg, x3sg, x1pl, x2pl, x3pl = unpack(prefixtext)
		end
		addpref(dest_slot_prefix .. "_1sg", x1sg, source_slot_prefix  .. "_1sg")
		addpref(dest_slot_prefix .. "_2sg", x2sg, source_slot_prefix  .. "_2sg")
		addpref(dest_slot_prefix .. "_3sg", x3sg, source_slot_prefix  .. "_3sg")
		addpref(dest_slot_prefix .. "_1pl", x1pl, source_slot_prefix  .. "_1pl")
		addpref(dest_slot_prefix .. "_2pl", x2pl, source_slot_prefix  .. "_2pl")
		addpref(dest_slot_prefix .. "_3pl", x3pl, source_slot_prefix  .. "_3pl")
	end

	-- Add non-gendered PREFIXTEXT to the forms in the gendered source slot row identified by
	-- SOURCE_SLOT_PREFIX and store the results in the (gendered) destination slot row identified
	-- by DEST_SLOT_PREFIX. See ngen_prefix_to_ngen() for definition of "slot row" and
	-- "non-gendered PREFIXTEXT". Here, the gendered source slot row is assumed to differ only
	-- in gender and number, not in person (i.e. it's a participle), while the gendered destination
	-- slot row differs in person, gender and number.
	local function ngen_prefix_to_gen(dest_slot_prefix, prefixtext, source_slot_prefix)
		local x1sg, x2sg, x3sg, x1pl, x2pl, x3pl = unpack(prefixtext)
		addpref(dest_slot_prefix .. "_m_1sg", x1sg, source_slot_prefix  .. "_m_sg")
		addpref(dest_slot_prefix .. "_f_1sg", x1sg, source_slot_prefix  .. "_f_sg")
		addpref(dest_slot_prefix .. "_n_1sg", x1sg, source_slot_prefix  .. "_n_sg")
		addpref(dest_slot_prefix .. "_m_2sg", x2sg, source_slot_prefix  .. "_m_sg")
		addpref(dest_slot_prefix .. "_f_2sg", x2sg, source_slot_prefix  .. "_f_sg")
		addpref(dest_slot_prefix .. "_n_2sg", x2sg, source_slot_prefix  .. "_n_sg")
		addpref(dest_slot_prefix .. "_m_3sg", x3sg, source_slot_prefix  .. "_m_sg")
		addpref(dest_slot_prefix .. "_f_3sg", x3sg, source_slot_prefix  .. "_f_sg")
		addpref(dest_slot_prefix .. "_n_3sg", x3sg, source_slot_prefix  .. "_n_sg")
		addpref(dest_slot_prefix .. "_1pl", x1pl, source_slot_prefix  .. "_pl")
		addpref(dest_slot_prefix .. "_2pl", x2pl, source_slot_prefix  .. "_pl")
		addpref(dest_slot_prefix .. "_3pl", x3pl, source_slot_prefix  .. "_pl")
	end

	-- Identical to ngen_prefix_to_gen() but adds suffix text (possibly differing by person/number)
	-- to a gendered source slot row instead of adding prefix text.
	local function ngen_suffix_to_gen(dest_slot_prefix, source_slot_prefix, suffixtext)
		local x1sg, x2sg, x3sg, x1pl, x2pl, x3pl = unpack(suffixtext)
		addsuf(dest_slot_prefix .. "_m_1sg", x1sg, source_slot_prefix  .. "_m_sg")
		addsuf(dest_slot_prefix .. "_f_1sg", x1sg, source_slot_prefix  .. "_f_sg")
		addsuf(dest_slot_prefix .. "_n_1sg", x1sg, source_slot_prefix  .. "_n_sg")
		addsuf(dest_slot_prefix .. "_m_2sg", x2sg, source_slot_prefix  .. "_m_sg")
		addsuf(dest_slot_prefix .. "_f_2sg", x2sg, source_slot_prefix  .. "_f_sg")
		addsuf(dest_slot_prefix .. "_n_2sg", x2sg, source_slot_prefix  .. "_n_sg")
		addsuf(dest_slot_prefix .. "_m_3sg", x3sg, source_slot_prefix  .. "_m_sg")
		addsuf(dest_slot_prefix .. "_f_3sg", x3sg, source_slot_prefix  .. "_f_sg")
		addsuf(dest_slot_prefix .. "_n_3sg", x3sg, source_slot_prefix  .. "_n_sg")
		addsuf(dest_slot_prefix .. "_1pl", x1pl, source_slot_prefix  .. "_pl")
		addsuf(dest_slot_prefix .. "_2pl", x2pl, source_slot_prefix  .. "_pl")
		addsuf(dest_slot_prefix .. "_3pl", x3pl, source_slot_prefix  .. "_pl")
	end

	-- Add gendered PREFIXTEXT to the forms in the non-gendered source slot row identified by
	-- SOURCE_SLOT_PREFIX and store the results in the (gendered) destination slot row identified
	-- by DEST_SLOT_PREFIX. See ngen_prefix_to_ngen() for definition of "slot row". Here,
	-- "gendered PREFIXTEXT" is a 12-element table corresponding to m_1sg, f_1sg, n_1sg,
	-- m_2sg, f_2sg, n_2sg, m_3sg, f_3sg, n_3sg, 1pl, 2pl, 3pl respectively, where each element
	-- of the table is either a string or a table of alternants, each of which is a string.
	local function gen_prefix_to_ngen(dest_slot_prefix, prefixtext, source_slot_prefix)
		local m_1sg, f_1sg, n_1sg, m_2sg, f_2sg, n_2sg, m_3sg, f_3sg, n_3sg, x1pl, x2pl, x3pl = unpack(prefixtext)
		addpref(dest_slot_prefix .. "_m_1sg", m_1sg, source_slot_prefix  .. "_1sg")
		addpref(dest_slot_prefix .. "_f_1sg", f_1sg, source_slot_prefix  .. "_1sg")
		addpref(dest_slot_prefix .. "_n_1sg", n_1sg, source_slot_prefix  .. "_1sg")
		addpref(dest_slot_prefix .. "_m_2sg", m_2sg, source_slot_prefix  .. "_2sg")
		addpref(dest_slot_prefix .. "_f_2sg", f_2sg, source_slot_prefix  .. "_2sg")
		addpref(dest_slot_prefix .. "_n_2sg", n_2sg, source_slot_prefix  .. "_2sg")
		addpref(dest_slot_prefix .. "_m_3sg", m_3sg, source_slot_prefix  .. "_3sg")
		addpref(dest_slot_prefix .. "_f_3sg", f_3sg, source_slot_prefix  .. "_3sg")
		addpref(dest_slot_prefix .. "_n_3sg", n_3sg, source_slot_prefix  .. "_3sg")
		addpref(dest_slot_prefix .. "_1pl", x1pl, source_slot_prefix  .. "_1pl")
		addpref(dest_slot_prefix .. "_2pl", x2pl, source_slot_prefix  .. "_2pl")
		addpref(dest_slot_prefix .. "_3pl", x3pl, source_slot_prefix  .. "_3pl")
	end

	-- Add gendered PREFIXTEXT to the forms in the gendered source slot row identified by
	-- SOURCE_SLOT_PREFIX and store the results in the (gendered) destination slot row identified
	-- by DEST_SLOT_PREFIX. See ngen_prefix_to_ngen() for definition of "slot row",
	-- gen_prefix_to_ngen() for the definition of "gendered PREFIXTEXT" and ngen_prefix_to_gen()
	-- for the definition of "gendered source slot row".
	local function gen_prefix_to_gen(dest_slot_prefix, prefixtext, source_slot_prefix)
		local m_1sg, f_1sg, n_1sg, m_2sg, f_2sg, n_2sg, m_3sg, f_3sg, n_3sg, x1pl, x2pl, x3pl = unpack(prefixtext)
		addpref(dest_slot_prefix .. "_m_1sg", m_1sg, source_slot_prefix  .. "_m_sg")
		addpref(dest_slot_prefix .. "_f_1sg", f_1sg, source_slot_prefix  .. "_f_sg")
		addpref(dest_slot_prefix .. "_n_1sg", n_1sg, source_slot_prefix  .. "_n_sg")
		addpref(dest_slot_prefix .. "_m_2sg", m_2sg, source_slot_prefix  .. "_m_sg")
		addpref(dest_slot_prefix .. "_f_2sg", f_2sg, source_slot_prefix  .. "_f_sg")
		addpref(dest_slot_prefix .. "_n_2sg", n_2sg, source_slot_prefix  .. "_n_sg")
		addpref(dest_slot_prefix .. "_m_3sg", m_3sg, source_slot_prefix  .. "_m_sg")
		addpref(dest_slot_prefix .. "_f_3sg", f_3sg, source_slot_prefix  .. "_f_sg")
		addpref(dest_slot_prefix .. "_n_3sg", n_3sg, source_slot_prefix  .. "_n_sg")
		addpref(dest_slot_prefix .. "_1pl", x1pl, source_slot_prefix  .. "_pl")
		addpref(dest_slot_prefix .. "_2pl", x2pl, source_slot_prefix  .. "_pl")
		addpref(dest_slot_prefix .. "_3pl", x3pl, source_slot_prefix  .. "_pl")
	end

	-- indicative
	local futip_prefixtext = concat_tables(shta_impf, "[[да]]")
	ngen_prefix_to_ngen("fut_pos", "[[ще]]", "pres")
	ngen_prefix_to_ngen("fut_neg", "[[ня́ма]] [[да]]", "pres")
	ngen_prefix_to_ngen("futip_pos", futip_prefixtext, "pres")
	ngen_prefix_to_ngen("futip_neg", "[[ня́маше]] [[да]]", "pres")
	ngen_suffix_to_gen("prespf", "paap_ind", sam_pres)
	ngen_prefix_to_gen("pastpf", sam_impf, "paap_ind")
	ngen_prefix_to_gen("futpf_pos", concat_tables("[[ще]]", sam_pres), "paap_ind")
	ngen_prefix_to_gen("futpf_neg", concat_tables("[[няма]] [[да]]", sam_pres), "paap_ind")
	ngen_prefix_to_gen("futpfip_pos", concat_tables(futip_prefixtext, sam_pres), "paap_ind")
	ngen_prefix_to_gen("futpfip_neg", concat_tables("[[ня́маше]] [[да]]", sam_pres), "paap_ind")

	-- renarrative
	ngen_suffix_to_gen("ren_pres", "paip", sam_pres_no3)
	ngen_suffix_to_gen("ren_aor", "paap_ind", sam_pres_no3)
	local ren_fut_pos = gender_cross_person(
		function(gender, person) return concn(shta_paip[gender], sam_pres_no3[person], "[[да]]") end
	)
	gen_prefix_to_ngen("ren_fut_pos", ren_fut_pos, "pres")
	ngen_prefix_to_ngen("ren_fut_neg", "[[ня́мало]] [[да]]", "pres")
	local ren_prespf = gender_cross_person(
		function(gender, person) return concat(sam_paip[gender], sam_pres_no3[person]) end
	)
	gen_prefix_to_gen("ren_prespf", ren_prespf, "paap_ind")
	local ren_futpf_pos = gender_cross_person(
		function(gender, person, index) return concat(ren_fut_pos[index], sam_pres[person]) end
	)
	gen_prefix_to_gen("ren_futpf_pos", ren_futpf_pos, "paap_ind")
	ngen_prefix_to_gen("ren_futpf_neg", concat_tables("[[ня́мало]] [[да]]", sam_pres), "paap_ind")

	-- dubitative
	gen_prefix_to_gen("dub_pres", ren_prespf, "paip")
	gen_prefix_to_gen("dub_aor", ren_prespf, "paap_ind")
	local dub_fut_pos = gender_cross_person(
		function(gender, person) return concn(shta_paip[gender], sam_pres_no3[person], sam_paip[gender], "[[да]]") end
	)
	gen_prefix_to_ngen("dub_fut_pos", dub_fut_pos, "pres")
	ngen_prefix_to_ngen("dub_fut_neg", "[[ня́мало]] [[било́]] [[да]]", "pres")
	-- no dubitative present and past perfect
	local dub_futpf_pos = gender_cross_person(
		function(gender, person, index) return concat(dub_fut_pos[index], sam_pres[person]) end
	)
	gen_prefix_to_gen("dub_futpf_pos", dub_futpf_pos, "paap_ind")
	ngen_prefix_to_gen("dub_futpf_neg", concat_tables("[[ня́мало]] [[било́]] [[да]]", sam_pres), "paap_ind")

	-- conclusive
	ngen_suffix_to_gen("conc_pres", "paip", sam_pres)
	ngen_suffix_to_gen("conc_aor", "paap_ind", sam_pres)
	local conc_fut_pos = gender_cross_person(
		function(gender, person) return concn(shta_paip[gender], sam_pres[person], "[[да]]") end
	)
	gen_prefix_to_ngen("conc_fut_pos", conc_fut_pos, "pres")
	ngen_prefix_to_ngen("conc_fut_neg", "[[ня́мало]] [[е]] [[да]]", "pres")
	local conc_prespf = gender_cross_person(
		function(gender, person) return concat(sam_paip[gender], sam_pres[person]) end
	)
	gen_prefix_to_gen("conc_prespf", conc_prespf, "paap_ind")
	local conc_futpf_pos = gender_cross_person(
		function(gender, person, index) return concat(conc_fut_pos[index], sam_pres[person]) end
	)
	gen_prefix_to_gen("conc_futpf_pos", conc_futpf_pos, "paap_ind")
	ngen_prefix_to_gen("conc_futpf_neg", concat_tables("[[ня́мало]] [[е]] [[да]]", sam_pres), "paap_ind")

	-- conditional
	ngen_prefix_to_gen("cond", bada_aor1, "paap_ind")
end


export.table_spec_compound_full = [=[
! rowspan="2" style="background:#c0cfe4" | future
! colspan="2" style="background:#c0cfe4" | pos.
| {fut_pos_1sg}
| {fut_pos_2sg}
| {fut_pos_3sg}
| {fut_pos_1pl}
| {fut_pos_2pl}
| {fut_pos_3pl}
|-
! colspan="2" style="background:#c0cfe4" | neg.
| {fut_neg_1sg}
| {fut_neg_2sg}
| {fut_neg_3sg}
| {fut_neg_1pl}
| {fut_neg_2pl}
| {fut_neg_3pl}
|-
! rowspan= "2" style="background:#c0cfe4" | future in the past
! colspan="2" style="background:#c0cfe4" | pos.
| {futip_pos_1sg}
| {futip_pos_2sg}
| {futip_pos_3sg}
| {futip_pos_1pl}
| {futip_pos_2pl}
| {futip_pos_3pl}
|-
! colspan="2" style="background:#c0cfe4" | neg.
| {futip_neg_1sg}
| {futip_neg_2sg}
| {futip_neg_3sg}
| {futip_neg_1pl}
| {futip_neg_2pl}
| {futip_neg_3pl}
|-
! rowspan="3" style="background:#c0cfe4" | present perfect
! colspan="2" style="background:#c0cfe4" | masc.
| {prespf_m_1sg}
| {prespf_m_2sg}
| {prespf_m_3sg}
|rowspan="3"| {prespf_1pl}
|rowspan="3"| {prespf_2pl}
|rowspan="3"| {prespf_3pl}
|-
! colspan="2" style="background:#c0cfe4" | fem.
| {prespf_f_1sg}
| {prespf_f_2sg}
| {prespf_f_3sg}
|-
! colspan="2" style="background:#c0cfe4" | neut.
| {prespf_n_1sg}
| {prespf_n_2sg}
| {prespf_n_3sg}
|-
! rowspan="3" style="background:#c0cfe4" | past perfect
! colspan="2" style="background:#c0cfe4" | masc.
| {pastpf_m_1sg}
| {pastpf_m_2sg}
| {pastpf_m_3sg}
|rowspan="3"| {pastpf_1pl}
|rowspan="3"| {pastpf_2pl}
|rowspan="3"| {pastpf_3pl}
|-
! colspan="2" style="background:#c0cfe4" | fem.
| {pastpf_f_1sg}
| {pastpf_f_2sg}
| {pastpf_f_3sg}
|-
! colspan="2" style="background:#c0cfe4" | neut.
| {pastpf_n_1sg}
| {pastpf_n_2sg}
| {pastpf_n_3sg}
|-
! rowspan="6" style="background:#c0cfe4" | future perfect
! rowspan="3" style="background:#c0cfe4" | pos.
! style="background:#c0cfe4" | masc.
| {futpf_pos_m_1sg}
| {futpf_pos_m_2sg}
| {futpf_pos_m_3sg}
|rowspan="3"| {futpf_pos_1pl}
|rowspan="3"| {futpf_pos_2pl}
|rowspan="3"| {futpf_pos_3pl}
|-
! style="background:#c0cfe4" | fem.
| {futpf_pos_f_1sg}
| {futpf_pos_f_2sg}
| {futpf_pos_f_3sg}
|-
! style="background:#c0cfe4" | neut.
| {futpf_pos_n_1sg}
| {futpf_pos_n_2sg}
| {futpf_pos_n_3sg}
|-
! rowspan="3" style="background:#c0cfe4" | neg.
! style="background:#c0cfe4" | masc.
| {futpf_neg_m_1sg}
| {futpf_neg_m_2sg}
| {futpf_neg_m_3sg}
|rowspan="3"| {futpf_neg_1pl}
|rowspan="3"| {futpf_neg_2pl}
|rowspan="3"| {futpf_neg_3pl}
|-
! style="background:#c0cfe4" | fem.
| {futpf_neg_f_1sg}
| {futpf_neg_f_2sg}
| {futpf_neg_f_3sg}
|-
! style="background:#c0cfe4" | neut.
| {futpf_neg_n_1sg}
| {futpf_neg_n_2sg}
| {futpf_neg_n_3sg}
|-
! rowspan="6" style="background:#c0cfe4" | future perfect in the past
! rowspan="3" style="background:#c0cfe4" | pos.
! style="background:#c0cfe4" | masc.
| {futpfip_pos_m_1sg}
| {futpfip_pos_m_2sg}
| {futpfip_pos_m_3sg}
|rowspan="3"| {futpfip_pos_1pl}
|rowspan="3"| {futpfip_pos_2pl}
|rowspan="3"| {futpfip_pos_3pl}
|-
! style="background:#c0cfe4" | fem.
| {futpfip_pos_f_1sg}
| {futpfip_pos_f_2sg}
| {futpfip_pos_f_3sg}
|-
! style="background:#c0cfe4" | neut.
| {futpfip_pos_n_1sg}
| {futpfip_pos_n_2sg}
| {futpfip_pos_n_3sg}
|-
! rowspan="3" style="background:#c0cfe4" | neg.
! style="background:#c0cfe4" | masc.
| {futpfip_neg_m_1sg}
| {futpfip_neg_m_2sg}
| {futpfip_neg_m_3sg}
|rowspan="3"| {futpfip_neg_1pl}
|rowspan="3"| {futpfip_neg_2pl}
|rowspan="3"| {futpfip_neg_3pl}
|-
! style="background:#c0cfe4" | fem.
| {futpfip_neg_f_1sg}
| {futpfip_neg_f_2sg}
| {futpfip_neg_f_3sg}
|-
! style="background:#c0cfe4" | neut.
| {futpfip_neg_n_1sg}
| {futpfip_neg_n_2sg}
| {futpfip_neg_n_3sg}
|-
! style="background:#c0e4c0" colspan="3" | renarrative
! style="background:#c0e4c0" | аз
! style="background:#c0e4c0" | ти
! style="background:#c0e4c0" | той/тя/то
! style="background:#c0e4c0" | ние
! style="background:#c0e4c0" | вие
! style="background:#c0e4c0" | те
|-
! rowspan="3" style="background:#c0e4c0" | present and imperfect
! colspan="2" style="background:#c0e4c0" | masc.
| {ren_pres_m_1sg}
| {ren_pres_m_2sg}
| {ren_pres_m_3sg}
|rowspan="3"| {ren_pres_1pl}
|rowspan="3"| {ren_pres_2pl}
|rowspan="3"| {ren_pres_3pl}
|-
! colspan="2" style="background:#c0e4c0" | fem.
| {ren_pres_f_1sg}
| {ren_pres_f_2sg}
| {ren_pres_f_3sg}
|-
! colspan="2" style="background:#c0e4c0" | neut.
| {ren_pres_n_1sg}
| {ren_pres_n_2sg}
| {ren_pres_n_3sg}
|-
! rowspan="3" style="background:#c0e4c0" | aorist
! colspan="2" style="background:#c0e4c0" | masc.
| {ren_aor_m_1sg}
| {ren_aor_m_2sg}
| {ren_aor_m_3sg}
|rowspan="3"| {ren_aor_1pl}
|rowspan="3"| {ren_aor_2pl}
|rowspan="3"| {ren_aor_3pl}
|-
! colspan="2" style="background:#c0e4c0" | fem.
| {ren_aor_f_1sg}
| {ren_aor_f_2sg}
| {ren_aor_f_3sg}
|-
! colspan="2" style="background:#c0e4c0" | neut.
| {ren_aor_n_1sg}
| {ren_aor_n_2sg}
| {ren_aor_n_3sg}
|-
! rowspan="4" style="background:#c0e4c0" | future and future in the past
! rowspan="3" style="background:#c0e4c0" | pos.
! style="background:#c0e4c0" | masc.
| {ren_fut_pos_m_1sg}
| {ren_fut_pos_m_2sg}
| {ren_fut_pos_m_3sg}
|rowspan="3"| {ren_fut_pos_1pl}
|rowspan="3"| {ren_fut_pos_2pl}
|rowspan="3"| {ren_fut_pos_3pl}
|-
! style="background:#c0e4c0" | fem.
| {ren_fut_pos_f_1sg}
| {ren_fut_pos_f_2sg}
| {ren_fut_pos_f_3sg}
|-
! style="background:#c0e4c0" | neut.
| {ren_fut_pos_n_1sg}
| {ren_fut_pos_n_2sg}
| {ren_fut_pos_n_3sg}
|-
! colspan="2" style="background:#c0e4c0" | neg.
| {ren_fut_neg_1sg}
| {ren_fut_neg_2sg}
| {ren_fut_neg_3sg}
| {ren_fut_neg_1pl}
| {ren_fut_neg_2pl}
| {ren_fut_neg_3pl}
|-
! rowspan="3" style="background:#c0e4c0" | present and past perfect
! colspan="2" style="background:#c0e4c0" | masc.
| {ren_prespf_m_1sg}
| {ren_prespf_m_2sg}
| {ren_prespf_m_3sg}
|rowspan="3"| {ren_prespf_1pl}
|rowspan="3"| {ren_prespf_2pl}
|rowspan="3"| {ren_prespf_3pl}
|-
! colspan="2" style="background:#c0e4c0" | fem.
| {ren_prespf_f_1sg}
| {ren_prespf_f_2sg}
| {ren_prespf_f_3sg}
|-
! colspan="2" style="background:#c0e4c0" | neut.
| {ren_prespf_n_1sg}
| {ren_prespf_n_2sg}
| {ren_prespf_n_3sg}
|-
! rowspan="6" style="background:#c0e4c0" | future perfect and future perfect in the past
! rowspan="3" style="background:#c0e4c0" | pos.
! style="background:#c0e4c0" | masc.
| {ren_futpf_pos_m_1sg}
| {ren_futpf_pos_m_2sg}
| {ren_futpf_pos_m_3sg}
|rowspan="3"| {ren_futpf_pos_1pl}
|rowspan="3"| {ren_futpf_pos_2pl}
|rowspan="3"| {ren_futpf_pos_3pl}
|-
! style="background:#c0e4c0" | fem.
| {ren_futpf_pos_f_1sg}
| {ren_futpf_pos_f_2sg}
| {ren_futpf_pos_f_3sg}
|-
! style="background:#c0e4c0" | neut.
| {ren_futpf_pos_n_1sg}
| {ren_futpf_pos_n_2sg}
| {ren_futpf_pos_n_3sg}
|-
! rowspan="3" style="background:#c0e4c0" | neg.
! style="background:#c0e4c0" | masc.
| {ren_futpf_neg_m_1sg}
| {ren_futpf_neg_m_2sg}
| {ren_futpf_neg_m_3sg}
|rowspan="3"| {ren_futpf_neg_1pl}
|rowspan="3"| {ren_futpf_neg_2pl}
|rowspan="3"| {ren_futpf_neg_3pl}
|-
! style="background:#c0e4c0" | fem.
| {ren_futpf_neg_f_1sg}
| {ren_futpf_neg_f_2sg}
| {ren_futpf_neg_f_3sg}
|-
! style="background:#c0e4c0" | neut.
| {ren_futpf_neg_n_1sg}
| {ren_futpf_neg_n_2sg}
| {ren_futpf_neg_n_3sg}
|-
! style="background:#f0e68c" colspan="3" | dubitative
! style="background:#f0e68c" | аз
! style="background:#f0e68c" | ти
! style="background:#f0e68c" | той/тя/то
! style="background:#f0e68c" | ние
! style="background:#f0e68c" | вие
! style="background:#f0e68c" | те
|-
! rowspan="3" style="background:#f0e68c" | present and imperfect
! colspan="2" style="background:#f0e68c" | masc.
| {dub_pres_m_1sg}
| {dub_pres_m_2sg}
| {dub_pres_m_3sg}
|rowspan="3"| {dub_pres_1pl}
|rowspan="3"| {dub_pres_2pl}
|rowspan="3"| {dub_pres_3pl}
|-
! colspan="2" style="background:#f0e68c" | fem.
| {dub_pres_f_1sg}
| {dub_pres_f_2sg}
| {dub_pres_f_3sg}
|-
! colspan="2" style="background:#f0e68c" | neut.
| {dub_pres_n_1sg}
| {dub_pres_n_2sg}
| {dub_pres_n_3sg}
|-
! rowspan="3" style="background:#f0e68c" | aorist
! colspan="2" style="background:#f0e68c" | masc.
| {dub_aor_m_1sg}
| {dub_aor_m_2sg}
| {dub_aor_m_3sg}
|rowspan="3"| {dub_aor_1pl}
|rowspan="3"| {dub_aor_2pl}
|rowspan="3"| {dub_aor_3pl}
|-
! colspan="2" style="background:#f0e68c" | fem.
| {dub_aor_f_1sg}
| {dub_aor_f_2sg}
| {dub_aor_f_3sg}
|-
! colspan="2" style="background:#f0e68c" | neut.
| {dub_aor_n_1sg}
| {dub_aor_n_2sg}
| {dub_aor_n_3sg}
|-
! rowspan="4" style="background:#f0e68c" | future and future in the past
! rowspan="3" style="background:#f0e68c" | pos.
! style="background:#f0e68c" | masc.
| {dub_fut_pos_m_1sg}
| {dub_fut_pos_m_2sg}
| {dub_fut_pos_m_3sg}
|rowspan="3"| {dub_fut_pos_1pl}
|rowspan="3"| {dub_fut_pos_2pl}
|rowspan="3"| {dub_fut_pos_3pl}
|-
! style="background:#f0e68c" | fem.
| {dub_fut_pos_f_1sg}
| {dub_fut_pos_f_2sg}
| {dub_fut_pos_f_3sg}
|-
! style="background:#f0e68c" | neut.
| {dub_fut_pos_n_1sg}
| {dub_fut_pos_n_2sg}
| {dub_fut_pos_n_3sg}
|-
! colspan="2" style="background:#f0e68c" | neg.
| {dub_fut_neg_1sg}
| {dub_fut_neg_2sg}
| {dub_fut_neg_3sg}
| {dub_fut_neg_1pl}
| {dub_fut_neg_2pl}
| {dub_fut_neg_3pl}
|-
! colspan="3" style="background:#f0e68c" | present and past perfect
| colspan="6" |<center>''none''</center>
|-
! rowspan="6" style="background:#f0e68c" | future perfect and future perfect in the past
! rowspan="3" style="background:#f0e68c" | pos.
! style="background:#f0e68c" | masc.
| {dub_futpf_pos_m_1sg}
| {dub_futpf_pos_m_2sg}
| {dub_futpf_pos_m_3sg}
|rowspan="3"| {dub_futpf_pos_1pl}
|rowspan="3"| {dub_futpf_pos_2pl}
|rowspan="3"| {dub_futpf_pos_3pl}
|-
! style="background:#f0e68c" | fem.
| {dub_futpf_pos_f_1sg}
| {dub_futpf_pos_f_2sg}
| {dub_futpf_pos_f_3sg}
|-
! style="background:#f0e68c" | neut.
| {dub_futpf_pos_n_1sg}
| {dub_futpf_pos_n_2sg}
| {dub_futpf_pos_n_3sg}
|-
! rowspan="3" style="background:#f0e68c" | neg.
! style="background:#f0e68c" | masc.
| {dub_futpf_neg_m_1sg}
| {dub_futpf_neg_m_2sg}
| {dub_futpf_neg_m_3sg}
|rowspan="3"| {dub_futpf_neg_1pl}
|rowspan="3"| {dub_futpf_neg_2pl}
|rowspan="3"| {dub_futpf_neg_3pl}
|-
! style="background:#f0e68c" | fem.
| {dub_futpf_neg_f_1sg}
| {dub_futpf_neg_f_2sg}
| {dub_futpf_neg_f_3sg}
|-
! style="background:#f0e68c" | neut.
| {dub_futpf_neg_n_1sg}
| {dub_futpf_neg_n_2sg}
| {dub_futpf_neg_n_3sg}
|-
! style="background:#9be1ff" colspan="3" | conclusive
! style="background:#9be1ff" | аз
! style="background:#9be1ff" | ти
! style="background:#9be1ff" | той/тя/то
! style="background:#9be1ff" | ние
! style="background:#9be1ff" | вие
! style="background:#9be1ff" | те
|-
! rowspan="3" style="background:#9be1ff" | present and imperfect
! colspan="2" style="background:#9be1ff" | masc.
| {conc_pres_m_1sg}
| {conc_pres_m_2sg}
| {conc_pres_m_3sg}
|rowspan="3"| {conc_pres_1pl}
|rowspan="3"| {conc_pres_2pl}
|rowspan="3"| {conc_pres_3pl}
|-
! colspan="2" style="background:#9be1ff" | fem.
| {conc_pres_f_1sg}
| {conc_pres_f_2sg}
| {conc_pres_f_3sg}
|-
! colspan="2" style="background:#9be1ff" | neut.
| {conc_pres_n_1sg}
| {conc_pres_n_2sg}
| {conc_pres_n_3sg}
|-
! rowspan="3" style="background:#9be1ff" | aorist
! colspan="2" style="background:#9be1ff" | masc.
| {conc_aor_m_1sg}
| {conc_aor_m_2sg}
| {conc_aor_m_3sg}
|rowspan="3"| {conc_aor_1pl}
|rowspan="3"| {conc_aor_2pl}
|rowspan="3"| {conc_aor_3pl}
|-
! colspan="2" style="background:#9be1ff" | fem.
| {conc_aor_f_1sg}
| {conc_aor_f_2sg}
| {conc_aor_f_3sg}
|-
! colspan="2" style="background:#9be1ff" | neut.
| {conc_aor_n_1sg}
| {conc_aor_n_2sg}
| {conc_aor_n_3sg}
|-
! rowspan="4" style="background:#9be1ff" | future and future in the past
! rowspan="3" style="background:#9be1ff" | pos.
! style="background:#9be1ff" | masc.
| {conc_fut_pos_m_1sg}
| {conc_fut_pos_m_2sg}
| {conc_fut_pos_m_3sg}
|rowspan="3"| {conc_fut_pos_1pl}
|rowspan="3"| {conc_fut_pos_2pl}
|rowspan="3"| {conc_fut_pos_3pl}
|-
! style="background:#9be1ff" | fem.
| {conc_fut_pos_f_1sg}
| {conc_fut_pos_f_2sg}
| {conc_fut_pos_f_3sg}
|-
! style="background:#9be1ff" | neut.
| {conc_fut_pos_n_1sg}
| {conc_fut_pos_n_2sg}
| {conc_fut_pos_n_3sg}
|-
! colspan="2" style="background:#9be1ff" | neg.
| {conc_fut_neg_1sg}
| {conc_fut_neg_2sg}
| {conc_fut_neg_3sg}
| {conc_fut_neg_1pl}
| {conc_fut_neg_2pl}
| {conc_fut_neg_3pl}
|-
! rowspan="3" style="background:#9be1ff" | present and past perfect
! colspan="2" style="background:#9be1ff" | masc.
| {conc_prespf_m_1sg}
| {conc_prespf_m_2sg}
| {conc_prespf_m_3sg}
|rowspan="3"| {conc_prespf_1pl}
|rowspan="3"| {conc_prespf_2pl}
|rowspan="3"| {conc_prespf_3pl}
|-
! colspan="2" style="background:#9be1ff" | fem.
| {conc_prespf_f_1sg}
| {conc_prespf_f_2sg}
| {conc_prespf_f_3sg}
|-
! colspan="2" style="background:#9be1ff" | neut.
| {conc_prespf_n_1sg}
| {conc_prespf_n_2sg}
| {conc_prespf_n_3sg}
|-
! rowspan="6" style="background:#9be1ff" | future perfect and future perfect in the past
! rowspan="3" style="background:#9be1ff" | pos.
! style="background:#9be1ff" | masc.
| {conc_futpf_pos_m_1sg}
| {conc_futpf_pos_m_2sg}
| {conc_futpf_pos_m_3sg}
|rowspan="3"| {conc_futpf_pos_1pl}
|rowspan="3"| {conc_futpf_pos_2pl}
|rowspan="3"| {conc_futpf_pos_3pl}
|-
! style="background:#9be1ff" | fem.
| {conc_futpf_pos_f_1sg}
| {conc_futpf_pos_f_2sg}
| {conc_futpf_pos_f_3sg}
|-
! style="background:#9be1ff" | neut.
| {conc_futpf_pos_n_1sg}
| {conc_futpf_pos_n_2sg}
| {conc_futpf_pos_n_3sg}
|-
! rowspan="3" style="background:#9be1ff" | neg.
! style="background:#9be1ff" | masc.
| {conc_futpf_neg_m_1sg}
| {conc_futpf_neg_m_2sg}
| {conc_futpf_neg_m_3sg}
|rowspan="3"| {conc_futpf_neg_1pl}
|rowspan="3"| {conc_futpf_neg_2pl}
|rowspan="3"| {conc_futpf_neg_3pl}
|-
! style="background:#9be1ff" | fem.
| {conc_futpf_neg_f_1sg}
| {conc_futpf_neg_f_2sg}
| {conc_futpf_neg_f_3sg}
|-
! style="background:#9be1ff" | neut.
| {conc_futpf_neg_n_1sg}
| {conc_futpf_neg_n_2sg}
| {conc_futpf_neg_n_3sg}
|-
! colspan="3" style="background:#f2b6c3" | conditional
! style="background:#f2b6c3" | аз
! style="background:#f2b6c3" | ти
! style="background:#f2b6c3" | той/тя/то
! style="background:#f2b6c3" | ние
! style="background:#f2b6c3" | вие
! style="background:#f2b6c3" | те
|-
! colspan="3" style="background:#f2b6c3" | masculine
| {cond_m_1sg}
| {cond_m_2sg}
| {cond_m_3sg}
|rowspan="3"| {cond_1pl}
|rowspan="3"| {cond_2pl}
|rowspan="3"| {cond_3pl}
|-
! colspan="3" style="background:#f2b6c3" | feminine
| {cond_f_1sg}
| {cond_f_2sg}
| {cond_f_3sg}
|-
! colspan="3" style="background:#f2b6c3" | neuter
| {cond_n_1sg}
| {cond_n_2sg}
| {cond_n_3sg}
|-
]=]


return export
