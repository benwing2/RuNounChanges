#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# FIXME:
#
# 1. [DONE] Check L2 header for language and use in place of 'en'.
# 2. [DONE] Need to preserve some links, e.g. probably at least in the translation (t1=). E.g.
#    Replaced <# {{zh-div|縣}} {{w|Li County, Hunan|Li County}} {{gloss|county in Hunan}}> with <# {{zh-div|縣}} {{place|zh|county|p/Hunan|t1=Li County}}>
#    There is no Wiktionary article "Li County".
# 3. [DONE] Restrict translation to the same form as that preceding County, district, etc.,
#    additionally allowing an initial "the".
# 4. [DONE] Add . to allowed chars preceding County, district, etc. (St. Louis County).
# 5. [PARTLY DONE; NOT FOR INITIAL CAP] Generalize proper noun regex to non-ASCII Latin chars.
# 6. If "Indian state of" or "US state of" appears, add the respective country to the holonym.
# 7. [DONE PARTLY IN MODULE] If "[Pp]refecture", "[Pp]rovince", etc. appears, consider including that text in the
#    holonym (perhaps always for certain cases, e.g. Japanese prefectures)? If so, consider
#    adding logic to this effect in [[Module:place]].
# 8. [DONE] If all holonyms can't be recognized, back off one word (or holonym?) at a time until
#    something (including at least one holonym) is recognized. FIXME: Unclear what to do when
#    a translation is available.
# 9. Holonyms like {{l|en|Egypt|id=Q79}} aren't handled properly because of the id=.
# 10. [DONE] Add "de" and "upon" as allowed words in proper nouns.
# 11. Strip {{wtorw}}.
# 12. [DONE] The following shouldn't happen:
#     Replaced <# {{wtorw|Martvili}} {{gloss|a town in western Georgia}}> with <# {{wtorw|Martvili}} {{place|en|town|western|s/Georgia}}>
#     Page 3052010 Cochin: Replaced <# {{alternative form of|en|Kochi}} (city in India)> with <# {{alternative form of|en|Kochi}} {{place|en|city|c/India}}>
# 13. Things that occur frequently in toponyms:
# 13a. [DONE; REGIONS] "Cilicia mentioned by Pliny", "Assyria mentioned by Pliny", "Asia mentioned by Pliny", etc.; Roman provinces?
# 13b. [DONE] "Clackmannanshire council area", "East Lothian council area", etc.
# 13c. [DONE] "Alpes-Maritimes department", "Moselle department", "Haut-Rhin département", etc.
# 13d. "Haut-Rhin department of Alsace", "Pyrénées-Orientales department of France", "Seine-et-Marne department of Île-de-France", etc.
# 13e. "and one of the two county seats of Prairie County", "which is one of the two county seats of St. Clair County", etc.
# 13f. [DONE] "Borough of Croydon", "Borough of Kingston upon Thames", "Borough of Tower Hamlets", etc.
# 13g. [DONE] "city of Aberdeen", "city of Newcastle upon Tyne", "city of Coventry", etc.
# 13h. "interior of Liguria", "interior of Calabria", "interior of Samnium", "interior of Sicily", etc.
# 13i. [DONE] "metropolitan borough of North Tyneside", "metropolitan borough of Kirklees", "metropolitan borough of Wakefield", etc.
# 13j. [DONE] "province Dalarna", "province Södermanland", "province Östergötland", etc.
# 13k. "{{m|ja|中部|tr=Chūbu}} region of Japan", "{{m|ja|関東|tr=Kantō}} region of Japan facing the Pacific Ocean", etc.
# 13l. [DONE] "London Borough of Croydon", "London Borough of Greenwich", etc. (Be careful, sometimes there's
#      another holonym "Greater London", sometimes there isn't.)
# 14. [DONE] "[[w = 24" unrecognized toponym; should only recognize : when followed by a space. Probably same for ,
#     (otherwise separate numbers like 200,000).
# 15. Should at least try to handle the following:
#     Page 824348 Nukus: Replaced <# A city in [[Uzbekistan]], the capital of [[Karakalpakstan]].> with <# {{place|en|city|c/Uzbekistan}}, the capital of [[Karakalpakstan]].>
#     Page 38297 Schwyz: Replaced <# A town in [[Switzerland]], the capital of the canton of Schwyz.> with <# {{place|de|town|c/Switzerland}}, the capital of the canton of Schwyz.>
#     Page 47576 Cebu: Replaced <# A city in the Philippines, the capital of Cebu province.> with <# {{place|en|city|c/Philippines}}, the capital of Cebu province.>
# 16. [DONE] Try to fill out official=, modern=, capital=, largest city=, caplc=
# 17. [DONE] Fix the following:
#     Page 3052017 Asansol: WARNING: Unable to recognize stripped holonym 'West Bengal province': <from> # A [[city]] in [[West Bengal]] province, [[eastern]] [[India]].
#     Page 3052024 Virginia Beach: WARNING: Unable to recognize stripped holonym 'state of Virginia': <from> # An [[independent city]] in the state of [[Virginia]] in the [[eastern]] [[United States]].
# 18. [DONE] Fix the following (probably by disallowing zero holonyms):
#     Page 5432682 Putnam County: Replaced <# a county in {{l|en|Georgia}}, USA, county seat {{l|en|Eatonton}}.> with <# {{place|en|county|s/Georgia|c/USA|;|county seat}} {{l|en|Eatonton}}.>
# 19. [DONE] Consider fixing the following (probably by putting countries and constituent countries after states, provinces, districts, prefectures, cantons, boroughs, counties, islands, etc. but not regions or seas):
#     Page 1622093 Visakhapatnam: Replaced <# A large [[city]] and [[district]] in [[India]], in the state of [[Andhra Pradesh]].> with <# {{place|en|large city/district|c/India|s/Andhra Pradesh}}
#     Page 81124 Bean: Replaced <# A [[village]] in [[Kent]], [[England]], in [[Dartford]] district.> with <# {{place|en|village|co/Kent|cc/England|dist/Dartford}}>
# 20. [DONE] Fix the following:
#     Page 143442 Galicia: Replaced <# [[#English|Galicia]] {{gloss|region in NW Spain, north of Portugal}}> with <# {{place|fi|region|in northwestern|c/Spain|in northern|c/Portugal|t1=Galicia}}>
#     Page 2265148 Södertälje: Replaced <# a town in central Sweden, south of Stockholm> with <# {{place|sv|town|in central|c/Sweden|in southern|city/Stockholm}}>
#     Page 2265150 Täby: Replaced <# a town in central Sweden, north of Stockholm> with <# {{place|sv|town|in central|c/Sweden|in northern|city/Stockholm}}>
# 21. [DONE] Fix the following (probably by disallowing two consecutive countries):
#     Page 1063838 Araks: Replaced <# A river that flows in [[Turkey]], [[Armenia]], [[Iran]] and [[Azerbaijan]] and empties into [[Kura]] river.> with <# {{place|en|river|c/Turkey|c/Armenia}}, [[Iran]] and [[Azerbaijan]] and empties into [[Kura]] river.>
# 22. [DONE] Fix the following (probably by putting "in" after countries followed by regions or seas, or regions followed by seas):
#     Page 955656 Opole: Replaced <# A city in southern [[Poland]], in the region of [[Silesia]]> with <# {{place|en|city|in southern|c/Poland|r/Silesia}}>
#     Page 6639682 Kimitoön: Replaced <# A [[municipality]] in the region of {{w|Southwest Finland}} in the {{w|Archipelago Sea}}> with <# {{place|en|municipality|r/Southwest Finland|sea/Archipelago Sea}}>
# 23. [DONE] Fix the following (probably by removing Macedonia as an alias of North Macedonia):
#     Page 3065170 Philippi: Replaced <# An ancient town in [[Macedonia]], [[Greece]]> with <# {{place|en|ancient town|c/North Macedonia|c/Greece}}>
#     Page 6506818 Arnissa: Replaced <# An ancient town of [[Macedonia]] in the province of [[Eordaea]]> with <# {{place|la|ancient town|c/North Macedonia|p/Eordaea}}>
# 24. [DONE] Fix the following (by moving preceding "in ..." qualifiers along with the country):
#     Page 2265176 Karlsborg: Replaced <# a small town in central Sweden, in the province [[Västergötland]]> with <# {{place|sv|small town|in central|p/Västergötland|c/Sweden}}>
# 25. [DONE] Consider adding module support for seat= for county seats of counties and parsing them out.
# 26. [DONE] Consider handling "modern ..." in holonyms.
# 27. [DONE] Manually correct the following:
#     Page 3797662 Gudauta: Replaced <# a town in [[Abkhazia]], [[Georgia]].> with <# {{place|en|town|s/Georgia|c/Abkhazia}}>
#     (others similar to the above)
#     Page 3911822 Badakhshan: Replaced <# A province of Afghanistan, [[Badakhshan Province]].> with <# {{place|en|province|p/Badakhshan Province|c/Afghanistan}}>
#     Page 4059975 Corduba: Replaced <# a town in [[Hispania Baetica]], [[Córdoba]]> with <# {{place|la|town|p/Hispania Baetica|city/Córdoba}}>
#     Page 4161646 Guayana Francesa: Replaced <# {{l|en|French Guiana}} {{gloss|department of French Guiana}}> with <# {{place|es|department|overseas department/French Guiana|t1=French Guiana}}>
#     Page 4942414 Mesudiye: Replaced <# A [[town]] and [[district]] of [[Ordu Province]] in the [[Black Sea]] region of [[Turkey]].> with <# {{place|en|town/district|p/Ordu Province|r/Black Sea|c/Turkey}}>
#     Page 4942414 Mesudiye: Replaced <# A small [[village]] located in [[Muğla Province]] in the [[Aegean]] region of [[Turkey]].> with <# {{place|en|small village|p/Muğla Province|r/Aegean|c/Turkey}}>
#     Page 5070113 Boko: Replaced <# A {{l|en|town}} in the {{l|en|Niangoloko}} Department of {{l|en|Comoé}} Province in southwestern {{l|en|Burkina Faso}}.> with <# {{place|en|town|p/Niangoloko Department of Comoé Province|in southwestern|c/Burkina Faso}}>
#     Page 3814875 Kikai: Replaced <# An island of the {{l|en|Amami}} archipelago, Japan.> with <# {{place|en|island|arch/Amami|c/Japan}}>
#     Page 845864 Sevastopol: Replaced <# A [[port]] city in the [[Crimea]]n [[peninsula]], base of the [[Black Sea]] [[fleet|Fleet]].> with <# {{place|en|port city|pen/Crimean}}, base of the [[Black Sea]] [[fleet|Fleet]].>
#     Page 2906281 Roby: Replaced <# a village in Huyton-with-Roby parish, Metropolitan Borough of {{l|en|Knowsley}}, [[Merseyside]], [[England]] {{q|[[OS]] grid ref SJ4390}}.> with <# {{place|en|village|par/Huyton-with-Roby|metbor/Knowsley|co/Merseyside|cc/England}} {{q|[[OS]] grid ref SJ4390}}>
#     Page 3292052 Bagley: Replaced <# a village in Hordley parish, Shropshire {{q|[[OS]] grid ref SJ4027}}.> with <# {{place|en|village|par/Hordley|co/Shropshire}} {{q|[[OS]] grid ref SJ4027}}>
#     Page 3292052 Bagley: Replaced <# a hamlet in {{l|en|Wedmore}} parish, {{l|en|Sedgemoor}} district, [[Somerset]], England {{q|OS grid ref ST4546}}.> with <# {{place|en|hamlet|par/Wedmore|dist/Sedgemoor|co/Somerset|cc/England}} {{q|OS grid ref ST4546}}>
#     Page 3612446 Dragonja: Replaced <# A river in the [[Istria]]n peninsula> with <# {{place|en|river|pen/Istrian}}>
#     Page 4011983 Lleida: Replaced <# A [[province]] of Spain, in the west of [[Catalonia]].> with <# {{place|en|province|c/Spain}}, in the west of [[Catalonia]].>
#     Page 5460157 Welton: Replaced <# A village in {{l|en|West Lindsey}} district, [[Lincolnshire]], England, in the parish of Welton-by-Lincoln {{q|OS grid ref TF0179}}.> with <# {{place|en|village|dist/West Lindsey|co/Lincolnshire|cc/England|par/Welton-by-Lincoln}} {{q|OS grid ref TF0179}}>
#     Page 5647088 Dium: Replaced <# A city in the peninsula of [[Acte]]> with <# {{place|la|city|pen/Acte}}>
#     Page 5652703 Atherstone: Replaced <# a hamlet in {{l|en|Whitelackington}} parish, {{l|en|South Somerset}} district, [[Somerset]], England {{q|OS grid ref ST3816}}.> with <# {{place|en|hamlet|par/Whitelackington|dist/South Somerset|co/Somerset|cc/England}} {{q|OS grid ref ST3816}}>
#     Page 5724286 Kertš: Replaced <# [[Kerch]] {{gloss|city in the Crimean peninsula}}> with <# {{place|fi|city|pen/Crimean|t1=Kerch}}>
#     Page 6492030 Åboland: Replaced <# A [[subregion]] in the archipelago of Southwest Finland.> with <# {{place|en|subregion|arch/Southwest Finland}}>
#     Page 6680562 Chipping Ongar: Replaced <# A small [[market town]] in {{l|en|Ongar}} parish, {{l|en|Epping Forest}} district, [[Essex]], [[England]] {{q|[[OS]] grid ref TL5503}}.> with <# {{place|en|small market town|par/Ongar|dist/Epping Forest|co/Essex|cc/England}} {{q|[[OS]] grid ref TL5503}}>
#     Page 6703411 Newbiggin: Replaced <# A [[hamlet]] in {{l|en|Ainstable}} parish, {{l|en|Eden}} district, [[Cumbria]], [[England]] {{q|[[OS]] grid ref NY5549}}.> with <# {{place|en|hamlet|par/Ainstable|dist/Eden|co/Cumbria|cc/England}} {{q|[[OS]] grid ref NY5549}}>
#     Page 6703411 Newbiggin: Replaced <# A [[village]] in {{l|en|Dacre}} parish, Eden district, Cumbria {{q|OS grid ref NY4729}}.> with <# {{place|en|village|par/Dacre|dist/Eden|co/Cumbria}} {{q|OS grid ref NY4729}}>
#     Page 198477 Qazvin: Replaced <# A city in the northwest of [[Iran]]. Capital of [[Qazvin Province]].> with <# {{place|en|city|in northwestern|p/Iran. Capital of Qazvin Province}}.>
#     Page 738820 Ayn: Replaced <# A [[commune]] in [[Savoie]] [[department|Department]], [[France]].> with <# {{place|en|commune|dept/Savoie Department|c/France}}.>
#     Page 1118915 Koszovó: Replaced <# [[Kosovo]] {{gloss|country in the Balkans and the region of Serbia}}> with <# {{place|hu|country|r/Balkans and the|c/Serbia|t1=Kosovo}}>
#     Page 2774006 Saint Louis: Replaced <# A [[city]] in the [[southwest]] of [[Reunion]] [[island|Island]] in the [[Indian Ocean]].> with <# {{place|en|city|in southwestern|isl/Reunion Island|ocean/Indian Ocean}}.>
#     Page 2774006 Saint Louis: Replaced <# A [[commune]] in [[Haut-Rhin]] [[department|Department]], [[Alsace]], [[France]].> with <# {{place|en|commune|dept/Haut-Rhin Department|r/Alsace|c/France}}.>
#     Page 84426 Volta: Replaced <# A [[river]] in West [[Africa]], [[w:Volta River|Volta River]], having given name to [[Upper Volta]]. {{topics|en|Rivers in Africa}}> with <# {{place|en|river|r/West Africa|riv/[[w:Volta River|Volta River]]}}, having given name to [[Upper Volta]]. {{topics|en|Rivers in Africa}}>
#     Page 3932384 Prahova: Replaced <# a [[river]] in [[Romania]], [[Prahova River]]> with <# {{place|ro|river|c/Romania|riv/Prahova River}}>
#     Page 3934468 Râul Prahova: Replaced <# a [[river]] in [[Romania]], [[Prahova River]]> with <# {{place|ro|river|c/Romania|riv/Prahova River}}>
#     Page 5566762 La Grange: Replaced <# a [[commune]] in {{l|en|Doubs}} Department, [[France]].> with <# {{place|en|commune|dept/Doubs Department|c/France}}.>
#     Page 5588910 Irkut: Replaced <# A river in [[Buryatia]] and the [[Irkutsk]] Oblast in [[Russia]].> with <# {{place|en|river|obl/Buryatia and the Irkutsk Oblast|c/Russia}}.>
#     Page 5642551 Sedan: Replaced <# a [[commune]] in {{l|en|Ardennes}} Department, [[France]].> with <# {{place|en|commune|dept/Ardennes Department|c/France}}.>
#     Page 817573 Bullock: Replaced <# An {{l|en|unincorporated}} {{l|en|community}} in {{l|en|Burlington County}} and {{l|en|Ocean County}} in the U.S. state of {{l|en|New Jersey}}.> with <# {{place|en|unincorporated community|co/Burlington County and Ocean County|s/New Jersey}}.>
#     Page 34305 Cherokee: Replaced <# A census-designated place in {{l|en|Swain County}} and {{l|en|Jackson County}}, {{l|en|North Carolina}}.> with <# {{place|en|census-designated place|co/Swain County and Jackson County|s/North Carolina}}.>
#     Page 5440547 Cherokee Village: Replaced <# A {{l|en|city}} in {{l|en|Fulton County}} and {{l|en|Sharp County}}, {{l|en|Arkansas}}.> with <# {{place|en|city|co/Fulton County and Sharp County|s/Arkansas}}.>
# 28. Find cases where "in northern" etc. occurs directly before c/USA and change to
#     "in the north of" etc. because c/USA gets rendered as "the United States".
# 29. [DONE] Allow multiple qualifiers, e.g. "small unincorporated".
# 30. [DONE] When backing off, break at '(that|which|where|near|located|situated)'.
# 31. [DONE] Handle 'Foo and Bar Counties'.
# 32. [DONE] Manually correct the following:
#     Page 6104 Asia: Replaced <# {{l|en|Asia}} {{gloss|the continent of Asia}}> with <# {{place|ast|continent|cont/Asia|t1=Asia}}>
#     Page 375322 San Carlos: Replaced <# a [[barangay]] in [[Valencia]], [[Bukidnon]], [[Philippines]]> with <# {{place|ceb|barangay|acomm/Valencia|p/Bukidnon|c/Philippines}}>
#     Page 539873 Asya: Replaced <# [[Asia]] (the continent of Asia)> with <# {{place|ku|continent|cont/Asia|t1=Asia}}>
#     Page 638250 Австралія: Replaced <# {{l|en|Australia}} {{gloss|the continent of Australia}}> with <# {{place|uk|continent|c/Australia|t1=Australia}}>
#     Page 680646 Portuguese Guinea: Replaced <# {{senseid|en|Q2002279}} {{lb|en|historical}} A former colony of Portugal and country in Africa, now called [[Guinea-Bissau]].> with <# {{senseid|en|Q2002279}} {{lb|en|historical}} {{place|en|former colony|c/Portugal and|cont/Africa}}, now called [[Guinea-Bissau]].>
#     Page 680647 Spanish Guinea: Replaced <# {{senseid|en|Q1232509}}A former colony of Spain and country in Africa, now called [[Equatorial Guinea]].> with <# {{senseid|en|Q1232509}}{{place|en|former colony|c/Spain and|cont/Africa}}, now called [[Equatorial Guinea]].>
#     Page 1267933 ອາຊີ: Replaced <# [[Asia]] (the continent of Asia)> with <# {{place|lo|continent|cont/Asia|t1=Asia}}>
#     Page 1435963 Adjara: Replaced <# An autonomous republic of [[Georgia]] located in its southwestern corner, bordered by Turkey to the south and by the [[Black Sea]] to the west. Predominantly populated by Muslim Georgians. Capital: [[Batumi]].> with <# {{place|en|autonomous republic|s/Georgia}} located in its southwestern corner, bordered by Turkey to the south and by the [[Black Sea]] to the west. Predominantly populated by Muslim Georgians. Capital: [[Batumi]].>
#     Page 1472187 Azia: Replaced <# [[Asia]] (the continent of Asia)> with <# {{place|sq|continent|cont/Asia|t1=Asia}}>
#     Page 2888775 Portuguese Congo: Replaced <# {{lb|en|historical}} A former colony of Portugal and country in Africa, now forming the [[Cabinda]] province of [[Angola]].> with <# {{lb|en|historical}} {{place|en|former colony|c/Portugal and|cont/Africa}}, now forming the [[Cabinda]] province of [[Angola]].>
#     Page 2933246 Tonkin: Replaced <# A [[w:Gulf of Tonkin|gulf]] in the [[north]] of Vietnam> with <# {{place|en|gulf|in northern|c/Vietnam}}>
#     Page 2933246 Tonkin: Replaced <# A [[w:Gulf of Tonkin|gulf]] in the [[north]] of Vietnam> with <# {{place|fr|gulf|in northern|c/Vietnam}}>
#     Page 4744607 Ustica: Replaced <# A small [[hill]] in the [[Sabine]] country, near [[Horace]]'s villa, now [[Val d'Ustica]]> with <# {{place|la|small hill|c/Sabine}}, near [[Horace]]'s villa, now [[Val d'Ustica]]>
#     Page 5441346 Bago: Replaced <# a [[barangay]] in [[Asturias]], [[Cebu]], [[Philippines]]> with <# {{place|ceb|barangay|acomm/Asturias|p/Cebu|c/Philippines}}>
#     Page 6456983 Baye: Replaced <# a [[barangay]] in [[Asturias]], [[Cebu]], [[Philippines]]> with <# {{place|ceb|barangay|acomm/Asturias|p/Cebu|c/Philippines}}>
#     Page 6595587 Lunas: Replaced <# a [[barangay]] in [[Asturias]], [[Cebu]], [[Philippines]]> with <# {{place|ceb|barangay|acomm/Asturias|p/Cebu|c/Philippines}}>
#     Page 6595588 Saksak: Replaced <# a [[barangay]] in [[Asturias]], [[Cebu]], [[Philippines]]> with <# {{place|ceb|barangay|acomm/Asturias|p/Cebu|c/Philippines}}>
#     Page 6595601 New Bago: Replaced <# a [[barangay]] in [[Asturias]], [[Cebu]], [[Philippines]]> with <# {{place|ceb|barangay|acomm/Asturias|p/Cebu|c/Philippines}}>
#     Page 6595602 Tubigagmanok: Replaced <# a [[barangay]] in [[Asturias]], [[Cebu]], [[Philippines]]> with <# {{place|ceb|barangay|acomm/Asturias|p/Cebu|c/Philippines}}>
#     Page 6595609 Santa Rita: Replaced <# a [[barangay]] in [[Asturias]], [[Cebu]], [[Philippines]]> with <# {{place|ceb|barangay|acomm/Asturias|p/Cebu|c/Philippines}}>
#     Page 6595633 Owak: Replaced <# a [[barangay]] in [[Asturias]], [[Cebu]], [[Philippines]]> with <# {{place|ceb|barangay|acomm/Asturias|p/Cebu|c/Philippines}}>

