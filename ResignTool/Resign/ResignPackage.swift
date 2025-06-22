//
//  ResignPackage.swift
//  ResignTool
//
//  Created by 刘吉新 on 2025/6/18.
//

import Foundation
import Cocoa

class ResignPackage {
    // 目标 ipa 包路径
    var linkPath: String!
    // 重置显示名称
    var appName: String?;
    // 重置版本
    var version: String?;
    // 重置buildID
    var bundleID: String?;
    // 重置构建号
    var bundleVersion: String?;
    // 重签名描述文件位置
    var provisionFilePath: String!;
    // 注入库路径
    var injectResourcePath: String!;
    // ipa 导出路径，不传默认导出到 Download 目录下
    var exportedIpaPath: String?;
    
    // ipa raw
    private var rawIpaPayloadHandler: IpaPayloadHandle? = nil;
    // Mach-O links
    private var dylibLinks: [DylibLinkItem] = [];
    // 选择证书名称
    private var signIdentity: String = "";

    init(linkPath: String, appName: String?, version: String?, bundleID: String?, provisionFilePath: String, injectResourcePath: String, exportedIpaPath: String?, bundleVersion: String?) {
        self.linkPath = linkPath
        self.appName = appName
        self.version = version;
        self.bundleID = bundleID;
        self.provisionFilePath = provisionFilePath;
        self.injectResourcePath = injectResourcePath;
        self.exportedIpaPath = exportedIpaPath;
        self.bundleVersion = bundleVersion;
    }
    
    func run(result: @escaping (_ result: Bool) -> Void) {
        if (self.linkPath.isEmpty) {
            print("linkPath 必传")
            result(false);
            return;
        }
        if (self.provisionFilePath.isEmpty) {
            print("provisionFilePath 必传")
            result(false);
            return;
        }
        
        // 第一步 解析 ipa
        guard self.ipaFileunzip(self.linkPath) else {
            result(false);
            return;
        }
        
        // 第二步 添加注入对象
        if (self.injectResourcePath.isEmpty == false) {
            let injectPaths = self.injectResourcePath.components(separatedBy: [","]);
            for path in injectPaths {
                let injectResourceLink = ResignPackage.getInjectResourceLink(path);
                let linkItem = DylibLinkItem(type: .userInject, link: injectResourceLink, injectResourcePath: path)
                self.dylibLinks.removeAll(where: {$0.link == injectResourceLink});
                self.dylibLinks.insert(linkItem, at: 0);
            }
        }
        
        // 第三步 解析重签描述文件
        guard let ppfModel = PPFModel.init(mobileprovisionFilePath: self.provisionFilePath) else {
            print("【error】描述文件解析失败");
            result(false)
            return
        }
        let cerNames = ppfModel.mdCertificates.map{ $0.commonName }
        if cerNames.count <= 0 {
            print("【error】描述文件无效: 未包含任何关联证书");
            result(false)
            return
        }
        self.signIdentity = cerNames[0];
        print("signIdentity: \(self.signIdentity)")
        
        // 第四步，重签
        result(self.resign())
    }
    
