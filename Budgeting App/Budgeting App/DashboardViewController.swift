//
//  DashboardViewController.swift
//  Budgeting App
//
//  Created by Thotakura Chanakya on 4/9/26.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class DashboardViewController: UIViewController {

    @IBOutlet weak var spentPercentageLabel: UILabel!
    @IBOutlet weak var totalBudgetLabel: UILabel!
    @IBOutlet weak var overallProgressView: UIProgressView!

    @IBOutlet weak var foodAmountLabel: UILabel!
    @IBOutlet weak var travelAmountLabel: UILabel!
    @IBOutlet weak var billsAmountLabel: UILabel!
    @IBOutlet weak var shoppingAmountLabel: UILabel!

    @IBOutlet weak var foodProgressView: UIProgressView!
    @IBOutlet weak var travelProgressView: UIProgressView!
    @IBOutlet weak var billsProgressView: UIProgressView!
    @IBOutlet weak var shoppingProgressView: UIProgressView!

    @IBOutlet weak var recentActivityLabel: UILabel!

    private struct Transaction {
        let type: String
        let amount: Double
        let category: String
        let notes: String
        let date: Date
    }

    private let firestore = Firestore.firestore()
    private let maxRecentItems = 6

    private lazy var currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureInitialUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadDashboardData()
    }

    private func configureInitialUI() {
        recentActivityLabel.numberOfLines = 0
        recentActivityLabel.text = "Loading transactions..."

        [overallProgressView, foodProgressView, travelProgressView, billsProgressView, shoppingProgressView]
            .forEach { $0?.progress = 0 }

        spentPercentageLabel.text = "0%"
        totalBudgetLabel.text = "Total Budget : \(formatCurrency(0))"
        foodAmountLabel.text = formatCurrency(0)
        travelAmountLabel.text = formatCurrency(0)
        billsAmountLabel.text = formatCurrency(0)
        shoppingAmountLabel.text = formatCurrency(0)
    }

    private func loadDashboardData() {
        guard let userID = Auth.auth().currentUser?.uid else {
            applySignedOutState()
            return
        }

        let userDocument = firestore.collection("users").document(userID)
        let transactionsQuery = userDocument
            .collection("transactions")
            .order(by: "date", descending: true)
            .limit(to: 150)

        let group = DispatchGroup()
        var totalBudget = 0.0
        var transactions: [Transaction] = []
        var queryError: Error?

        group.enter()
        userDocument.getDocument { snapshot, error in
            defer { group.leave() }
            if let error {
                queryError = error
                return
            }

            guard let data = snapshot?.data() else { return }
            totalBudget = Self.readAmount(from: data["budget"])
        }

        group.enter()
        transactionsQuery.getDocuments { snapshot, error in
            defer { group.leave() }
            if let error {
                queryError = error
                return
            }

            let docs = snapshot?.documents ?? []
            transactions = docs.compactMap { document in
                let data = document.data()
                let type = (data["type"] as? String ?? "expense").lowercased()
                let amount = Self.readAmount(from: data["amount"])
                guard amount > 0 else { return nil }

                let category = (data["category"] as? String ?? "Other")
                let notes = (data["notes"] as? String ?? "")

                let timestamp = (data["date"] as? Timestamp)
                    ?? (data["createdAt"] as? Timestamp)
                    ?? Timestamp(date: .distantPast)

                return Transaction(
                    type: type,
                    amount: amount,
                    category: category,
                    notes: notes,
                    date: timestamp.dateValue()
                )
            }
        }

        group.notify(queue: .main) {
            if let queryError {
                self.recentActivityLabel.text = "Unable to load dashboard: \(queryError.localizedDescription)"
            }

            self.applyDashboard(totalBudget: totalBudget, transactions: transactions)
        }
    }

    private func applySignedOutState() {
        spentPercentageLabel.text = "0%"
        totalBudgetLabel.text = "Total Budget : \(formatCurrency(0))"
        foodAmountLabel.text = formatCurrency(0)
        travelAmountLabel.text = formatCurrency(0)
        billsAmountLabel.text = formatCurrency(0)
        shoppingAmountLabel.text = formatCurrency(0)
        overallProgressView.progress = 0
        foodProgressView.progress = 0
        travelProgressView.progress = 0
        billsProgressView.progress = 0
        shoppingProgressView.progress = 0
        recentActivityLabel.text = "Please sign in to view dashboard data."
    }

    private func applyDashboard(totalBudget: Double, transactions: [Transaction]) {
        let expenses = transactions.filter { $0.type == "expense" }
        let totalSpent = expenses.reduce(0) { $0 + $1.amount }

        let spentPercentage = totalBudget > 0 ? (totalSpent / totalBudget) * 100 : 0
        spentPercentageLabel.text = "\(Int(round(spentPercentage)))%"
        totalBudgetLabel.text = "Total Budget : \(formatCurrency(totalBudget))"
        overallProgressView.progress = progressValue(numerator: totalSpent, denominator: totalBudget)

        let foodTotal = categoryTotal(named: "food", in: expenses)
        let travelTotal = categoryTotal(named: "travel", in: expenses)
        let billsTotal = categoryTotal(named: "bills", in: expenses)
        let shoppingTotal = categoryTotal(named: "shopping", in: expenses)

        foodAmountLabel.text = formatCurrency(foodTotal)
        travelAmountLabel.text = formatCurrency(travelTotal)
        billsAmountLabel.text = formatCurrency(billsTotal)
        shoppingAmountLabel.text = formatCurrency(shoppingTotal)

        foodProgressView.progress = progressValue(numerator: foodTotal, denominator: totalBudget)
        travelProgressView.progress = progressValue(numerator: travelTotal, denominator: totalBudget)
        billsProgressView.progress = progressValue(numerator: billsTotal, denominator: totalBudget)
        shoppingProgressView.progress = progressValue(numerator: shoppingTotal, denominator: totalBudget)

        recentActivityLabel.text = buildRecentActivityText(from: transactions)
    }

    private func categoryTotal(named category: String, in transactions: [Transaction]) -> Double {
        transactions
            .filter { $0.category.lowercased() == category }
            .reduce(0) { $0 + $1.amount }
    }

    private func buildRecentActivityText(from transactions: [Transaction]) -> String {
        let latest = transactions.sorted { $0.date > $1.date }.prefix(maxRecentItems)
        guard !latest.isEmpty else {
            return "No transactions yet. Add your first expense or income from Add Expense tab."
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        return latest.map { item in
            let sign = item.type == "expense" ? "-" : "+"
            let dateText = dateFormatter.string(from: item.date)
            let noteText = item.notes.isEmpty ? "" : " - \(item.notes)"
            return "\(dateText) | \(item.category) | \(sign)\(formatCurrency(item.amount))\(noteText)"
        }.joined(separator: "\n")
    }

    private func formatCurrency(_ amount: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: amount)) ?? "$0"
    }

    private func progressValue(numerator: Double, denominator: Double) -> Float {
        guard denominator > 0 else { return 0 }
        let raw = numerator / denominator
        return Float(min(max(raw, 0), 1))
    }

    private static func readAmount(from rawValue: Any?) -> Double {
        if let value = rawValue as? Double {
            return value
        }
        if let value = rawValue as? Int {
            return Double(value)
        }
        if let value = rawValue as? NSNumber {
            return value.doubleValue
        }
        return 0
    }

}
