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
