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

public class FileOutputStreamer {

    // MARK: Properties, initialization, deinitialization

    /// File stream in which data record is made.
    fileprivate let outputStream: UnsafeMutablePointer<FILE>

    /// Initialization.
    ///
    /// - Parameter file:  Path to the file in which it is necessary to make record.
    ///
    /// - Throws: `FileSystemError.openFileAtPathFailed`
    ///
    /// - Note: File would be created, if it doesn't exist.
    ///
    public init(file: String) throws {
        guard let os = fopen(file, "a+") else {
            throw FileSystemError.openFileAtPathFailed(path: file)
        }
        self.outputStream = os
    }

    deinit {
        synchronize()
        close()
    }

}

extension FileOutputStreamer {

    // MARK: Methods

    /// Writes data in a file stream.
    /// If the write operation is successful, return the actual number of bytes write in the stream.
    ///
    /// - Parameter content: Data to be written to a file.
    ///
    @discardableResult
    public func write(content: Data) -> UInt64 {
        var remaining = content.count
        var done = 0
        
        var bufferSize = 8 * 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        
        defer {
            buffer.deinitialize()
            buffer.deallocate(capacity: bufferSize)
        }
        
        repeat {
            let count = min(bufferSize, remaining)
            let upper = done + (count - 1)
            let range = Range<Data.Index>(done...upper)
            content.copyBytes(to: buffer, from: range)
            fwrite(buffer, count, 1, outputStream)
            done += count
            remaining -= count
        } while remaining > 0
        
        return UInt64(done)
    }

    /// Transfers all modified in-core data of (i.e., modified buffer cache pages for)
    /// the file stream to the disk device.
    ///
    public func synchronize() {
        fflush(outputStream)
        fsync(fileno(outputStream))
    }

    /// Close a file stream.
    ///
    public func close() {
        fclose(outputStream)
    }

}
