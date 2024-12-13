local m_gen_num = require("Module:gender and number")
local m_links = require("Module:links")
local m_utilities = require("Module:utilities")

local m_infl =  require("Module:vec-conj/data")

local lang = require("Module:languages").getByCode("vec")

local clitics = {["2sg"] = "(te) ", ["3sg"] = "(el/ła) ", ["3pl"] = "(i/łe) "}

local export = {}

-- Shows forms with links, or a dash if empty
local function show_form(subforms, form_name)
	if not subforms then
		return "&mdash;"
	elseif type(subforms) ~= "table" then
		error("a non-table value was given in the list of inflected forms.")
	elseif #subforms == 0 then
		return "&mdash;"
	end
	
	local ret = {}
	local form_cl = ""
	
	if clitics[form_name] then
		form_cl = clitics[form_name]
	end
	
	-- Go over each subform and insert links
	for key, subform in ipairs(subforms) do
		table.insert(ret, form_cl .. m_links.full_link({lang = lang, term = subform}))
	end
	
	return table.concat(ret, ", ")
end

-- Shows the table with the given forms
local function make_table(data)
	local ret = {[=[* Venetan conjugation varies from one region to another. Hence, the following conjugation should be considered as typical, not as exhaustive.
	
<div class="NavFrame">
<div class="NavHead">Conjugation of ]=]}
	table.insert(ret, m_links.full_link({lang = lang, alt = data.forms.inf[1]}, "term") .. " (" .. data.conj ..  ")</div>\n")
	table.insert(ret, [=[<div class="NavContent">
{| class="roa-inflection-table" data-toggle-category="inflection"
|-
! class="roa-nonfinite-header" | infinitive
| ]=])
	table.insert(ret, show_form(data.forms.inf) .. "\n")
	table.insert(ret, [=[
|-
! colspan="2" class="roa-nonfinite-header" | auxiliary verb
| ]=])
	table.insert(ret, show_form(data.forms.aux) .. "\n")
	table.insert(ret, [=[
! colspan="2" class="roa-nonfinite-header" | gerund
| colspan="2" | ]=])
	table.insert(ret, show_form(data.forms.gerund) .. "\n")
	table.insert(ret, [=[
|-
! colspan="2" class="roa-nonfinite-header" | past participle
| colspan="2" | ]=])
	table.insert(ret, show_form(data.forms.past_part) .. "\n")
	table.insert(ret, [=[
|-
! rowspan="2" class="roa-person-number-header" | person
! colspan="3" class="roa-person-number-header" | singular
! colspan="3" class="roa-person-number-header" | plural

|-
! class="roa-person-number-header" style="width:12.5%;" | first
! class="roa-person-number-header" style="width:12.5%;" | second
! class="roa-person-number-header" style="width:12.5%;" | third
! class="roa-person-number-header" style="width:12.5%;" | first
! class="roa-person-number-header" style="width:12.5%;" | second
! class="roa-person-number-header" style="width:12.5%;" | third

|-
! class="roa-indicative-left-rail" | indicative
! class="roa-indicative-left-rail" | mi
! class="roa-indicative-left-rail" | ti 
! class="roa-indicative-left-rail" | eło / eła 
! class="roa-indicative-left-rail" | noialtri / noialtre
! class="roa-indicative-left-rail" | voialtri / voialtre
! class="roa-indicative-left-rail" | łuri / łore 

|-

! class="roa-indicative-left-rail" style="height:3em;" | present
]=])
	table.insert(ret, "| " .. show_form(data.forms.pres_ind_1sg) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.pres_ind_2sg, "2sg") .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.pres_ind_3sg, "3sg") .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.pres_ind_1pl) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.pres_ind_2pl) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.pres_ind_3pl, "3pl") .. "\n")
	table.insert(ret, [=[
|-
! class="roa-indicative-left-rail" style="height:3em;" | imperfect
]=])
	table.insert(ret, "| " .. show_form(data.forms.impf_ind_1sg) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.impf_ind_2sg, "2sg") .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.impf_ind_3sg, "3sg") .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.impf_ind_1pl) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.impf_ind_2pl) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.impf_ind_3pl, "3pl") .. "\n")
	table.insert(ret, [=[
|-
! class="roa-indicative-left-rail" style="height:3em;" | future
]=])
	table.insert(ret, "| " .. show_form(data.forms.futr_ind_1sg) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.futr_ind_2sg, "2sg") .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.futr_ind_3sg, "3sg") .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.futr_ind_1pl) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.futr_ind_2pl) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.futr_ind_3pl, "3pl") .. "\n")
	table.insert(ret, [=[
|-
! class="roa-indicative-left-rail" style="height:3em;" | conditional
]=])
	table.insert(ret, "| " .. show_form(data.forms.cond_ind_1sg) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.cond_ind_2sg, "2sg") .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.cond_ind_3sg, "3sg") .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.cond_ind_1pl) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.cond_ind_2pl) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.cond_ind_3pl, "3pl") .. "\n")
	table.insert(ret, [=[
|-
! class="roa-subjunctive-left-rail" | subjunctive
! class="roa-subjunctive-left-rail" | che mi
! class="roa-subjunctive-left-rail" | che ti 
! class="roa-subjunctive-left-rail" | che eło / eła 
! class="roa-subjunctive-left-rail" | che noialtri / noialtre
! class="roa-subjunctive-left-rail" | che voialtri / voialtre
! class="roa-subjunctive-left-rail" | che łuri / łore 
|-
! class="roa-subjunctive-left-rail" style="height:3em;" | present
]=])
	table.insert(ret, "| " .. show_form(data.forms.pres_sub_1sg) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.pres_sub_2sg, "2sg") .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.pres_sub_3sg, "3sg") .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.pres_sub_1pl) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.pres_sub_2pl) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.pres_sub_3pl, "3pl") .. "\n")
	table.insert(ret, [=[
|-
! class="roa-subjunctive-left-rail" style="height:3em;" | imperfect
]=])
	table.insert(ret, "| " .. show_form(data.forms.impf_sub_1sg) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.impf_sub_2sg, "2sg") .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.impf_sub_3sg, "3sg") .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.impf_sub_1pl) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.impf_sub_2pl) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.impf_sub_3pl,"3pl") .. "\n")
	table.insert(ret, [=[
|-
! rowspan="2" class="roa-imperative-left-rail" style="height:3em;" | imperative
! class="roa-imperative-left-rail" | —
! class="roa-imperative-left-rail" | ti 
! class="roa-imperative-left-rail" | eło / eła 
! class="roa-imperative-left-rail" | noialtri / noialtre
! class="roa-imperative-left-rail" | voialtri / voialtre
! class="roa-imperative-left-rail" | łuri / łore 
|-
| —
]=])
	table.insert(ret, "| " .. show_form(data.forms.impr_2sg, "2sg") .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.impr_3sg, "3sg") .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.impr_1pl) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.impr_2pl) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.impr_3pl, "3pl") .. "\n")
	table.insert(ret, [=[
|}
</div></div>]=])

	return require("Module:TemplateStyles")("Module:roa-verb/style.css") .. table.concat(ret)
end

-- Main entry point
function export.show(frame)
	local args = mw.clone(frame:getParent().args)
	
	-- Create the forms
	local data = {forms = {}, categories = {}}
	
	if mw.title.getCurrentTitle().nsText ~= "" then return end
	
	local word = args[1] or mw.title.getCurrentTitle().text
	
	local last3 = mw.ustring.sub(word, -3, -1)
	local last2 = mw.ustring.sub(word, -2, -1)
	if m_infl[word] then
		args[1] = m_infl[word].get_stem(word)
		m_infl[word](args, data)
	elseif m_infl[last3] then
		args[1] = m_infl[last3].get_stem(word)
		m_infl[last3](args, data)
	elseif m_infl[last2] then
		args[1] = m_infl[last2].get_stem(word)
		-- Distinguishing first and second conjugation -ar verbs
		if mw.ustring.match(word, "[àèéìòó][bcdfgjłmnprstvxz][bcdfgjłmnprstvxz]?ar$") or args.conj == "2nd" then
			m_infl["ar-2nd"](args, data)
		else
			m_infl[last2](args, data)
		end
	else
		error("Inflection for " .. word .. " not found.")
	end
	
	return make_table(data) .. m_utilities.format_categories(data.categories, lang)
end

return export
