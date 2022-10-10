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

    private var fileName: String
    /// 频带数量
    private var frequencyBands: Int
    public lazy var analyzer = RealtimeAnalyzer(fftSize: 2048, frequencyBands: frequencyBands)
    private lazy var engine = AVAudioEngine()
    public lazy var recorder: AVAudioRecorder = {
        let path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first ?? (NSHomeDirectory() + "/Library/Audios")
        var url: URL
        if #available(iOS 16.0, *) {
            url = URL(filePath: String(format: "%@/%@.wav", path, fileName))
        } else {
            url = URL(fileURLWithPath: String(format: "%@/%@.wav", path, fileName))
        }
        let recordSetting: [String: Any] = [AVSampleRateKey: NSNumber(value: 22050.0),//采样率
                                              AVFormatIDKey: NSNumber(value: kAudioFormatLinearPCM),//音频格式
                                     AVLinearPCMBitDepthKey: NSNumber(value: 16),//采样位数
                                      AVNumberOfChannelsKey: NSNumber(value: 2),//通道数
                                   AVEncoderAudioQualityKey: NSNumber(value: AVAudioQuality.min.rawValue)//录音质量
        ]
        let recorder = try? AVAudioRecorder(url: url, settings: recordSetting)
        recorder?.isMeteringEnabled = true
        return recorder ?? AVAudioRecorder()
    }()
        
    public init(fileName: String, frequencyBands: Int = 80) {
        self.fileName = fileName
        self.frequencyBands = frequencyBands
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
    }
    
    /// 停止录音
    public func stop() {
        recorder.stop()
        engine.stop()
        delegate?.recorderNoSpectrum()
    }
}
