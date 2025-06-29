//
//  ViewController.swift
//  ResignTool
//
//  Created by 刘吉新 on 2025/6/15.
//

import Cocoa

// MARK: - NSTextField 扩展
extension NSTextField {
    static func label(withString string: String) -> NSTextField {
        let label = NSTextField()
        label.stringValue = string
        label.isEditable = false
        label.isSelectable = false
        label.isBordered = false
        label.backgroundColor = .clear
        return label
    }
}

extension String {
    func localizable() -> String {
        return NSLocalizedString(self, comment: "")
    }
}

class ViewController: NSViewController {
    
    // MARK: - 表单字段
    private let ipaPathLabel = NSTextField.label(withString: "源 IPA 文件路径:".localizable())
    private let ipaPathField = NSTextField()
    private let ipaPathButton = NSButton(title: NSLocalizedString("选择...", comment: ""), target: nil, action: nil)
    
    private let provisionFileLabel = NSTextField.label(withString: "描述文件路径（.mobileprovision）".localizable())
    private let provisionFileField = NSTextField()
    private let provisionFileButton = NSButton(title: NSLocalizedString("选择...", comment: ""), target: nil, action: nil)
    
    private let resourcePathLabel = NSTextField.label(withString: "注入 Framework (可选，将一个或多个 Framework 放在此目录下)".localizable())
    private let resourcePathField = NSTextField()
    private let resourcePathButton = NSButton(title: NSLocalizedString("选择...", comment: ""), target: nil, action: nil)
    
    private let appNameLabel = NSTextField.label(withString: "重置应用名称(可选)".localizable())
    private let appNameField = NSTextField()
    
    private let versionLabel = NSTextField.label(withString: "重置版本号(可选)".localizable())
    private let versionField = NSTextField()
    
    private let bundleIDLabel = NSTextField.label(withString: "重置 Bundle ID(可选)".localizable())
    private let bundleIDField = NSTextField()
    
    private let exportPathLabel = NSTextField.label(withString: "导出 IPA 路径(可选，默认导入到 /Downloads 目录)".localizable())
    private let exportPathField = NSTextField()
    private let exportPathButton = NSButton(title: NSLocalizedString("选择...", comment: ""), target: nil, action: nil)
    
    private let submitButton = NSButton(title: "开始重签".localizable(), target: nil, action: nil)
    
