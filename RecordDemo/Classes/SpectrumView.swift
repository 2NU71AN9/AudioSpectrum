//
//  SpectrumView.swift
//  RecordDemo
//
//  Created by 孙梁 on 2022/10/9.
//

import UIKit

public class SpectrumView: UIView {
    
    public enum SpectrumAlign: Int {
        case top = 0
        case center = 1
        case bottom = 2
    }
    
    /// 位置
    public var align: SpectrumAlign = .center {
        didSet {
            setupView()
        }
    }
    @IBInspectable
    public lazy var alignInt = align.rawValue {
        didSet {
            align = SpectrumAlign(rawValue: alignInt) ?? .bottom
        }
    }
    /// 左声道低频颜色
    @IBInspectable
    public var leftChannlLowColor: UIColor = UIColor.init(red: 255/255, green: 197/255, blue: 0/255, alpha: 1.0) {
        didSet {
            setupView()
        }
    }
    /// 左声道高频颜色
    @IBInspectable
    public var leftChannlHighColor: UIColor = UIColor.init(red: 194/255, green: 21/255, blue: 0/255, alpha: 1.0) {
        didSet {
            setupView()
        }
    }
    /// 右声道低频颜色
    @IBInspectable
    public var rightChannlLowColor: UIColor = UIColor.init(red: 15/255, green: 52/255, blue: 67/255, alpha: 1.0) {
        didSet {
            setupView()
        }
    }
    /// 右声道高频颜色
    @IBInspectable
    public var rightChannlHighColor: UIColor = UIColor.init(red: 52/255, green: 232/255, blue: 158/255, alpha: 1.0) {
        didSet {
            setupView()
        }
    }
    /// 每个柱宽度
    @IBInspectable
    public var barWidth: CGFloat = 3.0 {
        didSet {
            setupView()
        }
    }
    /// 间距
    @IBInspectable
    public var barSpace: CGFloat = 1.0 {
        didSet {
            setupView()
        }
    }
    /// 最小高度
    @IBInspectable
    public var barMinHeight: CGFloat = 10.0 {
        didSet {
            setupView()
        }
    }
    /// 上边距
    @IBInspectable
    public var topSpace: CGFloat = 0.0 {
        didSet {
            setupView()
        }
    }
    /// 下边距
    @IBInspectable
    public var bottomSpace: CGFloat = 0.0 {
        didSet {
            setupView()
        }
    }
    
    /// 数据源
    public var spectra:[[Float]]? {
        didSet {
            if let spectra = spectra {
                // left channel
                let leftPath = UIBezierPath()
                for (i, amplitude) in spectra[0].enumerated() {
                    let x = CGFloat(i) * (barWidth + barSpace) + barSpace
                    var h = barHeight(amplitude: amplitude)
                    h = min(h + barMinHeight, bounds.height - topSpace - bottomSpace)
                    var frame: CGRect
                    switch align {
                    case .top:
                        frame = CGRect(x: x, y: topSpace, width: barWidth, height: h)
                    case .center:
                        frame = CGRect(x: x, y: bounds.height/2 - h/2, width: barWidth, height: h)
                    case .bottom:
                        frame = CGRect(x: x, y: bounds.height - bottomSpace - h, width: barWidth, height: h)
                    }
                    let bar = UIBezierPath(rect: frame)
                    leftPath.append(bar)
                }
                let leftMaskLayer = CAShapeLayer()
                leftMaskLayer.path = leftPath.cgPath
                leftGradientLayer.frame = CGRect(x: 0, y: topSpace, width: bounds.width, height: bounds.height - topSpace - bottomSpace)
                leftGradientLayer.mask = leftMaskLayer
                
                // right channel
                if spectra.count >= 2 {
                    let rightPath = UIBezierPath()
                    for (i, amplitude) in spectra[1].enumerated() {
                        let x = CGFloat(spectra[1].count - 1 - i) * (barWidth + barSpace) + barSpace
                        var h = barHeight(amplitude: amplitude)
                        h = min(h + barMinHeight, bounds.height - topSpace - bottomSpace)
                        var frame: CGRect
                        switch align {
                        case .top:
                            frame = CGRect(x: x, y: topSpace, width: barWidth, height: h)
                        case .center:
                            frame = CGRect(x: x, y: bounds.height/2 - h/2, width: barWidth, height: h)
                        case .bottom:
                            frame = CGRect(x: x, y: bounds.height - bottomSpace - h, width: barWidth, height: h)
                        }
                        let bar = UIBezierPath(rect: frame)
                        rightPath.append(bar)
                    }
                    let rightMaskLayer = CAShapeLayer()
                    rightMaskLayer.path = rightPath.cgPath
                    rightGradientLayer.frame = CGRect(x: 0, y: topSpace, width: bounds.width, height: bounds.height - topSpace - bottomSpace)
                    rightGradientLayer.mask = rightMaskLayer
                }
            }
        }
    }

    private var leftGradientLayer = CAGradientLayer()
    private var rightGradientLayer = CAGradientLayer()
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
}

extension SpectrumView {
    private func setupView() {
        switch align {
        case .top:
            leftGradientLayer.colors = [leftChannlLowColor.cgColor,
                                        leftChannlHighColor.cgColor]
            leftGradientLayer.locations = [0, 0.4]
            
            rightGradientLayer.colors = [rightChannlLowColor.cgColor,
                                         rightChannlHighColor.cgColor]
            rightGradientLayer.locations = [0, 0.4]
        case .center:
            leftGradientLayer.colors = [leftChannlHighColor.cgColor,
                                        leftChannlLowColor.cgColor,
                                        leftChannlLowColor.cgColor,
                                        leftChannlHighColor.cgColor,]
            leftGradientLayer.locations = [0, 0.47, 0.53, 1.0]
            
            rightGradientLayer.colors = [rightChannlHighColor.cgColor,
                                         rightChannlLowColor.cgColor,
                                         rightChannlLowColor.cgColor,
                                         rightChannlHighColor.cgColor]
            rightGradientLayer.locations = [0, 0.47, 0.53, 1.0]
        case .bottom:
            leftGradientLayer.colors = [leftChannlHighColor.cgColor,
                                        leftChannlLowColor.cgColor]
            leftGradientLayer.locations = [0.6, 1.0]
            
            rightGradientLayer.colors = [rightChannlHighColor.cgColor,
                                         rightChannlLowColor.cgColor]
            rightGradientLayer.locations = [0.6, 1.0]
        }
        layer.addSublayer(rightGradientLayer)
        layer.addSublayer(leftGradientLayer)
    }
    
    private func barHeight(amplitude: Float) -> CGFloat {
        return CGFloat(amplitude) * (bounds.height - bottomSpace - topSpace)
    }
    private func translateAmplitudeToYPosition(amplitude: Float) -> CGFloat {
        let barHeight: CGFloat = CGFloat(amplitude) * (bounds.height - bottomSpace - topSpace)
        return bounds.height - bottomSpace - barHeight
    }
}