# FIXME for module:
# 1. Make links use {{wtorw}}?
# 2. [DONE] Handle place qualifiers (small, historic, former, etc.).
# 3. [NOT DONE] Support holonym qualifiers (central, northeastern, etc.). [NOT DONE;
#    JUST PUT "in" BEFORE QUALIFIER]
# 4. [DONE] Add twp=township, pen=peninsula, arch=archipelago
# 5. [DONE] Display "Metropolitan Borough of ..." in metbor (unless already begins with Metropolitan Borough of, possibly within links); link as [[Foo|Metropolitan Borough of Foo]] unless there are already links or templates in Foo
# 6. [DONE] Display "Foo parish" for parishes (unless already ends with parish or Parish, possibly within links); link as [[Foo|Foo parish]] unless there are already links or templates in Foo
# 7. [DONE] Display "County ..." for Irish counties; link as above
# 8. Fix module to display "the" if appropriate for holonyms when directly following raw text,
#    unless "the" already occurs at the end of the raw text. Find places where this
#    causes a difference and manually verify that they are OK.
# 9. [DONE] Allow multiple qualifiers, e.g. "small unincorporated".


from collections import defaultdict

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

blib.getData()

place_qualifiers = [
  "small",
  "large",
  "major",
  "minor",
  "tiny",
  "short",
  "long",
  "important",
  "former",
  "ancient",
  "historic",
  "coastal",
  "maritime",
  "inland",
  "incorporated",
  "unincorporated",
  "autonomous",
  "fictional",
  "mythological",
  "traditional",
  "unrecognized",
  "unrecognised",
  "medieval",
  "mediaeval",
  "overseas",
  "rural",
  "urban",
]

