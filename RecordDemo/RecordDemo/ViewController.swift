//
//  ViewController.swift
//  RecordDemo
//
//  Created by 孙梁 on 2022/10/8.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var spectrumView: SpectrumView!
    
    private lazy var recorder: AudioRecorder = {
        let recorder = AudioRecorder(fileName: "123", frequencyBands: 80)
        recorder.delegate = self
        return recorder
    }()
    private lazy var player: AudioPlayer = {
        let player = AudioPlayer(frequencyBands: 80)
        player.delegate = self
        return player
    }()
    
    private lazy var trackPaths: [String] = {
        var paths = Bundle.main.paths(forResourcesOfType: "mp3", inDirectory: nil)
        paths.sort()
        return paths.map { $0.components(separatedBy: "/").last! }
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

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
    }
    
    @IBAction func playRecord(_ sender: Any) {
        guard let url = Bundle.main.url(forResource: trackPaths[0], withExtension: nil) else { return }
//        let path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first ?? (NSHomeDirectory() + "/Library/Audios")
//        var url: URL
//        if #available(iOS 16.0, *) {
//            url = URL(filePath: String(format: "%@/123.wav", path))
//        } else {
//            url = URL(fileURLWithPath: String(format: "%@/123.wav", path))
//        }
        player.play(withUrl: url)
    }
    @IBAction func stopPlay(_ sender: Any) {
        player.stop()
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
    func playerNoSpectrum() {
        DispatchQueue.main.async {
            self.spectrumView.spectra = [Array(repeating: 0, count: self.player.analyzer.frequencyBands), Array(repeating: 0, count: self.player.analyzer.frequencyBands)]
        }
    }
    func player(_ player: AudioPlayer, didGenerateSpectrum spectrum: [[Float]]) {
        DispatchQueue.main.async {
            self.spectrumView.spectra = spectrum
        }
    }
}
