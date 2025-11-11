# Custom tag/tag domain properties example.
extends Resource


# This can select any tag in inspector.
@export_custom(PROPERTY_HINT_NONE, "DTagEdit") var tag1: StringName
# This will limit domain in "MainDomain1.Domain1":
@export_custom(PROPERTY_HINT_NONE, "DTagEdit: MainDomain1.Domain1") var tag2: StringName
# This will recognize each element as tag in inspector.
@export_custom(PROPERTY_HINT_TYPE_STRING, "%s:DTagEditor" % TYPE_STRING_NAME) var tag_list: Array[StringName]


# This can select any domain in inspector.
@export_custom(PROPERTY_HINT_NONE, "DTagDomainEdit") var tag_domain: Array[StringName]
# This will recognize each element as tag domain in inspector.
@export_custom(PROPERTY_HINT_TYPE_STRING, "%s:DTagDomainEditor" % TYPE_PACKED_STRING_ARRAY) var domain_list :Array[PackedStringArray]
