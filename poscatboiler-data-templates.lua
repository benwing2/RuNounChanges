local labels = {}
local raw_categories = {}



-----------------------------------------------------------------------------
--                                                                         --
--                                  LABELS                                 --
--                                                                         --
-----------------------------------------------------------------------------


labels["templates"] = {
	description = "{{{langname}}} [[Wiktionary:Templates|templates]], containing reusable wiki code that help with creating and managing entries.",
	umbrella = {
		parents = {{name = "Templates", sort = " "}},
		breadcrumb = "by language",
	},
	parents = {{name = "{{{langcat}}}", raw = true}},
}

labels["auto-table templates"] = {
	description = "Templates that contain {{{langname}}} tables generated automatically.",
	additional = "They use the <code>table:</code> prefix. For example, see [[Template:table:chess pieces/en]].",
	parents = {"templates"},
}

labels["category boilerplate templates"] = {
	description = "Templates used to generate descriptions and categorization for category pages.",
	parents = {"templates"},
}

labels["definition templates"] = {
	description = "Templates used in the [[Wiktionary:Glossary#definition line|definition line]] of {{{langname}}} entries to help in creating definitions.",
	parents = {"templates"},
}

labels["entry templates"] = {
	description = "Templates used to help in the creation of {{{langname}}} entries.",
	parents = {"templates"},
}

labels["etymology templates"] = {
	description = "Templates used in the etymology section of {{{langname}}} entries.",
	parents = {"templates"},
}

labels["experimental templates"] = {
	description = "Templates used to test possible content for {{{langname}}} entries.",
	parents = {"templates"},
}

labels["form-of templates"] = {
	description = "Templates used on the definition line of entries for inflected forms of words in {{{langname}}}, to link back to the main form.",
	parents = {"templates"},
}

labels["headword-line templates"] = {
	description = "Templates used to show lines that contain headwords in {{{langname}}}.",
	parents = {"templates"},
}

labels["index templates"] = {
	description = "Templates used to organize {{{langname}}} indexes.",
	parents = {"templates"},
}

labels["inflection-table templates"] = {
	description = "Templates used to show inflection tables for {{{langname}}} terms.",
	parents = {"templates"},
}

-- Do particular types of inflection-table templates.
for _, pos in ipairs({
	"adjective",
	"adverb",
	"determiner",
	"nominal",
	"noun",
	"numeral",
	"participle",
	"postposition",
	"preposition",
	"pronoun",
	"verb",
}) do
	labels[pos .. " inflection-table templates"] = {
		description = "Templates used to show declension tables for {{{langname}}} " .. pos .. "s.",
		parents = {"inflection-table templates"},
	}
end

labels["list templates"] = {
	description = "Templates that contain {{{langname}}} lists.",
	additional = "They use the <code>list:</code> prefix. For example, see [[Template:list:Latin script letters/en]].",
	parents = {"templates"},
}

labels["mutation templates"] = {
	description = "Templates used to show mutation of {{{langname}}} words.",
	parents = {"templates"},
}

labels["quotation templates"] = {
	description = "Templates used to generate quotations for {{{langname}}} entries.",
	parents = {"templates"},
}

labels["reference templates"] = {
	intro = function(data)
		if data.lang and data.lang:getCode() == "ine-pro" then
			return "{{shortcut|WT:RTINE}}"
		end
	end,
	description = "Templates used to generate reference footnotes for {{{langname}}} entries.",
	parents = {"templates"},
}

labels["supplementary templates"] = {
	description = "Templates used to keep contents for other {{{langname}}} templates.",
	parents = {"templates"},
}

labels["usage templates"] = {
	description = "Templates used to show usage notes in {{{langname}}} entries.",
	parents = {"templates"},
}


-- Add 'umbrella_parents' key if not already present.
for key, data in pairs(labels) do
	if not data.umbrella_parents then
		data.umbrella_parents = "Templates subcategories by language"
	end
	-- Add breadcrumb by chopping off the parent from the end of the label, if possible.
	if #data.parents == 1 and type(data.parents[1]) == "string" then
		local parent_re = " " .. require("Module:utilities").pattern_escape(data.parents[1]) .. "$"
		if key:find(parent_re) then
			data.breadcrumb = key:gsub(parent_re, "")
		end
	end
end



-----------------------------------------------------------------------------
--                                                                         --
--                              RAW CATEGORIES                             --
--                                                                         --
-----------------------------------------------------------------------------


raw_categories["Templates"] = {
	intro = "{{shortcut|WT:T}}",
	description = "An organizing category intended for all templates in use on Wiktionary.",
	additional = "''See also: [[Wiktionary:Templates]], [[meta:Help:Template]]''",
	parents = {"Wiktionary"},
}

raw_categories["Non-production templates and modules"] = {
	description = "Templates and modules not currently used in production.",
	additional = "{{also|Special:UnusedTemplates|Category:Unused templates}}",
	parents = {"Templates", "Modules", "Category:Wiktionary maintenance"},
}

raw_categories["Templates subcategories by language"] = {
	description = "Umbrella categories covering topics related to templates.",
	additional = "{{{umbrella_meta_msg}}}",
	parents = {
		"Umbrella metacategories",
		{name = "templates", is_label = true, sort = " "},
	},
}


return {LABELS = labels, RAW_CATEGORIES = raw_categories}
