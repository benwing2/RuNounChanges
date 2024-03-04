local export = {}

--[=[
Inflection specifications. The top-level key is the stem class, and the value is an object containing properties of the
stem class. If the stem class contains the word 'GENDER' in it, it expands into labels both for a parent category that
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
* `nom_sg`: The nominative singular ending. Use <...> to enclose literal Latin-script text (e.g. suffixes), which will
  be italicized. Prefix with an ! to replace the entire text with the specified text; otherwise the ending will be
  prefixed with "end in the nominative singular in ".
* `GENDER_nom_sg`: The nominative singular ending for the GENDER variant of this stem class. If not specified, the
  value of `nom_sg` is used.
* `gen_sg`: The genitive singular ending. Conventions are the same as for `nom_sg`.
* `GENDER_gen_sg`: The genitive singular ending for the GENDER variant of this stem class. If not specified, the value
  of `gen_sg` is used.
* `nom_pl`: The nominative plural ending. Conventions are the same as for `nom_sg`.
* `GENDER_nom_pl`: The nominative plural ending for the GENDER variant of this stem class. If not specified, the value
  of `nom_pl` is used.
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

	local function default_mark_spec_with_literal_text(spec)
		return (spec:gsub("<(.-)>", "''%1''"))
	end,
	local function default_make_spec_bare(spec)
		return (spec:gsub("<(.-)>", "%1"))
	end,
	local function mark_spec_with_literal_text(spec)
		return (data.mark_spec_with_literal_text or default_mark_spec_with_literal_text)(spec)
	end
	local function make_spec_bare(spec)
		return (data.make_spec_bare or default_make_spec_bare)(spec)
	end
	local plpos = require("Module:string utilities").pluralize(data.pos)
	for full_decl, spec in pairs(data.stem_classes) do
		local function process_ending(field, desc)
			local ending_spec = spec[field]
			if not ending_spec then
				error(("Internal error: for declension '%s', field '%s' for principal part '%s' is missing"):format(
					full_decl, field, desc))
			end
			return ("* in the %s: %s;\n"):format(desc, mark_spec_with_literal_text(ending_spec))
		end
		local subgenders = spec.possible_genders
		local decl
		if subgenders then
			if not full_decl:find("GENDER") then
				error(("Internal error: Declension spec '%s' needs to have the word 'GENDER' in it, in all caps"):format(full_decl))
			end
			decl = full_decl:gsub("GENDER ", "")
		else
			decl = full_decl
		end
		local breadcrumb = spec.breadcrumb or spec.sortkey or "+"
		if breadcrumb == "+" then
			breadcrumb = decl
		end
		local marked_up_desc = "{{{langname}}} " .. mark_spec_with_literal_text(decl) .. " " .. plpos
		local parents = {}
		local spec_parents = spec.parent
		if type(spec_parents) == "string" then
			spec_parents = {spec_parents}
		end
		local parent_sort = make_spec_bare(spec.sortkey or decl)
		if spec_parents then
			for _, parent in ipairs(spec_parents) do
				table.insert(parents, {name = parent .. " " .. plpos, sort = parent_sort})
			end
		else
			table.insert(parents, {name = plpos .. " by inflection type", sort = parent_sort})
		end
		local addl_parts = {}
		label function ins(txt)
			table.insert(addl_parts, txt)
		end
		if spec.gender then
			local most_commonly, gender = spec.gender:match("^(~)(.*)$")
			most_commonly = most_commonly and "most commonly " or ""
			gender = gender or spec.gender
			ins(("These %s are %s%s, typically with the following endings:\n"):format(plpos, most_commonly, gender))
		else
			ins(("These %s typically have the following endings:\n"):format(plpos))
		end
		for _, ppart_spec in ipairs(spec.principal_parts) do
			local ppart_field, ppart_desc = unpack(ppart_spec)
			ins(process_ending(ppart_spec, ppart_desc))
		end



		data.labels[make_spec_bare(decl) .. " " .. plpos] = {
			description = marked_up_desc .. ".",
			displaytitle = marked_up_desc,
			additional = ("These %s normally %s; %s; %s; and are %s%s."):format(plpos,
				process_ending(spec.nom_sg, "nominative singular"),
				process_ending(spec.gen_sg, "genitive singular"),
				process_ending(spec.nom_pl, "nominative plural"),
				most_commonly and "most commonly " or "", mark_spec_with_literal_text(gender)),
			breadcrumb = mark_spec_with_literal_text(breadcrumb),
			parents = parents,
		}
		if subgenders then
			for _, subgender in ipairs(subgenders) do
				local gender_decl = full_decl:gsub("GENDER", subgender)
				local marked_up_gender_desc = "{{{langname}}} " .. mark_spec_with_literal_text(gender_decl) .. " " ..
					plpos
				labels[make_spec_bare(gender_decl) .. " " .. plpos] = {
					description = marked_up_gender_desc .. ".",
					displaytitle = marked_up_gender_desc,
					additional = ("These %s normally %s; %s; %s; and are %s."):format(plpos,
						process_ending(spec[subgender .. "_nom_sg"] or spec.nom_sg, "nominative singular"),
						process_ending(spec[subgender .. "_gen_sg"] or spec.gen_sg, "genitive singular"),
						process_ending(spec[subgender .. "_nom_pl"] or spec.gen_sg, "nominative plural"),
						subgender),
					breadcrumb = subgender,
					parents = {{
						name = make_spec_bare(decl) .. " " .. plpos,
						sort = subgender,
					}},
				}
			end
		end
	end
end


return {LABELS = labels}
