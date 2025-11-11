class_name DTagDefinition

# Example:
# const MainDomain1 = {
# 	Domain1 = {
# 		Tag1 = "Example tag1", # Case 1：Use String/StringName as value will be recognized as comment in generated script.
# 		Tag2 = null, # Case 2：Use "null" as value will be recognized as tag, too.
# 	},
# 	Tag3 = "", # Case 3：Empty string as value will be recognized as tag, too.
# }

# class InternalClass extends DTagDefinition:
# 	const MainDomain2 = {
# 		Domain2 = {
# 			Tag1 = "Example tag",
# 			Tag2 = "Example tag",
# 		}
# 	}