aliased_place_qualifiers = {
  "historical": "historic",
  "seaside": "coastal",
}

place_qualifiers_with_aliases = {x: x for x in place_qualifiers}
place_qualifiers_with_aliases.update(aliased_place_qualifiers)
place_qualifiers_with_aliases_list = sorted(place_qualifiers_with_aliases.keys(), key=lambda x:-len(x))

place_types = [
  # city
  "city",
  "prefecture-level city",
  "county-level city",
  "county-administered city",
  "subprovincial city",
  "independent city",
  "home rule city",
  "port city",
  "resort city",
  "federal city",
  # town
  "town",
  "ghost town",
  "submerged ghost town",
  "market town",
  "town with bystatus",
  "harbour town",
  "harbor town",
  "port town",
  "statutory town",
  "suburban town",
  "spa town",
  "resort town",
  "township",
  "rural township",
  "mountain indigenous township",
  "resort",
  # village
  "village",
  "administrative village",
  "hamlet",
  # settlement
  "settlement",
  # municipality
  "municipality",
  "home rule municipality",
  "rural municipality",
  "island municipality",
  "municipality with city status",
  # census-designated place
  "census-designated place",
  # community
  "community",
  "rural community",
  # district
  "district",
  "subdistrict",
  "local government district",
  "local government district with borough status",
  "municipal district",
  "administrative district",
  # borough
  "borough",
  "metropolitan borough",
  "county borough",
  "London borough",
  # area
  "area",
  "residential area",
  "suburban area",
  "inner-city area",
  "urban area",
  "council area",
  # neighborhood
  "neighborhood",
  "neighbourhood",
  # seat
  "county seat",
  "parish seat",
  "borough seat",
  # capital
  "capital",
  "capital city",
  "state capital",
  "provincial capital",
  "administrative capital",
  "department capital",
  "district capital",
  "mention capital",
  "judicial capital",
  "legislative capital",
  "regional capital",
  # misc. cities
  "port",
  "seaport",
  "civil parish",
  "suburb",
  "unitary authority",
  "commune",
  "barangay",
  "kibbutz",
  # river
  "river",
  "tributary",
  "distributary",
  # misc. waterforms
  "lake",
  "bay",
  "atoll",
  "gulf",
  "sea",
  "marginal sea",
  "ocean",
  "strait",
  # misc. landforms
  "mountain",
  "mountain range",
  "valley",
  "desert",
  "forest",
  "headland",
  "hill",
  "cape",
  # larger divisions
  "county",
  "administrative county",
  "traditional county",
  "parish",
  "civil parish",
  "canton",
  "council area",
  "state",
  "separatist state",
  "province",
  "associated province",
  "subprovince",
  "department",
  "prefecture",
  "subprefecture",
  "governorate",
  "periphery",
  "regency",
  "regional unit",
  "voivodeship",
  "federal subject",
  "island",
  "group of islands",
  "chain of islands",
  "archipelago",
  "peninsula",
  "region",
  "subregion",
  "geographical region",
  "mountainous region",
  "administrative region",
  "special administrative region",
  "contregion",
  "macroregion",
  "historical region",
  "oblast",
  "okrug",
  "krai",
  "division",
  "territory",
  "external territory",
  "federal territory",
  "overseas territory",
  "dependent territory",
  "special territory",
  "collectivity",
  "special collectivity",
  "colony",
  "commandery",
  "commonwealth",
  "dependency",
  "crown dependency",
  "country",
  "island country",
  "constituent country",
  "republic",
  "polity",
  "historical polity",
  "satrapy",
  "bailiwick",
  "bishopric",
  "kingdom",
  "duchy",
  "empire",
  "continent",
  "supercontinent",
  "civilization",
  "civilisation",
]

aliased_place_types = {
  "CDP": "census-designated place",
  "home-rule municipality": "home rule municipality",
  "home-rule city": "home rule city",
  "home-rule class city": "home rule city",
  "home-rule-class city": "home rule city",
  "home rule class city": "home rule city",
  "home rule-class city": "home rule city",
  "town (with bystatus)": "town with bystatus",
  "city located": "city",
  "extinct town": "former town",
  "inner city area": "inner-city area",
  "earlier municipality": "former municipality",
  "river that flows": "river",
  "comune": "commune",
  "historical region": "historic region",
  "tributary river": "tributary",
  "port-town": "port town",
  "London Borough": "London borough",
  "departmental capital": "department capital",
  "sub-provincial city": "subprovincial city",
}

place_types_with_aliases = {x: x for x in place_types}
place_types_with_aliases.update(aliased_place_types)
place_types_with_aliases_list = sorted(place_types_with_aliases.keys(), key=lambda x:-len(x))

place_types_to_codes = {
  "archipelago": "arch",
  "country": "c",
  "province": "p",
  "region": "r",
  "state": "s",
  "borough": "bor",
  "county borough": "cobor",
  "metropolitan borough": "metbor",
  "canton": "can",
  "county": "co",
  "district": "dist",
  "division": "div",
  "department": "dept",
  "département": "dept",
  "island": "isl",
  "municipality": "mun",
  "parish": "par",
  "peninsula": "pen",
  "prefecture": "pref",
  "city": "city",
  "town": "town",
  "township": "twp",
}

continents = {
  "Europe",
  "Asia",
  "Africa",
  "North America",
  "Central America",
  "South America",
  "Oceania",
  "Antarctica",
}

regions = {
  "Middle East",
  "Caucasus",
  "Eastern Europe",
  "Central Europe",
  "Western Europe",
  "Southern Europe",
  "Southeast Asia",
  "South Asia",
  "East Asia",
  "Central Asia",
  "Western Asia",
  "Asia Minor",
  "Caribbean",
  "Polynesia",
  "Micronesia",
  "Melanesia",
  "Siberia",
  "North Africa",
  "Central Africa",
  "West Africa",
  "East Africa",
  "Southern Africa",
}

aliased_regions = {
  "central Asia": "Central Asia",
  "southern Asia": "South Asia",
  "southern Asia": "South Asia",
  "SE Asia": "Southeast Asia",
  "central Africa": "Central Africa",
  "Northern Africa": "North Africa",
  "northern Africa": "North Africa",
  "Eastern Africa": "East Africa",
  "eastern Africa": "East Africa",
  "Western Africa": "West Africa",
  "western Africa": "West Africa",
  "southern Africa": "Southern Africa",
}

regions_with_aliases = {x: x for x in regions}
regions_with_aliases.update(aliased_regions)

compass_points = [
  "eastern",
  "western",
  "northern",
  "southern",
  "northwestern",
  "northeastern",
  "southwestern",
  "southeastern",
  "central",
  "east-central",
  "west-central",
  "north-central",
  "south-central",
]

aliased_compass_points = [
  ("northwest", "northwestern"),
  ("north-western", "northwestern"),
  ("north-west", "northwestern"),
  ("NW", "northwestern"),
  ("northeast", "northeastern"),
  ("north-eastern", "northeastern"),
  ("north-east", "northeastern"),
  ("NE", "northeastern"),
  ("southwest", "southwestern"),
  ("south-western", "southwestern"),
  ("south-west", "southwestern"),
  ("SW", "southwestern"),
  ("southeast", "southeastern"),
  ("south-eastern", "southeastern"),
  ("south-east", "southeastern"),
  ("SE", "southeastern"),
  ("north of", "northern"),
  ("south of", "southern"),
  ("east of", "eastern"),
  ("west of", "western"),
  ("northeast of", "northeastern"),
  ("southeast of", "southeastern"),
  ("northwest of", "northwestern"),
  ("southwest of", "southwestern"),
  ("north-east of", "northeastern"),
  ("south-east of", "southeastern"),
  ("north-west of", "northwestern"),
  ("south-west of", "southwestern"),
  ("center of", "central"),
  ("centre of", "central"),
  ("interior of", "interior"),
  ("east central", "east-central"),
  ("west central", "west-central"),
  ("north central", "north-central"),
  ("south central", "south-central"),
  ("north", "northern"),
  ("south", "southern"),
  ("east", "eastern"),
  ("west", "western"),
]

# When attached to the first holonym, we're confident these are in the
# context of "in the north/south/east/west of", so it's OK to convert these
# to "northern" etc. When attached to later holonyms, it's currently not easy
# to tell if they are in the context of "in the north of" or in the context
# "north of", and in the latter case we don't want to convert to "northern",
# so we err on the side of conservatism and always reject them.
first_only_compass_points = {
  "north of",
  "south of",
  "east of",
  "west of",
  "northeast of",
  "southeast of",
  "northwest of",
  "southwest of",
  "north-east of",
  "south-east of",
  "north-west of",
  "south-west of",
}

compass_points_with_aliases = {x: x for x in compass_points}
compass_points_with_aliases.update(dict(aliased_compass_points))
compass_points_with_aliases_list = sorted(compass_points_with_aliases.keys(), key=lambda x:-len(x))

compass_points_before_coast = {
  "northern": "north",
  "southern": "south",
  "eastern": "east",
  "western": "west",
  "northeastern": "northeast",
  "southeastern": "southeast",
  "northwestern": "northwest",
  "southwestern": "southwest",
}

holonyms_with_the = {
  "Bahamas",
  "Central African Republic",
  "Comoros",
  "Republic of the Congo",
  "Democratic Republic of the Congo",
  "Czech Republic",
  "Dominican Republic",
  "Federated States of Micronesia",
  "Gambia",
  "Maldives",
  "Marshall Islands",
  "Netherlands",
  "Philippines",
  "Solomon Islands",
  "United Arab Emirates",
  "United Kingdom",
  "United States",
  "USA", # because it's converted to "United States" in the module
  "Congo",
  "Holy Roman Empire",
  "Vatican",
  "Basque Country",
  "Valencian Community",
  "Cyclades",
  "Dodecanese",
  "Caucasus",
  "North Caucasus",
  "Caribbean",
  "North Island",
  "South Island",
}

holonyms_with_the_re = "( (Peninsula|Ocean|Sea|Voivodeship)$|^(Gulf|Sea|Isle|City) )"

def holonym_needs_the(holonym):
  # Remove placetype spec from the beginning if it exists.
  holonym = re.sub("^.*?/", "", holonym)
  return holonym in holonyms_with_the or re.search(holonyms_with_the_re, holonym)

