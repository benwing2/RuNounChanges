local export = {}

local ut = require("Module:utils")


local function convert(data, conv)
	local col = {}
	local row = {}
	local colors = {}
	local marked = {}
	local slots = {}
	local function add(i,j)
		local col = col[i][j]
		local row = row[i][j]
		local color = colors[i][j]
		if col==0 or row==0 then
			return ""
		end
		local entry = data.finish_show_form(data, slots[i][j])
		if col==1 then
			if row==1 then
				return '\n|style="background:#' .. color .. ';" align=center | ' .. entry
			else
				return '\n|style="background:#' .. color .. ';" align=center rowspan=' .. row .. ' | ' .. entry
			end
		else
			if row==1 then
				return '\n|style="background:#' .. color .. ';" align=center colspan=' .. col .. ' | ' .. entry
			else
				return '\n|style="background:#' .. color .. ';" align=center colspan=' .. col .. ' rowspan=' .. row .. ' | ' .. entry
			end
		end
	end
	
	for i=1,#conv do
		col[i] = {}
		row[i] = {}
		colors[i] = {}
		marked[i] = {}
		slots[i] = {}
		for j=1,#conv[i] do
			col[i][j] = 1
			row[i][j] = 1
			colors[i][j] = "F8F8FF"
			marked[i][j] = false
			slots[i][j] = {conv[i][j]}
		end
	end

	-- Return true if the contents of the two slots are equal in every
	-- way. This means the forms are the same, the footnote text is the
	-- same, and the accelerator lemmas are the same. We need to compare
	-- the accelerator lemmas because in some cases different slots have
	-- different lemmas (e.g. when noneut=1 is set, the masculine slots
	-- will have the masculine lemma but the feminine slots will have the
	-- feminine lemma).
	local function slots_equal(slot1, slo2)
		return ut.equals(data.forms[slot1], data.forms[slot2]) and
			ut.equals(data.notetext[slot1], data.notetext[slot2])
			(data.accel[slot1] and data.accel[slot1].lemma or nil) ==
			(data.accel[slot2] and data.accel[slot2].lemma or nil)
	end

	--merge rows
	for i=1,#conv do for j=1,#conv[i] do
		if col[i][j] ~= 0 then
			for k=j+1,#conv[i] do
				local slotij = conv[i][j]
				local slotik = conv[i][k]
				if not slots_equal(slotij, slotik) then
					break
				end
				col[i][j] = col[i][j] + 1
				col[i][k] = 0
				row[i][k] = 0
				for _, slot in ipairs(slots[i][k]) do
					table.insert(slots[i][j], slot)
				end
				slots[i][k] = nil
			end
		end
	end end
	
	--merge columns
	for i=1,#conv do
		for j=1,#conv[i] do
			if row[i][j] ~= 0 then
				for k=i+1,#conv do
					local slotij = conv[i][j]
					local slotkj = conv[k][j]
					if not slots_equal(slotij, slotkj) then
						break
					end
					row[i][j] = row[i][j] + 1
					row[k][j] = 0
					for _, slot in ipairs(slots[k][j]) do
						table.insert(slots[i][j], slot)
					end
					slots[k][j] = nil
				end
			end
		end
	end
	
	--final
	for i=1,#data do
		for j=1,#data[i] do
			data[i][j] = add(i,j)
		end
		data[i] = table.concat(data[i])
	end
	return data
end

local function make_table_mfn_pl(data, noneut)
	local conv = {
		{"nom_pl_m"},
		{"gen_pl_m"},
		{"dat_pl_m"},
		{"acc_pl_m"},
		{"abl_pl_m"},
		{"voc_pl_m"},
	}
	conv = convert(data, conv)
	
	local output = data.title
	output = output .. '\n{| class="prettytable inflection-table"'
	output = output .. '\n!style="background:#549EA0; font-style:italic;"| Number'
	output = output .. '\n!style="background:#549EA0; font-style:italic;"| Plural'
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| Case / Gender'
	output = output .. '\n!style="background:#40E0D0;"| ' .. (noneut and 'Masc./Fem.' or 'Masc./Fem./Neut.')
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[nominative case|Nominative]]'
	output = output .. conv[1]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[genitive case|Genitive]]'
	output = output .. conv[2]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[dative case|Dative]]'
	output = output .. conv[3]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[accusative case|Accusative]]'
	output = output .. conv[4]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[ablative case|Ablative]]'
	output = output .. conv[5]
	output = output .. '\n|-'
	if data.voc then
		output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[vocative case|Vocative]]'
		output = output .. conv[6]
	end
	output = output .. '\n|}'
	output = output .. '\n' .. data.footnote
	
	return output
