/// Copyright 2017 Sergei Egorov
///
/// Licensed under the Apache License, Version 2.0 (the "License");
/// you may not use this file except in compliance with the License.
/// You may obtain a copy of the License at
///
/// http://www.apache.org/licenses/LICENSE-2.0
///
/// Unless required by applicable law or agreed to in writing, software
/// distributed under the License is distributed on an "AS IS" BASIS,
/// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
/// See the License for the specific language governing permissions and
/// limitations under the License.

#if os(OSX) || os(iOS)
    import Darwin.C
#elseif os(Linux) || CYGWIN
    import Glibc
#endif

import Foundation

public class FileSystem {

    // MARK: Properties, initialization, deinitialization
    
    /// Returns the default singleton instance.
    private static let _default = FileSystem()

    public class var `default`: FileSystem {
        return _default
    }

    public init() {}

}

extension FileSystem {

    // MARK: Process methods

    public var workPath: String {
        let maxBytes = Int(PATH_MAX) + 1
        let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: maxBytes)
        defer {
            buffer.deinitialize(count: maxBytes)
            buffer.deallocate(capacity: maxBytes)
        }
        getcwd(buffer, maxBytes)
        let path = String(cString: buffer)
        return path
    }
}

extension FileSystem {

    // MARK: Attribute methods

    /// Return true if the object exists.
    ///
    /// - Parameter path: The path to the object, the existence of which must 
    ///                   will be checked.
    ///
    /// - Note: This method does not follow links.
    ///
    public func existsObject(atPath path: String) -> Bool {
        return access(path, F_OK) == 0
    }

    /// Returns the object attributes.
    ///
    /// - Parameter path: The path to the object that you want to get attributes.
    ///
    /// - Throws: `FileSystemError.getAttributesFailed`
    ///
    /// - Note: This method does not follow links.
    ///
    public func attributesOfObject(atPath path: String) throws -> [String: AnyHashable] {
        var st = stat()
        guard lstat(path, &st) == 0 else {
            throw FileSystemError.getAttributesFailed(path: path)
        }

        var attr: [String: AnyHashable] = [:]

        var type: String
        switch st.st_mode & S_IFMT {
            case S_IFCHR: type = FileSystemObjectType.characterSpecial.rawValue
            case S_IFDIR: type = FileSystemObjectType.directory.rawValue
            case S_IFBLK: type = FileSystemObjectType.blockSpecial.rawValue
            case S_IFREG: type = FileSystemObjectType.regular.rawValue
            case S_IFLNK: type = FileSystemObjectType.symbolicLink.rawValue
            case S_IFSOCK: type = FileSystemObjectType.socket.rawValue
            default: type = FileSystemObjectType.unknown.rawValue
        }

        attr["type"] = type
        attr["size"] = UInt64(st.st_size)
        #if os(OSX) || os(iOS)
            attr["accessDate"] = Date(timeIntervalSince1970: TimeInterval(st.st_atimespec.tv_sec))
            attr["modificationDate"] = Date(timeIntervalSince1970: TimeInterval(st.st_mtimespec.tv_sec))
        #elseif os(Linux) || CYGWIN
            attr["accessDate"] = Date(timeIntervalSince1970: TimeInterval(st.st_atim.tv_sec))
            attr["modificationDate"] = Date(timeIntervalSince1970: TimeInterval(st.st_mtim.tv_sec))
        #endif
        attr["possixPermissions"] = UInt16(st.st_mode & 0o7777)

        return attr
    }

    /// If object exists returns the object type (represents FSObjectType enum),
    /// otherwise return nil.
    ///
    /// - Parameter path: The path to the object that you want to get attribute.
    ///
    /// - Note: This method does not follow links.
    ///
    public func typeOfObject(atPath path: String) -> FileSystemObjectType? {
        let attributes = try? attributesOfObject(atPath: path)
        guard let value = attributes?["type"] as? String else { return nil }
        return FileSystemObjectType(rawValue: value)
    }

    /// If object exists returns the size of the object in bytes, 
    /// otherwise return nil.
    ///
    /// - Parameter path: The path to the object that you want to get attribute.
    ///
    /// - Note: This method does not follow links.
    ///
    public func sizeOfObject(atPath path: String) -> UInt64? {
        let attributes = try? attributesOfObject(atPath: path)
        guard let value = attributes?["size"] as? NSNumber else { return nil }
        return value.uint64Value
    }

