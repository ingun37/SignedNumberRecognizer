# SignedNumberRecognizer

[![CI Status](https://img.shields.io/travis/ingun37/SignedNumberRecognizer.svg?style=flat)](https://travis-ci.org/ingun37/SignedNumberRecognizer)
[![Version](https://img.shields.io/cocoapods/v/SignedNumberRecognizer.svg?style=flat)](https://cocoapods.org/pods/SignedNumberRecognizer)
[![License](https://img.shields.io/cocoapods/l/SignedNumberRecognizer.svg?style=flat)](https://cocoapods.org/pods/SignedNumberRecognizer)
[![Platform](https://img.shields.io/cocoapods/p/SignedNumberRecognizer.svg?style=flat)](https://cocoapods.org/pods/SignedNumberRecognizer)

![alt-text](https://github.com/ingun37/SignedNumberRecognizer/blob/master/preview.gif)

A library that recognizes handwritten signed integer.

It takes CGPath as input, seperates them digit by digit, uses pre-built Tensorflowlite model to recognize each digits.

It recognizes the minus sign by simply checking ratio of it's bounding box.

## Usage

You can simply call 

```swift
public func recognize(path:CGPath)->String
```

which returns it's most confident result in `String`.

Parameter `path` is a `CGPath` that represents user's handwriting.

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

SignedNumberRecognizer is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'SignedNumberRecognizer'
```

## Author

ingun37, ingun37@gmail.com

## License

SignedNumberRecognizer is available under the MIT license. See the LICENSE file for more info.
