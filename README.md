# Godot - DTag

![](icon.svg)

## ⚪ [Click here to detail document.](addons/dtag.daylily-zeleen/README.md)

## ⚪ [点击此处查看详细文档](addons/dtag.daylily-zeleen/README.zh.md)

---------------------------

Godot-DTag provides a Tag mechanism similar to Unreal Engine's GameplayTag for Godot.

### Note: This project is still under development and may undergo significant changes in the future

## 1. Features

- The essence of DTag is `StringName`.
- Defined through text files (with ".dtag" extension), providing syntax highlighting and syntax checking in Godot's script editor.
- Provides editor tools to generate definition scripts, and supports custom code generators to generate definition code for different languages (such as C#).
- Provides inspector plugins for selecting **Tag** or **Tag Domain** (Note: Tag Domain is similar to the concept of namespace. Since "namespace" is already a keyword in GDScript, "domain" is used as an equivalent concept).
- Allow separate tag definitions of the same domain in different ".dtag" files.
- Supports redirection of **Tag** or **Tag Domain**, no need to modify old code to point to new targets.

## 2. [Click for detail document](addons/dtag.daylily-zeleen/README.md)

---------------------------

DTag，为 Godot 提供一个类似 Unreal Engine 中 GameplayTag 的 Tag 机制。

### 注意：该项目仍处于开发中，未来可能会发生巨大变化

## 1. 特性

- DTag 的本质是 `StringName`。
- 通过文本文件（以".dtag"作为文件扩展名）进行定义，在godot的脚本编辑器中提供语法高亮与语法检查。
- 提供编辑器工具用于生成定义脚本用于在代码中访问，并支持自定义的代码生成器生成不同的语言的定义代码段。
- 提供检查其插件用于选取 **Tag** 或 **Tag Domain** (注： Tag Domain 类似于命名空间的概念，namespace 已经作为 GDScript 的关键字，故使用 domain 作为同等概念)。
- 支持在不同的".dtag" 定义同一个 Domain 中的不同 Tag。
- 支持 **Tag** 或 **Tag Domain** 的重定向，无需修改旧代码来指向新的目标。
- 支持添加自定义代码生成器来生成适合你的DTag定义代码，如生成 DTag 的C#定义脚本等。

## 2. [点击此处详细文档](addons/dtag.daylily-zeleen/README.zh.md)
