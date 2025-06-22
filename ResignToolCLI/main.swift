//
//  main.swift
//  ResignToolCLI
//
//  Created by 刘吉新 on 2025/6/16.
//

import Foundation

func getArguments(key: String) -> String {
    let arguments = CommandLine.arguments;
    for idx in 0..<arguments.count {
        let arg = arguments[idx];
        if (arg == key && arguments.count > idx + 1) {
            return arguments[idx + 1];
        }
    }
    return "";
}

let cmdName = CommandLine.argc >= 2 ? CommandLine.arguments[1] : "";

if (cmdName == "-help") {
    let message = """
                  使用 resign 命令：
                  resign -linkPath ipa路径
                  -provisionFilePath 描述文件路径
                  -injectResourcePath 将要注入framework路径，多个用逗号隔开（可选）
                  -appName 重置名称（可选）
                  -version 重置版本（可选）
                  -bundleVersion 重置构建号（可选）
                  -bundleID 重置包名（可选）
                  -exportedIpaPath 导出ipa 路径，不传默认导入到下载(/Downloads)目录（可选）
                  """;
    print(message);
} else if (cmdName == "resign") {
    let appName = getArguments(key:"-appName");
    let version = getArguments(key:"-version");
    let bundleID = getArguments(key: "-bundleID");
    let exportedIpaPath = getArguments(key: "-exportedIpaPath");
    let bundleVersion = getArguments(key: "-bundleVersion");
    let resign = ResignPackage.init(linkPath: getArguments(key:"-linkPath"),
                                    appName: appName.isEmpty ? nil : appName,
                                    version: version.isEmpty ? nil : version,
                                    bundleID: bundleID.isEmpty ? nil : bundleID,
                                    provisionFilePath: getArguments(key:"-provisionFilePath"),
                                    injectResourcePath: getArguments(key:"-injectResourcePath"),
                                    exportedIpaPath: exportedIpaPath.isEmpty ? nil : exportedIpaPath,
                                    bundleVersion: bundleVersion.isEmpty ? nil : bundleVersion
    );
    resign.run { result in
        if (result) {
            print("任务执行结束");
        } else {
            print("请留意以上报错信息");
            exit(1);
        }
    };

} else {
    print("-help 查看使用方法");
}
