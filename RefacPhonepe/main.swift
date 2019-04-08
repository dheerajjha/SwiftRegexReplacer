//
//  main.swift
//  RefacPhonepe
//
//  Created by Dheeraj Jha on 03/04/19.
//  Copyright © 2019 Phonepe. All rights reserved.
//

import AppKit
import Foundation

enum ScanFilesType {
    case swift
    case xib
    case all

    func stringExtensionRequired() -> String? {
        switch self {
        case .swift:
            return ".swift"
        case .xib:
            return ".xib"
        case .all:
            return nil
        }
    }
}
enum TypeSearchRegex {
    case stringFormatLocalized
    case stringFormatPPLocalized
    case localizedStringWithFormat
    case ppLocalizedString
    case localized
    case stringFormatLongLocalized
    func getRegex() -> String {
        switch self {
        case .stringFormatLocalized:
            return "String\\(format: .*ocalized.*\\)"
        case .stringFormatPPLocalized:
//            return "String\\(format: PPLocalizedString\\(.*\\)\\)"
            return "String\\(format: PPLocalizedString\\(.*\\)"
        case .localizedStringWithFormat:
            return "String\\.localizedStringWithFormat\\(PPLoca.*\\)"
        case .ppLocalizedString:
            return "PPLocalizedString\\(\"(.*?)\"\\)"
        case .localized:
            return "\"(.*?)\".localized"
        case .stringFormatLongLocalized:
            return ""
        }
    }
    func getChars() -> (Character, Character)? {
        switch self {
        case .stringFormatLocalized:
            return (" ", ")")
        case .stringFormatPPLocalized:
            return (" ", ")")
        case .localizedStringWithFormat:
            return ("(", ")")
        case .ppLocalizedString:
            return ("\"", "\"")
        default:
            return nil
        }
    }

}

var masterKeyTypeReplacement: TypeSearchRegex = .stringFormatPPLocalized


private func getStringBetween(firstChar: Character, endChar: Character, inString: String) -> String {

    guard let index = inString.firstIndex(of: firstChar), let lastIndex = inString.lastIndex(of: endChar) else {
        return inString
    }
    let firstIndex = inString.index(index, offsetBy: 1)

    return String(inString[firstIndex..<lastIndex])
}


private func listOfFiles(_ scanFileType: ScanFilesType) throws -> [String] {
    let args = ProcessInfo.processInfo.arguments
    let currentDirectoryPath = FileManager.default.currentDirectoryPath
    let url = URL(fileURLWithPath: args[1], relativeTo: URL(fileURLWithPath: currentDirectoryPath))

    let fileManager = FileManager.default
    let enumerator = fileManager.enumerator(at: url,
                                            includingPropertiesForKeys: [],
                                            options: [],
                                            errorHandler: nil)!

    var filesList: [String] = []

    for case let fileURL as URL in enumerator {

        let resourceValues = try fileURL.resolvingSymlinksInPath()
            .resourceValues(forKeys: [.pathKey, .isDirectoryKey])
        if let isDirectory = resourceValues.isDirectory,
            !isDirectory,
            let path = resourceValues.path {
            filesList.append(path)
        }
    }

    if let pathFilter = scanFileType.stringExtensionRequired() {
        filesList = filesList.filter { (path) -> Bool in
            return path.hasSuffix(pathFilter)
        }
    }
    return filesList
}

private func matches(for regex: String, in text: String) -> [String] {
    do {
        let regex = try NSRegularExpression(pattern: regex)
        let results = regex.matches(in: text,
                                    range: NSRange(text.startIndex..., in: text))
        return results.map {
            String(text[Range($0.range, in: text)!])
        }
    } catch let error {
        print("invalid regex: \(error.localizedDescription)")
        return []
    }
}

private func stripPPLocalizedText(text: String) -> String {
    var newString = text
    if text.hasPrefix("PPLocalizedString(\"") {
        newString.removeFirst(19)
    }
    if text.hasSuffix("\")") {
        newString.removeLast(2)
    }
    return newString
}

private func stripDotLocalizedText(text: String) -> String {
    var newString = text
    if text.hasSuffix(".localized") {
        newString.removeLast(10)
    } else {
        print("Error dot localized strip")
    }
    return newString
}

private func stripQuoteFromBeginingEnd(text: String) -> String {
    var newString = text
    if newString.first == "\"" {
        newString.removeFirst()
    }
    if newString.last == "\"" {
        newString.removeLast()
    }

    return newString
}

private func removeDotAndConvertCamelCase(text: String) -> String {
    enum CharState {
        case dotFound
        case capitalizeNext
        case normal
    }

    var newString: String = ""
    var recentDot: CharState = .normal
    text.forEach { character in
        var finalCharacter = character
        if character == "." {
            recentDot = .dotFound
        }
        if recentDot == .capitalizeNext {
            finalCharacter = Character(String(character).uppercased())
            recentDot = .normal
        }
        if recentDot != .dotFound {
            newString.append(finalCharacter)
        }
        if recentDot == .dotFound {
            recentDot = .capitalizeNext
        }

    }
    return newString
}

