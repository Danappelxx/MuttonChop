# MuttonChop

[![Swift][swift-badge]][platform-url] [![Platform][platform-badge]][platform-url] [![License][mit-badge]][mit-url] [![Codebeat][codebeat-badge]][codebeat-url]

> Mutton Chops are synonymous to Sideburns. Sideburns are kind of similar to Mustaches.

Mustache templates in Swift. 100% spec compliant. Linux and macOS supported.

# Table of Contents

   * [Features](#features)
   * [Installation](#installation)
   * [Usage](#usage)
     * [Basic Template Usage](#basic-template-usage)
     * [Template Collections](#template-collections)
       * [Creation](#creation)
       * [Fetching](#fetching)
       * [Rendering](#rendering)
     * [Mustache Language](#mustache-language)
       * [Tags](#tags)
       * [Variables (Interpolation)](#variables-interpolation)
       * [Sections](#sections)
       * [Inverted Sections](#inverted-sections)
       * [Comments](#comments)
       * [Partials](#partials)
       * [Inheritance](#inheritance)
   * [Tips](#tips)
   * [Support](#support)
   * [Contributing](#contributing)
   * [License](#license)


# Features

- [x] Conforms entirely to the official [Mustache specification](https://github.com/mustache/spec).
- [x] Compiles its templates, meaning that it only parses them once. This makes it very fast.
- [x] Supports template inheritance, conforming to the [optional specification](https://github.com/mustache/spec/pull/125). Big thanks to [@groue](https://github.com/groue) for providing the inheritance algorithm.
- [x] Has template collections to make work with multiple templates convenient
- [ ] More coming soon! Do keep your eyes open.

# Installation

```swift
// Package.swift
.Package(url: "https://github.com/Danappelxx/MuttonChop.git", majorVersion: 0, minor: 5),
```

MuttonChop works best with Swift 5.4. Compatibility with previous/future snapshots/releases is not guaranteed.

# Usage

## Basic template usage

To compile a template, simply call the `Template` initializer with your template string. How you get that is up to you.

```swift
let template = try Template("Hello, {{name}}!")
```

Before we can render your template, we first have to create the context.

```swift
let context: Context = [
    "name": "Dan"
]
```

Notice how the type of context is [`Context`](https://github.com/Danappelxx/MuttonChop/blob/master/Sources/Context.swift). [`Context`](https://github.com/Danappelxx/MuttonChop/blob/master/Sources/Context.swift) is a JSON-like tree structure which conforms to [Codable](https://developer.apple.com/documentation/foundation/archives_and_serialization/encoding_and_decoding_custom_types), so you can either build it by hand or from an external source.

We can then render the template with the context like such:

```swift
let rendered = template.render(with: context)
print(rendered) // -> Hello, Dan!
```

## Template Collections

Template collections are useful when there are multiple templates which are meant to work together (for example, views in a web application).

### Creation

Template collections can be created in several ways:

```swift
// label and load templates manually
let collection = TemplateCollection(templates: [
    "one": try Template(...),
    "two": try Template(...)
])
```
```swift
// search directory for .mustache files
let collection = try TemplateCollection(directory: "/path/to/Views")
```
```swift
// search directory for .mustache and .html files
let collection = try TemplateCollection(
    directory: "/path/to/Views",
    fileExtensions: ["mustache", "html"]
)
```

### Fetching

Templates can be extracted from collections in one of two ways:

```swift
collection.templates["one"] // Template?
```
```swift
try collection.get(template: "one") // Template
```

### Rendering

Templates rendered in collections have the rest of the templates (including the template itself) registered as partials. Templates can be rendered like so:

```swift
try collection.render(template: "one", with: ["name": "Dan"])
```

## Mustache Language

Below is a comprehensive reference of the Mustache language features supported by Muttonchop. Examples are included with in each section.

### Tags

Tags are denoted by two opening braces `{{`, followed by some content, delimited by two closing braces `}}`. The first non-whitespace character inside the tag denotes the type of the tag.

The format for this section is: template, context, result. The syntax for doing all three is shown in the section above.

### Variables (Interpolation)

Interpolation tags do not have a type-denoting character. The tag is replaced with the result of its content looked up in the context stack. If the context stack does not contain its value, the tag is simply ignored.

The variable dot `{{.}}` is special, displaying the current topmost value of the context stack.

```mustache
{{ greeting }}, {{ location }}!
```

```swift
let context: Context = [
    "greeting": "Hello",
    "location": "world"
]
```

```
Hello, world!
```

### Sections

Section tags start with an opening tag (`{{# section }}`) and end with a closing tag (`{{/ section }}`). Everything between the open and closing tags is the content.

The content is only rendered if the value inside the opening/closing tags is truthy. If the value is an array, the array is iterated and the content of the section is rendered for every value. If the value is a dictionary, it is added to the context stack.

```mustache
{{# person }}
  {{ name }} is {{ age }} years old.
  Some numbers he knows are{{# numbers }} {{.}}{{/ numbers }}.
{{/ person }}
```

```swift
let context: Context = [
    "person": [
        "name": "Dan",
        "age": 16,
        "numbers": [1, 2, 3, 4, 5]
    ]
]
```

```
Dan is 16 years old.
Some numbers he knows are 1 2 3 4 5.
```

### Inverted Sections

An inverted section begins with an opening tag (`{{^ section }}`) and end with a closing tag (`{{/ section }}`). Everything between the tags is the content.

The content is only rendered if the value inside the section tag is falsy. A falsy value is either one that is not found in the context stack, or the boolean value false.

```mustache
{{^ person }}
  {{ message }}
{{/ person }}
```

```swift
let context: Context = [
    "message": "There is no person!"
]
```

```
There is no person!
```

### Comments

Comment tags (`{{! Some comment about something }}`) are not rendered, and are very useful for documenting your templates.

### Partials

A partial tag (`{{> partial }}`) inserts the contents of the template with the name of the partial in place of the tag. The partial has access to the same context stack.

Partials are passed to the template in the form of `[String:Template]` when rendering.

```swift
let person = try Template(...)
let people = try Template(...)
let partials = [
    "person": person,
    "people": people, // recursive partials are supported!
]
let rendered = people.render(with: context, partials: partials)
```

```mustache
{{! person.mustache }}
{{ name }} is {{ age }} years old.
Some numbers he knows are{{# numbers }} {{.}}{{/ numbers }}.

{{! people.mustache }}
{{# people }}
{{> person }}
{{/ people }}
```

```swift
let context: Context = [
    "people": [
        [
            "name": "Dan",
            "age": 16,
            "numbers": [1, 2, 3, 4, 5]
        ],
        [
            "name": "Kyle",
            "age": 16,
            "numbers": [6, 7, 8, 9, 10]
        ]
    ]
]
```

```mustache
Dan is 16 years old.
Some numbers he knows are 1 2 3 4 5.
Kyle is 16 years old.
Some numbers he knows are 6 7 8 9 10.
```

### Inheritance

MuttonChop supports template inheritance. This is done through a combination of two tags: the partial override tag (`{{< partial }}{{/ partial }}`) and the block tag (`{{$ block }}{{/ block }}`).

The partial override tag is similar to normal partial tag, except that blocks inside the contents _override_ the tags inside the included partial.

Blocks simply render their content. The only thing that makes them special is that they can override and be overriden by other blocks.

The code to render them is exactly the same as to render partials - put the templates in a dictionary and pass it to the `render` call.

```
{{! layout.mustache }}
The title of the page is: {{$ title }}Default title{{/ title }}!
{{$ content}}
Looks like somebody forgot to add meaningful content!
{{/ content}}

{{! page.mustache }}
{{< layout }}
    {{$ title }}{{ number }} reasons NOT to drink bleach! Number {{ special-number }} will blow your mind!{{/ title }}
{{/ layout }}
```

```swift
let context: Context [
    "number": 11,
    "special-number": 9
]
```

```
The title of the page is: 11 reasons NOT to drink bleach! Number 9 will blow your mind!!
Looks like somebody forgot to add meaningful content!
```

# Tips

Parsing is slow and unoptimized. Rendering is fast and optimized. Take advantage of the fact that MuttonChop compiles the templates and only create a single instance of a template (which you can render many times).

# Contributing

Any and all help is very welcome, I promise I won't bite. Contributing is more than just code! If you have any ideas at all, please do make an issue and/or pull request.

# License

MIT - more information is in the LICENSE file.

[codebeat-badge]: https://codebeat.co/badges/102d7671-84ec-4af2-b82c-b64844ad5e2b
[codebeat-url]: https://codebeat.co/projects/github-com-danappelxx-muttonchop
[mit-badge]: https://img.shields.io/badge/License-MIT-blue.svg?style=flat
[mit-url]: https://tldrlegal.com/license/mit-license
[platform-badge]: https://img.shields.io/badge/Platforms-macOS%20--%20Linux-lightgray.svg?style=flat
[platform-url]: https://swift.org
[swift-badge]: https://img.shields.io/badge/Swift-5.4-orange.svg?style=flat
[swift-url]: https://swift.org
