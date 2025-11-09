# Godot - DTag

[Click here to refer English README.md](README.md).

![](icon.svg)


DTag，为 Godot 提供一个类似 Unreal Engine 中 GameplayTag 的 Tag 机制。

### 注意：该项目仍处于开发中，未来可能会发生巨大变化。

## 特性：
- DTag 的本质是 `StringName`。
- 通过文本文件（以".dtag"作为文件扩展名）进行定义，在godot的脚本编辑器中提供语法高亮与语法检查。
- 提供编辑器工具用于生成定义脚本用于在代码中访问，并支持自定义的代码生成器生成不同的语言的定义代码段。
- 提供检查其插件用于选取 **Tag** 或 **Tag Domain** (注： Tag Domain 类似于命名空间的概念，namespace 已经作为 GDScript 的关键字，故使用 domain 作为同等概念)。
- 支持 **Tag** 或 **Tag Domain** 的重定向，无需修改旧代码来指向新的目标。
- 支持添加自定义代码生成器来生成适合你的DTag定义代码，如生成 DTag 的C#定义脚本等。

## 安装:

该插件完全由 GDScript 实现，你可以像普通插件一样加入到你的项目，并在项目设置中启用 “Godot - DTag” 插件即可。

## 如何使用 (基础篇):

![](.doc/Basic.gif)


### Step1: 定义你的 Tag

除了 "res://addons/" 目录以及 "." 开头的文件之外，所有以 ".dtag" 作为扩展名的文本文件都将被识别为 DTag 的定义文件。

".dtag" 的语法规则非常简单：
- 使用 "@" 作为 Domain 标识符的前缀
- 使用制表符定义层级。
- 使用 "->" 进行重定向。
- 使用 "#" 作为注释。
- 使用 "##" 作为特定域或标签的注释。
- Tag 和 Tag Domain 必须是有效的标识符。
- 子级 Domain 必须定义在 父级 Domain 的 Tag 之后。

每行的具体语法顺序如下([]中为可选内容)
```
[@]DomainOrTag [-> Redirect.To.New.DomainOrTag] [## Any comment of this domain or Tag]
```

即使不熟悉语法也没关系，在Godot的脚本编辑器中编辑 ".dtag" 文件时会进行解析并提供错误信息，相信你可以很快上手

示例:
```
# res://example/example.dtag
# Use "@" as the prefix for tag Domain.
# Use tabs to define hierarchy.
# Use "->" for redirection.
# Use "#" for comments.
# Use "##" for comments on specific domains or tags.
# Tags and Tag Domains must be valid identifiers.
# Child Domains must be defined after the parent Domain's Tags.
#
# Syntax: Content of "[]" are optional.
# [@]DomainOrTag [-> Redirect.To.New.DomainOrTag] [## Any comment of this domain or Tag]
#
# Example:
# @MainDomain ## Description of main Domain.
# 	Tag ## "Domain.Tag", tag should be defined before sub-domain.
# 	@SubDomain -> NewDomain ## This sub-domain will be redirected to "NewDomain", its tag will be redirected automatically.
# 		SubTag1 ## This tag will be redirected to "NewDomain.SubTag1" automatically.
# 		SubTag2 -> NewDomain.Tag ## This tag will be redirected to "NewDomain.Tag" manually.

TagWithoutDomain ## Tag without domain
TagWithoutDomain1 ## Tag without domain1


@MainDomain ## Desc
	Tag1 -> RedirectTo.New.Tag ## Desc
	@Domain -> RedirectTo.New.Domain ## Desc
		Tag2 ## Will be redirected to "RedirectTo.New.Domain.Tag2"
		Tag3 ## Will be redirected to "RedirectTo.New.Domain.Tag3"


@RedirectTo ## Sample redirect domain.
	@New
		Tag
		@Domain
			Tag1
			Tag2
			Tag3

```

### Step2: 生成 tag 定义.

通过 "项目->工具->Generate dtag_def.gen.gd" 即可生成 Tag 的定义代码段，其中 GDScript 用的 "res://dtag_def.gen.gd" 作为编辑器工具的依赖必然会被生成。

