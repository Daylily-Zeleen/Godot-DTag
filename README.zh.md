# Godot - DTag

[Click here to refer English README.md](README.md).

![](icon.svg)


DTag，为 Godot 提供一个类似 Unreal Engine 中 GameplayTag 的 Tag 机制。

DTag 的本质是 `StringName` ，该插件提供了编辑器用具用于生成结构化的常量 `Dictionary`, 并提供对应的检查器插件用于选取 **Tag** 或 **Tag Domain** (注： Tag Domain 类似于命名空间的概念，namespace 已经作为 GDScript 的关键字，故使用 domain 作为同等概念)

## 注意：该项目仍处于开发中，未来可能会发生巨大变化。

## 安装:

该插件完全由 GDScript 实现，你可以像普通插件一样加入到你的项目，并在项目设置中启用 “Godot - DTag” 插件即可。

## 如何使用 (基础篇):

![](.doc/Basic.gif)


### Step1: 定义你的 Tag

除了 "res://addons/", 包括脚本的内部类在内，所有直接继承自 `DTagDefinition` 的 GDScript 类型均会被检测。

Example:
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

### Step2: 生成 tag 定义.

通过 "项目->工具->Generate dtag_def.gen.gd" 即可生成 "res://dtag_def.gen.gd"。

这是由 step1 生成的脚本.
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

### Step3: 现在你可以直接使用它.

现在你可以通过`DTagDef`直接使用它们。

```

func example() -> void:
	var example_tag1 := DTagDef.MainDomain1.Domain1.Tag1
	print(example_tag1) # Output &"MainDomain1.Domain1.Tag1"


```


## 如何使用 (进阶篇):

该插件提供编辑器插件，通过一个特殊的选择器在检查器中选择 Tag 或 Tag Domain。

### 1. 使用 `DTag` 资源

![](.doc/DTag.gif)


`DTag` 拥有 `value/tag("value"在检查器中的别名)` 和 `domain` 属性.


### 2. 使用特殊的 hint_string 与自定义属性：

![](.doc/Custom.gif)


- **DTagEdit**: 一个将 `StringName`/`String` 识别为 Tag 的 hint_string.

	- 与 `StringName`/`String` 属性一起工作的基本用法:

		```GDScript
		# This can select any tag in inspector.
		@export_custom(PROPERTY_HINT_NONE, "DTagEdit") var tag1: StringName
		```

	- 可以通过类似 "DTagEdit: MainDomain1.Domain1" 的 hint_string 来限制可选 Tag 的 Tag Domain。

		``` GDScript
		# This will limit domain in "MainDomain1.Domain1":
		@export_custom(PROPERTY_HINT_NONE, "DTagEdit: MainDomain1.Domain1") var tag2: StringName
		```

    - 它还可以与 `Array[StringName]`/`Array[String]` 类型的属性一起工作, 将数组元素在检查器中识别为 Tag:

		``` GDScript
		# This will recognize each element as tag in inspector.
		@export_custom(PROPERTY_HINT_TYPE_STRING, "%s:DTagEditor" % TYPE_STRING_NAME) var tag_list: Array[StringName]
		```

- **DTagDomainEdit**: 一个将 `Array/Array[StringName]/Array[String]/PackedStringName` 类型属性识别为 Tag Domain 的 hint_string。

	- 与 `Array/Array[StringName]/Array[String]/PackedStringName` 一起使用的基础用法:

		```GDScript
		# This can select any domain in inspector.
		@export_custom(PROPERTY_HINT_NONE, "DTagDomainEdit") var tag_domain: Array[StringName]
		```

    - 与 `Array[Array]`/`Array[PackedStringArray]` 类型的属性一起工作，将数组元素在检查器中识别为 Tag Domain:

		```GDScript
		# This will recognize each element as tag domain in inspector.
        @export_custom(PROPERTY_HINT_TYPE_STRING, "%s:DTagDomainEditor" % TYPE_PACKED_STRING_ARRAY) var domain_list :Array[PackedStringArray]
		```
