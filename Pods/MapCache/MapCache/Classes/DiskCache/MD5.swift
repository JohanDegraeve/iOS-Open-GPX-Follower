//
//  MD5.swift
//  MapCache
//
//  Based on Open GPX Tracker created by merlos on 02/06/2019.
//
//
//  CryptoSwiftMD5.Swift
//
// To date, adding CommonCrypto to a Swift framework is problematic. See:
// http://stackoverflow.com/questions/25248598/importing-commoncrypto-in-a-swift-framework
// We're using a subset of CryptoSwift as a (temporary?) alternative.
// The following is an altered source version that only includes MD5. The original software can be found at:
// https://github.com/krzyzanowskim/CryptoSwift
// This is the original copyright notice:

/*
 Copyright (C) 2014 Marcin Krzyżanowski <marcin.krzyzanowski@gmail.com>
 This software is provided 'as-is', without any express or implied warranty.
 In no event will the authors be held liable for any damages arising from the use of this software.
 Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
 - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
 - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
 - This notice may not be removed or altered from any source or binary distribution.
 */

import Foundation

/// array of bytes, little-endian representation
func arrayOfBytes<T>(value:T, length:Int? = nil) -> [UInt8] {
    let totalBytes = length ?? MemoryLayout<T>.size
    
    let valuePointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
    valuePointer.pointee = value
    
    let bytesPointer = UnsafeMutablePointer<UInt8>(OpaquePointer(valuePointer))
    var bytes = Array<UInt8>(repeating: 0, count: totalBytes)
    for j in 0..<min(MemoryLayout<T>.size,totalBytes) {
        bytes[totalBytes - 1 - j] = (bytesPointer + j).pointee
    }
    
    valuePointer.deinitialize(count: 1)
    valuePointer.deallocate()
    
    return bytes
}

/// Extension for the implementation of MD5
extension Int {
    /// Array of bytes with optional padding (little-endian)
    public func bytes(totalBytes: Int = MemoryLayout<Int>.size) -> [UInt8] {
        return arrayOfBytes(value: self, length: totalBytes)
    }
    
}

/// Extension for the implementation of MD5
extension NSMutableData {
    
    /// Convenient way to append bytes
    internal func appendBytes(arrayOfBytes: [UInt8]) {
        self.append(arrayOfBytes, length: arrayOfBytes.count)
    }
    
}

/// Bytes sequence for the implementation of MD5
/// The following is an altered source version that only includes MD5. The original software can be found at:
/// https://github.com/krzyzanowskim/CryptoSwift
struct BytesSequence: Sequence {
    /// Chunk size
    let chunkSize: Int
    /// Data
    let data: [UInt8]
    /// makeIterator
    func makeIterator() -> AnyIterator<ArraySlice<UInt8>> {
        var offset:Int = 0
        return AnyIterator {
            let end = Swift.min(self.chunkSize, self.data.count - offset)
            let result = self.data[offset..<offset + end]
            offset += result.count
            return !result.isEmpty ? result : nil
        }
    }
}

/// HashBase
/// The following is an altered source version that only includes MD5. The original software can be found at:
/// https://github.com/krzyzanowskim/CryptoSwift
class HashBase {
    
    ///
    static let size:Int = 16 // 128 / 8
    
    /// Message to be converted into a MD5 string
    let message: [UInt8]
    
    /// Constructor
    /// - Parameter message the string as an array of UInt8
    init (_ message: [UInt8]) {
        self.message = message
    }
    
    /// Common part for hash calculation. Prepare header data.
    func prepare(_ len:Int) -> [UInt8] {
        var tmpMessage = message
        
        // Step 1. Append Padding Bits
        tmpMessage.append(0x80) // append one bit (UInt8 with one bit) to message
        
        // append "0" bit until message length in bits ≡ 448 (mod 512)
        var msgLength = tmpMessage.count
        var counter = 0
        
        while msgLength % len != (len - 8) {
            counter += 1
            msgLength += 1
        }
        
        tmpMessage += Array<UInt8>(repeating: 0, count: counter)
        return tmpMessage
    }
}

/// Rotate left for MD5 implementation
func rotateLeft(v: UInt32, n: UInt32) -> UInt32 {
    return ((v << n) & 0xFFFFFFFF) | (v >> (32 - n))
}

/// sliceToUInt32 for MD5 implementation
func sliceToUInt32Array(_ slice: ArraySlice<UInt8>) -> [UInt32] {
    var result = [UInt32]()
    result.reserveCapacity(16)
    for idx in stride(from: slice.startIndex, to: slice.endIndex, by: MemoryLayout<UInt32>.size) {
        let val1:UInt32 = (UInt32(slice[idx.advanced(by: 3)]) << 24)
        let val2:UInt32 = (UInt32(slice[idx.advanced(by: 2)]) << 16)
        let val3:UInt32 = (UInt32(slice[idx.advanced(by: 1)]) << 8)
        let val4:UInt32 = UInt32(slice[idx])
        let val:UInt32 = val1 | val2 | val3 | val4
        result.append(val)
    }
    return result
}

