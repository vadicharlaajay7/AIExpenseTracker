//
//  ExpenseScannerViewModel.swift
//  AIExpenseTracker
//
//  Created by Ajay on 17/11/26.
//
import SwiftUI
import PhotosUI
import Combine
@MainActor
class ExpenseScannerViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var scannedExpense: ExpenseReceipt? // Renamed to match ContentView
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // REQUIRED: The property the PhotosPicker binds to in ContentView
    @Published var imageSelection: PhotosPickerItem? = nil {
        didSet {
            if let imageSelection {
                loadTransferable(from: imageSelection)
            }
        }
    }

    private let aiService = AIExpenseService()
    
    // REQUIRED: Converts the system photo picker item into a usable UIImage
    private func loadTransferable(from imageSelection: PhotosPickerItem) {
        Task {
            do {
                if let data = try await imageSelection.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    self.selectedImage = uiImage
                    await analyzeReceipt(image: uiImage)
                }
            } catch {
                self.errorMessage = "Failed to load the selected image."
            }
        }
    }

    func analyzeReceipt(image: UIImage) async {
        selectedImage = image
        isLoading = true
        errorMessage = nil
        scannedExpense = nil

        do {
            scannedExpense = try await aiService.extractExpense(from: image)
        } catch {
            // Shows the REAL reason instead of always blaming the API key
            errorMessage = error.localizedDescription
            print(error)
        }

        isLoading = false
    }

    func reset() {
        selectedImage = nil
        scannedExpense = nil
        errorMessage = nil
        imageSelection = nil
    }
}