countries = {
  "Afghanistan",
  "Albania",
  "Algeria",
  "Andorra",
  "Angola",
  "Antigua and Barbuda",
  "Argentina",
  "Armenia",
  "Australia",
  "Austria",
  "Azerbaijan",
  "Bahamas",
  "Bahrain",
  "Bangladesh",
  "Barbados",
  "Belarus",
  "Belgium",
  "Belize",
  "Benin",
  "Bhutan",
  "Bolivia",
  "Bosnia and Herzegovina",
  "Botswana",
  "Brazil",
  "Brunei",
  "Bulgaria",
  "Burkina Faso",
  "Burma",
  "Burundi",
  "Cambodia",
  "Cameroon",
  "Canada",
  "Cape Verde",
  "Central African Republic",
  "Chad",
  "Chile",
  "China",
  "Colombia",
  "Comoros",
  "Costa Rica",
  "Croatia",
  "Cuba",
  "Cyprus",
  "Czech Republic",
  "Czechia",
  "Democratic Republic of the Congo",
  "Denmark",
  "Djibouti",
  "Dominica",
  "Dominican Republic",
  "East Timor",
  "Ecuador",
  "Egypt",
  "El Salvador",
  "Equatorial Guinea",
  "Eritrea",
  "Estonia",
  "Ethiopia",
  "Federated States of Micronesia",
  "Fiji",
  "Finland",
  "France",
  "Gabon",
  "Gambia",
  "Georgia",
  "Germany",
  "Ghana",
  "Greece",
  "Grenada",
  "Guatemala",
  "Guinea",
  "Guinea-Bissau",
  "Guyana",
  "Haiti",
  "Honduras",
  "Hungary",
  "Iceland",
  "India",
  "Indonesia",
  "Iran",
  "Iraq",
  "Ireland",
  "Israel",
  "Italy",
  "Ivory Coast",
  "Jamaica",
  "Japan",
  "Jordan",
  "Kazakhstan",
  "Kenya",
  "Kiribati",
  "Kosovo",
  "Kuwait",
  "Kyrgyzstan",
  "Laos",
  "Latvia",
  "Lebanon",
  "Lesotho",
  "Liberia",
  "Libya",
  "Liechtenstein",
  "Lithuania",
  "Luxembourg",
  "Madagascar",
  "Malawi",
  "Malaysia",
  "Maldives",
  "Mali",
  "Malta",
  "Marshall Islands",
  "Mauritania",
  "Mauritius",
  "Mexico",
  "Moldova",
  "Monaco",
  "Mongolia",
  "Montenegro",
  "Morocco",
  "Mozambique",
  "Myanmar",
  "Namibia",
  "Nauru",
  "Nepal",
  "Netherlands",
  "New Zealand",
  "Nicaragua",
  "Niger",
  "Nigeria",
  "North Korea",
  "Norway",
  "Oman",
  "Pakistan",
  "Palestine",
  "Palau",
  "Panama",
  "Papua New Guinea",
  "Paraguay",
  "Peru",
  "Philippines",
  "Poland",
  "Portugal",
  "Qatar",
  "Republic of the Congo",
  "Romania",
  "Russia",
  "Rwanda",
  "Saint Kitts and Nevis",
  "Saint Lucia",
  "Saint Vincent and the Grenadines",
  "Samoa",
  "San Marino",
  "São Tomé and Príncipe",
  "Saudi Arabia",
  "Senegal",
  "Serbia",
  "Seychelles",
  "Sierra Leone",
  "Singapore",
  "Slovakia",
  "Slovenia",
  "Solomon Islands",
  "Somalia",
  "South Africa",
  "South Korea",
  "South Sudan",
  "Spain",
  "Sri Lanka",
  "Sudan",
  "Suriname",
  "Swaziland",
  "Sweden",
  "Switzerland",
  "Syria",
  "Taiwan",
  "Tajikistan",
  "Tanzania",
  "Thailand",
  "Togo",
  "Tonga",
  "Trinidad and Tobago",
  "Tunisia",
  "Turkey",
  "Turkmenistan",
  "Tuvalu",
  "Uganda",
  "Ukraine",
  "United Arab Emirates",
  "United Kingdom",
  "Uruguay",
  "Uzbekistan",
  "Vanuatu",
  "Vatican City",
  "Venezuela",
  "Vietnam",
  "Western Sahara",
  "Yemen",
  "Zambia",
  "Zimbabwe",
}

aliased_countries = {
  "US": "USA",
  "U.S.": "USA",
  "U.S": "USA",
  "USA": "USA",
  "U.S.A.": "USA",
  "U.S.A": "USA",
  "United States": "USA",
  "United States of America": "USA",
  "UK": "United Kingdom",
  "UAE": "United Arab Emirates",
  "North Macedonia": "North Macedonia",
  "Republic of North Macedonia": "North Macedonia",
  "Republic of Macedonia": "North Macedonia",
  "Congo": "Democratic Republic of the Congo",
  "Republic of Ireland": "Ireland",
  "Republic of Armenia": "Armenia",
}

countries_with_aliases = {x: x for x in countries}
countries_with_aliases.update(aliased_countries)

us_states = {
  "Alabama",
  "Alaska",
  "Arizona",
  "Arkansas",
  "California",
  "Colorado",
  "Connecticut",
  "Delaware",
  "Florida",
  "Georgia",
  "Hawaii",
  "Idaho",
  "Illinois",
  "Indiana",
  "Iowa",
  "Kansas",
  "Kentucky",
  "Louisiana",
  "Maine",
  "Maryland",
  "Massachusetts",
  "Michigan",
  "Minnesota",
  "Mississippi",
  "Missouri",
  "Montana",
  "Nebraska",
  "Nevada",
  "New Hampshire",
  "New Jersey",
  "New Mexico",
  "New York",
  "North Carolina",
  "North Dakota",
  "Ohio",
  "Oklahoma",
  "Oregon",
  "Pennsylvania",
  "Rhode Island",
  "South Carolina",
  "South Dakota",
  "Tennessee",
  "Texas",
  "Utah",
  "Vermont",
  "Virginia",
  "Washington",
  "West Virginia",
  "Wisconsin",
  "Wyoming",
}

canadian_provinces_and_territories = {
  "Alberta": "p",
  "British Columbia": "p",
  "Manitoba": "p",
  "New Brunswick": "p",
  "Newfoundland and Labrador": "p",
  "Northwest Territories": "terr",
  "Nova Scotia": "p",
  "Nunavut": "terr",
  "Ontario": "p",
  "Prince Edward Island": "p",
  "Saskatchewan": "p",
  "Quebec": "p",
  "Yukon": "terr",
}

australian_states_and_territories = {
  "New South Wales": "s",
  "Northern Territory": "terr",
  "Queensland": "s",
  "South Australia": "s",
  "Tasmania": "s",
  "Victoria": "s",
  "Western Australia": "s",
}

chinese_provinces_and_autonomous_regions = {
  "Anhui": "p",
  "Fujian": "p",
  "Gansu": "p",
  "Guangdong": "p",
  "Guangxi": "ar",
  "Guizhou": "p",
  "Hainan": "p",
  "Hebei": "p",
  "Heilongjiang": "p",
  "Henan": "p",
  "Hubei": "p",
  "Hunan": "p",
  "Inner Mongolia": "ar",
  "Jiangsu": "p",
  "Jiangxi": "p",
  "Jilin": "p",
  "Liaoning": "p",
  "Ningxia": "ar",
  "Qinghai": "p",
  "Shaanxi": "p",
  "Shandong": "p",
  "Shanxi": "p",
  "Sichuan": "p",
  "Tibet": "ar",
  "Xinjiang": "ar",
  "Yunnan": "p",
  "Zhejiang": "p",
}

japanese_prefectures = {
  "Aichi",
  "Akita",
  "Aomori",
  "Chiba",
  "Ehime",
  "Fukui",
  "Fukuoka",
  "Fukushima",
  "Gifu",
  "Gunma",
  "Hiroshima",
  "Hokkaido",
  "Hyōgo",
  "Ibaraki",
  "Ishikawa",
  "Iwate",
  "Kagawa",
  "Kagoshima",
  "Kanagawa",
  "Kōchi",
  "Kumamoto",
  "Kyoto",
  "Mie",
  "Miyagi",
  "Miyazaki",
  "Nagano",
  "Nagasaki",
  "Nara",
  "Niigata",
  "Ōita",
  "Okayama",
  "Okinawa",
  "Osaka",
  "Saga",
  "Saitama",
  "Shiga",
  "Shimane",
  "Shizuoka",
  "Tochigi",
  "Tokushima",
  "Tottori",
  "Toyama",
  "Wakayama",
  "Yamagata",
  "Yamaguchi",
  "Yamanashi",
}

german_states = {
  "Baden-Württemberg",
  "Bavaria",
  "Berlin",
  "Brandenburg",
  "Bremen",
  "Hamburg",
  "Hesse",
  "Lower Saxony",
  "Mecklenburg-Vorpommern",
  "North Rhine-Westphalia",
  "Rhineland-Palatinate",
  "Saarland",
  "Saxony",
  "Saxony-Anhalt",
  "Schleswig-Holstein",
  "Thuringia",
}

aliased_german_states = {
  "Mecklenburg-Western Pomerania": "Mecklenburg-Vorpommern",
}

german_states_with_aliases = {x: x for x in german_states}
german_states_with_aliases.update(aliased_german_states)

norwegian_counties = {
  "Østfold",
  "Akershus",
  "Oslo",
  "Hedmark",
  "Oppland",
  "Buskerud",
  "Vestfold",
  "Telemark",
  "Aust-Agder",
  "Vest-Agder",
  "Rogaland",
  "Hordaland",
  "Sogn og Fjordane",
  "Møre og Romsdal",
  "Nordland",
  "Troms",
  "Finnmark",
  "Trøndelag",
}

finnish_regions = {
  "Lapland",
  "North Ostrobothnia",
  "Kainuu",
  "North Karelia",
  "Northern Savonia",
  "Southern Savonia",
  "South Karelia",
  "Central Finland",
  "South Ostrobothnia",
  "Ostrobothnia",
  "Central Ostrobothnia",
  "Pirkanmaa",
  "Satakunta",
  "Päijänne Tavastia",
  "Tavastia Proper",
  "Kymenlaakso",
  "Uusimaa",
  "Southwest Finland",
  "Åland Islands",
}

aliased_finnish_regions = {
  "Northern Ostrobothnia": "North Ostrobothnia",
  "Southern Ostrobothnia": "South Ostrobothnia",
  "North Savo": "Northern Savonia",
  "South Savo": "Southern Savonia",
  "Päijät-Häme": "Päijänne Tavastia",
  "Kanta-Häme": "Tavastia Proper",
  "Åland": "Åland Islands",
}

finnish_regions_with_aliases = {x: x for x in finnish_regions}
finnish_regions_with_aliases.update(aliased_finnish_regions)

uk_constituents = {
  "England": "cc",
  "Scotland": "cc",
  "Wales": "cc",
  "Northern Ireland": "p",
}

english_counties = {
  "Avon", # no longer
  "Bedfordshire",
  "Berkshire",
  "Brighton and Hove", # city
  "Bristol", # city
  "Buckinghamshire",
  "Cambridgeshire",
  "Cambridgeshire and Isle of Ely", # no longer
  "Cheshire",
  #"Cleveland", # no longer; conflicts with city in US
  "Cornwall",
  "Cumberland",
  "Cumbria",
  "Derbyshire",
  "Devon",
  "Dorset",
  "County Durham",
  "Durham",
  "East Suffolk", # no longer
  "East Sussex",
  "Essex",
  "Gloucestershire",
  "Greater London",
  "Greater Manchester",
  "Hampshire",
  "Hereford and Worcester", # no longer
  "Herefordshire", 
  "Hertfordshire",
  "Humberside", # no longer
  "Huntingdon and Peterborough", # no longer
  "Huntingdonshire", # no longer
  "Isle of Ely", # no longer
  "Isle of Wight",
  "Kent",
  "Lancashire",
  "Leicestershire",
  "Lincolnshire",
  "County of London",
  "Merseyside",
  "Middlesex", # no longer
  "Norfolk",
  "Northamptonshire",
  "Northumberland",
  "North Humberside", # no longer
  "North Yorkshire",
  "Nottinghamshire",
  "Oxfordshire",
  "Soke of Peterborough", # no longer
  "Rutland",
  "Shropshire",
  "Somerset",
  "South Humberside",
  "South Yorkshire",
  "Staffordshire",
  "Suffolk",
  "Surrey",
  "Sussex", # no longer
  "Tyne and Wear",
  "Warwickshire",
  "West Midlands",
  "Westmorland", # no longer
  "West Suffolk", # no longer
  "West Sussex",
  "West Yorkshire",
  "Wiltshire",
  "Worcestershire",
  "Yorkshire", # no longer
  "East Riding of Yorkshire",
  "North Riding of Yorkshire", # no longer
  "West Riding of Yorkshire", # no longer
}

northern_ireland_counties = {
  "Antrim",
  "Armagh",
  "City of Belfast",
  "Down",
  "Fermanagh",
  "Londonderry",
  "City of Derry",
  "Tyrone",
}

scotland_council_areas = {
  "City of Glasgow",
  "City of Edinburgh",
  "Fife",
  "North Lanarkshire",
  "South Lanarkshire",
  "Aberdeenshire",
  "Highland",
  "City of Aberdeen",
  "West Lothian",
  "Renfrewshire",
  "Falkirk",
  "Perth and Kinross",
  "Dumfries and Galloway",
  "City of Dundee",
  "North Ayrshire",
  "East Ayrshire",
  "Angus",
  "Scottish Borders",
  "South Ayrshire",
  "East Dunbartonshire",
  "East Lothian",
  "Moray",
  "East Renfrewshire",
  "Stirling",
  "Midlothian",
  "West Dunbartonshire",
  "Argyll and Bute",
  "Inverclyde",
  "Clackmannanshire",
  "Na h-Eileanan Siar",
  "Shetland Islands",
  "Orkney Islands",
}

