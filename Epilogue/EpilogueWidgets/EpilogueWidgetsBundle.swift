//
//  EpilogueWidgetsBundle.swift
//  EpilogueWidgets
//
//  Created by Kris Puckett on 10/7/25.
//

import WidgetKit
import SwiftUI

@main
struct EpilogueWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CurrentReadingWidget()
        ReadingStreakWidget()
        AmbientModeWidget()
    }
}