end

local function make_table_mfn_sg(data, noneut)
	local conv = {
		{"nom_sg_m"},
		{"gen_sg_m"},
		{"dat_sg_m"},
		{"acc_sg_m"},
		{"abl_sg_m"},
		{"voc_sg_m"},
	}
	conv = convert(data, conv)
	
	local output = data.title
	output = output .. '\n{| class="prettytable inflection-table"'
	output = output .. '\n!style="background:#549EA0; font-style:italic;"| Number'
	output = output .. '\n!style="background:#549EA0; font-style:italic;"| Singular'
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| Case / Gender'
	output = output .. '\n!style="background:#40E0D0;"| ' .. (noneut and 'Masc./Fem.' or 'Masc./Fem./Neut.')
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[nominative case|Nominative]]'
	output = output .. conv[1]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[genitive case|Genitive]]'
	output = output .. conv[2]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[dative case|Dative]]'
	output = output .. conv[3]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[accusative case|Accusative]]'
	output = output .. conv[4]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[ablative case|Ablative]]'
	output = output .. conv[5]
	output = output .. '\n|-'
	if data.voc then
		output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[vocative case|Vocative]]'
		output = output .. conv[6]
	end
	output = output .. '\n|}'
	output = output .. '\n' .. data.footnote
	
	return output
end

local function make_table_mf_and_n_pl(data)
	local conv = {
		{"nom_pl_m", "nom_pl_n"},
		{"gen_pl_m", "gen_pl_n"},
		{"dat_pl_m", "dat_pl_n"},
		{"acc_pl_m", "acc_pl_n"},
		{"abl_pl_m", "abl_pl_n"},
		{"voc_pl_m", "voc_pl_n"},
	}
	conv = convert(data, conv)
	
	local output = data.title
	output = output .. '\n{| class="prettytable inflection-table"'
	output = output .. '\n!style="background:#549EA0; font-style:italic;"| Number'
	output = output .. '\n!style="background:#549EA0; font-style:italic;" colspan="2" | Plural'
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| Case / Gender'
	output = output .. '\n!style="background:#40E0D0;"| Masc./Fem.'
	output = output .. '\n!style="background:#40E0D0;"| Neuter'
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[nominative case|Nominative]]'
	output = output .. conv[1]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[genitive case|Genitive]]'
	output = output .. conv[2]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[dative case|Dative]]'
	output = output .. conv[3]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[accusative case|Accusative]]'
	output = output .. conv[4]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[ablative case|Ablative]]'
	output = output .. conv[5]
	output = output .. '\n|-'
	if data.voc then
		output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[vocative case|Vocative]]'
		output = output .. conv[6]
	end
	output = output .. '\n|}'
	output = output .. '\n' .. data.footnote
	
	return output
end

local function make_table_mf_and_n_sg(data)
	local conv = {
		{"nom_sg_m", "nom_sg_n"},
		{"gen_sg_m", "gen_sg_n"},
		{"dat_sg_m", "dat_sg_n"},
		{"acc_sg_m", "acc_sg_n"},
		{"abl_sg_m", "abl_sg_n"},
		{"voc_sg_m", "voc_sg_n"},
	}
	conv = convert(data, conv)
	
	local output = data.title
	output = output .. '\n{| class="prettytable inflection-table"'
	output = output .. '\n!style="background:#549EA0; font-style:italic;"| Number'
	output = output .. '\n!style="background:#549EA0; font-style:italic;" colspan="2" | Singular'
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| Case / Gender'
	output = output .. '\n!style="background:#40E0D0;"| Masc./Fem.'
	output = output .. '\n!style="background:#40E0D0;"| Neuter'
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[nominative case|Nominative]]'
	output = output .. conv[1]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[genitive case|Genitive]]'
	output = output .. conv[2]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[dative case|Dative]]'
	output = output .. conv[3]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[accusative case|Accusative]]'
	output = output .. conv[4]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[ablative case|Ablative]]'
	output = output .. conv[5]
	output = output .. '\n|-'
	if data.voc then
		output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[vocative case|Vocative]]'
		output = output .. conv[6]
	end
	output = output .. '\n|}'
	output = output .. '\n' .. data.footnote
	
	return output
