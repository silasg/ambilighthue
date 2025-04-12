//
//  ViewExtensions.swift
//  ambilighthue
//
//  Created by Silas Graffy on 12.04.25.
//
import SwiftUI

extension View {
    func sheet2<Sheet>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Sheet
    ) -> some View where Sheet: View {
        return self.modifier(InspectableSheet(isPresented: isPresented, onDismiss: onDismiss, popupBuilder: content))
    }
    func alert2(isPresented: Binding<Bool>, content: @escaping () -> Alert) -> some View {
        return self.modifier(InspectableAlert(isPresented: isPresented, popupBuilder: content))
    }
}

struct InspectableSheet<Sheet>: ViewModifier where Sheet: View {
    
    let isPresented: Binding<Bool>
    let onDismiss: (() -> Void)?
    let popupBuilder: () -> Sheet
    
    func body(content: Self.Content) -> some View {
        content.sheet(isPresented: isPresented, onDismiss: onDismiss, content: popupBuilder)
    }
}

struct InspectableAlert: ViewModifier {
    
    let isPresented: Binding<Bool>
    let popupBuilder: () -> Alert
    let onDismiss: (() -> Void)? = nil
    
    func body(content: Self.Content) -> some View {
        content.alert(isPresented: isPresented, content: popupBuilder)
    }
}
