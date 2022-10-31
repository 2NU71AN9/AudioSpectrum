//
//  AudioEasyPlayer.swift
//  RecordDemo
//
//  Created by 孙梁 on 2022/10/31.
//

import UIKit
import AVFoundation
import MediaPlayer

public protocol AudioEasyPlayerDelegate: AnyObject {
    func playerStateChanged(state: AudioPlayerState)
    func player(currentDuration: Double, duration: Double)
}

public class AudioEasyPlayer: NSObject {
    
    public weak var delegate: AudioEasyPlayerDelegate? {
        didSet {
            if let player {
                delegate?.player(currentDuration: player.currentTime, duration: player.duration)
            }
        }
    }

    private lazy var player: AVAudioPlayer? = {
        let player = try? AVAudioPlayer(contentsOf: audioUrl)
        player?.delegate = self
        return player
    }()
    
    private let remoteC = MPRemoteCommandCenter.shared()
    private lazy var timer = Timer(fire: Date.distantFuture, interval: 0.5, repeats: true) { [weak self] _ in
        self?.delegate?.player(currentDuration: self?.player?.currentTime ?? 0, duration: self?.player?.duration ?? 0)
    }
    public let audioUrl: URL
    
    public init(url: URL) {
        if let type = AVAudioSession.sharedInstance().currentRoute.outputs.first?.portType {
            if type == .bluetoothA2DP || type == .headphones {
                try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: .allowBluetoothA2DP)
            } else {
                try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: .defaultToSpeaker)
            }
        }
        self.audioUrl = url
        super.init()
        
        setRemote()
        /// 监听耳机
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange(_ :)), name: AVAudioSession.routeChangeNotification, object: AVAudioSession.sharedInstance())
        
        RunLoop.main.add(timer, forMode: .common)
        player?.prepareToPlay()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        timer.invalidate()
        player = nil
    }
}

extension AudioEasyPlayer: AVAudioPlayerDelegate {
    /// 当音频播放完成时
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        delegate?.playerStateChanged(state: .stop)
    }
    /// 音频播放器在播放过程中遇到解码错误时
    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        delegate?.playerStateChanged(state: .stop)
    }
}

extension AudioEasyPlayer {
    /// 耳机是否链接
    private var isEarConnect: Bool {
        let type = AVAudioSession.sharedInstance().currentRoute.outputs.first?.portType ?? .builtInSpeaker
        return type == .headphones || type == .bluetoothA2DP
    }
    
    @objc private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
                let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
        if reason == .categoryChange {
            syncOutputPortType()
            if !isEarConnect { pause() }
        } else if reason == .newDeviceAvailable {
            // 连接了耳机
            syncOutputPortType()
        } else if reason == .oldDeviceUnavailable {
            // 断开了设备
            syncOutputPortType()
            pause()
        }
    }
    
    private func syncOutputPortType() {
        if isEarConnect {
            if AVAudioSession.sharedInstance().categoryOptions != .allowBluetoothA2DP {
                try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: .allowBluetoothA2DP)
                try? AVAudioSession.sharedInstance().setActive(true)
            }
        } else {
            if AVAudioSession.sharedInstance().categoryOptions != .defaultToSpeaker {
                try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: .defaultToSpeaker)
                try? AVAudioSession.sharedInstance().setActive(true)
            }
        }
    }
    
    private func setRemote() {
        remoteC.playCommand.isEnabled = true
        remoteC.pauseCommand.isEnabled = true
        remoteC.stopCommand.isEnabled = true
        remoteC.togglePlayPauseCommand.isEnabled = true
        remoteC.playCommand.addTarget { [weak self] event in
            if !(self?.isEarConnect ?? true) {
                try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: .allowBluetoothA2DP)
                try? AVAudioSession.sharedInstance().setActive(true)
            }
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
    }
    
    @objc func remoteCtlAction(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        play()
        return .success
    }
}

extension AudioEasyPlayer {
    public var audioDuration: Double { player?.duration ?? 0 }
    public var isPlaying: Bool { player?.isPlaying ?? false }
    
    public func play() {
        guard let player else { return }
        if player.play() {
            timer.fireDate = Date.distantPast
            delegate?.playerStateChanged(state: .playing)
        } else {
            delegate?.playerStateChanged(state: .stop)
        }
    }
    public func play(at time: TimeInterval) {
        guard let player else { return }
        if time >= player.duration {
            pause()
            player.currentTime = 0
        } else {
            player.currentTime = time
            delegate?.playerStateChanged(state: player.isPlaying ? .playing : .pause)
        }
    }
    public func pause() {
        guard let player else { return }
        player.pause()
        timer.fireDate = Date.distantFuture
        delegate?.playerStateChanged(state: player.isPlaying ? .playing : .pause)
    }
    public func stop() {
        guard let player else { return }
        player.stop()
        timer.fireDate = Date.distantFuture
        delegate?.playerStateChanged(state: player.isPlaying ? .playing : .stop)
    }
}