end

local function make_table_m_and_f_pl(data)
	local conv = {
		{"nom_pl_m", "nom_pl_f"},
		{"gen_pl_m", "gen_pl_f"},
		{"dat_pl_m", "dat_pl_f"},
		{"acc_pl_m", "acc_pl_f"},
		{"abl_pl_m", "abl_pl_f"},
		{"voc_pl_m", "voc_pl_f"},
	}
	conv = convert(data, conv)
	
	local output = data.title
	output = output .. '\n{| class="prettytable inflection-table"'
	output = output .. '\n!style="background:#549EA0; font-style:italic;"| Number'
	output = output .. '\n!style="background:#549EA0; font-style:italic;" colspan="2" | Plural'
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| Case / Gender'
	output = output .. '\n!style="background:#40E0D0;"| Masculine'
	output = output .. '\n!style="background:#40E0D0;"| Feminine'
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[nominative case|Nominative]]'
	output = output .. conv[1]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[genitive case|Genitive]]'
	output = output .. conv[2]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[dative case|Dative]]'
	output = output .. conv[3]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[accusative case|Accusative]]'
	output = output .. conv[4]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[ablative case|Ablative]]'
	output = output .. conv[5]
	output = output .. '\n|-'
	if data.voc then
		output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[vocative case|Vocative]]'
		output = output .. conv[6]
	end
	output = output .. '\n|}'
	output = output .. '\n' .. data.footnote
	
	return output
end

local function make_table_m_and_f_sg(data)
	local conv = {
		{"nom_sg_m", "nom_sg_f"},
		{"gen_sg_m", "gen_sg_f"},
		{"dat_sg_m", "dat_sg_f"},
		{"acc_sg_m", "acc_sg_f"},
		{"abl_sg_m", "abl_sg_f"},
		{"voc_sg_m", "voc_sg_f"},
	}
	conv = convert(data, conv)
	
	local output = data.title
	output = output .. '\n{| class="prettytable inflection-table"'
	output = output .. '\n!style="background:#549EA0; font-style:italic;"| Number'
	output = output .. '\n!style="background:#549EA0; font-style:italic;" colspan="2" | Singular'
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| Case / Gender'
	output = output .. '\n!style="background:#40E0D0;"| Masculine'
	output = output .. '\n!style="background:#40E0D0;"| Feminine'
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[nominative case|Nominative]]'
	output = output .. conv[1]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[genitive case|Genitive]]'
	output = output .. conv[2]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[dative case|Dative]]'
	output = output .. conv[3]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[accusative case|Accusative]]'
	output = output .. conv[4]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[ablative case|Ablative]]'
	output = output .. conv[5]
	output = output .. '\n|-'
	if data.voc then
		output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[vocative case|Vocative]]'
		output = output .. conv[6]
	end
	output = output .. '\n|}'
	output = output .. '\n' .. data.footnote
	
	return output
end

local function make_table_m_and_f_and_n_pl(data)
	local conv = {
		{"nom_pl_m", "nom_pl_f", "nom_pl_n"},
		{"gen_pl_m", "gen_pl_f", "gen_pl_n"},
		{"dat_pl_m", "dat_pl_f", "dat_pl_n"},
		{"acc_pl_m", "acc_pl_f", "acc_pl_n"},
		{"abl_pl_m", "abl_pl_f", "abl_pl_n"},
		{"voc_pl_m", "voc_pl_f", "voc_pl_n"},
	}
	conv = convert(data, conv)
	
	local output = data.title
	output = output .. '\n{| class="prettytable inflection-table"'
	output = output .. '\n!style="background:#549EA0; font-style:italic;"| Number'
	output = output .. '\n!style="background:#549EA0; font-style:italic;" colspan="3" | Plural'
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| Case / Gender'
	output = output .. '\n!style="background:#40E0D0;"| Masculine'
	output = output .. '\n!style="background:#40E0D0;"| Feminine'
	output = output .. '\n!style="background:#40E0D0;"| Neuter'
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[nominative case|Nominative]]'
	output = output .. conv[1]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[genitive case|Genitive]]'
	output = output .. conv[2]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[dative case|Dative]]'
	output = output .. conv[3]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[accusative case|Accusative]]'
	output = output .. conv[4]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[ablative case|Ablative]]'
	output = output .. conv[5]
	output = output .. '\n|-'
	if data.voc then
		output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[vocative case|Vocative]]'
		output = output .. conv[6]
	end
	output = output .. '\n|}'
	output = output .. '\n' .. data.footnote
	
	return output
