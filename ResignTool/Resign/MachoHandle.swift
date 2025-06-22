//
//  MachoHandle.swift
//  ResignTool
//
//  Created by 刘吉新 on 2025/6/16.
//

import Foundation

// Helper functions
func insert(filePath: String, toInsertData: Data, offset: Int) {
    let fh = try! FileHandle(forUpdating: URL(fileURLWithPath: filePath))
    fh.seek(toFileOffset: UInt64(offset))
    let remainData = fh.readDataToEndOfFile()
    fh.truncateFile(atOffset: UInt64(offset))
    fh.write(toInsertData)
    fh.write(remainData)
    fh.synchronizeFile()
    fh.closeFile()
}

func delete(filePath: String, offset: Int, size: Int) {
    let fh = try! FileHandle(forUpdating: URL(fileURLWithPath: filePath))
    fh.seek(toFileOffset: UInt64(offset + size))
    let remainData = fh.readDataToEndOfFile()
    fh.truncateFile(atOffset: UInt64(offset))
    fh.write(remainData)
    fh.synchronizeFile()
    fh.closeFile()
}

func loadBytes(file: FileHandle, offset: Int, size: Int) -> UnsafeMutableRawPointer {
    file.seek(toFileOffset: UInt64(offset))
    let data = file.readData(ofLength: size)
    let buf = calloc(1, size)
    data.copyBytes(to: buf!.assumingMemoryBound(to: UInt8.self), count: data.count)
    return buf!
}

class MachoHandle {
    private var machoFileHandle: FileHandle
    private var machoPath: String
    
    // MARK: - Public Methods
    
    init?(machoPath: String) {
        guard FileManager.default.fileExists(atPath: machoPath) else {
            assertionFailure("file not exists at: \(machoPath)")
            return nil
        }
        
        self.machoPath = machoPath
        self.machoFileHandle = try! FileHandle(forUpdating: URL(fileURLWithPath: machoPath))
        
        let magic = _readMagic(withOffset: 0)
        guard MachoHandle._isValidMacho(ofMagic: magic) else {
            assertionFailure("\(machoPath) is a illegal macho file")
            return nil
        }
    }
    
    // MARK: - Arch
    func getFatArchs() -> [FatArch] {
        let magic = _readMagic(withOffset: 0)
        let isFat = MachoHandle._isFat(ofMagic: magic)
        let is64 = MachoHandle._isMagic64(magic)
        let shouldSwap = MachoHandle._shouldSwapBytes(ofMagic: magic)
        
        if !isFat {
            return []
        }
        
        let fat_header_size = MemoryLayout<fat_header>.size
        let fat_arch_size = MemoryLayout<fat_arch>.size
        
        let fatHeader = loadBytes(file: machoFileHandle, offset: 0, size: fat_header_size).assumingMemoryBound(to: fat_header.self)
        if shouldSwap {
            swap_fat_header(fatHeader, NX_UnknownByteOrder)
        }
        
        var result = [FatArch]()
        var arch_offset = fat_header_size
        
        for _ in 0..<fatHeader.pointee.nfat_arch {
            let fatArchObj = FatArch()
            
            if is64 {
                let arch = loadBytes(file: machoFileHandle, offset: arch_offset, size: fat_arch_size).assumingMemoryBound(to: fat_arch_64.self)
                if shouldSwap {
                    swap_fat_arch_64(arch, 1, NX_UnknownByteOrder)
                }
                fatArchObj.fatArch64 = arch
            } else {
                let arch = loadBytes(file: machoFileHandle, offset: arch_offset, size: fat_arch_size).assumingMemoryBound(to: fat_arch.self)
                if shouldSwap {
                    swap_fat_arch(arch, 1, NX_UnknownByteOrder)
                }
                fatArchObj.fatArch = arch
            }
            fatArchObj.offset = arch_offset
            result.append(fatArchObj)
            arch_offset += fat_arch_size
        }
        
        return result
    }

    // MARK: - MachHeader
    
