//
//  Extensions.swift
//  ResignTool
//
//  Created by 刘吉新 on 2025/6/18.
//

import Foundation

extension String {
    func isMatch(_ pattern: String, caseInsensitive: Bool = true) -> Bool {
        var opt: NSRegularExpression.Options = []
        if caseInsensitive{
            opt.insert(NSRegularExpression.Options.caseInsensitive)
        }
        let regex = try! NSRegularExpression(pattern: pattern, options: opt)
        let matchNum = regex.numberOfMatches(in: self, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, self.count))
        return matchNum > 0
    }
    
    static func randomString(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        var ranStr = ""
        for _ in 0..<length {
            let index = Int(arc4random_uniform(UInt32(characters.count)))
            let stringIndex = characters.index(characters.startIndex, offsetBy: index)
            ranStr.append(characters[stringIndex])
        }
        return ranStr
    }

}

extension FileManager {
    func removeItemIfExists(at url: URL) throws {
        if self.fileExists(atPath: url.path) {
            try self.removeItem(at: url)
        }
    }
    
    func removeItemIfExists(at path: String) throws {
        if self.fileExists(atPath: path) {
            try self.removeItem(atPath: path)
        }
    }
    
    func copyItem(at srcURL: URL,
                  to dstURL: URL,
                  shouldOverwrite: Bool,
                  withIntermediateDirectories intermediateDirectories: Bool) throws {
        try self.copyItem(atPath: srcURL.path, toPath: dstURL.path, shouldOverwrite: shouldOverwrite, withIntermediateDirectories: intermediateDirectories)
    }
    
    func copyItem(atPath srcPath: String,
                  toPath dstPath: String,
                  shouldOverwrite: Bool,
                  withIntermediateDirectories intermediateDirectories: Bool) throws {
        if self.fileExists(atPath: dstPath) && shouldOverwrite {
            try self.removeItem(atPath: dstPath)
        }
        if intermediateDirectories {
            try self.createDirectory(at: URL(fileURLWithPath: dstPath).deletingLastPathComponent(), withIntermediateDirectories: intermediateDirectories, attributes: nil)
        }
        try self.copyItem(atPath: srcPath, toPath: dstPath)
    }
}

extension Dictionary {
    public static func dictionaryWith(plistData: Data) -> [Key:Value]? {
        return (try? PropertyListSerialization.propertyList(from: plistData,
                                                            options: PropertyListSerialization.ReadOptions.mutableContainersAndLeaves,
                                                            format: nil)) as? [Key:Value]
    }
}

extension Date {
    public func stringWithFormat(_ format: String) -> String {
        let dateformatter = DateFormatter()
        dateformatter.dateFormat = format
        return dateformatter.string(from: self)
    }
}
