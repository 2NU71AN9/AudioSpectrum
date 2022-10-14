//
//  AudioFileJoin.swift
//  RecordDemo
//
//  Created by 孙梁 on 2022/10/13.
//

import UIKit
import AVFoundation

public class AudioFileJoin {
    /// 音频拼接
    /// - Parameters:
    ///   - paths: 音频地址数组
    ///   - outputPath: 输出地址 后缀是.m4a
    ///   - complete: 完成回调
    public static func joinAudios(_ paths: [String], outputPath: String, complete: @escaping (String?) -> Void) {
//        guard paths.count > 1 else {
//            complete(paths.first)
//            return
//        }
        
        let assets = paths.compactMap { path in
            let url: URL
            if #available(iOS 16.0, *) {
                url = URL(filePath: path)
            } else {
                url = URL(fileURLWithPath: path)
            }
            return AVURLAsset(url: url)
        }
        let reversedAssets = Array(assets.reversed())

        let tracks = assets.compactMap { asset in
            return asset.tracks(withMediaType: .audio).first
        }
        // 3. 向音频合成器, 添加一个空的素材容器
        let composition = AVMutableComposition()
        let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: 0)
        
        for (i, track) in tracks.reversed().enumerated() {
            // 4. 向素材容器中, 插入音轨素材
            try? audioTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: reversedAssets[i].duration), of: track, at: CMTime.zero)
        }
        
        // 5. 根据合成器, 创建一个导出对象, 并设置导出参数
        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else { return }
        
        if #available(iOS 16.0, *) {
            session.outputURL = URL(filePath: outputPath)
        } else {
            session.outputURL = URL(fileURLWithPath: outputPath)
        }
        // 导出类型
        session.outputFileType = AVFileType.m4a
        session.exportAsynchronously {
            switch session.status {
            case .waiting:
                print("等待导出")
            case .exporting:
                print("导出中...")
            case .completed:
                print("导出完成")
                complete(outputPath)
            case .failed:
                print("导出失败")
                complete(nil)
            case .cancelled:
                print("取消导出")
                complete(nil)
            default:
                print("未知状态")
            }
        }
    }
}
