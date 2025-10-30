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
    @State private var showMailConfigAlert = false
    
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
                        isMailViewPresented: $isMailViewPresented,
                        showMailConfigAlert: $showMailConfigAlert
                    )
                }
                .padding()
            }
            .navigationTitle("My")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingShareSheet) {
                ShareSheetView(activityItems: ["Love this amazing moment with my pet, created by Petogether AI https://apps.apple.com/app/id6754391749"])
            }
            .sheet(isPresented: $isMailViewPresented) {
                MailView(result: $result) { mail in
                    mail.setSubject("Petogether App Feedback")
                    mail.setToRecipients(["tiktreeapp@gmail.com"])
                    mail.setMessageBody("Please enter your feedback here:", isHTML: false)
                }
            }
            .alert("Mail Not Configured", isPresented: $showMailConfigAlert) {
                Button("OK") { }
                Button("Open Settings") {
                    // Open mail settings if mail is not configured
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
            } message: {
                Text("Please configure mail in Settings to send feedback.")
            }
        }
    }
}

// App Information Section
struct AppInfoSection: View {
    var body: some View {
        VStack(spacing: 15) {
            // App Icon
            Image("My-icon120")
                .resizable()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            
            // App Name and Introduction
            VStack(spacing: 8) {
                Text("Petogether")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Fill pet moments with you by AI.Easily create photos of you and your pet in any life scene.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
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
    @Binding var showMailConfigAlert: Bool
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Setting")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Share Button
            Button(action: {
                showingShareSheet = true
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                    Text("Share")
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
                // Directly open App Store review page
                if let url = URL(string: "https://apps.apple.com/app/id6754391749?action=write-review") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Image(systemName: "star")
                        .foregroundColor(.yellow)
                    Text("Rate")
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
                if MFMailComposeViewController.canSendMail() {
                    // Device can send mail, present the mail view
                    isMailViewPresented = true
                } else {
                    // Device cannot send mail, show an alert with instructions
                    showMailConfigAlert = true
                }
            }) {
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(.red)
                    Text("Feedback")
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
