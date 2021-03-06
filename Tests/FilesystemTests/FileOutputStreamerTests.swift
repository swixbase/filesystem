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

import XCTest
import Foundation

@testable import Filesystem

class FileOutputStreamerTests: XCTestCase {

    let fsManager = FileSystem.default
    let fileHandler = FileHandler.default

    static var allTests : [(String, (FileOutputStreamerTests) -> () throws -> Void)] {
        return [
            ("testWriteData", testWriteData)
        ]
    }

    // MARK: - Helpers

    func createTestFile(atPath path: String) {
        let content = "abcdefghijklmnopqrstuvwxyz".data(using: .utf8)!
        fsManager.createFile(atPath: path, content: content)
    }

    func deleteTestFile(atPath path: String) {
        do {
            try fsManager.deleteObject(atPath: path)
        } catch let error as FileSystemError  {
            XCTFail(error.description)
        } catch {
            XCTFail("Unhandled error")
        }
    }

    // MARK: - Tests

    func testWriteData() throws {
        let testfilePath = "\(fsManager.workPath)/\(UUID().uuidString)"

        let fileOutStreamer: FileOutputStreamer = try FileOutputStreamer(file: testfilePath)
        let writeData = "abcdefghijklmnopqrstuvwxyz".data(using: .utf8)!
        let count = fileOutStreamer.write(content: writeData)
        fileOutStreamer.synchronize()
        
        let data = try fileHandler.readWholeFile(atPath: testfilePath)
        let content = String(data: data, encoding: .utf8)!

        XCTAssertEqual(content, "abcdefghijklmnopqrstuvwxyz")
        XCTAssertEqual(Int(count), writeData.count)
        deleteTestFile(atPath: testfilePath)
    }

}
