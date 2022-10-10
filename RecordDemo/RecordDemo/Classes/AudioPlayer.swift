//
//  AudioPlayer.swift
//  RecordDemo
//
//  Created by 孙梁 on 2022/10/8.
//

import UIKit
import AVFoundation
import Accelerate

public protocol AudioSpectrumPlayerDelegate: AnyObject {
    func player(_ player: AudioPlayer, didGenerateSpectrum spectrum: [[Float]])
    func playerNoSpectrum()
}

public class AudioPlayer {
    public weak var delegate: AudioSpectrumPlayerDelegate?
    private let engine = AVAudioEngine()
    public let player = AVAudioPlayerNode()
    /// 频带数量
    private var frequencyBands: Int
    public var analyzer: RealtimeAnalyzer!
    public var bufferSize: Int? {
        didSet {
            if let bufferSize = bufferSize {
                analyzer = RealtimeAnalyzer(fftSize: bufferSize, frequencyBands: frequencyBands)
                engine.mainMixerNode.removeTap(onBus: 0)
                engine.mainMixerNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize), format: nil, block: { [weak self] (buffer, when) in
                    guard let strongSelf = self else { return }
                    if !strongSelf.player.isPlaying {
                        strongSelf.delegate?.playerNoSpectrum()
                        return
                    }
                    buffer.frameLength = AVAudioFrameCount(bufferSize)
                    let spectra = strongSelf.analyzer.analyse(with: buffer)
                    strongSelf.delegate?.player(strongSelf, didGenerateSpectrum: spectra)
                })
            }
        }
    }
    
    public init(bufferSize: Int = 2048, frequencyBands: Int = 80) {
        self.frequencyBands = frequencyBands
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
        defer {
            self.bufferSize = bufferSize
        }
    }
}

extension AudioPlayer {
    /// 开始播放
    public func play(withUrl url: URL) {
        guard let audioFile = try? AVAudioFile(forReading: url) else { return }
        player.stop()
        engine.prepare()
        try? engine.start()
        player.scheduleFile(audioFile, at: nil, completionHandler: nil)
        player.play()
    }
    
    /// 暂停播放
    public func stop() {
        player.stop()
        engine.stop()
        delegate?.playerNoSpectrum()
    }
}
