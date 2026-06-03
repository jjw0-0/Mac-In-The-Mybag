#if canImport(UIKit)
import Foundation
import VideoToolbox
import CoreMedia

/// Assembles displayable `CMSampleBuffer`s from H.264 frame data for
/// `AVSampleBufferDisplayLayer` (F2). Parameter sets (SPS/PPS) must be supplied before
/// frames can be turned into sample buffers.
public final class VideoStreamDecoder {
    private var formatDescription: CMVideoFormatDescription?

    public init() {}

    public var isReady: Bool { formatDescription != nil }

    /// Builds the H.264 format description from parameter sets (4-byte NAL length prefix).
    public func setParameterSets(sps: Data, pps: Data) {
        sps.withUnsafeBytes { spsRaw in
            pps.withUnsafeBytes { ppsRaw in
                guard let spsBase = spsRaw.bindMemory(to: UInt8.self).baseAddress,
                      let ppsBase = ppsRaw.bindMemory(to: UInt8.self).baseAddress else { return }
                let pointers: [UnsafePointer<UInt8>] = [spsBase, ppsBase]
                let sizes: [Int] = [sps.count, pps.count]
                var description: CMFormatDescription?
                let status = CMVideoFormatDescriptionCreateFromH264ParameterSets(
                    allocator: kCFAllocatorDefault,
                    parameterSetCount: 2,
                    parameterSetPointers: pointers,
                    parameterSetSizes: sizes,
                    nalUnitHeaderLength: 4,
                    formatDescriptionOut: &description)
                if status == noErr { self.formatDescription = description }
            }
        }
    }

    /// Wraps AVCC frame data into a ready-to-display sample buffer, or nil if not ready.
    public func sampleBuffer(forFrame data: Data, ptsMicros: UInt64, isKeyframe: Bool) -> CMSampleBuffer? {
        guard let formatDescription, !data.isEmpty else { return nil }

        var blockBuffer: CMBlockBuffer?
        let createStatus = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: data.count,
            blockAllocator: kCFAllocatorDefault, customBlockSource: nil,
            offsetToData: 0, dataLength: data.count, flags: 0, blockBufferOut: &blockBuffer)
        guard createStatus == kCMBlockBufferNoErr, let blockBuffer else { return nil }

        let copyStatus = data.withUnsafeBytes { raw -> OSStatus in
            guard let base = raw.baseAddress else { return -1 }
            return CMBlockBufferReplaceDataBytes(with: base, blockBuffer: blockBuffer,
                                                 offsetIntoDestination: 0, dataLength: data.count)
        }
        guard copyStatus == kCMBlockBufferNoErr else { return nil }

        var sampleBuffer: CMSampleBuffer?
        var timing = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: CMTime(value: CMTimeValue(ptsMicros), timescale: 1_000_000),
            decodeTimeStamp: .invalid)
        var sampleSize = data.count
        let status = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault, dataBuffer: blockBuffer,
            formatDescription: formatDescription, sampleCount: 1,
            sampleTimingEntryCount: 1, sampleTimingArray: &timing,
            sampleSizeEntryCount: 1, sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer)
        guard status == noErr else { return nil }
        return sampleBuffer
    }
}
#endif
