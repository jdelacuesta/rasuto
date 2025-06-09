//
//  RetailerRequestView.swift
//  Rasuto
//
//  Created by Claude on 5/28/25.
//

import SwiftUI
import MessageUI

struct RetailerRequestView: View {
    @StateObject private var retailerManager = RetailerServiceManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedRetailer = ""
    @State private var customRetailerName = ""
    @State private var userEmail = ""
    @State private var additionalNotes = ""
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showMailComposer = false
    
    private let popularRetailers = [
        "Newegg", "B&H Photo", "GameStop", "Wayfair", "Overstock",
        "Sephora", "Ulta", "Nike", "Adidas", "REI",
        "Williams Sonoma", "Pottery Barn", "West Elm", "Crate & Barrel",
        "Staples", "Office Depot", "PetSmart", "Chewy", "CVS", "Walgreens"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                // Introduction Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Request a New Retailer", systemImage: "plus.app")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Help us expand Rasuto by suggesting retailers you'd like to see added. We review all requests and add the most popular ones.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                // Popular Retailers Section
                Section(header: Text("Popular Requests")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(popularRetailers.prefix(10), id: \.self) { retailer in
                                Button(action: {
                                    selectedRetailer = retailer
                                    customRetailerName = ""
                                }) {
                                    Text(retailer)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(selectedRetailer == retailer ? Color.blue : Color(.systemGray6))
                                        .foregroundColor(selectedRetailer == retailer ? .white : .primary)
                                        .cornerRadius(15)
                                }
                            }
                        }
                    }
                }
                
                // Custom Retailer Section
                Section(header: Text("Or Enter Custom Retailer")) {
                    TextField("Retailer name", text: $customRetailerName)
                        .onChange(of: customRetailerName) { _, newValue in
                            if !newValue.isEmpty {
                                selectedRetailer = ""
                            }
                        }
                }
                
                // User Information Section
                Section(header: Text("Contact Information")) {
                    TextField("Your email (optional)", text: $userEmail)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                    
                    Text("We'll notify you when this retailer is added")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Additional Notes Section
                Section(header: Text("Additional Information")) {
                    TextEditor(text: $additionalNotes)
                        .frame(minHeight: 100)
                        .placeholder(when: additionalNotes.isEmpty) {
                            Text("Any specific features or products you're interested in tracking from this retailer?")
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                }
                
                // Currently Available Section
                Section(header: Text("Currently Available Retailers")) {
                    ForEach(retailerManager.activeRetailers) { retailer in
                        HStack {
                            Image(systemName: retailer.icon)
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading) {
                                Text(retailer.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text(retailer.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Coming Soon Section
                if !retailerManager.availableRetailers.filter({ !$0.isActive }).isEmpty {
                    Section(header: Text("Coming Soon")) {
                        ForEach(retailerManager.availableRetailers.filter { !$0.isActive }) { retailer in
                            HStack {
                                Image(systemName: retailer.icon)
                                    .foregroundColor(.gray)
                                    .frame(width: 30)
                                
                                VStack(alignment: .leading) {
                                    Text(retailer.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text(retailer.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text("Soon")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(10)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Request Retailer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        submitRequest()
                    }
                    .disabled(!isValidRequest || isSubmitting)
                }
            }
            .alert("Request Submitted!", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Thank you for your suggestion! We'll review it and add popular retailers in future updates.")
            }
            .alert("Submission Failed", isPresented: $showErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showMailComposer) {
                if MFMailComposeViewController.canSendMail() {
                    MailComposerView(
                        subject: "Rasuto - New Retailer Request",
                        recipients: ["feedback@rasuto.app"],
                        messageBody: emailBody
                    )
                }
            }
        }
    }
    
    private var isValidRequest: Bool {
        !selectedRetailer.isEmpty || !customRetailerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var requestedRetailerName: String {
        if !selectedRetailer.isEmpty {
            return selectedRetailer
        } else {
            return customRetailerName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    private var emailBody: String {
        """
        Retailer Request
        
        Requested Retailer: \(requestedRetailerName)
        User Email: \(userEmail.isEmpty ? "Not provided" : userEmail)
        
        Additional Notes:
        \(additionalNotes.isEmpty ? "None" : additionalNotes)
        
        ---
        Sent from Rasuto iOS App
        """
    }
    
    private func submitRequest() {
        isSubmitting = true
        
        // In a real app, this would send to a backend API
        // For now, we'll simulate the submission
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            
            await MainActor.run {
                isSubmitting = false
                
                // Try to compose email if possible
                if MFMailComposeViewController.canSendMail() {
                    showMailComposer = true
                } else {
                    // Save request locally or show success
                    saveRequestLocally()
                    showSuccessAlert = true
                }
            }
        }
    }
    
    private func saveRequestLocally() {
        // Save to UserDefaults or local storage
        var existingRequests = UserDefaults.standard.stringArray(forKey: "retailerRequests") ?? []
        let newRequest = "\(Date().ISO8601Format()): \(requestedRetailerName)"
        existingRequests.append(newRequest)
        UserDefaults.standard.set(existingRequests, forKey: "retailerRequests")
        
        print("Saved retailer request: \(requestedRetailerName)")
    }
}

// MARK: - Mail Composer

struct MailComposerView: UIViewControllerRepresentable {
    let subject: String
    let recipients: [String]
    let messageBody: String
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailComposer = MFMailComposeViewController()
        mailComposer.setSubject(subject)
        mailComposer.setToRecipients(recipients)
        mailComposer.setMessageBody(messageBody, isHTML: false)
        mailComposer.mailComposeDelegate = context.coordinator
        return mailComposer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
        }
    }
}

// MARK: - Helper Extension

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - Preview

struct RetailerRequestView_Previews: PreviewProvider {
    static var previews: some View {
        RetailerRequestView()
    }
}