/// An actual implementation of the MD5
/// The following is an altered source version that only includes MD5. The original software can be found at:
/// https://github.com/krzyzanowskim/CryptoSwift
class MD5 : HashBase {
    
    
    /// specifies the per-round shift amounts
    private let s: [UInt32] = [7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22,
                               5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20,
                               4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23,
                               6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21]
    
    /// binary integer part of the sines of integers (Radians)
    private let k: [UInt32] = [0xd76aa478,0xe8c7b756,0x242070db,0xc1bdceee,
                               0xf57c0faf,0x4787c62a,0xa8304613,0xfd469501,
                               0x698098d8,0x8b44f7af,0xffff5bb1,0x895cd7be,
                               0x6b901122,0xfd987193,0xa679438e,0x49b40821,
                               0xf61e2562,0xc040b340,0x265e5a51,0xe9b6c7aa,
                               0xd62f105d,0x2441453,0xd8a1e681,0xe7d3fbc8,
                               0x21e1cde6,0xc33707d6,0xf4d50d87,0x455a14ed,
                               0xa9e3e905,0xfcefa3f8,0x676f02d9,0x8d2a4c8a,
                               0xfffa3942,0x8771f681,0x6d9d6122,0xfde5380c,
                               0xa4beea44,0x4bdecfa9,0xf6bb4b60,0xbebfbc70,
                               0x289b7ec6,0xeaa127fa,0xd4ef3085,0x4881d05,
                               0xd9d4d039,0xe6db99e5,0x1fa27cf8,0xc4ac5665,
                               0xf4292244,0x432aff97,0xab9423a7,0xfc93a039,
                               0x655b59c3,0x8f0ccc92,0xffeff47d,0x85845dd1,
                               0x6fa87e4f,0xfe2ce6e0,0xa3014314,0x4e0811a1,
                               0xf7537e82,0xbd3af235,0x2ad7d2bb,0xeb86d391]
    
    /// H
    private let h: [UInt32] = [0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476]
    
    /// Calculates the MD5 as an array of UInt8
    func calculate() -> [UInt8] {
        var tmpMessage = prepare(64)
        tmpMessage.reserveCapacity(tmpMessage.count + 4)
        
        // initialize hh with hash values
        var hh = h
        
        // Step 2. Append Length a 64-bit representation of lengthInBits
        let lengthInBits = (message.count * 8)
        let lengthBytes = lengthInBits.bytes(totalBytes: 64 / 8)
        tmpMessage += lengthBytes.reversed()
        
        // Process the message in successive 512-bit chunks:
        let chunkSizeBytes = 512 / 8 // 64
        for chunk in BytesSequence(chunkSize: chunkSizeBytes, data: tmpMessage) {
            // break chunk into sixteen 32-bit words M[j], 0 ≤ j ≤ 15
            let M = sliceToUInt32Array(chunk)
            assert(M.count == 16, "Invalid array")
            
            // Initialize hash value for this chunk:
            var A:UInt32 = hh[0]
            var B:UInt32 = hh[1]
            var C:UInt32 = hh[2]
            var D:UInt32 = hh[3]
            
            var dTemp:UInt32 = 0
            
            // Main loop
            for j in 0..<k.count {
                var g = 0
                var F:UInt32 = 0
                
                switch (j) {
                case 0...15:
                    F = (B & C) | ((~B) & D)
                    g = j
                    break
                case 16...31:
                    F = (D & B) | (~D & C)
                    g = (5 * j + 1) % 16
                    break
                case 32...47:
                    F = B ^ C ^ D
                    g = (3 * j + 5) % 16
                    break
                case 48...63:
                    F = C ^ (B | (~D))
                    g = (7 * j) % 16
                    break
                default:
                    break
                }
                dTemp = D
                D = C
                C = B
                B = B &+ rotateLeft(v: A &+ F &+ k[j] &+ M[g], n: s[j])
                A = dTemp
            }
            
            hh[0] = hh[0] &+ A
            hh[1] = hh[1] &+ B
            hh[2] = hh[2] &+ C
            hh[3] = hh[3] &+ D
        }
        
        var result = [UInt8]()
        result.reserveCapacity(hh.count / 4)
        
        hh.forEach {
            let itemLE = $0.littleEndian
            result += [UInt8(itemLE & 0xff), UInt8((itemLE >> 8) & 0xff), UInt8((itemLE >> 16) & 0xff), UInt8((itemLE >> 24) & 0xff)]
        }
        
        return result
    }
}
