# MuttonChop

[![Swift][swift-badge]][platform-url] [![Platform][platform-badge]][platform-url] [![License][mit-badge]][mit-url] [![Travis][travis-badge]][travis-url] [![Codebeat][codebeat-badge]][codebeat-url] [![Codecov][codecov-badge]][codecov-url]

> Mutton Chops are synonymous to Sideburns. Sideburns are kind of similar to Mustaches.

Mustache templates in Swift. 100% spec compliant. OSX and Linux supported.

# Features

MuttonChop conforms entirely to the official [Mustache specification](https://github.com/mustache/spec).

MuttonChop compiles its templates, meaning that it only parses them once. This makes it is very fast.

MuttonChop supports template inheritance, conforming to the [semi-official specification](https://github.com/mustache/spec/pull/75). Big thanks to [@groue](https://github.com/groue) for providing the inheritance algorithm.

More features are coming soon! Do keep your eyes open.

# Installation

```swift
import PackageDescription

let package = Package(
    dependencies: [
        .Package(url: "https://github.com/Danappelxx/MuttonChop.git", majorVersion: 0, minor: 1),
    ]
)
```

MuttonChop should work with any version of Swift ranging from `08-04` to the Xcode 8 GM Seed.

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

Notice how the type of context is `Context`. `Context` is a typealias (for clarity) to `StructuredData`, which is an intermediate type from [Open-Swift](https://github.com/open-swift/C7/blob/master/Sources/StructuredData.swift) that can be converted to and from other data types such as JSON, XML, YAML, and so on.

We can then render the template with the context like such:

```swift
let rendered = template.render(with: context)
print(rendered) // -> Hello, Dan!
```

## Tags

Tags are denoted by two opening braces `{{`, followed by some content, delimited by two closing braces `}}`. The first non-whitespace character inside the tag denotes the type of the tag.

The format for this section is: template, context, result. The syntax for doing all three is shown in the section above.

## Variables (Interpolation)

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

## Sections

Section tags start with an opening tag (`{{# section }}`) and end with a closing tag (`{{/ section }}`). Everything between the open and closing tags is the content.

The content is only rendered if the value inside the opening/closing tags is truthy. If the value is an array, the array is iterated and the content of the section is rendered for every value. If the value is a dictionary, it is added to the context stack.

```mustache
{{# person}}
  {{name}} is {{age}} years old.
  Some numbers he knows are{{# numbers}} {{.}}{{/numbers}}.
{{/ person}}
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

## Inverted Sections

An inverted section begins with an opening tag (`{{^ section }}`) and end with a closing tag (`{{/ section }}`). Everything between the tags is the content.

The content is only rendered if the value inside the section tag is falsy. A falsy value is either one that is not found in the context stack, or the boolean value false.

```mustache
{{^ person}}
  {{message}}
{{/person}}
```

```swift
let context: Context = [
    "message": "There is no person!"
]
```

```
There is no person!
```

## Comments

Comment tags (`{{! Some comment about something }}`) are not rendered, and are very useful for documenting your templates.

## Partials

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
{{name}} is {{age}} years old.
Some numbers he knows are{{# numbers}} {{.}}{{/numbers}}.

{{! people.mustache}}
{{# people}}
  {{> person}}
{{/ people}}
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

## Inheritance

Under construction...

# Tips

Parsing is slow and unoptimized. Rendering is fast and optimized. Take advantage of the fact that MuttonChop compiles the templates and only create a single instance of a template (which you can render many times).

# Support

If you need any help; feel free to email me, make an issue, or talk to me at the [Zewo Slack](http://slack.zewo.io).

# Contributing

Any and all help is very welcome, I promise I won't bite. Contributing is more than just code! If you have any ideas at all, please do make an issue and/or pull request.

# License

MIT - more information is in the LICENSE file.

[codebeat-badge]: https://codebeat.co/badges/102d7671-84ec-4af2-b82c-b64844ad5e2b
[codebeat-url]: https://codebeat.co/projects/github-com-danappelxx-muttonchop
[codecov-badge]: https://codecov.io/gh/Danappelxx/MuttonChop/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/Danappelxx/MuttonChop
[mit-badge]: https://img.shields.io/badge/License-MIT-blue.svg?style=flat
[mit-url]: https://tldrlegal.com/license/mit-license
[platform-badge]: https://img.shields.io/badge/Platforms-OS%20X%20--%20Linux-lightgray.svg?style=flat
[platform-url]: https://swift.org
[swift-badge]: https://img.shields.io/badge/Swift-3.0-orange.svg?style=flat
[swift-url]: https://swift.org
[travis-badge]: https://travis-ci.org/Danappelxx/MuttonChop.svg?branch=master
[travis-url]: https://travis-ci.org/Danappelxx/MuttonChop
