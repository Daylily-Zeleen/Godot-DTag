# Godot - DTag

[点击此处查看中文自述文件。](README.zh.md) 

![](icon.svg)


DTag, a tool for creating tag like "GameplayTag" in Unreal Engine.

The essence of DTag is `StringName`, this plugin provide tool to generate structured constant `Dictionary`, and provide editor inspector plugin to select **tag** and **tag domain**.

## NOTE: This project is still under development, it may undergo significant changes in the future.

## Install:

This plugin is fully implemented by GDScript. You can plugin it in your project like general plugin and enabled "Godot - DTag" in project setting.

## How to use (Basic):

![](.doc/Basic.gif)


### Step1: Define your tags.

Exclude "res://addons/", including internal class in GDScript, any type which extends from `DTagDefinition` will be scanned.

For example:
```GDScript
# res://dtag_example.gd
extends DTagDefinition

const MainDomain1 = {
	Domain1 = {
		Tag1 = "Example tag1", # Case 1：Use String/StringName as value will be recognized as comment in generated script.
		Tag2 = null, # Case 2：Use "null" as value will be recognized as tag, too.
	},
	Tag3 = "", # Case 3：Empty string as value will be recognized as tag, too.
}

class InternalClass extends DTagDefinition:
	const MainDomain2 = {
		Domain2 = {
			Tag1 = "Example tag",
			Tag2 = "Example tag",
		}
	}
...

```

### Step2: Generate tag def.

Generate "res://dtag_def.gen.gd" by using tool "Project->Tool->Generate dtag_def.gen.gd".

Here is the generated file of step1.
```GDScript
# res://dtag_def.gen.gd
# NOTE: This file is generated, any modify maybe discard.
class_name DTagDef


const MainDomain1 = {
	Domain1 = {
		## Example tag1
		Tag1 = &"MainDomain1.Domain1.Tag1",
		Tag2 = &"MainDomain1.Domain1.Tag2",
	},
	Tag3 = &"MainDomain1.Tag3",
}

```

### Step3: Just use it.

Now you can use tags through `DTagDef`.

```

func example() -> void:
	var example_tag1 := DTagDef.MainDomain1.Domain1.Tag1
	print(example_tag1) # Output &"MainDomain1.Domain1.Tag1"


```


## How to use (Advance):

This plugin provide an EditorInspectorPlugin to edit tag/tag domain through inspector by using a special selector.

### 1. Use resource `DTag`

![](.doc/DTag.gif)


`DTag` has properties `value/tag(alias of "value" for inspector)` and `domain`.


### 2. Custom property with specific hint_string:

![](.doc/Custom.gif)


- **DTagEdit**: A hint string to recognize a `StringName`/`String` property as tag.

	- Basically work with `StringName`/`String` property:

		```GDScript
		# This can select any tag in inspector.
		@export_custom(PROPERTY_HINT_NONE, "DTagEdit") var tag1: StringName
		```

	- You can specific tag's domain, for example, Use "DTagEdit: MainDomain1.Domain1", you can limit choices in the domain "MainDomain1.Domain1".

		``` GDScript
		# This will limit domain in "MainDomain1.Domain1":
		@export_custom(PROPERTY_HINT_NONE, "DTagEdit: MainDomain1.Domain1") var tag2: StringName
		```

    - It can work with `Array[StringName]`/`Array[String]` property:

		``` GDScript
		# This will recognize each element as tag in inspector.
		@export_custom(PROPERTY_HINT_TYPE_STRING, "%s:DTagEditor" % TYPE_STRING_NAME) var tag_list: Array[StringName]
		```

- **DTagDomainEdit**: A hint string to recognize a `Array/Array[StringName]/Array[String]/PackedStringName` property as tag domain.

	- Basically work with `Array/Array[StringName]/Array[String]/PackedStringName` property:

		```GDScript
		# This can select any domain in inspector.
		@export_custom(PROPERTY_HINT_NONE, "DTagDomainEdit") var tag_domain: Array[StringName]
		```

    - It can work with `Array[Array]`/`Array[PackedStringArray]` property:

		```GDScript
		# This will recognize each element as tag domain in inspector.
        @export_custom(PROPERTY_HINT_TYPE_STRING, "%s:DTagDomainEditor" % TYPE_PACKED_STRING_ARRAY) var domain_list :Array[PackedStringArray]
		```
