//
//  ExpenseReceipt.swift
//  AIExpenseTracker
//
//  Created by Ajay on 17/11/26.
//

import Foundation

struct ExpenseReceipt: Codable {
    let merchantName: String
    let date: String
    let totalAmount: Double
    let taxAmount: Double
    let category: String
    let isSubscription: Bool
    
    // MARK: - UI Helpers
    var formattedTotal: String {
        totalAmount.formatted(.currency(code: "USD"))
    }
    
    var formattedTax: String {
        taxAmount.formatted(.currency(code: "USD"))
    }
}