end

local function make_table_m_and_f_and_n_sg(data)
	local conv = {
		{"nom_sg_m", "nom_sg_f", "nom_sg_n"},
		{"gen_sg_m", "gen_sg_f", "gen_sg_n"},
		{"dat_sg_m", "dat_sg_f", "dat_sg_n"},
		{"acc_sg_m", "acc_sg_f", "acc_sg_n"},
		{"abl_sg_m", "abl_sg_f", "abl_sg_n"},
		{"voc_sg_m", "voc_sg_f", "voc_sg_n"},
	}
	conv = convert(data, conv)
	
	local output = data.title
	output = output .. '\n{| class="prettytable inflection-table"'
	output = output .. '\n!style="background:#549EA0; font-style:italic;"| Number'
	output = output .. '\n!style="background:#549EA0; font-style:italic;" colspan="3" | Singular'
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| Case / Gender'
	output = output .. '\n!style="background:#40E0D0;"| Masculine'
	output = output .. '\n!style="background:#40E0D0;"| Feminine'
	output = output .. '\n!style="background:#40E0D0;"| Neuter'
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[nominative case|Nominative]]'
	output = output .. conv[1]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[genitive case|Genitive]]'
	output = output .. conv[2]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[dative case|Dative]]'
	output = output .. conv[3]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[accusative case|Accusative]]'
	output = output .. conv[4]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[ablative case|Ablative]]'
	output = output .. conv[5]
	output = output .. '\n|-'
	if data.voc then
		output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[vocative case|Vocative]]'
		output = output .. conv[6]
	end
	output = output .. '\n|}'
	output = output .. '\n' .. data.footnote
	
	return output
end

local function make_table_mfn(data, noneut)
	local conv = {
		{"nom_sg_m"},
		{"gen_sg_m"},
		{"dat_sg_m"},
		{"acc_sg_m"},
		{"abl_sg_m"},
		{"voc_sg_m"},
		{"----"},
		{"nom_pl_m"},
		{"gen_pl_m"},
		{"dat_pl_m"},
		{"acc_pl_m"},
		{"abl_pl_m"},
		{"voc_pl_m"},
	}
	conv = convert(data, conv)
	
	local output = data.title
	output = output .. '\n{| class="prettytable inflection-table"'
	output = output .. '\n!style="background:#549EA0; font-style:italic;"| Number'
	output = output .. '\n!style="background:#549EA0; font-style:italic;"| Singular'
	output = output .. '\n|rowspan="2"|'
	output = output .. '\n!style="background:#549EA0; font-style:italic;"| Plural'
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| Case / Gender'
	output = output .. '\n!style="background:#40E0D0;"| ' .. (noneut and 'Masc./Fem.' or 'Masc./Fem./Neut.')
	output = output .. '\n!style="background:#40E0D0;"| ' .. (noneut and 'Masc./Fem.' or 'Masc./Fem./Neut.')
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[nominative case|Nominative]]'
	output = output .. conv[1]
	if data.voc then
		output = output .. '\n|rowspan="6"|'
	else
		output = output .. '\n|rowspan="5"|'
	end
	output = output .. conv[8]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[genitive case|Genitive]]'
	output = output .. conv[2]
	output = output .. conv[9]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[dative case|Dative]]'
	output = output .. conv[3]
	output = output .. conv[10]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[accusative case|Accusative]]'
	output = output .. conv[4]
	output = output .. conv[11]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[ablative case|Ablative]]'
	output = output .. conv[5]
	output = output .. conv[12]
	output = output .. '\n|-'
	if data.voc then
		output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[vocative case|Vocative]]'
		output = output .. conv[6]
		output = output .. conv[13]
	end
	output = output .. '\n|}'
	output = output .. '\n' .. data.footnote
	
	return output
end

