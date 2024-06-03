import SwiftUI
import Combine
import QuartzCore

class FPSCounter: ObservableObject {
    @Published var fps: Int = 0

    private var displayLink: CADisplayLink?
    private var lastUpdate: CFTimeInterval = 0
    private var frameCount: Int = 0

    init() {
        start()
    }

    private func start() {
        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.add(to: .main, forMode: .default)
    }

    @objc private func update(displayLink: CADisplayLink) {
        if lastUpdate == 0 {
            lastUpdate = displayLink.timestamp
            return
        }

        frameCount += 1
        let elapsed = displayLink.timestamp - lastUpdate

        if elapsed >= 1 {
            fps = frameCount
            frameCount = 0
            lastUpdate = displayLink.timestamp
        }
    }

    deinit {
        displayLink?.invalidate()
    }
}

struct ColorObject: Identifiable {
    let id = UUID()
    let color: Color
    var position: CGPoint
}

class ColorObjectViewModel: ObservableObject {
    @Published var objects: [ColorObject] = []
    
    func addObject(at position: CGPoint, color: Color) {
        let newObject = ColorObject(color: color, position: position)
        objects.append(newObject)
        self.objectWillChange.send()
    }
    
    var orangeCount: Int {
        objects.filter { $0.color == .orange }.count
    }
    
    var blueCount: Int {
        objects.filter { $0.color == .blue }.count
    }
    
    var totalCount: Int {
        objects.count
    }
    
    var orangeRatio: Double {
        totalCount == 0 ? 0 : Double(orangeCount) / Double(totalCount)
    }
    
    var blueRatio: Double {
        totalCount == 0 ? 0 : Double(blueCount) / Double(totalCount)
    }
}

class SettingsViewModel: ObservableObject {
    @Published var stepSize: CGFloat = 5
    @Published var canvasWidth: CGFloat = 300
    @Published var canvasHeight: CGFloat = 300
}

struct ContentView: View {
    @StateObject private var viewModel = ColorObjectViewModel()
    @StateObject private var settings = SettingsViewModel()
    @StateObject private var fpsCounter = FPSCounter()
    @State private var selectedColor: Color = .orange

    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    selectedColor = .orange
                }) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 50, height: 50)
                }
                
                Button(action: {
                    selectedColor = .blue
                }) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 50, height: 50)
                }
                
                Spacer()
                
                VStack {
                    Text("Orange Ratio: \(viewModel.orangeCount)/\(viewModel.totalCount)")
                    Text("Blue Ratio: \(viewModel.blueCount)/\(viewModel.totalCount)")
                    Text("FPS: \(fpsCounter.fps)")
                }
            }
            .padding()
            
            GeometryReader { geometry in
                ZStack {
                    Canvas { context, size in
                        let colors = viewModel.objects.map { $0.color }
                        let points = viewModel.objects.map { $0.position }
                        
                        let step = settings.stepSize
                        
                        for x in stride(from: 0, to: size.width, by: step) {
                            for y in stride(from: 0, to: size.height, by: step) {
                                let point = CGPoint(x: x, y: y)
                                let blendedColor = blendColors(at: point, points: points, colors: colors, size: size)
                                context.fill(Path(CGRect(x: x, y: y, width: step, height: step)), with: .color(blendedColor))
                            }
                        }
                    }
                    .border(Color.black, width: 1)
                    .frame(width: settings.canvasWidth, height: settings.canvasHeight)
                    
                    ForEach(viewModel.objects) { object in
                        Circle()
                            .fill(object.color)
                            .frame(width: 20, height: 20)
                            .position(object.position)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            let location = value.location
                            viewModel.addObject(at: location, color: selectedColor)
                        }
                )
            }
            .padding()
            
            VStack {
                HStack {
                    Text("Resolution")
                    Slider(value: $settings.stepSize, in: 1...20, step: 1)
                }
                .padding()
                
                HStack {
                    Text("Width")
                    Slider(value: $settings.canvasWidth, in: 100...500, step: 10)
                }
                .padding()
                
                HStack {
                    Text("Height")
                    Slider(value: $settings.canvasHeight, in: 100...500, step: 10)
                }
                .padding()
            }
        }
    }
    
    func blendColors(at point: CGPoint, points: [CGPoint], colors: [Color], size: CGSize) -> Color {
        var totalWeight: CGFloat = 0
        var colorSum = (red: CGFloat(0), green: CGFloat(0), blue: CGFloat(0), opacity: CGFloat(0))
        
        for (i, objectPoint) in points.enumerated() {
            let distance = hypot(point.x - objectPoint.x, point.y - objectPoint.y)
            let weight = max(0, size.width / 2 - distance) / (size.width / 2)
            
            if weight > 0 {
                let color = UIColor(colors[i])
                var red: CGFloat = 0
                var green: CGFloat = 0
                var blue: CGFloat = 0
                var alpha: CGFloat = 0
                color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                
                colorSum.red += red * weight
                colorSum.green += green * weight
                colorSum.blue += blue * weight
                colorSum.opacity += alpha * weight
                totalWeight += weight
            }
        }
        
        if totalWeight == 0 {
            return .clear
        }
        
        return Color(
            red: colorSum.red / totalWeight,
            green: colorSum.green / totalWeight,
            blue: colorSum.blue / totalWeight,
            opacity: colorSum.opacity / totalWeight
        )
    }
}