private func strip(text: String) -> String {
    switch masterKeyTypeReplacement {
    case .stringFormatLocalized:
        return removeDotAndConvertCamelCase(text: stripQuoteFromBeginingEnd(text: stripDotLocalizedText(text: text)))
    case .stringFormatPPLocalized:
        return removeDotAndConvertCamelCase(text: stripQuoteFromBeginingEnd(text: stripPPLocalizedText(text: text)))
    case .localizedStringWithFormat:
        return removeDotAndConvertCamelCase(text: stripQuoteFromBeginingEnd(text: stripPPLocalizedText(text: text)))
    case .ppLocalizedString:
        return removeDotAndConvertCamelCase(text: stripQuoteFromBeginingEnd(text: stripPPLocalizedText(text: text)))
    default:
        print("No stripping")
        return ""
    }
}

//L10n.goldStateViewControllerPriceDetailText(d, <#T##p2: String##String#>, <#T##p3: String##String#>)
private func addParams(list: [String]) -> String {
    if list.isEmpty == true {
        print("error add params")
        return ""
    }
    let firstString = strip(text: list[0])
    var newString: String = ""
    newString.append(firstString)
    newString.append("(")
    for i in 1..<list.count {
        if i + 1 == list.count {
            newString.append(list[i])
        } else {
            newString.append(list[i])
            newString.append(", ")
        }
    }
    newString.append(")")

    return newString
}

private func getParams(inString: String) -> [String] {
    var braceCount = 0
    var newString = ""
    var cleanString = inString

    if let chars = masterKeyTypeReplacement.getChars() {
        cleanString = getStringBetween(firstChar: chars.0, endChar: chars.1, inString: inString)
    }

    cleanString.forEach { (char) in
        var newChar = char
        if char == "(" {
            braceCount += 1
        }
        if char == ")" {
            braceCount -= 1
        }
        if braceCount > 0, char == "," {
            newChar = "~"
        }
        newString.append(newChar)
    }
    var splitStringListCommaFinal:[String] = []
    let splitStringListComma = newString.split(separator: ",")
    splitStringListComma.forEach { (string) in
        var finalString = ""
        string.forEach { (char) in
            var newChar = char
            if char == "~" {
                newChar = ","
            }
            finalString.append(newChar)
        }
        splitStringListCommaFinal.append(finalString)
    }

    //cleaning of strings removing " and spaces
    for i in 0..<splitStringListCommaFinal.count {
        while splitStringListCommaFinal[i].first == " " || splitStringListCommaFinal[i].last == " " {
            if splitStringListCommaFinal[i].first == " " {
                splitStringListCommaFinal[i].removeFirst()
            }
            if splitStringListCommaFinal[i].last == " " {
                splitStringListCommaFinal[i].removeLast()
            }
        }
//        splitStringListCommaFinal[i] = stripQuoteFromBeginingEnd(text: splitStringListCommaFinal[i])
    }

    return splitStringListCommaFinal
}

//L10n."mandateListExecutionSummaryTitleSucceess"Localized(formattedAmount, date)
//String(format: self.serviceURL(), model.userId)
//L10n.L10n.goldStateViewControllerPriceDetailText()(weightDescription, reservedPrice, L10n.goldWeightMetrickGmText())


private func targetText(_ sourceText: String) -> String {
    switch masterKeyTypeReplacement {
    case .localized:
        return "L10n." + removeDotAndConvertCamelCase(text: stripQuoteFromBeginingEnd(text: stripDotLocalizedText(text: sourceText)))

    case .stringFormatLocalized:
        let params = getParams(inString: sourceText)
        return "L10n." + addParams(list: params)

    case .stringFormatPPLocalized:
        let params = getParams(inString: sourceText)
        return "L10n." + addParams(list: params)

    case .localizedStringWithFormat:
        let params = getParams(inString: sourceText)
        return "L10n." + addParams(list: params)

    case .ppLocalizedString:
        return "L10n." + removeDotAndConvertCamelCase(text: stripQuoteFromBeginingEnd(text: stripPPLocalizedText(text: sourceText)))

    case .stringFormatLongLocalized:
        return ""
    }
}


private func replaceLocalizedString(filePath: String) throws {
    var result: [String] = []
    var content = try String(contentsOfFile: filePath)
    let fileURL = URL(fileURLWithPath: filePath)

    matches(for: masterKeyTypeReplacement.getRegex(), in: content).forEach { (string) in
        result.append(string)
    }

    if !result.isEmpty {
        print(result)
        result.forEach { (sourceText) in
            content = content.replacingOccurrences(of: sourceText, with: targetText(sourceText))
        }
        try content.write(to: fileURL, atomically: false, encoding: .utf8)
    } else {
//        print("No changes for \(filePath)")
    }
}

let list: [String] = try listOfFiles(.swift)

try list.forEach { (file) in
    try replaceLocalizedString(filePath: file)
}







