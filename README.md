# 🎭 [Playwright](https://playwright.dev) for Swift

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fm1guelpf%2Fswift-playwright%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/m1guelpf/swift-playwright) [![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fm1guelpf%2Fswift-playwright%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/m1guelpf/swift-playwright) [![Test](https://github.com/m1guelpf/swift-playwright/actions/workflows/test.yml/badge.svg)](https://github.com/m1guelpf/swift-playwright/actions/workflows/test.yml)

Playwright is a Swift library to automate [Chromium](https://www.chromium.org/Home), [Firefox](https://www.mozilla.org/en-US/firefox/new/) and [WebKit](https://webkit.org/) with a single API. Playwright is built to enable cross-browser web automation that is **ever-green**, **capable**, **reliable** and **fast**.

## Installation

Add `swift-playwright` to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/m1guelpf/swift-playwright.git", from: "0.1.0"),
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "Playwright", package: "swift-playwright"),
    ]),
]
```

Then install the Playwright driver and browsers:

```bash
# Download the Playwright driver (~40MB, one-time setup)
swift package install-playwright

# Install browsers (requires Node.js)
npx playwright install
```

## Quick Start

```swift
import Playwright

let playwright = try await Playwright.launch()
let browser = try await playwright.chromium.launch()
let page = try await browser.newPage()

// Navigate and read content
let response = try await page.goto("https://example.com")
print(try await page.title()) // "Example Domain"

// Find and interact with elements
try await page.locator("input[name=q]").fill("swift playwright")
try await page.getByRole(.button, name: "Search").click()

// Run JavaScript
let result = try await page.evaluate("1 + 1", as: Int.self)

// Capture a screenshot
let png = try await page.screenshot()

try await browser.close()
await playwright.close()
```

## How It Works

`swift-playwright` works by communicating with the Node.js Playwright server, same as the official Python, Java, and .NET drivers:

```
┌─────────────────────────────────────────────────┐
│ Playwright (Swift API)                          │
├─────────────────────────────────────────────────┤
│ JSON-RPC over stdio                             │
├─────────────────────────────────────────────────┤
│ Playwright Server (Node.js)                     │
├───────────────┬───────────────┬─────────────────┤
│   Chromium    │    Firefox    │     WebKit      │
└───────────────┴───────────────┴─────────────────┘
```

## License

This project is licensed under the MIT License - see the [LICENSE file](LICENSE) for details.