    func getMachHeader(inFatArch fatArch: FatArch?) -> MachHeader {
        var mach_header_offset: Int = 0
        
        if let fatArch = fatArch {
            if fatArch.fatArch != nil {
                mach_header_offset = Int(fatArch.fatArch!.pointee.offset)
            } else if fatArch.fatArch64 != nil {
                mach_header_offset = Int(fatArch.fatArch64!.pointee.offset)
            } else {
                assertionFailure("fatArch is nil")
            }
        }
        
        let machHeaderObj = MachHeader()
        machHeaderObj.offset = mach_header_offset
        
        let magic = _readMagic(withOffset: mach_header_offset)
        let is_64 = MachoHandle._isMagic64(magic)
        let is_swap_mach = MachoHandle._shouldSwapBytes(ofMagic: magic)

        if is_64 {
            let header_size = MemoryLayout<mach_header_64>.size
            let header = loadBytes(file: machoFileHandle, offset: mach_header_offset, size: header_size).assumingMemoryBound(to: mach_header_64.self)
            if is_swap_mach {
                swap_mach_header_64(header, NX_UnknownByteOrder)
            }
            machHeaderObj.machHeader64 = header
        } else {
            let header_size = MemoryLayout<mach_header>.size
            let header = loadBytes(file: machoFileHandle, offset: mach_header_offset, size: header_size).assumingMemoryBound(to: mach_header.self)
            if is_swap_mach {
                swap_mach_header(header, NX_UnknownByteOrder)
            }
            machHeaderObj.machHeader = header
        }
        
        return machHeaderObj
    }

    // MARK: - Dylib Link
    
    func addDylibLink(_ link: String) {
        let fatArchs = getFatArchs()
        if fatArchs.count > 0 {
            for arch in fatArchs {
                _addLink(link, inFatArch: arch)
            }
        } else {
            _addLink(link, inFatArch: nil)
        }
    }
    
    func removeLinkedDylib(_ link: String) {
        let fatArchs = getFatArchs()
        if fatArchs.count > 0 {
            for arch in fatArchs {
                _removeLink(link, inFatArch: arch)
            }
        } else {
            _removeLink(link, inFatArch: nil)
        }
    }

    func getLinkName(forDylibCmd dylibCmd: DylibCommand) -> String {
        let pathstringLen = Int(dylibCmd.dylibCmd!.pointee.cmdsize) - Int(dylibCmd.dylibCmd!.pointee.dylib.name.offset)
        let paths = loadBytes(file: machoFileHandle, offset: dylibCmd.offset + Int(dylibCmd.dylibCmd!.pointee.dylib.name.offset), size: pathstringLen)
        return String(cString: paths.assumingMemoryBound(to: CChar.self))
    }

    // MARK: - Load Command
    
    func getAllLoadCommands(inFatArch fatArch: FatArch?) -> [LoadCommand] {
        let machheader = getMachHeader(inFatArch: fatArch)
        return _getLoadCommands(afterMachHeader: machheader)
    }
    
    func getLoadCommands(inFatArch fatArch: FatArch?, loadCommandType: Int) -> [LoadCommand] {
        let lcmds = getAllLoadCommands(inFatArch: fatArch)
        return lcmds.filter { $0.loadCmd?.pointee.cmd == UInt32(loadCommandType) }
    }

    func getDylibCommand(inFatArch fatArch: FatArch?) -> [DylibCommand] {
        var result = [DylibCommand]()
        let machheader = getMachHeader(inFatArch: fatArch)
        let magic = _readMagic(withOffset: machheader.offset)
        let shouldSwap = MachoHandle._shouldSwapBytes(ofMagic: magic)
        
        var lcmds = getLoadCommands(inFatArch: fatArch, loadCommandType: Int(LC_LOAD_DYLIB))
        lcmds += getLoadCommands(inFatArch: fatArch, loadCommandType: Int(LC_LOAD_UPWARD_DYLIB))
        
        for cmd in lcmds {
            let dylib = loadBytes(file: machoFileHandle, offset: cmd.offset, size: MemoryLayout<dylib_command>.size).assumingMemoryBound(to: dylib_command.self)
            if shouldSwap {
                swap_dylib_command(dylib, NX_UnknownByteOrder)
            }
            
            let dylibcmd = DylibCommand()
            dylibcmd.offset = cmd.offset
            dylibcmd.dylibCmd = dylib
            result.append(dylibcmd)
        }
        
        return result
    }

