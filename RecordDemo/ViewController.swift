//
//  ViewController.swift
//  RecordDemo
//
//  Created by 孙梁 on 2022/10/8.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var spectrumView: SpectrumView!
    
    @IBOutlet weak var curTimeLabel: UILabel!
    @IBOutlet weak var allTimeLabel: UILabel!
    @IBOutlet weak var slider: UISlider!
    
    private lazy var recorder: AudioRecorder = {
        let recorder = AudioRecorder(fileName: "123", frequencyBands: 80)
        recorder.delegate = self
        return recorder
    }()
    private lazy var player: AudioPlayer = {
        let url = Bundle.main.url(forResource: trackPaths[0], withExtension: nil)!
//        let path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first ?? (NSHomeDirectory() + "/Library/Audios")
//        var url: URL
//        if #available(iOS 16.0, *) {
//            url = URL(filePath: String(format: "%@/123.aac", path))
//        } else {
//            url = URL(fileURLWithPath: String(format: "%@/123.aac", path))
//        }
        let player = AudioPlayer(url: url, frequencyBands: 80)
        player.delegate = self
        return player
    }()
    
    private var trackPaths: [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        var paths = Bundle.main.paths(forResourcesOfType: "mp3", inDirectory: nil)
        paths.sort()
        trackPaths = paths.map { $0.components(separatedBy: "/").last! }
    }
    
    override func viewDidLayoutSubviews() {
        if let analyzer = player.player.isPlaying ? player.analyzer : recorder.analyzer {
            let barSpace = spectrumView.frame.width / CGFloat(analyzer.frequencyBands * 3 - 1)
            spectrumView.barWidth = barSpace * 2
            spectrumView.barSpace = barSpace
        }
    }
    
    @IBAction func startRecord(_ sender: Any) {
        recorder.record()
    }
    @IBAction func stopRecord(_ sender: Any) {
        recorder.pause()
        let path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first ?? (NSHomeDirectory() + "/Library/Audios")
        var url: URL
        if #available(iOS 16.0, *) {
            url = URL(filePath: String(format: "%@/123.aac", path))
        } else {
            url = URL(fileURLWithPath: String(format: "%@/123.aac", path))
        }
        player.audioUrl = url
    }
    
    @IBAction func playRecord(_ sender: Any) {
        player.play()
    }
    @IBAction func pauseRecord(_ sender: Any) {
        player.pause()
    }
    @IBAction func stopPlay(_ sender: Any) {
        player.stop()
    }
    
    @IBAction func sliderAction(_ sender: UISlider) {
        guard !sender.isTracking else {
            curTimeLabel.text = String(format: "%.0f", sender.value * Float(player.audioDuration))
            return
        }
        player.play(at: Int(Double(sender.value) * player.audioDuration))
    }
}

extension ViewController: AudioSpectrumRecorderDelegate {
    func recorderNoSpectrum() {
        DispatchQueue.main.async {
            self.spectrumView.spectra = [Array(repeating: 0, count: self.recorder.analyzer.frequencyBands), Array(repeating: 0, count: self.recorder.analyzer.frequencyBands)]
        }
    }
    func recorder(_ recorder: AudioRecorder, didGenerateSpectrum spectrum: [[Float]]) {
        DispatchQueue.main.async {
            self.spectrumView.spectra = spectrum
        }
    }
}

extension ViewController: AudioSpectrumPlayerDelegate {
    func player(currentDuration: Double, duration: Double, playEnded: Bool) {
        allTimeLabel.text = String(format: "%.0f", duration)
        if !slider.isTracking {
            curTimeLabel.text = String(format: "%.0f", currentDuration)
            slider.value = Float(currentDuration / duration)
        }
    }
    func playerNoSpectrum() {
        spectrumView.spectra = [Array(repeating: 0, count: self.player.analyzer.frequencyBands), Array(repeating: 0, count: self.player.analyzer.frequencyBands)]
    }
    func player(_ player: AudioPlayer, didGenerateSpectrum spectrum: [[Float]]) {
        spectrumView.spectra = spectrum
    }
}
