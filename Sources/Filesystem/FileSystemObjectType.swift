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

import Foundation

public enum FileSystemObjectType: String {

    /// The object is a directory.
    case directory = "typeDirectory"

    /// The object is a regular file.
    case regular = "typeRegular"

    /// The object is a symbolic link.
    case symbolicLink = "typeSymbolicLink"

    /// The object is a socket.
    case socket = "typeSocket"

    /// The object is a characer special file.
    case characterSpecial = "typeCharacterSpecial"

    /// The object is a block special file.
    case blockSpecial = "typeBlockSpecial"

    /// The type of the object is unknown.
    case unknown = "typeUnknown"

}
