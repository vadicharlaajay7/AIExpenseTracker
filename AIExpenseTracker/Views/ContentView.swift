//
//  ContentView.swift
//  AIExpenseTracker
//
//  Created by Ajay on 17/11/26.
//
import SwiftUI
import PhotosUI

struct ContentView: View {
    @StateObject private var viewModel = ExpenseScannerViewModel()
    @State private var isApproved = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - Receipt Image Section
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                            .frame(height: 250)
                        
                        if let image = viewModel.selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 250)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(radius: 5)
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.text.viewfinder")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                Text("No receipt selected")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // MARK: - Action Button
                    PhotosPicker(selection: $viewModel.imageSelection, matching: .images) {
                        Label(viewModel.selectedImage == nil ? "Scan Receipt" : "Retake Photo", systemImage: "camera.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // MARK: - Loading State
                    if viewModel.isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("AI is extracting details...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 20)
                    }
                    
                    // MARK: - Extracted Data Card
                    if let expense = viewModel.scannedExpense, !viewModel.isLoading {
                        expenseDetailsCard(expense: expense)
                    }
                    
                    // MARK: - Error Handling
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Expense Report")
            .background(Color(.systemGroupedBackground))
        }
    }
    
    // MARK: - Production UI Components
    @ViewBuilder
    private func expenseDetailsCard(expense: ExpenseReceipt) -> some View {
        VStack(spacing: 0) {
            // Card Header
            HStack {
                Text("Transaction Details")
                    .font(.headline)
                Spacer()
                // Dynamic Status Badge
                Text(isApproved ? "Approved" : "Needs Review")
                    .font(.caption).bold()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(isApproved ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .foregroundColor(isApproved ? .green : .orange)
                    .clipShape(Capsule())
            }
            .padding()
            .background(Color(.systemBackground))
            
            Divider()
            
            // Data Rows
            VStack(spacing: 16) {
                dataRow(icon: "building.2", title: "Merchant", value: expense.merchantName)
                dataRow(icon: "calendar", title: "Date", value: expense.date)
                dataRow(icon: "tag", title: "Category", value: expense.category)
                
                // FIXED: Changed to match your struct's 'isSubscription' boolean
                if expense.isSubscription {
                    HStack {
                        Image(systemName: "arrow.2.squarepath")
                            .foregroundColor(.purple)
                        Text("Recurring Subscription")
                            .font(.subheadline)
                            .foregroundColor(.purple)
                        Spacer()
                    }
                    .padding(.top, 4)
                }
                
                Divider()
                
                // FIXED: Used the formatted string helper for the Tax Double
                dataRow(icon: "building.columns", title: "Tax", value: expense.formattedTax)
                
                HStack {
                    Text("Total")
                        .font(.title3.bold())
                    Spacer()
                    // FIXED: Used the formatted string helper for the Total Double
                    Text(expense.formattedTotal)
                        .font(.title3.bold())
                }
                .padding(.top, 4)
            }
            .padding()
            .background(Color(.systemBackground))
            
            // Submit Button
            Button(action: {
                withAnimation {
                    isApproved = true
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            }) {
                Text(isApproved ? "Submitted to HR" : "Approve & Submit")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isApproved ? Color.green : Color.black)
            }
            .disabled(isApproved)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func dataRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}