welsh_counties_etc = {
  "Blaenau Gwent": "cobor",
  "Bridgend": "cobor",
  "Caerphilly": "cobor",
  # "Cardiff": "city",
  "Carmarthenshire": "co",
  "Ceredigion": "co",
  "Conwy": "cobor",
  "Denbighshire": "co",
  "Flintshire": "co",
  "Gwynedd": "co",
  "Isle of Anglesey": "co",
  "Merthyr Tydfil": "cobor",
  "Monmouthshire": "co",
  "Neath Port Talbot": "cobor",
  # "Newport": "city",
  "Pembrokeshire": "co",
  "Powys": "co",
  "Rhondda Cynon Taf": "cobor",
  # "Swansea": "city",
  "Torfaen": "cobor",
  "Vale of Glamorgan": "cobor",
  "Wrexham": "cobor",
}

austrian_states = {
  "Vienna",
  "Lower Austria",
  "Upper Austria",
  "Styria",
  "Tyrol",
  "Carinthia",
  "Salzburg",
  "Vorarlberg",
  "Burgenland",
}

italian_regions = {
  "Abruzzo": "r",
  "Aosta Valley": "r",
  "Apulia": "r",
  "Basilicata": "r",
  "Calabria": "r",
  "Campania": "r",
  "Emilia-Romagna": "r",
  "Friuli-Venezia Giulia": "r",
  "Lazio": "r",
  "Liguria": "r",
  "Lombardy": "r",
  "Marche": "r",
  "Molise": "r",
  "Piedmont": "r",
  "Sardinia": "r",
  "Sicily": "r",
  "Trentino-Alto Adige": "r",
  "South Tyrol": "p",
  "Tuscany": "r",
  "Umbria": "r",
  "Veneto": "r",
}

indian_states_and_union_territories = {
  "Andaman and Nicobar Islands": "uterr",
  "Andhra Pradesh": "s",
  "Arunachal Pradesh": "s",
  "Assam": "s",
  "Bihar": "s",
  "Chandigarh": "uterr",
  "Chhattisgarh": "s",
  "Dadra and Nagar Haveli": "uterr",
  "Daman and Diu": "uterr",
  "Delhi": "uterr",
  "Goa": "s",
  "Gujarat": "s",
  "Haryana": "s",
  "Himachal Pradesh": "s",
  "Jammu and Kashmir": "uterr",
  "Jharkhand": "s",
  "Karnataka": "s",
  "Kerala": "s",
  "Ladakh": "uterr",
  "Lakshadweep": "uterr",
  "Madhya Pradesh": "s",
  "Maharashtra": "s",
  "Manipur": "s",
  "Meghalaya": "s",
  "Mizoram": "s",
  "Nagaland": "s",
  "Odisha": "s",
  "Puducherry": "uterr",
  "Punjab": "s",
  "Rajasthan": "s",
  "Sikkim": "s",
  "Tamil Nadu": "s",
  "Telangana": "s",
  "Tripura": "s",
  "Uttar Pradesh": "s",
  "Uttarakhand": "s",
  "West Bengal": "s",
}

philippine_provinces = {
  "Abra",
  "Agusan del Norte",
  "Agusan del Sur",
  "Aklan",
  "Albay",
  "Antique",
  "Apayao",
  "Aurora",
  "Basilan",
  "Bataan",
  "Batanes",
  "Batangas",
  "Benguet",
  "Biliran",
  "Bohol",
  "Bukidnon",
  "Bulacan",
  "Cagayan",
  "Camarines Norte",
  "Camarines Sur",
  "Camiguin",
  "Capiz",
  "Catanduanes",
  "Cavite",
  "Cebu",
  "Cotabato",
  "Davao de Oro",
  "Davao del Norte",
  "Davao del Sur",
  "Davao Occidental",
  "Davao Oriental",
  "Dinagat Islands",
  "Eastern Samar",
  "Guimaras",
  "Ifugao",
  "Ilocos Norte",
  "Ilocos Sur",
  "Iloilo",
  "Isabela",
  "Kalinga",
  "La Union",
  "Laguna",
  "Lanao del Norte",
  "Lanao del Sur",
  "Leyte",
  "Maguindanao",
  "Marinduque",
  "Masbate",
  "Misamis Occidental",
  "Misamis Oriental",
  "Mountain Province",
  "Negros Occidental",
  "Negros Oriental",
  "Northern Samar",
  "Nueva Ecija",
  "Nueva Vizcaya",
  "Occidental Mindoro",
  "Oriental Mindoro",
  "Palawan",
  "Pampanga",
  "Pangasinan",
  "Quezon",
  "Quirino",
  "Rizal",
  "Romblon",
  "Samar",
  "Sarangani",
  "Siquijor",
  "Sorsogon",
  "South Cotabato",
  "Southern Leyte",
  "Sultan Kudarat",
  "Sulu",
  "Surigao del Norte",
  "Surigao del Sur",
  "Tarlac",
  "Tawi-Tawi",
  "Zambales",
  "Zamboanga del Norte",
  "Zamboanga del Sur",
  "Zamboanga Sibugay",
  "Metro Manila",
}

irish_counties = {
  "Carlow",
  "Cavan",
  "Clare",
  "Cork",
  "Donegal",
  "Dublin",
  "Galway",
  "Kerry",
  "Kildare",
  "Kilkenny",
  "Laois",
  "Leitrim",
  "Limerick",
  "Longford",
  "Louth",
  "Mayo",
  "Meath",
  "Monaghan",
  "Offaly",
  "Roscommon",
  "Sligo",
  "Tipperary",
  "Waterford",
  "Westmeath",
  "Wexford",
  "Wicklow",
}

spanish_autonomous_communities = {
  "Andalusia",
  "Aragon",
  "Asturias",
  "Balearic Islands",
  "Basque Country",
  "Canary Islands",
  "Cantabria",
  "Castile and León",
  "Castilla-La Mancha",
  "Catalonia",
  "Community of Madrid",
  "Extremadura",
  "Galicia",
  "La Rioja",
  "Murcia",
  "Navarre",
  "Valencia",
}

roman_provinces = {
  # only include cases that are more or less unambiguously provinces rather than regions
  "Hispania Baetica",
  "Hispania Tarraconensis",
  "Lusitania",
  "Gallia Narbonensis",
  "Gallia Cisalpina",
  "Gallia Belgica",
  "Gallia Transpadana",
  "Gallia Lugdunensis",
  "Britannia",
  "Aquitania",
  "Latium",
  "Pannonia",
  "Noricum",
}

# "mentioned by Pliny", "mentioned by Arrian" etc.
ancient_mentioned_regions = {
  "Arabia",
  "Bithynia",
  "Mauritania",
  "Caria",
  "Mysia",
  "India",
  "Pontus",
  "Cilicia",
  "Aeolis",
  "Syria",
  "Asia",
  "Lycia",
  "Ionia",
  "Mesopotamia",
  "Phoenicia",
  "Thrace",
  "Africa",
  # "Ganges",
  # "Iazyges",
  "Gedrosia",
  "Carmania",
  "Numidia",
  "Phrygia",
  "Sarmatia",
  "Hyrcania",
  "India",
  # "Elymais",
  "Persia",
  "Cyrenaica",
  "Albania",
  "Cyprus",
  "Armenia",
  "Crete",
  "Ariana",
  "Tauric Chersonesus",
  "Macedonia",
  "Aetolia",
  "Assyria",
  "Germany",
  "Paphlagonia",
  "Susiana",
  "Dalmatia",
}

aliased_ancient_mentioned_regions = {
  "Lybia": "Libya",
  "Mauritania": "Mauretania",
  "Asian Scythia": "Scythia",
  "Bactriana": "Bactria",
}

ancient_mentioned_regions_with_aliases = {x: x for x in ancient_mentioned_regions}
ancient_mentioned_regions_with_aliases.update(aliased_ancient_mentioned_regions)

misc_places = {
  "London": "city",
  "Greater London": "co",
  "Sydney": "city",
  "Melbourne": "city",
  "Perth": "city",
  "Beijing": "city",
  "Calgary": "city",
  "Liverpool": "city",
  "New York City": "city",
  "Glasgow": "city",
  "San Francisco": "city",
  "Edmonton": "city",
  "Toronto": "city",
  "Rome": "city",
  "Louisville": "city",
  "Tokyo": "city",
  "Boston": "city",
  "Lucerne": "city",
  "Johannesburg": "city",
  "Birmingham": "city",
  "Chicago": "city",
  "Manchester": "city",
  "Seattle": "city",
  "Los Angeles": "city",
  "Athens": "city",
  "Adelaide": "city",
  "Rio de Janeiro": "city",
  "Philadelphia": "city",
  "Minneapolis": "city",
  "Stockholm": "city",
  "Warrington": "city",
  "Baltimore": "city",
  "Chengdu": "city",
  "Paris": "city",
  "Chongqing": "city",
  "Portland": "city",
  "Naples": "city",
  "Istanbul": "city",
  "Stockport": "city",
  "Warsaw": "city",
  "Trentino": "p",
  "Shanghai": "city",
  "Edinburgh": "city",
  "Ticino": "can",
  "Palermo": "city",
  "Veracruz": "s",
  "Cape Town": "city",
  "Tbilisi": "city",
  "Zaragoza": "city", # check this
  "Townsville": "city",
  "São Paulo": "city",
  "Winnipeg": "city",
  "Aleppo": "city",
  "Miami": "city",
  "Keelung City": "city",
  "Canberra": "city",
  "Paphlagonia": "r",
  "Moscow": "city",
  "Atlanta": "city",
  "Barcelona": "city",
  "Providence": "city",
  "St. Louis": "city",
  "Cádiz": "city",
  "Budapest": "city",
  "Kaohsiung": "city",
  "Nashville": "city",
  "Roanoke": "city",
  "Cardiff": "city",
  "Cambridge": "city",
  "Dalian": "city",
  "Ottawa": "city",
  "New Orleans": "city",
  "Cincinnati": "city",
  "Brisbane": "city",
  "Halifax": "city",
  "Southampton": "city",
  "Wellington": "city",
  "Shrewsbury": "city",
  "Cairo": "city",
  "Guangzhou": "city",
  "Montreal": "city",
  "Saskatoon": "city",
  "Montevideo": "city",
  "Ho Chi Minh City": "city",
  "Taipei": "city",
  "Portsmouth": "city",
  "Leicester": "city",
  "Sheffield": "city",
  "Córdoba": "city",
  "Suizhou": "city",
  "Prague": "city",
  "Cairns": "city",
  "Manhattan": "bor",
  "Brooklyn": "bor",
  "Queens": "bor",
  "Bronx": "bor",
  "Oaxaca": "s",
  "Scandinavia": "r",
  "Bohemia": "r",
  "Moravia": "r",
  "Alsace": "r",
  # ancient and historical regions
  "Lucania": "r",
  "Cilicia": "r",
  "Cappadocia": "r",
  "Phoenicia": "r",
  "Anatolia": "r",
  "Mesopotamia": "r",
  "Aetolia": "r",
  "Etruria": "r",
  "Mysia": "r",
  "Dalmatia": "r", # also a Roman province
  "Slavonia": "r",
  "Istria": "r", # also a peninsula
  # "Attica": ambiguously ancient region/peninsula, modern administrative region of Greece
  # "Thessaly": ambiguously ancient region, modern administrative region of Greece
  # "Epirus": ambiguously ancient region, modern administrative region of Greece
  # "Crete": ambiguously ancient island, modern administrative region of Greece
  # "Peloponnese": ambiguously ancient island, modern administrative region of Greece
  # "Boeotia": ambiguously ancient region, modern regional unit of Greece
  # "Euboea": ambiguously ancient island, modern regional unit of Greece
  # "Arcadia": ambiguously ancient region, modern regional unit of Greece
  # "Laconia": ambiguously ancient region, modern regional unit of Greece
  # "Crimea": ambiguously ancient region/peninsula, modern autonomous republic of Ukraine, modern republic of Russia
  # "Numidia": ambiguously ancient kingdom, Roman province
  # "Bithynia": ambiguously ancient region and kingdom, later part of the Roman province of Bithynia et Pontus
  # "Pontus": ambiguously ancient region and kingdom, later part of the Roman province of Bithynia et Pontus
  "Hong Kong": "sar",
  "Macau": "sar",
  "New Taipei": "city",
  "Courland": "r",
  "Ofoten": "dist",
  "Elis": "dist",
  "Epirus": "r",
  "Samnium": "r",
  "South Gloucestershire": "unitary authority",
  "Ariège": "dept",
  "Lofoten": "dist",
  "Vicenza": "city",
  "Gwynedd": "co",
  "Bruttium": "r",
  # Argolis: ambiguously ancient region, modern regional unit of Greece
  "Brittany": "r",
  "Picenum": "r",
  "Dacia": "r",
  # Phocis: ambiguously ancient region, modern regional unit of Greece
  # Messenia: ambiguously ancient region, modern regional unit of Greece
  # Eurasia
  # Balkans
  "South Wales": "r",
  "Cheshire East": "unitary authority",
  "French Guiana": "overseas department",
  "Wallonia": "r",
  "Normandy": "r",
  "KwaZulu-Natal": "p",
  "Troas": "r",
  "Sarmatia": "r",
  "Acarnania": "r",
  "Caria": "r",
  "Western Norway": "r",
  "Eastern Norway": "r",
  "Cyclades": "arch",
  "Puglia": "r",
  # Chalcidice: ambiguously peninsula, modern regional unit of Greece
  "Pallars Jussà": "co",
  "Dodecanese": "arch",
  "Chersonesus": "colony",
  "Abkhazia": "c",
  "West Bank": "r",
  "Burgundy": "r",
  # Cities in Cebu
  "Cebu City": "city",
  "Bogo": "city",
  "Mandaue": "city",
  "San Remigio": "mun",
  "Naga": "city",
  "Talisay": "city",
  "Liloan": "mun",
}

