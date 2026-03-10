# Playwright for Swift

> Swift language bindings for [Microsoft Playwright](https://playwright.dev)
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
let result = try await page.evaluate("1 + 1")
print(result) // Optional(2)

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
