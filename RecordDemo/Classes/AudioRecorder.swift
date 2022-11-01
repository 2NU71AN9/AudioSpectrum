//
//  AudioRecorder.swift
//  RecordDemo
//
//  Created by 孙梁 on 2022/10/8.
//

import UIKit
import AVFoundation
import Accelerate

public protocol AudioSpectrumRecorderDelegate: AnyObject {
    func recorderStart()
    func recorderPause()
    func recorderStop()
    func recorder(_ recorder: AudioRecorder, didGenerateSpectrum spectrum: [[Float]])
    func recorderNoSpectrum()
}

public class AudioRecorder {
    
    public enum FileType: String {
        case wav
        case aac
        
        var formatID: AudioFormatID {
            switch self {
            case .wav:
                return kAudioFormatLinearPCM
            case .aac:
                return kAudioFormatMPEG4AAC
            }
        }
    }
    
    public weak var delegate: AudioSpectrumRecorderDelegate?
    /// 保存路径
    public let fileDir = (NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first ?? (NSHomeDirectory() + "/Library/Caches")) + "/Audios"
    /// 文件全路径
    private var filePath: String
    /// 保存每个录音文件
    private var filePaths: [String] = []
    /// 合成后录音的保存路径
    private var outputPath: String?
    /// 频带数量
    private var frequencyBands: Int
    /// 文件类型
    private var fileType: FileType = .wav
    public lazy var analyzer = RealtimeAnalyzer(fftSize: 2048, frequencyBands: frequencyBands)
    
    private let session = AVAudioSession.sharedInstance()
    private lazy var engine = AVAudioEngine()
    public lazy var recorder: AVAudioRecorder = {
        // PCM=>wav AAC=>aac
        let recordSetting: [String: Any] = [AVSampleRateKey: NSNumber(value: 22050.0),//采样率
                                              AVFormatIDKey: NSNumber(value: fileType.formatID),//音频格式
                                     AVLinearPCMBitDepthKey: NSNumber(value: 16),//采样位数
                                      AVNumberOfChannelsKey: NSNumber(value: 1),//通道数
                                   AVEncoderAudioQualityKey: NSNumber(value: AVAudioQuality.high.rawValue)//录音质量
        ]
        let recorder = try? AVAudioRecorder(url: string2url(filePath), settings: recordSetting)
        recorder?.isMeteringEnabled = true
        return recorder ?? AVAudioRecorder()
    }()
        
    public init(frequencyBands: Int = 80, fileType: FileType = .wav) {
        try? session.setCategory(.playAndRecord, mode: .videoRecording, options: .defaultToSpeaker)
        try? session.setCategory(.playAndRecord, mode: .videoRecording, options: .allowBluetoothA2DP)
        try? session.setActive(true)
        
        let fileName = UUID().uuidString
        self.frequencyBands = frequencyBands
        self.fileType = fileType
        let exist = FileManager.default.fileExists(atPath: fileDir)
        if !exist {
            //如果文件夹不存在
            try? FileManager.default.createDirectory(atPath: fileDir, withIntermediateDirectories: true)
        }
        self.filePath = String(format: "%@/%@.%@", fileDir, fileName, fileType.rawValue)
        
        engine.inputNode.removeTap(onBus: 0)
        engine.inputNode.installTap(onBus: 0, bufferSize: 2048, format: nil, block: { [weak self] buffer, when in
            guard let strongSelf = self else { return }
            if !strongSelf.recorder.isRecording {
                strongSelf.delegate?.recorderNoSpectrum()
                return
            }
            buffer.frameLength = AVAudioFrameCount(2048)
            let spectra = strongSelf.analyzer.analyse(with: buffer)
            strongSelf.delegate?.recorder(strongSelf, didGenerateSpectrum: spectra.count > 1 ? spectra : [spectra.first ?? [0], [0]])
        })
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption(_ :)), name: AVAudioSession.interruptionNotification, object: session)
        /// 监听耳机
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange(_ :)), name: AVAudioSession.routeChangeNotification, object: session)
    }
    
    deinit {
        filePaths.forEach {
            try? FileManager.default.removeItem(atPath: $0)
        }
        NotificationCenter.default.removeObserver(self)
    }
}

extension AudioRecorder {
    /// 重录
    public func reRecord() {
        filePaths.forEach {
            try? FileManager.default.removeItem(atPath: $0)
        }
        if let outputPath = outputPath {
            try? FileManager.default.removeItem(atPath: outputPath)
        }
        try? session.setCategory(.playAndRecord, mode: .videoRecording, options: .defaultToSpeaker)
        try? session.setCategory(.playAndRecord, mode: .videoRecording, options: .allowBluetoothA2DP)
        try? session.setActive(true)
        record()
    }
    
    /// 开始录音
    public func record() {
        recorder.stop()
        recorder.prepareToRecord()
        recorder.record()
        engine.prepare()
        try? engine.start()
        delegate?.recorderStart()
    }
    
    /// 暂停录音
    public func pause() {
        recorder.stop()
        engine.pause()
        delegate?.recorderNoSpectrum()
        rename()
        delegate?.recorderPause()
    }
    
    /// 停止录音
    public func stop() {
        recorder.stop()
        engine.stop()
        delegate?.recorderNoSpectrum()
        rename()
        delegate?.recorderStop()
    }
    
    /// 合成一个录音文件
    public func joinAudios(complete: @escaping (String?) -> Void) {
        outputPath = String(format: "%@/%@.%@", fileDir, UUID().uuidString, fileType.rawValue)
        AudioFileJoin.appendAudios(filePaths, outputPath: outputPath!) { [weak self] path in
            complete(path)
            self?.filePaths.forEach {
                try? FileManager.default.removeItem(atPath: $0)
            }
        }
    }
}

extension AudioRecorder {
    /// 文件重命名
    private func rename() {
        guard FileManager.default.fileExists(atPath: filePath) else { return }
        let newPath = String(format: "%@/%@.%@", fileDir, UUID().uuidString, string2url(filePath).pathExtension)
        do {
            try FileManager.default.moveItem(at: string2url(filePath), to: string2url(newPath))
            filePaths.append(newPath)
        } catch let error {
            print(error)
        }
    }
    
    private func string2url(_ str: String) -> URL {
        if #available(iOS 16.0, *) {
            return URL(filePath: str)
        } else {
            return URL(fileURLWithPath: str)
        }
    }
    
    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                let reason = AVAudioSession.InterruptionType(rawValue: reasonValue) else { return }
        if reason == .began {
            pause()
        }
    }
    
    @objc private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
                let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
        if reason == .categoryChange {

        } else if reason == .newDeviceAvailable {
            // 连接了耳机
            try? session.setPreferredInput(session.currentRoute.inputs.first)
        } else if reason == .oldDeviceUnavailable {
            // 断开了设备
            try? session.setPreferredInput(session.currentRoute.inputs.first)
        } else if reason == .override {
            // 断开了耳机
            try? session.setPreferredInput(session.currentRoute.inputs.first)
        }
    }
}
