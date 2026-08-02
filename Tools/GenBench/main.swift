import Foundation
for bias in [0.0, 0.15, 0.3, 0.5] {
    var line = String(format: "bias %.2f  ", bias)
    for size in [6, 9] {
        var opCounts:[Operation:Int]=[:]; var times:[Double]=[]; var fails=0; var freebie:[Double]=[]
        for seed in 0..<30 {
            var o = PuzzleGenerator.Options.forSize(size); o.tightnessBias = bias
            let t0=Date()
            guard let r = PuzzleGenerator.generate(size:size, options:o, seed:UInt64(seed &* 6151 &+ size)) else { fails+=1; continue }
            times.append(Date().timeIntervalSince(t0))
            for c in r.puzzle.cages { opCounts[c.operation,default:0]+=1 }
            freebie.append(Double(r.puzzle.cages.filter(\.isFreebie).count)/Double(r.puzzle.cages.count))
        }
        let total=opCounts.values.reduce(0,+)
        func pct(_ o:Operation)->Int { Int(Double(opCounts[o] ?? 0)/Double(max(total,1))*100) }
        line += String(format:"| %dx%d +%2d%% ×%2d%% −%2d%% ÷%2d%% fail=%d worst %4.0fms ",
            size,size,pct(.add),pct(.multiply),pct(.subtract),pct(.divide),fails,(times.max() ?? 0)*1000)
    }
    print(line)
}