unrecognized_place_types = defaultdict(int)
recognized_place_types = defaultdict(int)
unrecognized_holonyms = defaultdict(int)
recognized_holonyms = defaultdict(int)
recognized_lines = 0
unparsable_lines = 0
unrecognized_placetype_lines = 0
unrecognized_holonym_lines = 0
multiple_repls_lines = 0
total_lines = 0
total_parsable_lines = 0

def output_stats(num_counts):
  if total_parsable_lines > 0:
    msg("Recognized lines: %s (%.2f%% of parsable)" % (recognized_lines, (100.0 * recognized_lines) / total_parsable_lines))
    msg("Unrecognized placetype lines: %s (%.2f%% of parsable)" % (unrecognized_placetype_lines, (100.0 * unrecognized_placetype_lines) / total_parsable_lines))
    msg("Unrecognized holonym lines: %s (%.2f%% of parsable)" % (unrecognized_holonym_lines, (100.0 * unrecognized_holonym_lines) / total_parsable_lines))
    msg("Lines with multiple repls the same: %s (%.2f%% of parsable)" % (multiple_repls_lines, (100.0 * multiple_repls_lines) / total_parsable_lines))
  if total_lines > 0:
    msg("Unparsable lines: %s (%.2f%% of total)" % (unparsable_lines, (100.0 * unparsable_lines) / total_lines))
  def output_counts(dic):
    by_count = sorted(dic.items(), key=lambda x:-x[1])
    by_count = by_count[0:num_counts]
    for k, v in by_count:
      msg("%s = %s" % (k, v))
  msg("Unrecognized place types:")
  msg("-------------------------")
  output_counts(unrecognized_place_types)
  msg("Unrecognized holonyms:")
  msg("----------------------")
  output_counts(unrecognized_holonyms)
  msg("Recognized place types:")
  msg("-------------------------")
  output_counts(recognized_place_types)
  msg("Recognized holonyms:")
  msg("----------------------")
  output_counts(recognized_holonyms)

# Compute the list of all uppercase Unicode characters, see
# https://stackoverflow.com/questions/36187349/python-regex-for-unicode-capitalized-words
pLu = u'[{}]'.format("".join([unichr(i) for i in range(sys.maxunicode) if unichr(i).isupper()]))
proper_noun_word_regex = r"(?u)%s[\w'.-]*" % pLu
# The following regex requires that the first word of a county/parish/borough name be capitalized
# and contain only letters, hyphens (Stratford-on-Avon), apostrophes (King's Lynn) and periods
# (St. Louis), and remaining words must either be of the same format or be "and" (Tyne and Wear,
# Lewis and Clark), "and the" (Saint Vincent and the Grenadines), "of" (Isle of Wight), "of the",
# "upon" (Newcastle upon Tyne), "de" (Rio de Janeiro), "du" (Fond du Lac County), "del" (Tierra del Fuego),
# "la" (Andorra la Vella, Pays de la Loire), "am" (Offenbach am Main), "in der" (Weiden in der Oberpfalz,
# Landau in der Pfalz), "an der" (Brandenburg an der Havel), "es" (Dar es Salaam), "op" (Bergen op Zoom).
# This should catch cases like
# -- co/Missouri which is one of the two county seats of Jackson County
# -- co/Han dynasty southwest of Xiyang County
proper_noun_regex = "(?:%s)(?: +(?:%s|and|and the|of|of the|upon|de|du|del|la|am|in der|an der|es|op))*" % (
  proper_noun_word_regex, proper_noun_word_regex)

def inner_parse_holonym(holonym, all_holonyms):
  # US etc. Do '... Island' later because of 'Prince Edward Island' (should be province not island).
  if holonym in us_states:
    # Do states before countries because of Georgia.
    return "s/" + holonym
  normalized_holonym = re.sub(" [Ss]tate$", "", holonym)
  if normalized_holonym in us_states:
    return "s/" + normalized_holonym
  normalized_holonym = re.sub(r"^(US|U\.S\. +)?state of ", "", holonym)
  if normalized_holonym in us_states:
    return "s/" + normalized_holonym
  # UK
  if holonym in uk_constituents:
    return "%s/%s" % (uk_constituents[holonym], holonym)
  if holonym in english_counties:
    return "co/" + holonym
  if holonym in northern_ireland_counties:
    return "co/" + holonym
  normalized_holonym = re.sub("^[Cc]ounty +", "", holonym)
  if normalized_holonym in northern_ireland_counties:
    return "co/" + normalized_holonym
  if holonym in scotland_council_areas:
    return "council area/" + holonym
  normalized_holonym = re.sub(" [Cc]ouncil +[Aa]rea$", "", holonym)
  if normalized_holonym in scotland_council_areas:
    return "council area/" + normalized_holonym
  normalized_holonym = re.sub(" [Cc]ouncil +[Aa]rea +of +Scotland$", "", holonym)
  if normalized_holonym in scotland_council_areas:
    return ["council area/" + normalized_holonym, "cc/Scotland"]
  if holonym in welsh_counties_etc:
    return "%s/%s" % (welsh_counties_etc[holonym], holonym)
  # Borough of Ealing, Borough of Slough, Borough of Tower Hamlets, Borough of Hinckley and Bosworth,
  # borough of Chesterfield, borough of North Tyneside, etc.
  m = re.search("^[Bb]orough +of +(%s)$" % proper_noun_regex, holonym)
  if m:
    return "bor/%s" % m.group(1)
  m = re.search("^[Mm]etropolitan +[Bb]orough +of +(%s)$" % proper_noun_regex, holonym)
  if m:
    return "metbor/%s" % m.group(1)
  # London Borough of Ealing, London Borough of Hammersmith and Fulham, etc.
  m = re.search("^[Ll]ondon +[Bb]orough +of +(%s)$" % proper_noun_regex, holonym)
  if m:
    if "Greater London" in all_holonyms:
      return "lbor/%s" % m.group(1)
    else:
      return ["lbor/%s" % m.group(1), "co/Greater London"]
  # city of Manchester, city of Sydney, city of Fremont (California), city of Thunder Bay (Ontario), etc.
  # NOTE: capitalized City can refer to other things, e.g. City of Melville (local government area)
  m = re.search("^city +of +(%s)$" % proper_noun_regex, holonym)
  if m:
    return "city/%s" % m.group(1)
  # countries
  if holonym in countries_with_aliases:
    return "c/" + countries_with_aliases[holonym]
  # continents
  if holonym in continents:
    return "cont/" + holonym
  # regions
  if holonym in regions_with_aliases:
    return "r/" + regions_with_aliases[holonym]
  # Australia
  if holonym in australian_states_and_territories:
    return "%s/%s" % (australian_states_and_territories[holonym], holonym)
  # Austria
  if holonym in austrian_states:
    return "s/%s" % holonym
  # Canada
  if holonym in canadian_provinces_and_territories:
    return "%s/%s" % (canadian_provinces_and_territories[holonym], holonym)
  # China
  if holonym in chinese_provinces_and_autonomous_regions:
    return "%s/%s" % (chinese_provinces_and_autonomous_regions[holonym], holonym)
  normalized_holonym = re.sub(" +([Pp]rovince|[Aa]utonomous +[Rr]egion)$", "", holonym)
  if normalized_holonym in chinese_provinces_and_autonomous_regions:
    return "%s/%s" % (chinese_provinces_and_autonomous_regions[normalized_holonym], normalized_holonym)
  # Finland
  if holonym in finnish_regions_with_aliases:
    return "r/" + finnish_regions_with_aliases[holonym]
  normalized_holonym = re.sub("^region +of +", "", holonym)
  if normalized_holonym in finnish_regions_with_aliases:
    return "r/" + finnish_regions_with_aliases[normalized_holonym]
  # France
  if m:
    return "dept/%s" % m.group(1)
  m = re.search("^(%s) +(?:department|département) +of +France$" % proper_noun_regex, holonym)
  if m:
    return ["dept/%s" % m.group(1), "c/France"]
  # Germany
  if holonym in german_states_with_aliases:
    return "s/%s" % german_states_with_aliases[holonym]
  # India
  if holonym in indian_states_and_union_territories:
    return "%s/%s" % (indian_states_and_union_territories[holonym], holonym)
  normalized_holonym = re.sub("^(Indian +)?state +of +", "", holonym)
  if normalized_holonym in indian_states_and_union_territories:
    return "%s/%s" % (indian_states_and_union_territories[normalized_holonym], normalized_holonym)
  # Ireland
  if holonym in irish_counties:
    return "co/" + holonym
  normalized_holonym = re.sub("^[Cc]ounty +", "", holonym)
  if normalized_holonym in irish_counties:
    return "co/" + normalized_holonym
  # Italy
  if holonym in italian_regions:
    return "%s/%s" % (italian_regions[holonym], holonym)
  # Check for "Perugia province of Umbria". Allow "the" before region name because of "the Veneto".
  m = re.search("^(%s) +province +of +(?:the +)?(%s)$" % (proper_noun_regex, proper_noun_regex), holonym)
  if m and m.group(2) in italian_regions:
    return ["p/%s" % m.group(1), "%s/%s" % (italian_regions[m.group(2)], m.group(2))]
  # Japan
  if holonym in japanese_prefectures:
    return "pref/%s" % holonym
  normalized_holonym = re.sub(" +([Pp]refecture)$", "", holonym)
  if normalized_holonym in japanese_prefectures:
    return "pref/%s" % normalized_holonym
  # Norway
  if holonym in norwegian_counties:
    return "co/%s" % holonym
  normalized_holonym = re.sub(" +county$", "", holonym)
  if normalized_holonym in norwegian_counties:
    return "co/%s" % normalized_holonym
  # Philippines
  if holonym in philippine_provinces:
    return "p/%s" % holonym
  # Spain
  if holonym in spanish_autonomous_communities:
    return "acomm/%s" % holonym
  # Ancient Rome, etc.
  if holonym in roman_provinces:
    return "p/%s" % holonym
  m = re.search("^(%s) (mentioned +by +.*)$" % proper_noun_regex, holonym)
  if m:
    normalized_holonym, mentioned_by = m.groups()
    if normalized_holonym in ancient_mentioned_regions_with_aliases:
      return ["r/%s" % ancient_mentioned_regions_with_aliases[normalized_holonym], mentioned_by]
  # Misc places
  if holonym in misc_places:
    return "%s/%s" % (misc_places[holonym], holonym)
  # Recognize "(the) Foo province" etc.
  coded_place_type_regex = "|".join(re.escape(x) for x in place_types_to_codes.keys())
  m = re.search("^(%s) (%s)$" % (proper_noun_regex, coded_place_type_regex), holonym)
  if m:
    bare_holonym, placetype = m.groups()
    return "%s/%s" % (place_types_to_codes[placetype], bare_holonym)
  # Recognize "(the) province of Foo", "(the) province Foo", etc.
  m = re.search("^(%s) +(?:of +)?(%s)$" % (coded_place_type_regex, proper_noun_regex), holonym)
  if m:
    placetype, bare_holonym = m.groups()
    return "%s/%s" % (place_types_to_codes[placetype], bare_holonym)
  # Recognize holonyms with the placetype in the name itself, e.g.
  # 'Meadow Township', 'Chaffee County'.
  m = re.search("^%s +(County|Parish|Borough|Township|State|Province|Oblast|Voivodeship|Department|Autonomous Region|Region|Peninsula|Ocean|Sea|Island|River)$" % proper_noun_regex, holonym)
  if m:
    placetype = {"County": "co", "Parish": "par", "Borough": "bor", "Township": "twp", "State": "s",
      "Province": "p", "Oblast": "obl", "Voivodeship": "voi", "Department": "dept", "Autonomous Region": "ar",
      "Region": "r", "Peninsula": "pen", "Ocean": "ocean", "Sea": "sea", "Island": "isl",
      "River": "riv",
    }[m.group(1)]
    return "%s/%s" % (placetype, m.group(0))
  # Recognize 'Contra Costa and Alameda Counties' etc.
  m = re.search("^(%s) +and +(%s) +Counties$" % (proper_noun_regex, proper_noun_regex), holonym)
  if m:
    county1, county2 = m.groups()
    return ["co/%s County" % county1, "and", "co/%s County" % county2]
  # Recognize 'Ticino canton of Switzerland' etc. Note, we don't include 'state' because of things like
  # 'German state of Bremen', 'Brazilian state of Mato Grosso do Sul', 'US state of Alabama', etc.
  # There are also such things as 'Canadian province of Ontario' but they will be rejected by the
  # check for double provinces/countries/etc.
  m = re.search("^(%s) +(district|region|canton|borough|province) +of +(?:the +)?(%s)$" % (proper_noun_regex, proper_noun_regex),
    holonym)
  if m:
    subdiv, subdiv_type, div = m.groups()
    div_holonym = parse_holonym(div, all_holonyms)
    if div_holonym:
      if type(div_holonym) is not list:
        div_holonym = [div_holonym]
      return ["%s/%s" % (place_types_to_codes[subdiv_type], subdiv)] + div_holonym
  return None