    /// If object exists returns the creation date of the object, 
    /// otherwise return nil.
    ///
    /// - Parameter path: The path to the object that you want to get attribute.
    ///
    /// - Note: This method does not follow links.
    ///
    public func accessDateOfObject(atPath path: String) -> Date? {
        let attributes = try? attributesOfObject(atPath: path)
        guard let value = attributes?["accessDate"] as? Date else { return nil }
        return value
    }

    /// If object exists returns the modification date of the object, 
    /// otherwise return nil.
    ///
    /// - Parameter path: The path to the object that you want to get attribute.
    ///
    /// - Note: This method does not follow links.
    ///
    public func modificationDateOfObject(atPath path: String) -> Date? {
        let attributes = try? attributesOfObject(atPath: path)
        guard let value = attributes?["modificationDate"] as? Date else { return nil }
        return value
    }

    /// If object exists returns the POSIX permissions of the object, 
    /// otherwise return nil.
    ///
    /// - Parameter path: The path to the object that you want to get attribute.
    ///
    /// - Note: This method does not follow links.
    ///
    public func posixPermissionsOfObject(atPath path: String) -> UInt16? {
        let attributes = try? attributesOfObject(atPath: path)
        guard let value = attributes?["posixPermissions"] as? NSNumber else { return nil }
        return value.uint16Value
    }

}

extension FileSystem {

    // MARK: Permission methods

    /// Return true if the object can be read from.
    ///
    /// - Parameter path: The path to the object, for which permission must be obtained.
    ///
    public func isReadableObject(atPath path: String) -> Bool {
        return access(path, R_OK) == 0
    }

    /// Return true if the object can be written to.
    ///
    /// - Parameter path: The path to the object, for which permission must be obtained.
    ///
    public func isWritableObject(atPath path: String) -> Bool {
        return access(path, W_OK) == 0
    }

    /// Return true if the object can be executed.
    ///
    /// - Parameter path: The path to the object, for which permission must be obtained.
    ///
    public func isExecutableObject(atPath path: String) -> Bool {
        return access(path, X_OK) == 0
    }

}

extension FileSystem {

    // MARK: Filesystem methods

    /// If the object is a directory, returns the object children paths.
    ///
    /// - Parameters:
    ///   - path:      The path to the object that you want to get a contents.
    ///   - recursive: Whether to obtain the paths recursively.
    ///                Default value is `false`.
    ///
    /// - Throws: `FileSystemError.getDirectoryContentsFailed`
    ///
    /// - Note: this method follow links if recursive is `false`, otherwise not follow links.
    ///
    public func contentsOfDirectory(atPath path: String, recursive: Bool = false) throws -> [String] {
        guard let dir = opendir(path) else { throw FileSystemError.getDirectoryContentsFailed(path: path) }
        
        defer { closedir(dir) }

        var children: [String] = []
        var ep = readdir(dir)

        while ep != nil {
            guard let name = ep?.pointee.d_name else { return [] }

            var nameBuf: [CChar] = []
            let mirror = Mirror(reflecting: name)

            for child in mirror.children {
                guard let c = child.value as? Int8 else { return [] }
                nameBuf.append(c)
            }
            nameBuf.append(0)

            let child = String(cString: nameBuf)
            ep = readdir(dir)
            if child != "." && child != ".." { children.append(child) }
        }

        return children
    }

    /// Creates a symbolic link at a path that points to object.
    ///
    /// - Parameters:
    ///   - path:   The path to which at which the link of the object will be created.
    ///   - object: The path to the object for which to create a symbolic link.
    ///
    /// - Throws: 
    ///   - `FileSystemError.objectDoesNotExist`
    ///   - `FileSystemError.createSymlinkFailed`
    ///
    public func createSymbolicLink(atPath path: String, ofObject object: String) throws {
        guard existsObject(atPath: object) else {
            throw FileSystemError.objectDoesNotExist(path: object)
        }

        if directoryReadyForWrite(path) {
            do {
                let linkPath = "\(path.directoryPathForWrite)\(object.lastPathComponent)"
                try symboliclink(atPath: linkPath, withDestinationPath: object)
                return
            } catch {
                throw FileSystemError.createSymlinkFailed(from: object, to: path)
            }
        }

        guard
            existsObject(atPath: path) == false,
            directoryReadyForWrite(path.deletingLastPathComponent)
        else {
            throw FileSystemError.createSymlinkFailed(from: object, to: path)
        }

        do {
            try symboliclink(atPath: path, withDestinationPath: object)
        } catch {
            throw FileSystemError.createSymlinkFailed(from: object, to: path)
        }
    }

