import UIKit
import SignedNumberRecognizer

protocol TestController {
    func process(path:CGPath)
}
class ViewController: UIViewController, TestController {
    func emptyStack(stk:UIStackView) {
        for l in stk.arrangedSubviews {
            stk.removeArrangedSubview(l)
            l.removeFromSuperview()
        }
    }
    func process(path: CGPath) {
        let newpaths = seperate(path: path)
        emptyStack(stk: hstack)
        let imgViews = newpaths.map({ CGPath2SquareImage(path: $0, toSize: 28) }).map({UIImageView(image: $0)})
        for v in imgViews {
            hstack.addArrangedSubview(v)
        }
        
        emptyStack(stk: lblStack)
        let (sign, results) = recognize(paths: newpaths)
        let most = UILabel()
        most.text = mostLikely(sign: sign, results: results)
        lblStack.addArrangedSubview(most)
        
        for r in results {
            let l = UILabel()
            l.text = r.inferences.map({$0.label}).joined(separator: ", ")
            lblStack.addArrangedSubview(l)
        }
    }
    
    @IBOutlet weak var padView:PadView!
    @IBOutlet weak var lblStack:UIStackView!
    @IBOutlet weak var hstack:UIStackView!
    override func viewDidLoad() {
        super.viewDidLoad()
        padView.del = self
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

class PadView: UIView {
    var del:TestController?
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard !drawing.isEmpty else {
            return
        }
        guard let context: CGContext = UIGraphicsGetCurrentContext() else { return }
        UIGraphicsPushContext(context)
        context.addPath(drawing)
        context.setLineCap(.round)
        context.setBlendMode(.normal)
        context.setLineWidth(2)
        context.setStrokeColor(UIColor.black.cgColor)
        context.strokePath()
        UIGraphicsPopContext()
    }
    var drawing = CGMutablePath()
    var lastPhase:UITouch.Phase = .began
    var lastPoint = CGPoint.zero
    
    func follow(touch:UITouch) {
        let loc = touch.location(in: self)
        switch touch.phase {
        case .began:
            drawing.move(to: loc)
            timer?.invalidate()
        case .moved:
            drawing.addLine(to: loc)
        case .ended:
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false, block: {[unowned self] (tmr) in
                self.del?.process(path: self.drawing)
                self.drawing = CGMutablePath()
                self.setNeedsDisplay()
            })
        case .cancelled:
            drawing = CGMutablePath()
        default:
            drawing = CGMutablePath()
        }
        lastPhase = touch.phase
        lastPoint = loc
        
        setNeedsDisplay()
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first else {return}
        follow(touch: touch)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first else {return}
        follow(touch: touch)
    }
    var timer:Timer? = nil
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard let touch = touches.first else {return}
        follow(touch: touch)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        guard let touch = touches.first else {return}
        follow(touch: touch)
    }
    
}
