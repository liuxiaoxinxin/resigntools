//
//  EditableBundle.swift
//  ResignTool
//
//  Created by 刘吉新 on 2025/6/18.
//

import Foundation

class EditableBundle {
    let bundlePath: String
    
    let bundleURL: URL
    
    var infoDictionary: [String:Any]?
    
    //国际化文件
    var zhHansInfoDictionary: [String:Any]?
    
    let builtInPlugInsPath: String!
    
    init(path: String) {
        self.bundleURL = URL.init(fileURLWithPath: path)
        self.bundlePath = bundleURL.path
        self.builtInPlugInsPath = self.bundleURL.appendingPathComponent("PlugIns").path
        self.infoDictionary =  NSDictionary.init(contentsOf: self.infoPlist) as? [String : Any]
        if FileManager.default.fileExists(atPath: self.zhHansInfoPlistStringsFile.path){
            self.zhHansInfoDictionary = NSDictionary.init(contentsOf: self.zhHansInfoPlistStringsFile) as? [String : Any]
        }
    }
    
    convenience init(url: URL) {
        self.init(path: url.path)
    }
    
    var executablePath: String? {
        guard let executableName = self.executableName else{
            return nil
        }
        return self.bundleURL.appendingPathComponent(executableName).path
    }
    
    var infoPlistPath: String {
        return self.infoPlist.path
    }
    
    var zhHansInfoPlistStringsFile: URL {
        return self.bundleURL.appendingPathComponent("zh-Hans.lproj/InfoPlist.strings")
    }
    
    var infoPlist: URL {
        return self.bundleURL.appendingPathComponent("Info.plist")
    }
    
    var displayName: String?{
        if let hanDic = self.zhHansInfoDictionary, let name = hanDic["CFBundleDisplayName"] as? String{
            return name
        }
        return self.infoDictionary?["CFBundleDisplayName"] as? String
    }
    
    var shortVersion: String?{
        return self.infoDictionary?["CFBundleShortVersionString"] as? String
    }
    
    var bundleVersion: String?{
        return self.infoDictionary?["CFBundleVersion"] as? String
    }
    
    var bundleName: String?{
        return self.infoDictionary?["CFBundleName"] as? String
    }
    
    var bundleIdentifier: String?{
        return self.infoDictionary?["CFBundleIdentifier"] as? String
    }
    
    var executableName: String?{
        return self.infoDictionary?["CFBundleExecutable"] as? String
    }
    
    func updateBundleID(_ newBundleID: String){
        self.infoDictionary?["CFBundleIdentifier"] = newBundleID
        flushInfoDictionaryToInfoPlist()
    }
    
    func updateDisplayName(_ newDisplayName: String){
        if self.zhHansInfoDictionary != nil {
            self.zhHansInfoDictionary!["CFBundleDisplayName"] = newDisplayName
            flushZHHansInfoDictionaryToInfoPlist()
        }
        self.infoDictionary?["CFBundleDisplayName"] = newDisplayName
        flushInfoDictionaryToInfoPlist()
    }
    
    func updateNo(_ newVal: String){
        self.infoDictionary?["yingymmk"] = newVal
        flushInfoDictionaryToInfoPlist()
    }
    
    func updateShortVersion(_ newShortVersion: String) {
        self.infoDictionary?["CFBundleShortVersionString"] = newShortVersion
        flushInfoDictionaryToInfoPlist()
    }
    
    func updateBundleVersion(_ bundleVersion: String) {
        self.infoDictionary?["CFBundleVersion"] = bundleVersion
        flushInfoDictionaryToInfoPlist()
    }
    
    func flushInfoDictionaryToInfoPlist() {
        let os = OutputStream.init(url: URL.init(fileURLWithPath: self.infoPlistPath), append: false)!
        os.open()
        var error: NSError? = nil
        PropertyListSerialization.writePropertyList(infoDictionary!, to: os, format: PropertyListSerialization.PropertyListFormat.binary, options: 0, error: &error)
        os.close()
    }
    
    func flushZHHansInfoDictionaryToInfoPlist() {
        let os = OutputStream.init(url: self.zhHansInfoPlistStringsFile, append: false)!
        os.open()
        var error: NSError? = nil
        PropertyListSerialization.writePropertyList(zhHansInfoDictionary!, to: os, format: PropertyListSerialization.PropertyListFormat.binary, options: 0, error: &error)
        os.close()
    }
}
