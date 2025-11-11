## Custom tag/tag domain properties example.
@tool # NOTE: to enable redirection in editor.
extends Resource


@export_group("Tag")
## Select any tag in inspector.
@export_custom(PROPERTY_HINT_NONE, "DTagEdit") var tag1: StringName
## Select tag in "MainDomain1.Domain1":
@export_custom(PROPERTY_HINT_NONE, "DTagEdit: MainDomain.Domain") var tag2: StringName
## Recognize each element as tag in inspector.
@export_custom(PROPERTY_HINT_TYPE_STRING, "%s:DTagEditor" % TYPE_STRING_NAME) var tag_list: Array[StringName]


@export_group("Tag Domain")
## Select any domain (String/StringName).
@export_custom(PROPERTY_HINT_NONE, "DTagDomainEdit") var tag_domain_text: StringName
## Select domain with limitation (String/StringName).
@export_custom(PROPERTY_HINT_NONE, "DTagDomainEdit: MainDomain") var tag_domain_text_with_limit: StringName
## Recognize each element as tag domain in inspector (String/StringName).
@export_custom(PROPERTY_HINT_NONE, "%s:DTagDomainEditor" % TYPE_STRING_NAME) var tag_domain_text_list: Array[StringName]
## Select any domain in inspector (Array/Array[StringName]/PackedStringArray).
@export_custom(PROPERTY_HINT_NONE, "DTagDomainEdit") var tag_domain_array: Array[StringName]
## Recognize each element as tag domain in inspector (Array/Array[StringName]/PackedStringArray).
@export_custom(PROPERTY_HINT_TYPE_STRING, "%s:DTagDomainEditor" % TYPE_PACKED_STRING_ARRAY) var tag_domain_array_list :Array[PackedStringArray]


## NOTE: for custom properties of tag or tag domain, recommend to use "DTag.redirect()"
@export_group("Recommend")
## Select any tag in inspector with redirection.
@export_custom(PROPERTY_HINT_NONE, "DTagEdit") var tag_with_redirect: StringName:
	set(v):
		tag_with_redirect = DTag.redirect(v)
## Select any domain in inspector with redirection.
@export_custom(PROPERTY_HINT_NONE, "DTagDomainEdit") var domain_with_redirect: StringName:
	set(v):
		domain_with_redirect = DTag.redirect(v)
