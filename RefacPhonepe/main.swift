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
enum TypeSearch {
    case stringFormat
    case localized
    case stringformatwithlocalized
    func getRegex() -> String {
        switch self {
        case .stringFormat:
            return "String\\(format: .*localized.*\\)"
        case .localized:
            return "\"(.*?)\".localized"
        case .stringformatwithlocalized:
            return ""
        }
    }
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

//String(format: "mandate.list.execution.summary.title.succeess".localized, formattedAmount, date)
//String(format: self.serviceURL(), model.userId)

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
    if newString.first == "\"" && newString.last == "\"" {
        newString.removeLast()
        newString.removeFirst()
    } else {
        print("Error quote strip")
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

private func targetText(_ sourceText: String) -> String {
    return "L10n." + removeDotAndConvertCamelCase(text: stripQuoteFromBeginingEnd(text: stripDotLocalizedText(text: sourceText)))
}


private func replaceLocalizedString(filePath: String) throws {
    var result: [String] = []
    var content = try String(contentsOfFile: filePath)
    let fileURL = URL(fileURLWithPath: filePath)

    matches(for: TypeSearch.stringFormat.getRegex(), in: content).forEach { (string) in
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







