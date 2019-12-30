//
//  SStatsItem.swift
//  Pock
//
//  Created by Andreas Hanft on 29/12/2019.
//  Copyright © 2019 Andreas Hanft. All rights reserved.
//

import Foundation
import Defaults

class GradientView: NSView {
    private let colors: [NSColor] = [
        NSColor(red: 215 / 255, green: 3 / 255, blue: 0 / 255, alpha: 1),   // Red
        NSColor(red: 208 / 255, green: 238 / 255, blue: 0 / 255, alpha: 1), // Yellow
        NSColor(red: 0 / 255, green: 190 / 255, blue: 0 / 255, alpha: 1)    // Green
    ]
    
    override func draw(_ dirtyRect: NSRect) {
        let gradient = NSGradient(colors: colors)
        gradient?.draw(in: dirtyRect, angle: 270)
    }
}

class VerticalGaugeView: NSView {
    
    var value: Double = 0 {
        didSet {
            constraint?.constant = frame.height * CGFloat(value)
        }
    }
    
    private weak var constraint: NSLayoutConstraint?
    
    override var intrinsicContentSize: NSSize {
        .init(width: 4, height: 26) // Max height of touchbar is 30pt
    }
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .horizontal)
        
        let background = GradientView(frame: .init(origin: .zero, size: frame.size))
        background.alphaValue = 0.5
        self.addSubview(background)
        background.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            background.trailingAnchor.constraint(equalTo: trailingAnchor),
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.topAnchor.constraint(equalTo: topAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        let container = NSView()
        self.addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        constraint = container.heightAnchor.constraint(equalToConstant: 0)
        constraint?.isActive = true
        
        let gradient = GradientView(frame: .init(origin: .zero, size: frame.size))
        container.addSubview(gradient)
        gradient.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            gradient.trailingAnchor.constraint(equalTo: trailingAnchor),
            gradient.leadingAnchor.constraint(equalTo: leadingAnchor),
            gradient.heightAnchor.constraint(equalTo: heightAnchor),
            gradient.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        self.wantsLayer = true
        self.layer?.cornerRadius = 2
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SStatsItem: StatusItem {
    
    /// Core
    private var refreshTimer: Timer?
    private var fans: [Fan] = []
    
    /// UI
    private var tempLabel: NSTextField!
    private var stackView: NSStackView!
    private var fanGauges: [VerticalGaugeView] = []

    private var cpuTemperature: Double {
        let temp = try? SMCKit.temperature(TemperatureSensors.CPU_PECI.code)
        return temp ?? 0
    }
    
    init() {
        didLoad()
        reload()
    }
    
    deinit {
        didUnload()
    }
    
    func didLoad() {
        try? SMCKit.open()
        
        if let fans = try? SMCKit.allFans() {
            self.fans = fans
        }
        
        if stackView == nil {
            initStackView()
            
            for _ in fans {
                let gauge = VerticalGaugeView()
                fanGauges.append(gauge)
                stackView.addArrangedSubview(gauge)
            }
            
            tempLabel = makeLabel()
            stackView.addArrangedSubview(tempLabel)
        }
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [unowned self] _ in
            self.reload()
        })
    }
    
    func didUnload() {
        SMCKit.close()
        
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    #warning("TODO: Add settings option")
    var enabled: Bool { true } // Defaults[.shouldShowStatsItem] }
    
    var title: String { "stats" }
    
    var view: NSView { stackView }
    
    func action() {}
    
    func reload() {
        
        fans.enumerated().forEach { index, fan in
            guard let currentSpeed = try? SMCKit.fanCurrentSpeed(index) else { return }
            
            fanGauges[index].value = fan.absoluteSpeed(with: currentSpeed)
        }
        
        tempLabel.stringValue = String(format: "%.0f °C", cpuTemperature)
        tempLabel.sizeToFit()
    }
    
    private func initStackView() {
        stackView = NSStackView()
        stackView.orientation  = .horizontal
        stackView.alignment    = .centerY
        stackView.distribution = .fillProportionally
        stackView.spacing      = 4
    }
    
    private func makeLabel() -> NSTextField {
        let label = NSTextField()
        label.font = NSFont.systemFont(ofSize: 13)
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.sizeToFit()
        
        return label
    }
}

extension Fan {
    func absoluteSpeed(with currentSpeed: Int) -> Double {
        let absolute = Double(currentSpeed) / Double(maxSpeed)
        
        return min(max(absolute, 0.0), 1.0)
    }
}
