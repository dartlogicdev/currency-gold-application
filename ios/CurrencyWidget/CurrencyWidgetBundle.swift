//
//  CurrencyWidgetBundle.swift
//  CurrencyWidget
//
//  Created by Hasan Can Cesur on 19.04.26.
//

import WidgetKit
import SwiftUI

@main
struct CurrencyWidgetBundle: WidgetBundle {
    var body: some Widget {
        CurrencyWidget()
        CurrencyWidgetControl()
        CurrencyWidgetLiveActivity()
    }
}