    func resign() -> Bool {
        do {
            print("准备导出 Payload 副本...");
            let fm = FileManager.default
            let copyDir = URL(fileURLWithPath: "/tmp").appendingPathComponent( "SResignerCopy\(Date().stringWithFormat("yyyyMMddHHmmss"))")
            let copyPayload = copyDir.appendingPathComponent("Payload")
            try! fm.copyItem(at: self.rawIpaPayloadHandler!.payload, to: copyPayload, shouldOverwrite: true, withIntermediateDirectories: true)
            
            let copyPayloadHanlder: IpaPayloadHandle = try IpaPayloadHandle.init(payload: copyPayload)

            let toInjectLinkItems: [DylibLinkItem] = self.dylibLinks.filter{$0.type == .userInject}
            if (toInjectLinkItems.count > 0) {
                print("新增 \(toInjectLinkItems.count) 个库，开始注入");
                for linkItem in toInjectLinkItems {
                    print("Inject \(linkItem.link)");
                    try copyPayloadHanlder.injectDylib(dylibFilePath: linkItem.injectResourcePath!, link: linkItem.link)
                }
            }
            
            if((self.version) != nil) {
                print("更新 version " + self.version!);
                copyPayloadHanlder.mainBundle.updateShortVersion(self.version!);
            }
            if ((self.appName) != nil) {
                print("更新 appName " + self.appName!);
                copyPayloadHanlder.mainBundle.updateDisplayName(self.appName!);
            }
            if ((self.bundleID) != nil) {
                print("更新 buildid " + self.bundleID!);
                copyPayloadHanlder.mainBundle.updateBundleID(self.bundleID!);
            }
            if ((self.bundleVersion) != nil) {
                print("更新 bundleVersion " + self.bundleVersion!);
                copyPayloadHanlder.mainBundle.updateBundleVersion(self.bundleVersion!);
            }

            print("Remove nested app...")
            let allNestedBundles = copyPayloadHanlder.currentNestedAppBundles()
            let remainNestedBundleIDs: [String] = []
            for bundle in allNestedBundles {
                if !remainNestedBundleIDs.contains(bundle.bundleIdentifier!) {
                    print("Remove nested app at path: \(bundle.bundlePath)")
                    try fm.removeItem(atPath: bundle.bundlePath)
                }
            }
            let watchDir = copyPayloadHanlder.mainBundle.bundlePath + "/Watch";
            let watchPlaceholder = copyPayloadHanlder.mainBundle.bundlePath + "/com.apple.WatchPlaceholder";
            if FileManager.default.fileExists(atPath: watchDir) {
                print("remove Watch...")
                try! FileManager.default.removeItem(atPath: watchDir)
            }
            if FileManager.default.fileExists(atPath: watchPlaceholder) {
                print("remove WatchPlaceholder...")
                try! FileManager.default.removeItem(atPath: watchPlaceholder)
            }

            print("开始重签...");
            
            let extraResignResources: (singleFiles: [String], frameworks: [String]) = {
                var singleFiles: [String] = []
                var frameworks: [String] = []
                let bundlePath =  copyPayloadHanlder.mainBundle.bundlePath
                let fm = FileManager.default
                let allSubPaths = fm.subpaths(atPath: bundlePath) ?? []
                
                let mainExecutablePath = copyPayloadHanlder.mainBundle.executablePath!
                for path in allSubPaths {
                    let absPath = bundlePath + "/" + path
                    let absPathUrl = URL.init(fileURLWithPath: absPath)
                    var isDirectory = ObjCBool(false)
                    fm.fileExists(atPath: absPath, isDirectory: &isDirectory)
                    // frameworks 不过滤
                    if isDirectory.boolValue {
                        if absPathUrl.pathExtension == "framework" && self.checkFrameworkFileIsValidDylib(filePath: absPathUrl.path) {
                            frameworks.append(path)
                        }
                        continue
                    }
                    /* -------------- 过滤掉一些不用单独签的 ------------- */
                    // 过滤：主executable
                    if absPath == mainExecutablePath {
                        continue
                    }
                    //过滤：Framework 的 executable 文件
                    let lastName = absPathUrl.lastPathComponent
                    let last2Name = absPathUrl.deletingLastPathComponent().lastPathComponent
                    if (lastName + ".framework") == last2Name {
                        continue
                    }
                    
                    let fh: FileHandle = FileHandle.init(forReadingAtPath:absPath)!

                    let bytes = Array(fh.readData(ofLength: 4))
                    if bytes.count < 4 {
                        continue
                    }
                    let ret = (UInt32(bytes[0])<<24) + (UInt32(bytes[1])<<16) + (UInt32(bytes[2])<<8) + UInt32(bytes[3]);
                    if ret == FAT_MAGIC
                        || ret == FAT_CIGAM
                        || ret == MH_MAGIC_64
                        || ret == MH_CIGAM_64
                        || ret == MH_CIGAM
                        || ret == MH_MAGIC{
                        singleFiles.append(path)
                    }
                }
                return (singleFiles, frameworks)
            }()

            let sdate = Date()
            let newBundleID = (self.bundleID != nil) ? self.bundleID! : copyPayloadHanlder.mainBundle.bundleIdentifier!;
            let newDisplayName = (self.appName != nil) ? self.appName! : copyPayloadHanlder.mainBundle.displayName!;
            try copyPayloadHanlder.resign(mainAppNewPPFPath: self.provisionFilePath,
                                               nestAppBundleIDToPPFPath: [:],
                                               codeSignID: self.signIdentity,
                                               extraResignResources: extraResignResources.singleFiles,
                                               extraResignFrameworks: extraResignResources.frameworks,
                                               resignBundleIDSettingStrategy: .changeTo(newBundleID),
                                               process: { (onSignFile: String)->Void in
                print("Sign " + onSignFile);
            })
            let enddate = Date()
            print("resign 用时: \(enddate.timeIntervalSince(sdate)) 秒")
            print("开始生成 ipa 文件...")
            var exportedIpa:URL;
            if (self.exportedIpaPath == nil) {
                let exportIpaName: String = "\(newDisplayName)_resigned\(Date().stringWithFormat("yyyyMMddHHmmss")).ipa"
                exportedIpa = URL(fileURLWithPath: NSHomeDirectory()+"/Downloads").appendingPathComponent(exportIpaName)
            } else {
                exportedIpa = URL(fileURLWithPath: self.exportedIpaPath!);
            }
            
            try fm.removeItemIfExists(at: exportedIpa)
            // 压缩回 ipa
            print("Zip to ipa: \(exportedIpa)...")

            try ShellCmds.zip(filePath: copyPayloadHanlder.payload.path, toDestination: exportedIpa.path)
            print("Clean...")
            
            // 清理
            do {
                // 在清理文件时，如果文件被 chattr 命令加锁了后，会无法删除，继而会报权限问题 ，这里忽略，在 菜单->清理缓存 的时候会有提示
                try fm.removeItem(at: copyDir)
            } catch {
                if (error as NSError).code != 513 {
                    throw error
                }
            }
            print("完成！")
            // 用访达打开导出的 ipa 文件，注释掉的部分。
            // TODO: 界面上添加按钮在 访达 中查看
//            allExportIpaPath.append(exportedIpa)
//            if allExportIpaPath.count > 1{
//                // open
//                try ShellCmds.open(directory: allExportIpaPath[0].deletingLastPathComponent().path, shouldSelect: true)
//            } else {
//                // open
//                try ShellCmds.open(directory: allExportIpaPath[0].path, shouldSelect: true)
//            }
            return true;

        } catch {
            print("【error】重签失败: \(error)");
            return false;
        }
    }
    