这是由 step1 的 "example.dtag" 生成的脚本.
```GDScript
# res://dtag_def.gen.gd
# NOTE: This file is generated, any modify maybe discard.
class_name DTagDef


## Tag without domain
const TagWithoutDomain = &"TagWithoutDomain"

## Tag without domain1
const TagWithoutDomain1 = &"TagWithoutDomain1"

## Desc
@abstract class MainDomain extends Object:
	## StringName of this domain.
	const DOMAIN_NAME = &"MainDomain"
	## Desc
	const Tag1 = &"RedirectTo.New.Tag"

	## Desc
	@abstract class Domain extends Object:
		## StringName of this domain.
		const DOMAIN_NAME = &"RedirectTo.New.Domain"
		## Will be redirected to "RedirectTo.New.Domain.Tag2"
		const Tag2 = &"RedirectTo.New.Domain.Tag2"
		## Will be redirected to "RedirectTo.New.Domain.Tag3"
		const Tag3 = &"RedirectTo.New.Domain.Tag3"


## Sample redirect domain.
@abstract class RedirectTo extends Object:
	## StringName of this domain.
	const DOMAIN_NAME = &"RedirectTo"

	@abstract class New extends Object:
		## StringName of this domain.
		const DOMAIN_NAME = &"RedirectTo.New"
		const Tag = &"RedirectTo.New.Tag"

		@abstract class Domain extends Object:
			## StringName of this domain.
			const DOMAIN_NAME = &"RedirectTo.New.Domain"
			const Tag1 = &"RedirectTo.New.Domain.Tag1"
			const Tag2 = &"RedirectTo.New.Domain.Tag2"
			const Tag3 = &"RedirectTo.New.Domain.Tag3"


# ===== Redirect map. =====
const _REDIRECT_NAP: Dictionary[StringName, StringName] = {
	&"MainDomain.Tag1" : &"RedirectTo.New.Tag",
	&"MainDomain.Domain" : &"RedirectTo.New.Domain",
	&"MainDomain.Domain.Tag2" : &"RedirectTo.New.Domain.Tag2",
	&"MainDomain.Domain.Tag3" : &"RedirectTo.New.Domain.Tag3",
}

```

### Step3: 现在你可以直接使用它.

现在你可以通过`DTagDef`直接使用它们。

```

func example() -> void:
	print(DTagDef.MainDomain.Tag1)
	print(DTagDef.MainDomain.Domain.Tag2)

```


## 如何使用 (进阶篇):

该插件提供编辑器插件，通过一个特殊的选择器在检查器中选择 Tag 或 Tag Domain。

### 1. 使用 `DTag` 资源

![](.doc/DTag.gif)


`DTag` 拥有 `value/tag("tag"为"value"在检查器中的别名)` 和 `domain` 属性.


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

### 3. 对于传入的 StringName, 可使用 `DTag.redirect()` 确保重定向至最新的目标。

> **NOTE: 典型的使用场景是使用导出的 dtag 属性时确保其重定向至最新目标。**

```GDScript
......
@export_custom(PROPERTY_HINT_NONE, "DTagEdit") var tag: StringName
......
	var redirected_target := DTag.redirect(tag)
......
```

### 4. 添加自定义的代码生成器

可以通过项目设置中的 "DTag/basic/code_generators” 选项添加自定义的代码生成器，如生成 DTag 的C#定义脚本等。
自定义代码生成器必须标记为工具脚本，且拥有一个签名为`func generate(parse_result: Dictionary[String, RefCounted], redirect_map: Dictionary[String, String]) -> String` 的生成函数，返回值为生成的文件路径。

示例：（仅输出解析结果的键作为演示，具体请参考 "res://addons/dtag.daylily-zeleen/generater/gen_dtag_def_gdscript.gd"）
```GDScript
# res://example/example_generator.gd
@tool # Tool annotation is required

func generate(parse_result: Dictionary[String, RefCounted], redirect_map: Dictionary[String, String]) -> String:
	for k in parse_result:
		print(k)

	return ""

```