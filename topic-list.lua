local export = {}

local columns_module = "Module:columns"
local parameters_module = "Module:parameters"


--[==[
This implements topic lists. A given topic list template must directly invoke this function rather than
going through a wrapping template. A sample template implementation (e.g. for {{tl|list:continents/sw}}) is
{
{{#invoke:topic list|show|sw
|hypernym=[[bara|mabara]]
|Afrika<t:Africa>
|Antaktika~Antaktiki<t:Antarctica>
|Asia<t:Asia>
|Ulaya,Uropa<t:Europe>
|Amerika ya Kaskazini<t:North America>
|Amerika ya Kusini<t:South America>
|Australia<t:Australia>
}}
}

The syntax of the params is largely the same as for {{tl|col}}, but the following additional params supported:
* {{para|cat}}: Comma-separated list of categories to add the page to. The categories should specify bare topic
  categories without the preceding language code, e.g. `Islamic calendar months` for a category
  `LANGCODE:Islamic calendar months`. If you need to specify a different type of category, prefix the full category name
  with `Category:`. There must not be any spaces after the comma delimiter for it to be recognized as such. By default,
  the category comes from the template name, minus the initial `list:` and anything starting with a slash, and with the
  first letter capitalized; but only if the top-level language-agnostic category exists. Hence a template like
  {{tl|list:prefectures of Japan/ja}} will automatically categorize into [[:Category:ja:Prefectures of Japan]] (and
  likewise {{tl|list:prefectures of Japan/sq}} will still categorize into [[:Category:sq:Prefectures of Japan]] whether
  or not it exists, because the top-level [[:Category:Prefectures of Japan]] exists), but a template like
  {{tl|list:human anatomy direction adjectives/en}} will not categorize anywhere by default because there is no
  top-level [[:Category:Human anatomy direction adjectives]]. Use {{para|cat|-}} to disable categorization. Note that no
  categorization takes place if {{para|nocat|1}} is specified in the invocation of the list template or if the page is
  the same as any of the pages linked to by the language-specific hypernym(s) given in {{para|hypernym}}.
* {{para|hypernym}}: The language-specific plural form of the hypernym category (e.g. in the above example, the word for
  "continents" in Swahili). Generally this should be linked to the corresponding singular, if they are different. If
  specified, it is displayed after the English hypernym, following a colon. This parameter can be omitted to not display
  a hypernym, and you can also specify multiple comma-separated or tilde-separated hypernyms with inline modifiers
  attached to each one (essentially, following the format of a given item in {{tl|col}}).
* {{para|enhypernym}}: The English-language hypernym, e.g. `continents` in the above example. If omitted, this is
  derived from the template name by chopping off the initial `list:` and anything starting with a slash. This will be
  hyperlinked to the first category that the page categorizes into, if such a category exists.
]==]
function export.show(frame)
	local raw_item_args = frame.args
	local frame_parent = frame:getParent()
	local raw_user_args = frame_parent.args
	local topic_list_template = frame_parent:getTitle()

	local user_params = {
		nocat = {type = "boolean"},
		sortbase = {},
	}

	local user_args = require(parameters_module).process(raw_user_args, user_params)

	return require(columns_module).handle_display_from_or_topic_list(
		{minrows = 2, sort = true, collapse = true}, raw_item_args, user_args, topic_list_template)
end

return export