local function make_table_mf_and_n(data)
	local conv = {
		{"nom_sg_m", "nom_sg_n"},
		{"gen_sg_m", "gen_sg_n"},
		{"dat_sg_m", "dat_sg_n"},
		{"acc_sg_m", "acc_sg_n"},
		{"abl_sg_m", "abl_sg_n"},
		{"voc_sg_m", "voc_sg_n"},
		{"----"},
		{"nom_pl_m", "nom_pl_n"},
		{"gen_pl_m", "gen_pl_n"},
		{"dat_pl_m", "dat_pl_n"},
		{"acc_pl_m", "acc_pl_n"},
		{"abl_pl_m", "abl_pl_n"},
		{"voc_pl_m", "voc_pl_n"},
	}
	conv = convert(data, conv)
	
	local output = data.title
	output = output .. '\n{| class="prettytable inflection-table"'
	output = output .. '\n!style="background:#549EA0; font-style:italic;"| Number'
	output = output .. '\n!style="background:#549EA0; font-style:italic;" colspan="2" | Singular'
	output = output .. '\n|rowspan="2"|'
	output = output .. '\n!style="background:#549EA0; font-style:italic;" colspan="2" | Plural'
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| Case / Gender'
	output = output .. '\n!style="background:#40E0D0;"| Masc./Fem.'
	output = output .. '\n!style="background:#40E0D0;"| Neuter'
	output = output .. '\n!style="background:#40E0D0;"| Masc./Fem.'
	output = output .. '\n!style="background:#40E0D0;"| Neuter'
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[nominative case|Nominative]]'
	output = output .. conv[1]
	if data.voc then
		output = output .. '\n|rowspan="6"|'
	else
		output = output .. '\n|rowspan="5"|'
	end
	output = output .. conv[8]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[genitive case|Genitive]]'
	output = output .. conv[2]
	output = output .. conv[9]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[dative case|Dative]]'
	output = output .. conv[3]
	output = output .. conv[10]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[accusative case|Accusative]]'
	output = output .. conv[4]
	output = output .. conv[11]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[ablative case|Ablative]]'
	output = output .. conv[5]
	output = output .. conv[12]
	output = output .. '\n|-'
	if data.voc then
		output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[vocative case|Vocative]]'
		output = output .. conv[6]
		output = output .. conv[13]
	end
	output = output .. '\n|}'
	output = output .. '\n' .. data.footnote
	
	return output
end

local function make_table_m_and_f(data)
	local conv = {
		{"nom_sg_m", "nom_sg_f"},
		{"gen_sg_m", "gen_sg_f"},
		{"dat_sg_m", "dat_sg_f"},
		{"acc_sg_m", "acc_sg_f"},
		{"abl_sg_m", "abl_sg_f"},
		{"voc_sg_m", "voc_sg_f"},
		{"----"},
		{"nom_pl_m", "nom_pl_f"},
		{"gen_pl_m", "gen_pl_f"},
		{"dat_pl_m", "dat_pl_f"},
		{"acc_pl_m", "acc_pl_f"},
		{"abl_pl_m", "abl_pl_f"},
		{"voc_pl_m", "voc_pl_f"},
	}
	conv = convert(data, conv)
	
	local output = data.title
	output = output .. '\n{| class="prettytable inflection-table"'
	output = output .. '\n!style="background:#549EA0; font-style:italic;"| Number'
	output = output .. '\n!style="background:#549EA0; font-style:italic;" colspan="2" | Singular'
	output = output .. '\n|rowspan="2"|'
	output = output .. '\n!style="background:#549EA0; font-style:italic;" colspan="2" | Plural'
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| Case / Gender'
	output = output .. '\n!style="background:#40E0D0;"| Masculine'
	output = output .. '\n!style="background:#40E0D0;"| Feminine'
	output = output .. '\n!style="background:#40E0D0;"| Masculine'
	output = output .. '\n!style="background:#40E0D0;"| Feminine'
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[nominative case|Nominative]]'
	output = output .. conv[1]
	if data.voc then
		output = output .. '\n|rowspan="6"|'
	else
		output = output .. '\n|rowspan="5"|'
	end
	output = output .. conv[8]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[genitive case|Genitive]]'
	output = output .. conv[2]
	output = output .. conv[9]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[dative case|Dative]]'
	output = output .. conv[3]
	output = output .. conv[10]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[accusative case|Accusative]]'
	output = output .. conv[4]
	output = output .. conv[11]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[ablative case|Ablative]]'
	output = output .. conv[5]
	output = output .. conv[12]
	output = output .. '\n|-'
	if data.voc then
		output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[vocative case|Vocative]]'
		output = output .. conv[6]
		output = output .. conv[13]
	end
	output = output .. '\n|}'
	output = output .. '\n' .. data.footnote
	
	return output
