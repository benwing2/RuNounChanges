local export = {}

--[=[
Generate labels for inflection classes. `data` is a table with the following fields:
* `labels`: The table into which the labels are written.
* `pos`: The singular part of speech, e.g. "noun".
* `stem_classes`: Table of possible stem classes and associated properties. See below.
* `principal_parts`: List of the principal part fields and descriptions. Each list element is a two-element list
  consisting of {"FIELD", "DESCRIPTION"} where FIELD is the field in the element in `stem_classes` (e.g. "nom_sg",
  "gen_sg", "pl", "sup") containing the detailed description of what this principal part looks like, and DESCRIPTION
  is the corresponding English description of the principal part (e.g. "nominative singular").
* `mark_up_spec`: Optional function to add markup to a spec. Takes two arguments, the spec and a flag `nolink`; if the
  flag is true, links should not be present in the resulting markup. The default just converts literal text enclosed
  in <...> into italics.
* `make_spec_bare`: Optional function to make a spec (stem class or sortkey) free of markup. The default just converts
  literal text enclosed in <...> into bare text.
* `addl`: Optional additional text to be displayed in the footer of each category page.

`stem_classes` is a table describing the various stem classes and how to format the category description of each. It is
a table with keys specifying the stem classes and values consisting of an object containing properties of the stem
class. If the stem class contains the word 'GENDER' in it, it expands into labels both for a parent category that
subsumes several genders (obtained by removing the word 'GENDER' and following whitespace) as well as gender-specific
children categories (obtained by replacing the word 'GENDER' with the genders specified in the `possible_genders`
field). The stem class can contain literal text (e.g. suffixes), which will be marked up appropriately (e.g. italicized)
in breadcrumbs and titles. The fields of the property object for a given stem class are as follows:
* `gender`: The description of the gender(s) of the stem class. If preceded by ~, the description is preceded by
  "most commonly". This appears in the `additional` field of the label properties. It is not used in gender-specific
  children categories; instead the gender of that category is used.
* `possible_genders`: The possible genders this class occurs in. If this is specified, the word 'GENDER' must occur in
  the stem class, and gender-specific variants of the stem class (with GENDER replaced by the possible genders) are
  handled along with a parent category subsuming all genders. 
* `PRINCIPAL_PART`: The ending for the specified principal part. Use <...> to enclose literal Latin-script text (e.g.
  suffixes), which will be italicized. There will be one field for each principal part listed in the `principal_parts`
  table described above.
* `GENDER_PRINCIPAL_PART`: The ending for the GENDER variant of the specified principal part. If not specified, the
  value of `PRINCIPAL_PART` is used.
* `breadcrumb`: The breadcrumb for the category, appearing in the trail of breadcrumbs at the top of the page. If this
  stem has gender-specific variants, the breadcrumb specified here is used only for the parent category, while the
  gender-specific child categories use the gender as the breadcrumb. If not specified, it defaults to `sortkey`. If that
  is also not specified, or if the breadcrumb has the value "+", the stem class (without the word 'GENDER') is used.
  (Use "+" when a sortkey is specified but the stem class should be used as the breadcrumb.)
* `parent`: The parent category or categories. If specified, the actual category label is formed by appending the part
  of speech (e.g. "nouns"). Defaults to "POS by inflection type" where POS is the part of speech. Note that
  gender-specific child categories do not use this, but always have the gender-subsuming parent stem class category as
  their parent.
* `sortkey`: The sort key used for sorting this category among its parent's children. Defaults to the stem class
  (without the word 'GENDER'). Note that gender-specific child categories do nto use this, but always use the gender
  as the sort key.
* `addl`: Optional additional text to be displayed in the footer of the category page.
* `GENDER_addl`: Optional additional text to be displayed in the footer of a gender-specific category page, defaulting
  to `addl`. Use the value `false` to cancel out a non-gender-specific value.
]=]