    private var hud: HUDViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let window: NSWindow? = NSApplication.shared.windows.first;
        window?.title = "ResignTool";
        window?.minSize = NSSize(width: 500, height: 600)
        setupUI()
    }
    
    // MARK: - UI 设置
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        // 设置文本字段样式
        let textFields = [ipaPathField, provisionFileField, resourcePathField,
                         appNameField, versionField, bundleIDField, exportPathField]
        
        textFields.forEach {
            $0.bezelStyle = .roundedBezel
            $0.isEditable = true
            $0.isSelectable = true
            $0.usesSingleLineMode = true
            $0.lineBreakMode = .byTruncatingHead
        }
        
        // 设置按钮
        let buttons = [ipaPathButton, provisionFileButton, resourcePathButton, exportPathButton, submitButton]
        
        buttons.forEach {
            $0.bezelStyle = .rounded
            $0.setButtonType(.momentaryPushIn)
        }
        
        submitButton.bezelStyle = .regularSquare
        submitButton.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        
        // 添加子视图
        let labels = [ipaPathLabel, provisionFileLabel, resourcePathLabel,
                     appNameLabel, versionLabel, bundleIDLabel, exportPathLabel]
        
        let allViews: [NSView] = labels + textFields + buttons
        allViews.forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        // 布局约束
        let padding: CGFloat = 20
        let fieldHeight: CGFloat = 24
        let buttonWidth: CGFloat = 80
        let fieldWidth = view.frame.width - 2 * padding - buttonWidth - 10

        // IPA 路径
        NSLayoutConstraint.activate([
            ipaPathLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: padding),
            ipaPathLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            
            ipaPathField.topAnchor.constraint(equalTo: ipaPathLabel.bottomAnchor, constant: 5),
            ipaPathField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            ipaPathField.widthAnchor.constraint(equalToConstant: fieldWidth),
            ipaPathField.heightAnchor.constraint(equalToConstant: fieldHeight),
            
            ipaPathButton.leadingAnchor.constraint(equalTo: ipaPathField.trailingAnchor, constant: 10),
            ipaPathButton.centerYAnchor.constraint(equalTo: ipaPathField.centerYAnchor),
            ipaPathButton.widthAnchor.constraint(equalToConstant: buttonWidth),
        ])
        
        // 描述文件路径
        NSLayoutConstraint.activate([
            provisionFileLabel.topAnchor.constraint(equalTo: ipaPathField.bottomAnchor, constant: padding),
            provisionFileLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            
            provisionFileField.topAnchor.constraint(equalTo: provisionFileLabel.bottomAnchor, constant: 5),
            provisionFileField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            provisionFileField.widthAnchor.constraint(equalToConstant: fieldWidth),
            provisionFileField.heightAnchor.constraint(equalToConstant: fieldHeight),
            
            provisionFileButton.leadingAnchor.constraint(equalTo: provisionFileField.trailingAnchor, constant: 10),
            provisionFileButton.centerYAnchor.constraint(equalTo: provisionFileField.centerYAnchor),
            provisionFileButton.widthAnchor.constraint(equalToConstant: buttonWidth),
        ])

        // 注入资源路径
        NSLayoutConstraint.activate([
            resourcePathLabel.topAnchor.constraint(equalTo: provisionFileField.bottomAnchor, constant: padding),
            resourcePathLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            
            resourcePathField.topAnchor.constraint(equalTo: resourcePathLabel.bottomAnchor, constant: 5),
            resourcePathField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            resourcePathField.widthAnchor.constraint(equalToConstant: fieldWidth),
            resourcePathField.heightAnchor.constraint(equalToConstant: fieldHeight),
            
            resourcePathButton.leadingAnchor.constraint(equalTo: resourcePathField.trailingAnchor, constant: 10),
            resourcePathButton.centerYAnchor.constraint(equalTo: resourcePathField.centerYAnchor),
            resourcePathButton.widthAnchor.constraint(equalToConstant: buttonWidth),
        ])
        
        // 应用名称
        NSLayoutConstraint.activate([
            appNameLabel.topAnchor.constraint(equalTo: resourcePathField.bottomAnchor, constant: padding),
            appNameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            
            appNameField.topAnchor.constraint(equalTo: appNameLabel.bottomAnchor, constant: 5),
            appNameField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            appNameField.widthAnchor.constraint(equalToConstant: fieldWidth + buttonWidth + 10),
            appNameField.heightAnchor.constraint(equalToConstant: fieldHeight),
        ])

        // 版本号
        NSLayoutConstraint.activate([
            versionLabel.topAnchor.constraint(equalTo: appNameField.bottomAnchor, constant: padding),
            versionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            
            versionField.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: 5),
            versionField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            versionField.widthAnchor.constraint(equalToConstant: fieldWidth + buttonWidth + 10),
            versionField.heightAnchor.constraint(equalToConstant: fieldHeight),
        ])
        
        // Bundle ID
        NSLayoutConstraint.activate([
            bundleIDLabel.topAnchor.constraint(equalTo: versionField.bottomAnchor, constant: padding),
            bundleIDLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            
            bundleIDField.topAnchor.constraint(equalTo: bundleIDLabel.bottomAnchor, constant: 5),
            bundleIDField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            bundleIDField.widthAnchor.constraint(equalToConstant: fieldWidth + buttonWidth + 10),
            bundleIDField.heightAnchor.constraint(equalToConstant: fieldHeight),
        ])
        
        // 导出路径
        NSLayoutConstraint.activate([
            exportPathLabel.topAnchor.constraint(equalTo: bundleIDField.bottomAnchor, constant: padding),
            exportPathLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            
            exportPathField.topAnchor.constraint(equalTo: exportPathLabel.bottomAnchor, constant: 5),
            exportPathField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            exportPathField.widthAnchor.constraint(equalToConstant: fieldWidth),
            exportPathField.heightAnchor.constraint(equalToConstant: fieldHeight),
            
            exportPathButton.leadingAnchor.constraint(equalTo: exportPathField.trailingAnchor, constant: 10),
            exportPathButton.centerYAnchor.constraint(equalTo: exportPathField.centerYAnchor),
            exportPathButton.widthAnchor.constraint(equalToConstant: buttonWidth),
        ])
        
        // 提交按钮
        NSLayoutConstraint.activate([
            submitButton.topAnchor.constraint(equalTo: exportPathField.bottomAnchor, constant: 30),
            submitButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            submitButton.widthAnchor.constraint(equalToConstant: 120),
            submitButton.heightAnchor.constraint(equalToConstant: 32),
        ])
        
        // 设置按钮动作
        ipaPathButton.target = self
        ipaPathButton.action = #selector(selectIPAPath)
        
        provisionFileButton.target = self
        provisionFileButton.action = #selector(selectProvisionFile)
        
        resourcePathButton.target = self
        resourcePathButton.action = #selector(selectResourcePath)
        
        exportPathButton.target = self
        exportPathButton.action = #selector(selectExportPath)
        
        submitButton.target = self
        submitButton.action = #selector(submitForm)
    }

    // MARK: - 按钮动作
    @objc private func selectIPAPath() {
        let openPanel = NSOpenPanel()
        openPanel.title = "选择 IPA 文件".localizable()
        openPanel.showsResizeIndicator = true
        openPanel.showsHiddenFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.allowedFileTypes = ["ipa"]
        
        if openPanel.runModal() == .OK {
            ipaPathField.stringValue = openPanel.url?.path ?? ""
        }
    }
    
    @objc private func selectProvisionFile() {
        let openPanel = NSOpenPanel()
        openPanel.title = "选择描述文件".localizable()
        openPanel.showsResizeIndicator = true
        openPanel.showsHiddenFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.allowedFileTypes = ["mobileprovision"]
        
        if openPanel.runModal() == .OK {
            provisionFileField.stringValue = openPanel.url?.path ?? ""
        }
    }

    @objc private func selectResourcePath() {
        let openPanel = NSOpenPanel()
        openPanel.title = "选择要注入的 Framework 目录".localizable()
        openPanel.canChooseDirectories = true
        
        if openPanel.runModal() == .OK {
            let paths = openPanel.urls.map { $0.path }
            resourcePathField.stringValue = paths.joined(separator: ",")
        }
    }

    @objc private func selectExportPath() {
        let openPanel = NSOpenPanel()
        openPanel.title = "选择导出 IPA 的目录".localizable()
        openPanel.showsResizeIndicator = true
        openPanel.showsHiddenFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        
        if openPanel.runModal() == .OK {
            if let url = openPanel.url {
                exportPathField.stringValue = url.path
            }
        }
    }

    @objc private func submitForm() {
        let ipaPath = ipaPathField.stringValue
        let provisionFilePath = provisionFileField.stringValue
        let resourcePaths = resourcePathField.stringValue
        let appName = appNameField.stringValue
        let version = versionField.stringValue
        let bundleID = bundleIDField.stringValue
        let exportPath = exportPathField.stringValue
        
        // 验证必填字段
//        guard !ipaPath.isEmpty else {
//            showAlert(title: "错误".localizable(), message: "请选择 IPA 文件路径".localizable())
//            return
//        }
//        
//        guard !provisionFilePath.isEmpty else {
//            showAlert(title: "错误".localizable(), message: "请选择描述文件路径")
//            return
//        }
                
        var framworks: String?;
        if (!resourcePaths.isEmpty) {
            framworks = getFileNamesAsString(from: resourcePaths)
        }
        print("""
        IPA 路径: \(ipaPath)
        描述文件路径: \(provisionFilePath)
        注入资源路径: \(String(describing: framworks))
        应用名称: \(appName)
        版本号: \(version)
        Bundle ID: \(bundleID)
        导出路径: \(exportPath)
        """)
        startInjectionProcess(
            ipaPath: ipaPath,
            provisionFilePath: provisionFilePath,
            resourcePaths: resourcePaths,
            appName: appName.isEmpty ? nil : appName,
            version: version.isEmpty ? nil : version,
            bundleID: bundleID.isEmpty ? nil : bundleID,
            exportPath: exportPath.isEmpty ? nil : exportPath
        )
    }

    private func startInjectionProcess(
        ipaPath: String,
        provisionFilePath: String,
        resourcePaths: String,
        appName: String?,
        version: String?,
        bundleID: String?,
        exportPath: String?
    ) {
        
        // 在需要显示 HUD 的地方
        let window: NSWindow? = NSApplication.shared.windows.first;
        self.hud = HUDViewController.showHUD(in: window!)
        let resign = ResignPackage.init(linkPath: ipaPath,
                                        appName: appName,
                                        version: version,
                                        bundleID: bundleID,
                                        provisionFilePath: provisionFilePath,
                                        injectResourcePath: resourcePaths,
                                        exportedIpaPath: exportPath,
                                        bundleVersion: nil
        );
        resign.printCallback = { message in
            DispatchQueue.main.async {
                self.hud?.log(message)
            }
        }
        DispatchQueue.global(qos: .background).async {
            resign.run { result in
                DispatchQueue.main.async {
                    if (result) {
                        self.hud?.log("任务执行结束".localizable());
                    } else {
                        self.hud?.log("请留意以上报错信息".localizable());
                    }
                }
            };
        }
    }
    
    func getFileNamesAsString(from directoryPath: String) -> String? {
        let fileManager = FileManager.default
        
        // 1. 检查目录是否存在
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directoryPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            print("目录不存在或不是文件夹")
            return nil
        }
        
        do {
            // 2. 获取目录下所有内容
            let contents = try fileManager.contentsOfDirectory(atPath: directoryPath)
            // 3. 过滤出文件
            var files = contents.map { item in
                return (directoryPath as NSString).appendingPathComponent(item)
            }
            files = files.filter({ item in
                return item.hasSuffix("framework")
            })
            
            // 4. 用逗号拼接文件名
            let result = files.joined(separator: ",")
            return result
            
        } catch {
            print("读取目录失败: \(error.localizedDescription)")
            return nil
        }
    }

    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.icon = NSImage.init(imageLiteralResourceName: "error");
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
        
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}