end

local function make_table_m_and_f_and_n(data)	
	local conv = {
		{"nom_sg_m", "nom_sg_f", "nom_sg_n"},
		{"gen_sg_m", "gen_sg_f", "gen_sg_n"},
		{"dat_sg_m", "dat_sg_f", "dat_sg_n"},
		{"acc_sg_m", "acc_sg_f", "acc_sg_n"},
		{"abl_sg_m", "abl_sg_f", "abl_sg_n"},
		{"voc_sg_m", "voc_sg_f", "voc_sg_n"},
		{"----", "----", "----"},
		{"nom_pl_m", "nom_pl_f", "nom_pl_n"},
		{"gen_pl_m", "gen_pl_f", "gen_pl_n"},
		{"dat_pl_m", "dat_pl_f", "dat_pl_n"},
		{"acc_pl_m", "acc_pl_f", "acc_pl_n"},
		{"abl_pl_m", "abl_pl_f", "abl_pl_n"},
		{"voc_pl_m", "voc_pl_f", "voc_pl_n"},
	}
	conv = convert(data, conv)
	
	local output = data.title
	output = output .. '\n{| class="prettytable inflection-table"'
	output = output .. '\n!style="background:#549EA0; font-style:italic;"| Number'
	output = output .. '\n!style="background:#549EA0; font-style:italic;" colspan="3" | Singular'
	output = output .. '\n|rowspan="2"|'
	output = output .. '\n!style="background:#549EA0; font-style:italic;" colspan="3" | Plural'
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| Case / Gender'
	output = output .. '\n!style="background:#40E0D0;"| Masculine'
	output = output .. '\n!style="background:#40E0D0;"| Feminine'
	output = output .. '\n!style="background:#40E0D0;"| Neuter'
	output = output .. '\n!style="background:#40E0D0;"| Masculine'
	output = output .. '\n!style="background:#40E0D0;"| Feminine'
	output = output .. '\n!style="background:#40E0D0;"| Neuter'
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[nominative case|Nominative]]'
	output = output .. conv[1]
	if data.voc then
		output = output .. '\n|rowspan="6"|'
	else
		output = output .. '\n|rowspan="5"|'
	end
	output = output .. conv[8]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[genitive case|Genitive]]'
	output = output .. conv[2]
	output = output .. conv[9]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[dative case|Dative]]'
	output = output .. conv[3]
	output = output .. conv[10]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[accusative case|Accusative]]'
	output = output .. conv[4]
	output = output .. conv[11]
	output = output .. '\n|-'
	output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[ablative case|Ablative]]'
	output = output .. conv[5]
	output = output .. conv[12]
	if data.voc then
		output = output .. '\n|-'
		output = output .. '\n!style="background:#40E0D0; font-style:italic;"| [[vocative case|Vocative]]'
		output = output .. conv[6]
		output = output .. conv[13]
	end
	output = output .. '\n|}'
	output = output .. '\n' .. data.footnote
	
	return output
end

function export.make_table(data, noneut)
	if not data.forms.nom_sg_n and not data.forms.nom_pl_n then
		if data.forms.nom_sg_f or data.forms.nom_pl_f then
			if data.num == "pl" then return make_table_m_and_f_pl(data)
			elseif data.num == "sg" then return make_table_m_and_f_sg(data)
			else return make_table_m_and_f(data) end
		else
			if data.num == "pl" then return make_table_mfn_pl(data, noneut)
			elseif data.num == "sg" then return make_table_mfn_sg(data, noneut)
			else return make_table_mfn(data, noneut) end
		end
	elseif not data.forms.nom_sg_f and not data.forms.nom_pl_f then
		if data.num == "pl" then return make_table_mf_and_n_pl(data)
		elseif data.num == "sg" then return make_table_mf_and_n_sg(data)
		else return make_table_mf_and_n(data) end
	else
		if data.num == "pl" then return make_table_m_and_f_and_n_pl(data)
		elseif data.num == "sg" then return make_table_m_and_f_and_n_sg(data)
		else return make_table_m_and_f_and_n(data) end
	end
end

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
