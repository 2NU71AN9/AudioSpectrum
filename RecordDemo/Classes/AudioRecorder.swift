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
    func recorder(_ recorder: AudioRecorder, didGenerateSpectrum spectrum: [[Float]])
    func recorderNoSpectrum()
}

public class AudioRecorder {
    
    public weak var delegate: AudioSpectrumRecorderDelegate?
    
    /// 保存每个录音文件
    public var filePaths: [String] = []
    
    /// 保存路径
    private let fileDir = (NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first ?? (NSHomeDirectory() + "/Library/Caches")) + "/Audios"
    /// 文件名
    private var fileName: String
    /// 文件全路径
    private var filePath: URL
    /// 频带数量
    private var frequencyBands: Int
    public lazy var analyzer = RealtimeAnalyzer(fftSize: 2048, frequencyBands: frequencyBands)
    private lazy var engine = AVAudioEngine()
    public lazy var recorder: AVAudioRecorder = {
        // PCM=>wav AAC=>aac
        let recordSetting: [String: Any] = [AVSampleRateKey: NSNumber(value: 22050.0),//采样率
                                              AVFormatIDKey: NSNumber(value: kAudioFormatMPEG4AAC),
//                                              AVFormatIDKey: NSNumber(value: kAudioFormatLinearPCM),//音频格式
                                     AVLinearPCMBitDepthKey: NSNumber(value: 16),//采样位数
                                      AVNumberOfChannelsKey: NSNumber(value: 1),//通道数
                                   AVEncoderAudioQualityKey: NSNumber(value: AVAudioQuality.high.rawValue)//录音质量
        ]
        let recorder = try? AVAudioRecorder(url: filePath, settings: recordSetting)
        recorder?.isMeteringEnabled = true
        return recorder ?? AVAudioRecorder()
    }()
        
    public init(fileName: String, frequencyBands: Int = 80) {
        self.fileName = fileName
        self.frequencyBands = frequencyBands
        let exist = FileManager.default.fileExists(atPath: fileDir)
        if !exist {
            //如果文件夹不存在
            try? FileManager.default.createDirectory(atPath: fileDir, withIntermediateDirectories: true)
        }
        var url: URL
        if #available(iOS 16.0, *) {
            url = URL(filePath: String(format: "%@/%@.aac", fileDir, fileName))
        } else {
            url = URL(fileURLWithPath: String(format: "%@/%@.aac", fileDir, fileName))
        }
        self.filePath = url
        
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
    }
}

extension AudioRecorder {
    /// 开始录音
    public func record() {
        recorder.stop()
        recorder.prepareToRecord()
        recorder.record()
        engine.prepare()
        try? engine.start()
    }
    
    /// 暂停录音
    public func pause() {
        recorder.stop()
        engine.pause()
        delegate?.recorderNoSpectrum()
        rename()
    }
    
    /// 停止录音
    public func stop() {
        recorder.stop()
        engine.stop()
        delegate?.recorderNoSpectrum()
        rename()
    }
    
    /// 合成一个录音文件
    public func joinAudios(complete: @escaping (String?) -> Void) {
        AudioFileJoin.joinAudios(filePaths, outputPath: filePath.absoluteString) { path in
            complete(path)
        }
    }
}

extension AudioRecorder {
    /// 文件重命名
    private func rename() {
        let newPath = String(format: "%@/%@.%@", fileDir, UUID().uuidString, filePath.pathExtension)
        do {
            try FileManager.default.moveItem(at: filePath, to: string2url(newPath))
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
}