    /// Creates a hard link of object to path.
    ///
    /// - Parameters:
    ///   - path:   The path to which the link of the object will be created.
    ///   - object: The path to the object for which to create a hard link.
    ///
    /// - Throws: 
    ///   - `FileSystemError.objectDoesNotExist`
    ///   - `FileSystemError.createHardlinkFailed`
    ///
    public func createHardLink(ofObject object: String, toPath path: String) throws {
        guard existsObject(atPath: object) else {
            throw FileSystemError.objectDoesNotExist(path: object)
        }

        if directoryReadyForWrite(path) {
            do {
                let linkPath = "\(path.directoryPathForWrite)\(object.lastPathComponent)"
                try hardlink(atPath: object, toPath: linkPath)
                return
            } catch {
                throw FileSystemError.createHardlinkFailed(from: object, to: path)
            }
        }

        guard
            existsObject(atPath: path) == false,
            directoryReadyForWrite(path.deletingLastPathComponent)
        else {
            throw FileSystemError.createHardlinkFailed(from: object, to: path)
        }

        do {
            try hardlink(atPath: object, toPath: path)
        } catch {
            throw FileSystemError.createHardlinkFailed(from: object, to: path)
        }
    }

    /// Deletes the object.
    ///
    /// Throws an error if the object cannot be deleted, or doe's not exist.
    ///
    /// - Parameter path: The path to the object you want to delete.
    ///
    /// - Throws: 
    ///   - `FileSystemError.objectDoesNotExist`
    ///   - `FileSystemError.deleteObjectFailed`
    ///
    /// - Note: This method does not follow links.
    ///
    public func deleteObject(atPath path: String) throws {
        guard existsObject(atPath: path) else {
            throw FileSystemError.objectDoesNotExist(path: path)
        }

        do {
            try removeItem(atPath: path)
        } catch {
            throw FileSystemError.deleteObjectFailed(path: path)
        }
    }

    /// Moves the object at its current location to a path.
    ///
    /// Throws an error if the object cannot be moved.
    ///
    /// - Parameters:
    ///   - srcPath: The path to the object you want to move.
    ///   - dstPath: Path destination of the object.
    ///
    /// - Throws: 
    ///   - `FileSystemError.objectDoesNotExist`
    ///   - `FileSystemError.moveObjectFailed`
    ///
    /// - Note: This method does not follow links.
    ///
    public func moveObject(atPath srcPath: String, toPath dstPath: String) throws {
        guard existsObject(atPath: srcPath) else {
            throw FileSystemError.objectDoesNotExist(path: srcPath)
        }

        if directoryReadyForWrite(dstPath) {
            do {
                let destinationPath = "\(dstPath.directoryPathForWrite)\(srcPath.lastPathComponent)"
                try moveItem(atPath: srcPath, toPath: destinationPath)
                return
            } catch {
                throw FileSystemError.moveObjectFailed(from: srcPath, to: dstPath)
            }
        }

        guard
            existsObject(atPath: dstPath) == false,
            directoryReadyForWrite(dstPath.deletingLastPathComponent)
        else {
            throw FileSystemError.moveObjectFailed(from: srcPath, to: dstPath)
        }

        do {
            try moveItem(atPath: srcPath, toPath: dstPath)
        } catch {
            throw FileSystemError.moveObjectFailed(from: srcPath, to: dstPath)
        }
    }

    /// Copies the object at its current location to a path.
    ///
    /// Throws an error if the object could not be copied or if a object
    /// already exists at the destination path.
    ///
    /// - Parameters:
    ///   - srcPath: The path to the object you want to copy.
    ///   - dstPath: Path destination of the object.
    ///
    /// - Throws: 
    ///   - `FileSystemError.objectDoesNotExist`
    ///   - `FileSystemError.copyObjectFailed`
    ///
    /// - Note: This method does not follow links.
    ///
    public func copyObject(atPath srcPath: String, toPath dstPath: String) throws {
        guard existsObject(atPath: srcPath) else {
            throw FileSystemError.objectDoesNotExist(path: srcPath)
        }

        if directoryReadyForWrite(dstPath) {
            do {
                let destinationPath = "\(dstPath.directoryPathForWrite)\(srcPath.lastPathComponent)"
                try copyItem(atPath: srcPath, toPath: destinationPath)
                return
            } catch {
                throw FileSystemError.copyObjectFailed(from: srcPath, to: dstPath)
            }
        }

        guard
            existsObject(atPath: dstPath) == false,
            directoryReadyForWrite(dstPath.deletingLastPathComponent)
        else {
            throw FileSystemError.copyObjectFailed(from: srcPath, to: dstPath)
        }

        do {
            try copyItem(atPath: srcPath, toPath: dstPath)
        } catch {
            throw FileSystemError.copyObjectFailed(from: srcPath, to: dstPath)
        }
    }

