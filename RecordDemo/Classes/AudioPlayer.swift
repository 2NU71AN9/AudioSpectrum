//
//  AudioPlayer.swift
//  RecordDemo
//
//  Created by 孙梁 on 2022/10/8.
//

import UIKit
import AVFoundation
import Accelerate
import MediaPlayer

public enum AudioPlayerState {
    case playing
    case pause
    case stop
}

public protocol AudioSpectrumPlayerDelegate: AnyObject {
    func playerStateChanged(state: AudioPlayerState)
    func player(currentDuration: Double, duration: Double, playEnded: Bool)
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
                        DispatchQueue.main.async {
                            strongSelf.delegate?.playerNoSpectrum()
                        }
                        return
                    }
                    /// 计算当前播放时间
                    if let lastRenderTime = strongSelf.player.lastRenderTime,
                        let time = strongSelf.player.playerTime(forNodeTime: lastRenderTime) {
                        let nowTime = Double(time.sampleTime) / time.sampleRate
                        DispatchQueue.main.async {
                            strongSelf.currentDuration = strongSelf.preTime + nowTime
                            if strongSelf.currentDuration <= strongSelf.audioDuration {
                                strongSelf.delegate?.player(currentDuration: strongSelf.currentDuration, duration: strongSelf.audioDuration, playEnded: strongSelf.currentDuration >= strongSelf.audioDuration)
                            } else {
                                strongSelf.pause()
                                strongSelf.delegate?.player(currentDuration: strongSelf.audioDuration, duration: strongSelf.audioDuration, playEnded: true)
                            }
                        }
                    }
                    
                    buffer.frameLength = AVAudioFrameCount(bufferSize)
                    let spectra = strongSelf.analyzer.analyse(with: buffer)
                    DispatchQueue.main.async {
                        strongSelf.delegate?.player(strongSelf, didGenerateSpectrum: spectra)
                    }
                })
            }
        }
    }
    
    public var audioUrl: URL? {
        didSet {
            setupAudio()
        }
    }
    public private(set) var playerState: AudioPlayerState = .stop {
        didSet {
            delegate?.playerStateChanged(state: playerState)
        }
    }
    public private(set) var audioFile: AVAudioFile?
    /// 总时间
    public private(set) var audioDuration: Double = 0
    /// 当前播放时间
    public private(set) var currentDuration: Double = 0
    ///
    private var preTime: Double = 0
    
    private let session = AVAudioSession.sharedInstance()
    private let nowPlayingC = MPNowPlayingInfoCenter.default()
    private let remoteC = MPRemoteCommandCenter.shared()
    
    public init(url: URL, frequencyBands: Int = 80) {
        try? session.setCategory(.playback, options: .defaultToSpeaker)
        try? session.setCategory(.playback, options: .allowBluetoothA2DP)
        self.audioUrl = url
        self.frequencyBands = frequencyBands
        setupAudio()
        setRemote()
        /// 监听中断
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption(_ :)), name: AVAudioSession.interruptionNotification, object: session)
        /// 监听耳机
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange(_ :)), name: AVAudioSession.routeChangeNotification, object: session)
        defer {
            self.bufferSize = 2048
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupAudio() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
        engine.prepare()

        if let audioUrl = audioUrl, let audioFile = try? AVAudioFile(forReading: audioUrl) {
            self.audioFile = audioFile
            preTime = 0
            currentDuration = 0
            audioDuration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
            delegate?.player(currentDuration: 0, duration: audioDuration, playEnded: false)
        }
    }
}

extension AudioPlayer {
    /// 开始播放
    public func play() {
        guard let audioFile = audioFile else { return }

//        syncOutputPortType()
        try? engine.start()
        player.stop()
//        player.scheduleFile(audioFile, at: nil, completionHandler: nil)
        let time = currentDuration < audioDuration ? currentDuration : 0
        let sampleTime = AVAudioFramePosition(time * audioFile.processingFormat.sampleRate)
        player.scheduleSegment(audioFile, startingFrame: sampleTime, frameCount: AVAudioFrameCount(audioFile.length - sampleTime), at: nil)
        preTime = time
        player.play()
        playerState = .playing
        setNowPlayingCenter()
    }
    public func play(at time: Int) {
        guard let audioFile = audioFile else { return }

//        syncOutputPortType()
        try? engine.start()
        preTime = Double(time)
        player.stop()
        let time: Double = min(audioDuration, Double(max(time, 0)))
        let sampleTime = AVAudioFramePosition(time * audioFile.processingFormat.sampleRate)
        player.scheduleSegment(audioFile, startingFrame: sampleTime, frameCount: AVAudioFrameCount(audioFile.length - sampleTime), at: nil)
        player.play()
        playerState = .playing
        setNowPlayingCenter()
    }
    /// 暂停播放
    public func pause() {
        player.pause()
        engine.pause()
        playerState = .pause
        setNowPlayingCenter()
    }
    /// 停止播放
    public func stop() {
        player.stop()
        engine.stop()
        delegate?.playerNoSpectrum()
        playerState = .stop
        setNowPlayingCenter()
    }
}

extension AudioPlayer {
    /// 设置锁屏播放
    private func setNowPlayingCenter() {
        nowPlayingC.nowPlayingInfo = [
            MPMediaItemPropertyTitle: "正在播放",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentDuration,
            MPMediaItemPropertyPlaybackDuration: audioDuration,
            MPNowPlayingInfoPropertyAssetURL: audioUrl
        ]
    }
    
    /// 耳机是否链接
    private var isEarConnect: Bool {
        let type = session.currentRoute.outputs.first?.portType ?? .builtInSpeaker
        return type == .headphones || type == .bluetoothA2DP
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
//            syncOutputPortType()
            if !isEarConnect { pause() }
        } else if reason == .newDeviceAvailable {
            // 连接了耳机
//            syncOutputPortType()
        } else if reason == .oldDeviceUnavailable {
            // 断开了设备
//            syncOutputPortType()
            pause()
        }
    }
    
//    private func syncOutputPortType() {
//        if isEarConnect {
//            if session.categoryOptions == .defaultToSpeaker {
//                try? session.setCategory(.playAndRecord, options: .allowBluetoothA2DP)
//                try? session.setActive(true)
//            }
//        } else {
//            if session.categoryOptions != .defaultToSpeaker {
//                try? session.setCategory(.playAndRecord, options: .defaultToSpeaker)
//                try? session.setActive(true)
//            }
//        }
//    }
    
    private func setRemote() {
        remoteC.playCommand.isEnabled = true
        remoteC.pauseCommand.isEnabled = true
        remoteC.stopCommand.isEnabled = true
        remoteC.togglePlayPauseCommand.isEnabled = true
        remoteC.changePlaybackPositionCommand.isEnabled = true
        remoteC.playCommand.addTarget { [weak self] event in
            self?.play()
            return .success
        }
        remoteC.pauseCommand.addTarget { [weak self] event in
            self?.pause()
            return .success
        }
        remoteC.stopCommand.addTarget { [weak self] event in
            self?.stop()
            return .success
        }
        remoteC.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self?.play(at: Int(event.positionTime))
            }
            return .success
        }
    }
    
    @objc func remoteCtlAction(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        play()
        return .success
    }
}