    // MARK: - Private Methods
    
    private func _addLink(_ link: String, inFatArch arch: FatArch?) {
        var dylib_size = UInt32(link.data(using: .utf8)!.count) + UInt32(MemoryLayout<dylib_command>.size)
        dylib_size += UInt32(MemoryLayout<UInt>.size) - (dylib_size % UInt32(MemoryLayout<UInt>.size)) // Align to UInt size
        
        var dyld = dylib_command()
        dyld.cmd = UInt32(LC_LOAD_DYLIB)
        dyld.cmdsize = dylib_size
        dyld.dylib.compatibility_version = 0
        dyld.dylib.current_version = 0
        dyld.dylib.timestamp = 0
        dyld.dylib.name.offset = UInt32(MemoryLayout<dylib_command>.size)
        
        let machHeader = getMachHeader(inFatArch: arch)
        let headerOffset = machHeader.offset
        var headerSize = 0
        var originNcmdSize = 0

        // Modify mach header
        if let machHeaderPtr = machHeader.machHeader {
            originNcmdSize = Int(machHeaderPtr.pointee.sizeofcmds)
            headerSize = MemoryLayout<mach_header>.size
            machHeaderPtr.pointee.ncmds += 1
            machHeaderPtr.pointee.sizeofcmds += dyld.cmdsize
            
            machoFileHandle.seek(toFileOffset: UInt64(machHeader.offset))
            machoFileHandle.write(Data(bytes: machHeaderPtr, count: MemoryLayout<mach_header>.size))
        } else if let machHeader64Ptr = machHeader.machHeader64 {
            originNcmdSize = Int(machHeader64Ptr.pointee.sizeofcmds)
            headerSize = MemoryLayout<mach_header_64>.size
            machHeader64Ptr.pointee.ncmds += 1
            machHeader64Ptr.pointee.sizeofcmds += dyld.cmdsize
            
            machoFileHandle.seek(toFileOffset: UInt64(machHeader.offset))
            machoFileHandle.write(Data(bytes: machHeader64Ptr, count: MemoryLayout<mach_header_64>.size))
        }
        
        machoFileHandle.seek(toFileOffset: UInt64(headerOffset + headerSize + originNcmdSize))
        machoFileHandle.write(Data(bytes: &dyld, count: MemoryLayout<dylib_command>.size))
        machoFileHandle.write(link.data(using: .utf8)!)
    }

    private func _removeLink(_ link: String, inFatArch arch: FatArch?) {
        let allDlCmds = getDylibCommand(inFatArch: arch)
        guard let toDelDc = allDlCmds.first(where: { dc in
            let linkName = getLinkName(forDylibCmd: dc)
            return linkName.range(of: link) != nil
        }) else {
            return
        }
        
        let machHeader = getMachHeader(inFatArch: arch)
        let headerOffset = machHeader.offset
        var headerSize = 0
        var originNcmdSize = 0
        
        // Change mach header
        if let machHeaderPtr = machHeader.machHeader {
            originNcmdSize = Int(machHeaderPtr.pointee.sizeofcmds)
            headerSize = MemoryLayout<mach_header>.size
            machHeaderPtr.pointee.ncmds -= 1
            machHeaderPtr.pointee.sizeofcmds -= toDelDc.dylibCmd!.pointee.cmdsize
            
            machoFileHandle.seek(toFileOffset: UInt64(machHeader.offset))
            machoFileHandle.write(Data(bytes: machHeaderPtr, count: MemoryLayout<mach_header>.size))
        } else if let machHeader64Ptr = machHeader.machHeader64 {
            originNcmdSize = Int(machHeader64Ptr.pointee.sizeofcmds)
            headerSize = MemoryLayout<mach_header_64>.size
            machHeader64Ptr.pointee.ncmds -= 1
            machHeader64Ptr.pointee.sizeofcmds -= toDelDc.dylibCmd!.pointee.cmdsize
            
            machoFileHandle.seek(toFileOffset: UInt64(machHeader.offset))
            machoFileHandle.write(Data(bytes: machHeader64Ptr, count: MemoryLayout<mach_header_64>.size))
        }

        let n = Int(toDelDc.dylibCmd!.pointee.cmdsize)
        var arr = [UInt8](repeating: 0, count: n)
        insert(filePath: machoPath, toInsertData: Data(bytes: &arr, count: n), offset: headerOffset + headerSize + originNcmdSize)
        delete(filePath: machoPath, offset: toDelDc.offset, size: Int(toDelDc.dylibCmd!.pointee.cmdsize))
    }
    
