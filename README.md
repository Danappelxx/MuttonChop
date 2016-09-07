# MuttonChop

[![Swift][swift-badge]][platform-url] [![Platform][platform-badge]][platform-url] [![License][mit-badge]][mit-url] [![Travis][travis-badge]][travis-url] [![Codebeat][codebeat-badge]][codebeat-url]

> Mutton Chops are synonymous to Sideburns. Sideburns are kind of similar to Mustaches.

Mustache templates in Swift. 99% spec compliant. OSX and Linux supported.

Still an intense work in progress.

# Features

MuttonChop conforms entirely to the official [Mustache specification](https://github.com/mustache/specs). The only exception is [recursive partials](https://github.com/Danappelxx/MuttonChop/blob/master/Tests/SpecTests/SpecTests.swift#L1253-L1266), which are not supported due to the fact that MuttonChop compiles all of its templates ahead of time, making infinite recursion impossible to resolve.

More features (inheritance, etc.) are coming soon! Do keep your eyes open.

# Installation

```swift
import PackageDescription

let package = Package(
    dependencies: [
        .Package(url: "https://github.com/Danappelxx/MuttonChop.git", majorVersion: 0, minor: 1),
    ]
)
```

Compiles with the `08-31` snapshot. Compatibility with other versions of Swift is not guaranteed.

# Usage

## Basic template usage

To compile a template, simply call the `Template` initializer with your template string. How you get that is up to you.

```swift
let template = try Template("Hello, {{name}}!")
```

Before we can render your template, we first have to create the context.

```swift
let context: StructuredData = [
    "name": "Dan"
]
```

Notice how the type of context is `StructuredData`. This is an intermediate type from [Open-Swift](https://github.com/open-swift/C7/blob/master/Sources/StructuredData.swift) that can be converted to and from other data types such as JSON, XML, YAML, and so on.

We can then render the template with the context like such:

```swift
let rendered = template.render(with: context)
print(rendered) // -> Hello, Dan!
```

## Tags

## Variables (Interpolation)

Under construction... g

## Sections

Under construction...

## Inverted Sections

Under construction...

## Partials

Under construction...

# Tips

Parsing is slow and unoptimized. Rendering is fast and optimized. Take advantage of the fact that MuttonChop compiles the templates and only create a single instance of a template (which you can render many times).

# Support

If you need any help; feel free to email me, make an issue, or talk to me at the [Zewo Slack][slack-url].

# Contributing

Any and all help is very welcome, I promise I won't bite. Contributing is more than just code! If you have any ideas at all, please do make an issue and/or pull request.

# License

MIT - more information is in the LICENSE file.

[codebeat-badge]: https://codebeat.co/badges/102d7671-84ec-4af2-b82c-b64844ad5e2b
[codebeat-url]: https://codebeat.co/projects/github-com-danappelxx-muttonchop
[mit-badge]: https://img.shields.io/badge/License-MIT-blue.svg?style=flat
[mit-url]: https://tldrlegal.com/license/mit-license
[platform-badge]: https://img.shields.io/badge/Platforms-OS%20X%20--%20Linux-lightgray.svg?style=flat
[platform-url]: https://swift.org
[swift-badge]: https://img.shields.io/badge/Swift-3.0-orange.svg?style=flat
[swift-url]: https://swift.org
[travis-badge]: https://travis-ci.org/Danappelxx/MuttonChop.svg?branch=master
[travis-url]: https://travis-ci.org/Danappelxx/MuttonChop
