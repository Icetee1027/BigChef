import SwiftUI

// MARK: - Models
struct ScanningState {
    var preference = Preference(
        cooking_method: "一般烹調",  // 預設值
        dietary_restrictions: [],
        serving_size: "1人份"
    )
    var activeSheet: ScanningSheet?
    var showCompletionAlert = false
    var scanSummary = ""
}

// MARK: - Model Extensions
extension Ingredient {
    static var empty: Self {
        Ingredient(name: "", type: "", amount: "", unit: "", preparation: "")
    }
}

extension Equipment {
    static var empty: Self {
        Equipment(name: "", type: "", size: "", material: "", power_source: "")
    }
}
