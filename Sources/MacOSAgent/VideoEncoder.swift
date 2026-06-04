#if os(macOS)
import Foundation
import VideoToolbox
import CoreMedia
import CoreVideo
import SharedCore

/// Hardware H.264/H.265 encoder (VideoToolbox) producing framed, low-latency output (B1, F1).
public final class VideoEncoder {
    public enum EncoderError: Error { case creationFailed(OSStatus) }

    /// Called for each encoded frame with its framing header and compressed bytes.
    public var onEncodedFrame: ((VideoFrameHeader, Data) -> Void)?

    /// Called once with the H.264 parameter sets (SPS, PPS) when they first become available,
    /// so the client can build its decoder format description.
    public var onParameterSets: ((Data, Data) -> Void)?

    /// The most recent H.264 parameter sets, cached so a newly-connected client can be sent
    /// them immediately without waiting to re-extract on the next keyframe.
    public private(set) var lastParameterSets: (sps: Data, pps: Data)?

    private var session: VTCompressionSession?
    private let width: Int32
    private let height: Int32
    private var sequence: UInt64 = 0

    public init(width: Int, height: Int, codec: VideoCodec = .h264, fps: Int = 60, bitrate: Int = 8_000_000) throws {
        self.width = Int32(width)
        self.height = Int32(height)

        let codecType: CMVideoCodecType = (codec == .h265) ? kCMVideoCodecType_HEVC : kCMVideoCodecType_H264
        var created: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: nil, width: Int32(width), height: Int32(height),
            codecType: codecType, encoderSpecification: nil, imageBufferAttributes: nil,
            compressedDataAllocator: nil, outputCallback: nil, refcon: nil,
            compressionSessionOut: &created)
        guard status == noErr, let session = created else { throw EncoderError.creationFailed(status) }
        self.session = session

        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: NSNumber(value: bitrate))
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: NSNumber(value: fps * 2))
        VTCompressionSessionPrepareToEncodeFrames(session)
    }

    deinit {
        if let session { VTCompressionSessionInvalidate(session) }
    }

    /// Submits a frame for encoding. Encoded output is delivered via `onEncodedFrame`.
    public func encode(_ pixelBuffer: CVPixelBuffer, pts: CMTime, forceKeyframe: Bool = false) {
        guard let session else { return }
        let frameProperties: CFDictionary? = forceKeyframe
            ? [kVTEncodeFrameOptionKey_ForceKeyFrame: true] as CFDictionary
            : nil

        VTCompressionSessionEncodeFrame(
            session, imageBuffer: pixelBuffer, presentationTimeStamp: pts, duration: .invalid,
            frameProperties: frameProperties, infoFlagsOut: nil
        ) { [weak self] status, _, sampleBuffer in
            guard let self, status == noErr, let sampleBuffer else { return }
            self.deliver(sampleBuffer, pts: pts)
        }
    }

    private func deliver(_ sampleBuffer: CMSampleBuffer, pts: CMTime) {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        var lengthAtOffset = 0
        var totalLength = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        guard CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0,
                                          lengthAtOffsetOut: &lengthAtOffset,
                                          totalLengthOut: &totalLength,
                                          dataPointerOut: &dataPointer) == noErr,
              let dataPointer else { return }

        let data = Data(bytes: dataPointer, count: totalLength)

        if lastParameterSets == nil,
           let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
           let (sps, pps) = Self.parameterSets(from: formatDescription) {
            lastParameterSets = (sps, pps)
            onParameterSets?(sps, pps)
        }

        sequence &+= 1
        let seconds = pts.seconds
        let ptsMicros = seconds.isFinite ? UInt64(max(0, seconds * 1_000_000)) : 0
        let header = VideoFrameHeader(
            isKeyframe: Self.isKeyframe(sampleBuffer),
            sequence: sequence,
            ptsMicros: ptsMicros,
            width: UInt16(clamping: Int(width)),
            height: UInt16(clamping: Int(height)))
        onEncodedFrame?(header, data)
    }

    static func isKeyframe(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
                as? [[CFString: Any]],
              let first = attachments.first else { return true }
        let notSync = (first[kCMSampleAttachmentKey_NotSync] as? Bool) ?? false
        return !notSync
    }

    static func parameterSets(from formatDescription: CMFormatDescription) -> (sps: Data, pps: Data)? {
        var spsPointer: UnsafePointer<UInt8>?
        var spsSize = 0
        var count = 0
        let s0 = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            formatDescription, parameterSetIndex: 0,
            parameterSetPointerOut: &spsPointer, parameterSetSizeOut: &spsSize,
            parameterSetCountOut: &count, nalUnitHeaderLengthOut: nil)
        var ppsPointer: UnsafePointer<UInt8>?
        var ppsSize = 0
        let s1 = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            formatDescription, parameterSetIndex: 1,
            parameterSetPointerOut: &ppsPointer, parameterSetSizeOut: &ppsSize,
            parameterSetCountOut: nil, nalUnitHeaderLengthOut: nil)
        guard s0 == noErr, s1 == noErr, count >= 2,
              let spsPointer, let ppsPointer else { return nil }
        return (Data(bytes: spsPointer, count: spsSize), Data(bytes: ppsPointer, count: ppsSize))
    }
}
#endif
