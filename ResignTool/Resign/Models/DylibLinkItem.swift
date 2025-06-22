//
//  DylibLinkItem.swift
//  swift-tools
//
//  Created by liujixin on 2022/5/24.
//

import Foundation

enum DylibLinkItemType: String {
    /// 原系统库
    case originSystem
    /// 原用户库
    case originInject
    /// 注入库
    case userInject
}

class DylibLinkItem: NSObject {
    var type: DylibLinkItemType = .originSystem
    var link: String = ""
    var injectResourcePath: String?
    
    init(type: DylibLinkItemType, link: String) {
        self.injectResourcePath = nil
        self.type = type
        self.link = link
    }
    
    init(type: DylibLinkItemType, link: String, injectResourcePath: String) {
        self.type = type
        self.link = link
        self.injectResourcePath = injectResourcePath
    }

}
