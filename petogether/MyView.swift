//
//  MyView.swift
//  petogether
//
//  Created by Sun1 on 2025/10/24.
//

import SwiftUI
import MessageUI
import StoreKit
import UIKit
import Foundation

struct MyView: View {
    @State private var showingShareSheet = false
    @State private var showingAppStoreReview = false
    @State private var result: Result<MFMailComposeResult, Error>? = nil
    @State private var isMailViewPresented = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // App Information Section
                    AppInfoSection()
                    
                    // Function Operation Section
                    ActionButtonsSection(
                        showingShareSheet: $showingShareSheet,
                        showingAppStoreReview: $showingAppStoreReview,
                        isMailViewPresented: $isMailViewPresented
                    )
                }
                .padding()
            }
            .navigationTitle("My")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingShareSheet) {
                ShareSheetView(activityItems: [URL(string: "https://apps.apple.com/app/petogether")!])
            }
            .sheet(isPresented: $isMailViewPresented) {
                MailView(result: $result) { mail in
                    mail.setSubject("PetTogether App Feedback")
                    mail.setMessageBody("Please enter your feedback here:", isHTML: false)
                }
            }
        }
    }
}

// App Information Section
struct AppInfoSection: View {
    var body: some View {
        VStack(spacing: 15) {
            // App Icon
            Image(systemName: "photo.fill.on.rectangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .frame(width: 100, height: 100)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            
            // App Name and Introduction
            VStack(spacing: 8) {
                Text("PetTogether")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Capture every beautiful moment with your pet and keep the memories forever")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Version Information
            HStack {
                Text("Version 1.0.0")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }
}

// Function Operation Section
struct ActionButtonsSection: View {
    @Binding var showingShareSheet: Bool
    @Binding var showingAppStoreReview: Bool
    @Binding var isMailViewPresented: Bool
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Functions & Feedback")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Share Button
            Button(action: {
                showingShareSheet = true
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                    Text("Share App")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
            }
            
            // Review Button
            Button(action: {
                // In a real app, this would navigate to the App Store review page
                showingAppStoreReview = true
                if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                    Task {
                        SKStoreReviewController.requestReview(in: scene)
                    }
                }
            }) {
                HStack {
                    Image(systemName: "star")
                        .foregroundColor(.yellow)
                    Text("Rate App")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
            }
            
            // Email Feedback Button
            Button(action: {
                isMailViewPresented = true
            }) {
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(.red)
                    Text("Email Feedback")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
            }
        }
    }
}

// 分享视图
struct ShareSheetView: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        controller.excludedActivityTypes = excludedActivityTypes
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// 邮件视图
struct MailView: UIViewControllerRepresentable {
    @Binding var result: Result<MFMailComposeResult, Error>?
    @Environment(\.presentationMode) var presentation
    var configure: (MFMailComposeViewController) -> Void
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var presentation: PresentationMode
        @Binding var result: Result<MFMailComposeResult, Error>?
        
        init(presentation: Binding<PresentationMode>, result: Binding<Result<MFMailComposeResult, Error>?>) {
            _presentation = presentation
            _result = result
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            defer {
                $presentation.wrappedValue.dismiss()
            }
            
            guard error == nil else {
                self.result = .failure(error!)
                return
            }
            
            self.result = .success(result)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(presentation: presentation, result: $result)
    }
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        configure(vc)
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
}

#Preview {
    MyView()
}