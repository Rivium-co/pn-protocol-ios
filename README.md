# PN Protocol — iOS

Lightweight messaging protocol layer by Rivium Push with offline-first sync.

[![Swift 5.7+](https://img.shields.io/badge/Swift-5.7+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2013+-blue.svg)](https://developer.apple.com)
[![CocoaPods](https://img.shields.io/cocoapods/v/PNProtocol.svg)](https://cocoapods.org/pods/PNProtocol)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Installation

### Swift Package Manager (Xcode)

1. In Xcode, go to **File → Add Package Dependencies**
2. Enter the repository URL:
   ```
   https://github.com/Rivium-co/pn-protocol-ios
   ```
3. Select version **0.2.0**
4. Add **PNProtocol** library to your target

### Swift Package Manager (Package.swift)

```swift
dependencies: [
    .package(url: "https://github.com/Rivium-co/pn-protocol-ios", from: "0.2.0"),
]
```

### CocoaPods

Add to your `Podfile`:

```ruby
pod 'PNProtocol', '~> 0.2'
```

Then run:

```bash
pod install
```

## Documentation

- [Rivium Cloud](https://rivium.co/cloud)
- [Rivium Console](https://console.rivium.co)

## License

MIT
