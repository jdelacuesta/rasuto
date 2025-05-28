//
//  AppLogoView.swift
//  Rasuto
//
//  Created by JC Dela Cuesta on 4/15/25.
//

import SwiftUI

// MARK: - App Logo View

struct AppLogoView: View {
    var body: some View {
        Text("R")
            .font(.title)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(width: 40, height: 40)
            .background(Color.black)
            .clipShape(Circle())
    }
}

#Preview {
    AppLogoView()
}