    /// Creates a directory at its path.
    ///
    /// Throws an error if the object already exists at the destination path,
    /// or destination directory is not writable.
    ///
    /// - Parameter path: The path on which the directory will be created.
    ///
    /// - Throws: 
    ///   - `FileSystemError.objectAlreadyExists`
    ///   - `FileSystemError.createObjectFailed`
    ///
    public func createDirectory(atPath path: String) throws {
        guard !existsObject(atPath: path) else {
            throw FileSystemError.objectAlreadyExists(path: path)
        }

        if directoryReadyForWrite(path.deletingLastPathComponent) {
            if mkdir(path, S_IRWXO | S_IRWXG | S_IRWXU) != 0 {
                throw FileSystemError.createObjectFailed(path: path)
            }
        }
    }

    /// Creates a regular file at its path.
    ///
    /// Return true if file successfully created.
    ///
    /// - Parameters:
    ///   - path:    The path on which the directory will be created.
    ///   - content: The contents of the file.
    ///
    /// - Note: If the file already exists, it is would be overwritten.
    ///
    @discardableResult
    public func createFile(atPath path: String, content: Data?) -> Bool {
        let modes = S_IROTH | S_IRGRP | S_IRUSR | S_IWOTH | S_IWGRP | S_IWUSR
        let fd = open(path, O_WRONLY | O_CREAT, modes)
       
        defer { close(fd) }
        
        guard fd > -1 else { return false }
        
        guard let data = content else { return true }

        let bufferSize = data.count
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer {
            buffer.deinitialize(count: bufferSize)
            buffer.deallocate(capacity: bufferSize)
        }
        data.copyBytes(to: buffer, count: bufferSize)
        return write(fd, buffer, bufferSize) == data.count
    }

}

extension FileSystem {

    // MARK: Private methods

    fileprivate func directoryReadyForWrite(_ path: String) -> Bool {
        guard existsObject(atPath: path),
            typeOfObject(atPath: path) == .directory,
            isWritableObject(atPath: path) else {

            return false
        }
        return true
    }

    fileprivate func symboliclink(atPath path: String, withDestinationPath dstPath: String) throws {
        if symlink(dstPath, path) != 0 {
            throw NSError(domain: "com.swixbase.filesystem.error", code: Int(errno), userInfo: nil)
        }
    }

    fileprivate func hardlink(atPath srcPath: String, toPath dstPath: String) throws {
        if link(srcPath, dstPath) != 0 {
            throw NSError(domain: "com.swixbase.filesystem.error", code: Int(errno), userInfo: nil)
        }
    }

    fileprivate func moveItem(atPath srcPath: String, toPath dstPath: String) throws {
        try copyItem(atPath: srcPath, toPath: dstPath)
        try removeItem(atPath: srcPath)
    }

    fileprivate func removeItem(atPath path: String) throws {
        guard let type = typeOfObject(atPath: path), type == .directory else {
            guard unlink(path) == 0 else {
                throw NSError(domain: "com.swixbase.filesystem.error", code: Int(errno), userInfo: nil)
            }
            return
        }
        let children = try contentsOfDirectory(atPath: path)
        for child in children {
            try removeItem(atPath: "\(path)/\(child)")
        }
        guard rmdir(path) == 0 else {
            throw NSError(domain: "com.swixbase.filesystem.error", code: Int(errno), userInfo: nil)
        }
    }

    fileprivate func copyItem(atPath srcPath: String, toPath dstPath: String) throws {
        guard let type = typeOfObject(atPath: srcPath), type == .directory else {
            var st = stat()
            var done = 0
            
            let bufferSize = 8 * 1024
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)

            defer {
                buffer.deinitialize(count: bufferSize)
                buffer.deallocate(capacity: bufferSize)
            }

            stat(srcPath, &st)

            let fdIn = open(srcPath, O_RDONLY)
            let fdOut = open(dstPath, O_WRONLY | O_CREAT, st.st_mode)

            defer {
                close(fdOut)
                close(fdIn)
            }

            while done < Int(st.st_size) {
                let count = read(fdIn, buffer, bufferSize)
                write(fdOut, buffer, count)
                done += count
            }

            return
        }

        try createDirectory(atPath: dstPath)
        let children = try contentsOfDirectory(atPath: srcPath)
        for child in children {
            try copyItem(atPath: "\(srcPath)/\(child)", toPath: "\(dstPath)/\(child)")
        }
    }

}