def parse_holonym(holonym, all_holonyms):
  m = re.search("^(modern|modern-day) +(.*)$", holonym)
  if m:
    modern, holonym = m.groups()
    holonym = inner_parse_holonym(holonym, all_holonyms)
    if holonym is None:
      return None
    if type(holonym) is not list:
      holonym = [holonym]
    return ["in " + modern] + holonym
  else:
    return inner_parse_holonym(holonym, all_holonyms)

class DoubleReplException(Exception):
  pass

def strip_wikicode(text, record_links_dict, pagemsg):
  def record_link(m, replnum):
    orig = m.group(0)
    repl = m.group(replnum)
    if record_links_dict is not None:
      if repl in record_links_dict:
        pagemsg("WARNING: Saw holonym %s twice with links (original %s)" % (repl, orig))
        raise DoubleReplException
      record_links_dict[repl] = orig
    return repl
  def record_link_1(m):
    return record_link(m, 1)
  def record_link_2(m):
    return record_link(m, 2)
  try:
    text = re.sub(r"(''+)(.*?)\1", record_link_2, text)
    text = re.sub(r"\{\{l\|(?:en|n[bno])\|(?:[^{}|\[\]]*?\|)?([^{}|\[\]]+?)\}\}", record_link_1, text)
    text = re.sub(r"\{\{w\|(?:[^{}|\[\]]*?\|)?([^{}|\[\]]+?)\}\}", record_link_1, text)
    text = re.sub(r"\[\[w:(?:[^{}|\[\]]*?\|)?([^{}|\[\]]+?)\]\]", record_link_1, text)
    text = re.sub(r"\[\[(?:[^{}|\[\]]*?\|)?([^{}|\[\]]+?)\]\]", record_link_1, text)
  except DoubleReplException:
    return None
  return text

def restore_links(text, record_links_dict, pagemsg, wikipedia_only=False):
  # Put back original links. Abort if anything goes wrong (e.g. two replacements when one expected).
  for repl, orig in record_links_dict.iteritems():
    if repl in text and (not wikipedia_only or re.search(r"^\{\{w\||\[\[w:", orig)):
      text, did_replace = blib.replace_in_text(text, repl, orig, pagemsg, abort_if_warning=True)
      if not did_replace:
        return None
  return text