    private func _getLoadCommands(afterMachHeader machHeader: MachHeader) -> [LoadCommand] {
        var ncmds = 0
        var load_commands_offset = 0
        
        if machHeader.machHeader != nil {
            ncmds = Int(machHeader.machHeader!.pointee.ncmds)
            load_commands_offset = machHeader.offset + MemoryLayout<mach_header>.size
        } else if machHeader.machHeader64 != nil {
            ncmds = Int(machHeader.machHeader64!.pointee.ncmds)
            load_commands_offset = machHeader.offset + MemoryLayout<mach_header_64>.size
        } else {
            assertionFailure("nil machHeader")
        }
        
        let magic = _readMagic(withOffset: machHeader.offset)
        let shouldSwap = MachoHandle._shouldSwapBytes(ofMagic: magic)
        
        var result = [LoadCommand]()

        for _ in 0..<ncmds {
            let cmd = loadBytes(file: machoFileHandle, offset: load_commands_offset, size: MemoryLayout<load_command>.size).assumingMemoryBound(to: load_command.self)
            if shouldSwap {
                swap_load_command(cmd, NX_UnknownByteOrder)
            }
            
            let lc = LoadCommand()
            lc.offset = load_commands_offset
            lc.loadCmd = cmd
            
            result.append(lc)
            
            load_commands_offset += Int(cmd.pointee.cmdsize)
        }
        
        return result
    }

    // MARK: - Magic
    
    private func _readMagic(withOffset offset: Int) -> UInt32 {
        let t = loadBytes(file: machoFileHandle, offset: offset, size: MemoryLayout<UInt32>.size).assumingMemoryBound(to: UInt32.self)
        return t.pointee
    }
    
    private static func _isFat(ofMagic magic: UInt32) -> Bool {
        return magic == FAT_MAGIC || magic == FAT_CIGAM
    }
    
    private static func _isMagic64(_ magic: UInt32) -> Bool {
        return magic == MH_MAGIC_64 || magic == MH_CIGAM_64
    }
    
    private static func _shouldSwapBytes(ofMagic magic: UInt32) -> Bool {
        return magic == MH_CIGAM || magic == MH_CIGAM_64 || magic == FAT_CIGAM
    }
    
    private static func _isValidMacho(ofMagic magic: UInt32) -> Bool {
        return magic == FAT_MAGIC || magic == FAT_CIGAM ||
               magic == MH_MAGIC_64 || magic == MH_MAGIC ||
               magic == MH_CIGAM || magic == MH_CIGAM_64
    }
    
    deinit {
        machoFileHandle.closeFile()
    }
}

// Helper classes
class FatArch {
    var fatArch: UnsafeMutablePointer<fat_arch>?
    var fatArch64: UnsafeMutablePointer<fat_arch_64>?
    var offset: Int = 0
}

class MachHeader {
    var machHeader: UnsafeMutablePointer<mach_header>?
    var machHeader64: UnsafeMutablePointer<mach_header_64>?
    var offset: Int = 0
}

class LoadCommand {
    var loadCmd: UnsafeMutablePointer<load_command>?
    var offset: Int = 0
}

class DylibCommand {
    var dylibCmd: UnsafeMutablePointer<dylib_command>?
    var offset: Int = 0
}