    static func getInjectResourceLink(_ filePath: String) -> String {
        let url = URL.init(fileURLWithPath: filePath);
        var path = "";
        if let bundle = Bundle.init(path: filePath),
           let execuableName = bundle.executableURL?.lastPathComponent {
            if filePath.hasSuffix("framework"){
                path = "Frameworks/\(url.lastPathComponent.removingPercentEncoding!)/\(execuableName.removingPercentEncoding!)"
            } else {
                path = "\(url.lastPathComponent.removingPercentEncoding!)/\(execuableName.removingPercentEncoding!)"
            }
        } else {
            path = "\(url.lastPathComponent.removingPercentEncoding!)";
        }
        return "@executable_path/" + path;
    }
    
    // 解压ipa，获取 IpaPayloadHandle 对象，返回是否成功
    func ipaFileunzip(_ ipaPath: String) -> Bool {
        print("开始解压 handle ipa: \(ipaPath)");
        let upZipDir = URL(fileURLWithPath: "/tmp").appendingPathComponent( "SResignerUnzip\(Date().stringWithFormat("yyyyMMddHHmmss"))")
        try! ShellCmds.unzip(filePath: ipaPath, toDirectory: upZipDir.path)

        // 获取解压后的Payload
        let searchPayloadPath = { () -> String? in
            let opt = FileSearcher.SearchOption()
            opt.maxResultNumbers = 1
            opt.searchItemType = [.directory]
            opt.maxSearchDepth = 1
            return FileSearcher.searchItems(nameMatchPattern: "Payload$", inDirectory: upZipDir.path, option: opt).first
        }()

        guard let payloadPath = searchPayloadPath else {
            print("【error】ipa 解压目录里找不到 ”Payload“ 目录")
            return false;
        }
        
        var hender: IpaPayloadHandle?;
        do {
            hender = try IpaPayloadHandle.init(payload: URL(fileURLWithPath: payloadPath))
        } catch {
            print("【error】ipa 文件解析失败：\(error)");
            return false;
        }
        
        // 获取所有 links 库
        let dylibLinks = hender!.getDylibLinks().map({ (link) -> DylibLinkItem in
            if link.starts(with: "@executable_path"){
                return DylibLinkItem(type: .originInject, link: link)
            } else if link.starts(with: "@loader_path"){
                return DylibLinkItem(type: .originInject, link: link)
            } else {
                return DylibLinkItem(type: .originSystem, link: link)
            }
        })
        
        self.rawIpaPayloadHandler = hender;
        self.dylibLinks = dylibLinks;
        return true;
    }
    
    // 检查指定路径上的 framework 是否是有效的动态库
    func checkFrameworkFileIsValidDylib(filePath: String) -> Bool {
        let url: URL = URL.init(fileURLWithPath: filePath)
        let fkName: String = url.deletingPathExtension().lastPathComponent
        let macho = url.appendingPathComponent(fkName)
        if !FileManager.default.fileExists(atPath: macho.path) {
            return false
        }
        let fh: FileHandle = FileHandle.init(forReadingAtPath: macho.path)!
        let bytes = Array(fh.readData(ofLength: 4))
        if bytes.count < 4{
            return false
        }
        let b_0:UInt32 = UInt32(bytes[0])<<24
        let b_1:UInt32 = UInt32(bytes[1])<<16
        let b_2:UInt32 = UInt32(bytes[2])<<8
        let b_3:UInt32 = UInt32(bytes[3])
        let ret:UInt32 = b_0 + b_1 + b_2 + b_3;
        if ret == FAT_MAGIC
            || ret == FAT_CIGAM
            || ret == MH_MAGIC_64
            || ret == MH_CIGAM_64
            || ret == MH_CIGAM
            || ret == MH_MAGIC{
            return true
        }
        return false
    }
}
