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
<div class="NavHead" style="text-align: left">Conjugation of ]=]}
	table.insert(ret, m_links.full_link({lang = lang, alt = data.forms.inf[1]}, "term") .. " (" .. data.conj ..  ")</div>\n")
	table.insert(ret, [=[<div class="NavContent">
{| style="background:#F0F0F0;border-collapse:separate;border-spacing:2px;width:100%" class="inflection-table"
|-
! colspan="1" style="background:#e2e4c0" | infinitive
| colspan="1" | ]=])
	table.insert(ret, show_form(data.forms.inf) .. "\n")
	table.insert(ret, [=[
|-
! colspan="2" style="background:#e2e4c0" | auxiliary verb
| colspan="1" | ]=])
	table.insert(ret, show_form(data.forms.aux) .. "\n")
	table.insert(ret, [=[
! colspan="2" style="background:#e2e4c0" | gerund
| colspan="2" | ]=])
	table.insert(ret, show_form(data.forms.gerund) .. "\n")
	table.insert(ret, [=[
|-
! colspan="2" style="background:#e2e4c0" | past participle
| colspan="2" | ]=])
	table.insert(ret, show_form(data.forms.past_part) .. "\n")
	table.insert(ret, [=[
|-
! colspan="1" rowspan="2" style="background:#C0C0C0" | person
! colspan="3" style="background:#C0C0C0" | singular
! colspan="3" style="background:#C0C0C0" | plural

|-
! style="background:#C0C0C0;width:12.5%" | first
! style="background:#C0C0C0;width:12.5%" | second
! style="background:#C0C0C0;width:12.5%" | third
! style="background:#C0C0C0;width:12.5%" | first
! style="background:#C0C0C0;width:12.5%" | second
! style="background:#C0C0C0;width:12.5%" | third

|-
! style="background:#c0cfe4" colspan="1" | indicative
! style="background:#c0cfe4" | mi
! style="background:#c0cfe4" | ti 
! style="background:#c0cfe4" | eło / eła 
! style="background:#c0cfe4" | noialtri / noialtre
! style="background:#c0cfe4" | voialtri / voialtre
! style="background:#c0cfe4" | łuri / łore 

|-

! style="height:3em;background:#c0cfe4" colspan="1" | present
]=])
	table.insert(ret, "| " .. show_form(data.forms.pres_ind_1sg) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.pres_ind_2sg, "2sg") .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.pres_ind_3sg, "3sg") .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.pres_ind_1pl) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.pres_ind_2pl) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.pres_ind_3pl, "3pl") .. "\n")
	table.insert(ret, [=[
|-
! style="height:3em;background:#c0cfe4" colspan="1" | imperfect
]=])
	table.insert(ret, "| " .. show_form(data.forms.impf_ind_1sg) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.impf_ind_2sg, "2sg") .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.impf_ind_3sg, "3sg") .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.impf_ind_1pl) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.impf_ind_2pl) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.impf_ind_3pl, "3pl") .. "\n")
	table.insert(ret, [=[
|-
! style="height:3em;background:#c0cfe4" colspan="1" | future
]=])
	table.insert(ret, "| " .. show_form(data.forms.futr_ind_1sg) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.futr_ind_2sg, "2sg") .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.futr_ind_3sg, "3sg") .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.futr_ind_1pl) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.futr_ind_2pl) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.futr_ind_3pl, "3pl") .. "\n")
	table.insert(ret, [=[
|-
! style="background:#c0d8e4" colspan="1" | conditional
! style="background:#c0d8e4" | mi
! style="background:#c0d8e4" | ti 
! style="background:#c0d8e4" | eło / eła 
! style="background:#c0d8e4" | noialtri / noialtre
! style="background:#c0d8e4" | voialtri / voialtre
! style="background:#c0d8e4" | łuri / łore 
|-
! style="height:3em;background:#c0d8e4" colspan="1" | present
]=])
	table.insert(ret, "| " .. show_form(data.forms.cond_ind_1sg) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.cond_ind_2sg, "2sg") .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.cond_ind_3sg, "3sg") .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.cond_ind_1pl) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.cond_ind_2pl) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.cond_ind_3pl, "3pl") .. "\n")
	table.insert(ret, [=[
|-
! style="background:#c0e4c0" colspan="1" | subjunctive
! style="background:#c0e4c0" | che mi
! style="background:#c0e4c0" | che ti 
! style="background:#c0e4c0" | che eło / eła 
! style="background:#c0e4c0" | che noialtri / noialtre
! style="background:#c0e4c0" | che voialtri / voialtre
! style="background:#c0e4c0" | che łuri / łore 
|-
! style="height:3em;background:#c0e4c0" colspan="1" | present
]=])
	table.insert(ret, "| " .. show_form(data.forms.pres_sub_1sg) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.pres_sub_2sg, "2sg") .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.pres_sub_3sg, "3sg") .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.pres_sub_1pl) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.pres_sub_2pl) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.pres_sub_3pl, "3pl") .. "\n")
	table.insert(ret, [=[
|-
! style="height:3em;background:#c0e4c0" colspan="1" | imperfect
]=])
	table.insert(ret, "| " .. show_form(data.forms.impf_sub_1sg) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.impf_sub_2sg, "2sg") .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.impf_sub_3sg, "3sg") .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.impf_sub_1pl) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.impf_sub_2pl) .. "\n")
	table.insert(ret, "| " .. show_form(data.forms.impf_sub_3pl,"3pl") .. "\n")
	table.insert(ret, [=[
|-
! colspan="1" rowspan="2" style="height:3em;background:#e4d4c0" | imperative
! style="background:#e4d4c0" | —
! style="background:#e4d4c0" | ti 
! style="background:#e4d4c0" | eło / eła 
! style="background:#e4d4c0" | noialtri / noialtre
! style="background:#e4d4c0" | voialtri / voialtre
! style="background:#e4d4c0" | łuri / łore 
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

	return table.concat(ret)
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