def remove_links_from_topics(text):
  def remove_links(m):
    return blib.remove_links(m.group(0))
  return re.sub(r"\{\{(topics|topic|top|C|c)\|.*?\}\}", remove_links, text)

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  origtext = text
  notes = []
  if index % 250000 == 0:
    output_stats(100)
  if re.search("^[a-z]", pagetitle):
    return text, notes

  # Main function to templatize a given line. This is a regex function called from the regex at the bottom
  # that checks for any line containing any of the known place types.
  def templatize_place_line(m, langcode):
    global recognized_lines
    global unparsable_lines
    global unrecognized_placetype_lines
    global unrecognized_holonym_lines
    global multiple_repls_lines
    global total_lines
    global total_parsable_lines
    total_lines += 1
    origline = m.group(0)
    linelen = len(origline)
    if linelen > 5000:
      # Page 4967143 [[Module:User:IsomorphycSandbox/testmodule/reverse index]] is over 1,000,000 chars in length,
      # and the script gets stuck as the loop below that successively chops off endings is O(N^2) in the number
      # of segments.
      pagemsg("Skipping overly long line (%s chars): %s..." % (linelen, origline[0:5000]))
      return origline
    line = origline
    postline = ""
    status = None
    badlines = []

    # Replacement for pagemsg() that stores the message instead of outputting it directly.
    # The outputted message has <from> ORIGLINE <to> ORIGLINE <end> at the end (used by
    # push_manual_changes.py) in case we want to manually fix up some bad lines.
    def append_pagemsg(txt):
      newline = "Page %s %s: %s: <from> %s <to> %s <end>" % (
          index, pagetitle, txt, origline, origline)
      if newline not in badlines:
        badlines.append(newline)

    # Track recognized and unrecognized place types and holonyms.
    this_unrecognized_place_types = set()
    this_recognized_place_types = set()
    this_unrecognized_holonyms = set()
    this_recognized_holonyms = set()
    def add_this_to_all():
      for pt in this_unrecognized_place_types:
        unrecognized_place_types[pt] += 1
      for pt in this_recognized_place_types:
        recognized_place_types[pt] += 1
      for h in this_unrecognized_holonyms:
        unrecognized_holonyms[h] += 1
      for h in this_recognized_holonyms:
        recognized_holonyms[h] += 1

    while True: # Loop over smaller sections of the line, chopping from the right
      while True: # "Loop" to simulate goto with break
        record_links_dict = {}
        cap_officials = []

        # Check for and strip off capital, official name, county/parish/borough seat
        chopped_line = strip_wikicode(line, record_links_dict, append_pagemsg)
        if chopped_line is None:
          status = "multiple repls"
          multiple_repls_lines += 1
          break

        def cap_official_type_to_param(cap_official_type):
          cap_official_type = cap_official_type.lower()
          if cap_official_type == "capital":
            return "capital"
          elif cap_official_type == "official name":
            return "official"
          else:
            return "seat"

        # Try successively to strip off capital, official name, or county/parish/borough seat specs
        # from the right.
        while True:
          # Check for the format "with the capital in Foo" or similar.
          m = re.search(r"^(.*[^,.;: ])(?:[,.;:] *(?:[Ww]ith +)?|[,.;:]? *[Ww]ith +)(?:[Tt]he +|[Ii]t'?s +)?([Cc]apital|[Oo]fficial [Nn]ame|[Cc]ounty [Ss]eat|[Pp]arish [Ss]eat|[Bb]orough [Ss]eat)(?: +[Ii]s(?: +in)?)?:? *(?:[Tt]he +)?(%s)(?<!\.) *((?:\)|\}\} *)?[,.;:]?) *$" % proper_noun_regex, chopped_line)
          if m:
            chopped_line, cap_official_type, cap_official_name, final_punct = m.groups()
            chopped_line += final_punct
            cap_official_param = cap_official_type_to_param(cap_official_type)
            cap_officials.append((cap_official_param, cap_official_name))
          else:
            # Check for the format "with Foo as the capital" or similar.
            m = re.search(r"^(.*[^,.;: ])[,.;:]? *(?:(?:[Ww]hich|[Tt]hat) +[Hh]as +|[Ww]ith +|[Hh]aving +)(%s) +[Aa]s +(?:[Tt]he +|[Ii]t'?s +)?([Cc]apital|[Oo]fficial [Nn]ame|[Cc]ounty [Ss]eat|[Pp]arish [Ss]eat|[Bb]orough [Ss]eat) *((?:\)|\}\} *)?[,.;:]?) *$" % proper_noun_regex, chopped_line)
            if m:
              chopped_line, cap_official_name, cap_official_type, final_punct = m.groups()
              chopped_line += final_punct
              cap_official_param = cap_official_type_to_param(cap_official_type)
              cap_officials.append((cap_official_param, cap_official_name))
            else:
              break

        # Main regex to parse a line. We look for a definition line with a possible template at the
        # beginning (e.g. {{lb|...}}) followed by "A foo in/of Bar" (or similar), possibly followed by
        # a qualifier with {{q|...}} (used for grid coordinates and such), possibly followed by final
        # punctuation. Note that the line as parsed here may already have had stuff stripped off the
        # right (either by the code above to parse off capitals, official names, etc. or by the larger
        # loop that successively chops off extraneous stuff on the right), so we may well see a final
        # comma or other non-period punctuation.
        m = re.search(r"^(#+ *(?:\{\{.*?\}\})? *)[Aa]n? +([^{}|\n]*?) +(?:located in|situated in|in|of) +(?:the +)?(.*?)((?: *\{\{q\|[^{}]*?\}\})?) *([,.;:]?) *$", chopped_line)
        if m:
          pretext, placetype, holonyms, postq, final_period = m.groups()
          trans = None
        else:
          # Also check for the "translation" format "Foo (a/the bar in/of Baz)" (or similar); we also
          # look for "Foo {{gloss|a/the bar in/of Baz}}", "Foo; a/the bar in/of Baz" and
          # "Foo: a/the bar in/of Baz" (or similar).
          m = re.search(r"^(#+ *(?:\{\{(?:[^lw]|[lw][^|])[^{}]*?\}\} *)*)([^();:]+?) *([(;:]|\{\{gloss\|) *(?:[Tt]he |[Aa]n? )?([^{}|\n]*?) +(?:located in|situated in|in|of) +(?:the +)?(.*?)(\)|\}\})?((?: *\{\{q\|[^{}]*?\}\})?) *\.? *$", chopped_line)
          if not m:
            status = status or "unparsable"
            #append_pagemsg("WARNING: Unable to parse line")
            break
          pretext, trans, opener, placetype, holonyms, closer, postq = m.groups()
          # Ignore a final period, which shouldn't be present in this format. Note that in the case
          # where text follows and is chopped off in the outer loop, any punctuation before the text
          # (including a period) will be chopped off as well, so this won't wrongly remove periods.
          final_period = ""
          if opener not in [";", ":"] and not closer:
            # Reject the case where a left paren or "{{gloss|" opener occurs without a closer.
            # If we don't do that, we will wrongly replace things like
            # {{l|en|Offenbach am Main}} ([[independent city]] in [[Hesse]], Germany, next to the river [[Main]])
            # with
            # {{place|de|independent city|s/Hesse|c/Germany|t1=Offenbach am Main}}, next to the river [[Main]])
            status = status or "unparsable"
            #append_pagemsg("WARNING: Unable to parse line")
            break
        pretext = restore_links(pretext, record_links_dict, append_pagemsg)
        if pretext is None:
          status = "multiple repls"
          multiple_repls_lines += 1
          break
        # restore_links may wrongly add bare links inside of {{topics}} etc. if the same bare links occur elsewhere.
        # The following hack corrects this.
        pretext = remove_links_from_topics(pretext)
        postq = restore_links(postq, record_links_dict, append_pagemsg)
        if postq is None:
          status = "multiple repls"
          multiple_repls_lines += 1
          break
        postq = remove_links_from_topics(postq)
        if trans:
          if not re.search("^(?:the )?%s$" % proper_noun_regex, trans):
            status = status or "unparsable"
            append_pagemsg("WARNING: Bad format for translation '%s'" % trans)
            break

        ####### Handle placetypes.
        split_placetype = re.split("(?:/| and (?:the |an? )?)", placetype)
        split_placetype_with_quals = []
        outer_break = False
        coast_spec = None
        for i, pt in enumerate(split_placetype):
          # Check for "island off the coast", "port city on the west coast", etc.
          m = re.search("^(.*?),? +(?:situated +|located +)?(off|on) +the +(?:(%s) +)?coast$" % "|".join(re.escape(x) for x in compass_points_with_aliases_list), pt)
          if m:
            pt, offon, compass_point = m.groups()
            if compass_point:
              compass_point = compass_points_with_aliases[compass_point]
              compass_point = compass_points_before_coast.get(compass_point, compass_point)
              coast_spec = "%s the %s coast of" % (offon, compass_point)
            else:
              coast_spec = "%s the coast of" % offon
          if coast_spec and i != len(split_placetype) - 1:
            append_pagemsg("WARNING: Coast spec '%s' cannot occur with non-final placetype in '%s'" % (coast_spec, placetype))
            status = status or "bad placetype"
            outer_break = True
            break

          # Check for qualifiers if placetype isn't recognized.
          pt_quals = []
          if pt not in place_types_with_aliases:
            # Successively peel off qualifiers at the beginning.
            while True:
              m = re.search("^(%s) +(.*)$" % "|".join(re.escape(x) for x in place_qualifiers_with_aliases_list), pt)
              if m:
                pt_qual, pt = m.groups()
                pt_qual = place_qualifiers_with_aliases[pt_qual]
                pt_quals.append(pt_qual)
              else:
                break
            if pt not in place_types_with_aliases:
              this_unrecognized_place_types.add(pt)
              append_pagemsg("WARNING: Unable to recognize stripped placetype '%s'" % pt)
              status = status or "bad placetype"
              outer_break = True
              break

          # Append qualifiers and bare placetype to split_placetype_with_quals.
          split_placetype_with_quals.append((pt_quals, pt))
          this_recognized_place_types.add(pt)
          for i in range(len(pt_quals)):
            this_recognized_place_types.add("%s %s" % (" ".join(pt_quals[i:]), pt))

        if outer_break:
          break

        ####### Handle holonyms.
        holonyms = re.sub(",? *(?:and |(?:that|which) is )?(?:the )?(county|parish|borough) seat of ", r", \1 seat, ", holonyms)
        # Handle "A city in and the county seat of ...".
        m = re.search("^, (county|parish|borough) seat, (.*)$", holonyms)
        if m:
          split_placetype_with_quals.append((None, "%s seat" % m.group(1)))
          holonyms = m.group(2)
        holonyms = re.sub(",? in (?:the )?", ", ", holonyms)
        holonyms = re.split(", *", holonyms)
        parsed_holonyms = []

        def add_to_parsed_holonyms(parsed_holonym):
          if type(parsed_holonym) is list:
            parsed_holonyms.extend(parsed_holonym)
            for ph in parsed_holonym:
              this_recognized_holonyms.add(ph)
          else:
            parsed_holonyms.append(parsed_holonym)
            this_recognized_holonyms.add(parsed_holonym)

        outer_break = False
        for holonym_index, holonym in enumerate(holonyms):
          if holonym in ["county seat", "parish seat", "borough seat"]:
            add_to_parsed_holonyms(";")
            add_to_parsed_holonyms(holonym)
          else:
            bad_holonym = False
            parsed_holonym = parse_holonym(holonym, holonyms)
            if parsed_holonym:
              add_to_parsed_holonyms(parsed_holonym)
            else:
              m = re.search("^(%s) +(?:the +)?(.*)$" % "|".join(re.escape(x) for x in compass_points_with_aliases_list), holonym)
              if m:
                compass_point, base_holonym = m.groups()
                if holonym_index > 0 and compass_point in first_only_compass_points:
                  bad_holonym = True
                else:
                  compass_term = compass_points_with_aliases[compass_point]
                  parsed_holonym = parse_holonym(base_holonym, holonyms)
                  if parsed_holonym:
                    first_parsed_holonym = parsed_holonym[0] if type(parsed_holonym) is list else parsed_holonym
                    if holonym_needs_the(first_parsed_holonym):
                      add_to_parsed_holonyms("in the " + compass_term)
                    else:
                      add_to_parsed_holonyms("in " + compass_term)
                    add_to_parsed_holonyms(parsed_holonym)
                  else:
                    bad_holonym = True
                    holonym = base_holonym
              else:
                bad_holonym = True
            if bad_holonym:
              status = status or "bad holonym"
              this_unrecognized_holonyms.add(holonym)
              append_pagemsg("WARNING: Unable to recognize stripped holonym '%s'" % holonym)
              outer_break = True
              break
        if outer_break:
          break

        def normalize_placetype(pt_quals, pt):
          pt_qual_text = " ".join(pt_quals) + " " if pt_quals else ""
          return pt_qual_text + place_types_with_aliases[pt]
        normalized_placetypes = [normalize_placetype(pt_quals, pt) for pt_quals, pt in split_placetype_with_quals]
        if len(normalized_placetypes) >= 2:
          if re.search("^(county|parish|borough) +seat$", normalized_placetypes[-1]):
            normalized_placetype = "/".join(normalized_placetypes)
          else:
            normalized_placetype = "/".join(normalized_placetypes[0:-1]) + "/and/" + normalized_placetypes[-1]
        else:
          normalized_placetype = normalized_placetypes[0]
        if not normalized_placetype or not parsed_holonyms:
          break

        # A coast spec is "off the coast of" or similar. If it occurs and the first holonym begins with "in ",
        # remove that preposition, or we'll get {{place|en|large island|off the coast of|in eastern|c/Canada}}.
        # If it occurs and the first holonym requires "the", we need to add "the" to the coast spec.
        if coast_spec:
          if parsed_holonyms[0].startswith("in "):
            parsed_holonyms[0] = parsed_holonyms[0][3:]
          if holonym_needs_the(parsed_holonyms[0]):
            coast_spec += " the"
        placeargs = [normalized_placetype] + ([coast_spec] if coast_spec else []) + parsed_holonyms
        # Now, split place args by semicolon-separated "runs".
        place_args_runs = []
        place_args_run = []
        for arg in placeargs:
          if arg == ";":
            if place_args_run:
              place_args_runs.append(place_args_run)
            place_args_run = []
          else:
            place_args_run.append(arg)
        if place_args_run:
          place_args_runs.append(place_args_run)

        # Loop over runs.
        outer_break = False
        for run in place_args_runs:
          # Check for missing holonym. Currently can only happen with special code
          # that converts "county seat" holonyms into placetypes.
          if len(run) == 1:
            append_pagemsg("WARNING: Missing holonym")
            status = status or "bad holonym"
            outer_break = True
            break

          # Check for same holonym placetype occurring twice (e.g. due to a "foo, bar and baz" list).
          seen_holonym_placetypes = {}
          inner_break = False
          for holonym in run[1:]:
            if holonym == "and":
              # If we see 'and', don't further check for duplicates because they might be intentional,
              # as in 'Contra Costa and Alameda Counties', which we handle specially.
              break
            if "/" not in holonym:
              continue
            holonym_placetype, holonym_placename = holonym.split("/")
            if holonym_placetype in seen_holonym_placetypes:
              append_pagemsg("WARNING: Saw holonym placetype twice in %s and %s" % (
                seen_holonym_placetypes[holonym_placetype], holonym))
              status = status or "bad holonym"
              inner_break = True
              outer_break = True
              break
            seen_holonym_placetypes[holonym_placetype] = holonym
          if inner_break:
            break

          # If country occurs before country subdivision, switch them. If multiple country subdivisions
          # follow, the country will bubble to the end.
          for i in range(2, len(run)):
            if re.search("^(c|cc)/", run[i - 1]) and (
              re.search("^(p|s|voi|bor|cobor|metbor|lbor|can|co|par|dist|div|dept|isl|mun|pref|city|town)/", run[i])
            ) or run[i - 1].startswith("c/") and run[i].startswith("cc/"):
              # Look for "in ..." preceding the country and swap it too.
              if i > 2 and run[i - 2].startswith("in "):
                temp = run[i]
                run[i] = run[i - 1]
                run[i - 1] = run[i - 2]
                run[i - 2] = temp
              else:
                temp = run[i]
                run[i] = run[i - 1]
                run[i - 1] = temp

          # If country is followed by region, sea, ocean or continent, insert "in".
          if len(run) >= 3 and re.search("^(c|cc)/", run[-2]) and re.search("^(r|sea|ocean|cont)/", run[-1]):
            if holonym_needs_the(run[-1]):
              run[-1:-1] = ["in the"]
            else:
              run[-1:-1] = ["in"]

        if outer_break:
          break

        # Now rejoin runs into place_args.
        place_args = []
        outer_break = False
        for run in place_args_runs:
          placetype = run[0]
          holonyms = "|".join(run[1:])
          holonyms = restore_links(holonyms, record_links_dict, append_pagemsg, wikipedia_only=True)
          if holonyms is None:
            status = "multiple repls"
            multiple_repls_lines += 1
            outer_break = True
            break
          if place_args:
            place_args.append(";")
          place_args.append(placetype)
          place_args.append(holonyms)
        if outer_break:
          break

        # Construct new place template.
        joined_place_args = "|".join(place_args)
        cap_official_params = []
        for param, val in cap_officials:
          cap_official_params.append("|%s=%s" % (param, val))
        cap_official_str = "".join(cap_official_params)
        cap_official_str = restore_links(cap_official_str, record_links_dict, append_pagemsg,
            wikipedia_only=True)
        if cap_official_str is None:
          status = "multiple repls"
          multiple_repls_lines += 1
          break
        if trans:
          trans = restore_links(trans, record_links_dict, append_pagemsg, wikipedia_only=True)
          if trans is None:
            status = "multiple repls"
            multiple_repls_lines += 1
            break
        new_place_template = "{{place|%s|%s%s%s}}" % (langcode, joined_place_args, cap_official_str,
            "|t1=%s" % trans if trans else "")

        # Construct entire line and return it.
        retval = "%s%s%s%s%s" % (pretext, new_place_template, postq, final_period, postline)
        notes.append("templatize %s place spec into {{place}}" % placetype)
        pagemsg("Replaced <%s> with <%s>" % (origline, retval))
        recognized_lines += 1
        total_parsable_lines += 1
        add_this_to_all()
        return retval

      # Break at either a punctuation mark + text, or optional punctuation mark +
      # any of (that|which|where|with|located|situated|near) + text, or a template +
      # optional text. The notation (?<!ated ) is a negative lookbehind expression
      # to prevent the word "near" matching the common expressions "situated near"
      # and "located near", otherwise "near" will match and we'll get an unrecognized
      # holonym like "Calabria situated".
      m = re.search("^(.*[^ ])( *(?:[,.:;]|[,.:;]? +(?:that|which|where|with|located|situated|(?<!ated )near)) +.+?| *\{\{[^{}]*\}\}.*?)$", line)
      if m:
        line, this_postline = m.groups()
        postline = this_postline + postline
      else:
        if status == "unparsable":
          unparsable_lines += 1
        else:
          total_parsable_lines += 1
          if status == "bad placetype":
            unrecognized_placetype_lines += 1
          elif status == "bad holonym":
            unrecognized_holonym_lines += 1
          elif status == "multiple repls":
            multiple_repls_lines += 1
          else:
            assert False
        add_this_to_all()
        for m in badlines:
          msg(m)
        return origline

  sections = re.split("(^==[^\n=]*==\n)", text, 0, re.M)
  for j in range(2, len(sections), 2):
    m = re.search("^==(.*)==\n$", sections[j - 1])
    assert m
    langname = m.group(1)
    if langname not in blib.languages_byCanonicalName:
      pagemsg("WARNING: Unrecognized language %s" % langname)
    else:
      langcode = blib.languages_byCanonicalName[langname]["code"]
      def do_templatize_place_line(m):
        return templatize_place_line(m, langcode)
      sections[j] = re.sub(r"^.*(%s).*$" % "|".join(re.escape(x) for x in place_types_with_aliases_list),
        do_templatize_place_line, sections[j], 0, re.M)
  return "".join(sections), notes

parser = blib.create_argparser("Templatize place specs into {{place}}",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
output_stats(5000)