function export.add_inflection_labels(data)
	for _, reqfield_spec in ipairs {
		{"labels", "table of labels"},
		{"pos", "singular part of speech"},
		{"stem_classes", "table of possible stem classes and associated properties"},
		{"principal_parts", "list of principal part fields and names"},
	} do
		local reqfield, gloss = unpack(reqfield_spec)
		if not data[reqfield] then
			error(("Internal error: Missing field '%s', which should containing the %s"):format(reqfield, gloss))
		end
	end

	local function default_mark_up_spec(spec, nolink)
		return (spec:gsub("<(.-)>", "''%1''"))
	end
	local function default_make_spec_bare(spec)
		return (spec:gsub("<(.-)>", "%1"))
	end
	local function mark_up_spec(spec, nolink)
		return (data.mark_up_spec or default_mark_up_spec)(spec, nolink)
	end
	local function make_spec_bare(spec)
		return (data.make_spec_bare or default_make_spec_bare)(spec)
	end
	local plpos = require("Module:string utilities").pluralize(data.pos)
	for full_infl, spec in pairs(data.stem_classes) do
		local subgenders = spec.possible_genders

		-- Get the stem type.
		local infl
		if subgenders then
			if not full_infl:find("GENDER") then
				error(("Internal error: Declension spec '%s' needs to have the word 'GENDER' in it, in all caps"):format(full_infl))
			end
			infl = full_infl:gsub("GENDER ", "")
		else
			infl = full_infl
		end

		-- Get the breadcrumb.
		local breadcrumb = spec.breadcrumb or spec.sortkey or "+"
		if breadcrumb == "+" then
			breadcrumb = infl
		end

		-- Generate the parents.
		local parents = {}
		local spec_parents = spec.parent
		if type(spec_parents) == "string" then
			spec_parents = {spec_parents}
		end
		local parent_sort = make_spec_bare(spec.sortkey or infl)
		if spec_parents then
			for _, parent in ipairs(spec_parents) do
				table.insert(parents, {name = make_spec_bare(parent) .. " " .. plpos, sort = parent_sort})
			end
		else
			table.insert(parents, {name = plpos .. " by inflection type", sort = parent_sort})
		end

		-- Generate the additional text, including principal part descriptions and footer.
		local function create_addl(gender_spec, subgender_prefix)
			local addl_parts = {}
			local function ins(txt)
				table.insert(addl_parts, txt)
			end
			local function insert_header(gender_spec)
				if gender_spec then
					local most_commonly, gender = gender_spec:match("^(~)(.*)$")
					most_commonly = most_commonly and "most commonly " or ""
					gender = gender or gender_spec
					ins(("These %s are %s%s, typically with the following endings:\n"):format(plpos, most_commonly,
						mark_up_spec(gender)))
				else
					ins(("These %s typically have the following endings:\n"):format(plpos))
				end
			end
			local function process_ending(field, desc, is_last)
				local ending_spec = spec[subgender_prefix .. field] or spec[field]
				if not ending_spec then
					error(("Internal error: for inflection '%s', field '%s' for principal part '%s' is missing"):format(
						full_infl, field, desc))
				end
				return ("* in the %s: %s%s"):format(desc, mark_up_spec(ending_spec), is_last and "." or ";\n")
			end
			local function insert_principal_part_info(subgender_prefix)
				for i, ppart_spec in ipairs(data.principal_parts) do
					local ppart_field, ppart_desc = unpack(ppart_spec)
					ins(process_ending(ppart_field, ppart_desc, i == #data.principal_parts))
				end
			end
			insert_header(gender_spec)
			insert_principal_part_info("")
			local spec_addl = spec[subgender_prefix .. "addl"]
			if spec_addl == nil then
				spec_addl = spec.addl
			end
			if data.addl or spec_addl then
				local footer_parts = {}
				if data.addl then
					table.insert(footer_parts, mark_up_spec(data.addl))
				end
				if spec_addl then
					table.insert(footer_parts, mark_up_spec(spec_addl))
				end
				ins("\n" .. table.concat(footer_parts, " "))
			end
			return table.concat(addl_parts)
		end

		data.labels[make_spec_bare(infl) .. " " .. plpos] = {
			description = "{{{langname}}} " .. mark_up_spec(infl) .. " " .. plpos .. ".",
			displaytitle = "{{{langname}}} " .. mark_up_spec(infl, "nolink") .. " " .. plpos,
			additional = create_addl(spec.gender, ""),
			breadcrumb = mark_up_spec(breadcrumb, "nolink"),
			parents = parents,
		}
		if subgenders then
			for _, subgender in ipairs(subgenders) do
				local gender_infl = full_infl:gsub("GENDER", subgender)
				data.labels[make_spec_bare(gender_infl) .. " " .. plpos] = {
					description = "{{{langname}}} " .. mark_up_spec(gender_infl) .. " " .. plpos .. ".",
					displaytitle = "{{{langname}}} " .. mark_up_spec(gender_infl, "nolink") .. " " .. plpos,
					additional = create_addl(subgender, subgender .. "_"),
					breadcrumb = subgender,
					parents = {{
						name = make_spec_bare(infl) .. " " .. plpos,
						sort = subgender,
					}},
				}
			end
		end
	end
end

return export
