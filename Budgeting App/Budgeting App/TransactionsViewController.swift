//
//  TransactionsViewController.swift
//  Budgeting App
//
//  Created by Thotakura Chanakya on 4/13/26.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class TransactionsViewController: UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var filterCardView: UIView!
    @IBOutlet weak var listCardView: UIView!
    @IBOutlet weak var typeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var categoryFilterButton: UIButton!
    @IBOutlet weak var searchTextField: UITextField!
    @IBOutlet weak var refreshButton: UIButton!
    @IBOutlet weak var transactionsTableView: UITableView!
    @IBOutlet weak var emptyStateLabel: UILabel!

    private struct TransactionItem {
        let id: String
        let type: String
        var amount: Double
        var category: String
        var notes: String
        let date: Date
    }

    private let firestore = Firestore.firestore()
    private var allTransactions: [TransactionItem] = []
    private var filteredTransactions: [TransactionItem] = []
    private var selectedCategory = "All Categories"
    private var isLoading = false

    private let accentColor = UIColor(red: 0.77, green: 0.48, blue: 0.27, alpha: 1)
    private let expenseColor = UIColor(red: 0.64, green: 0.29, blue: 0.15, alpha: 1)
    private let incomeColor = UIColor.systemGreen

    private lazy var currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureInterface()
        configureTableView()
        configureFilters()
        loadTransactions(forceServer: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadTransactions(forceServer: false)
    }

    @IBAction func typeFilterChanged(_ sender: UISegmentedControl) {
        applyFilters()
    }

    @IBAction func refreshTapped(_ sender: UIButton) {
        loadTransactions(forceServer: true)
    }

    @objc private func searchTextChanged(_ sender: UITextField) {
        applyFilters()
    }

    private func configureInterface() {
        view.backgroundColor = UIColor(red: 0.91, green: 0.85, blue: 0.76, alpha: 1)

        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)
        titleLabel.textColor = UIColor(red: 0.16, green: 0.11, blue: 0.07, alpha: 1)

        [filterCardView, listCardView].forEach {
            $0?.backgroundColor = UIColor(white: 1, alpha: 0.5)
            $0?.layer.cornerRadius = 20
            $0?.layer.masksToBounds = true
        }

        typeSegmentedControl.selectedSegmentIndex = 0
        typeSegmentedControl.setTitle("All", forSegmentAt: 0)
        typeSegmentedControl.setTitle("Expense", forSegmentAt: 1)
        typeSegmentedControl.setTitle("Income", forSegmentAt: 2)
        typeSegmentedControl.selectedSegmentTintColor = accentColor

        var categoryConfig = categoryFilterButton.configuration ?? UIButton.Configuration.filled()
        categoryConfig.title = "All Categories"
        categoryConfig.baseForegroundColor = .black
        categoryConfig.baseBackgroundColor = UIColor(red: 0.94, green: 0.90, blue: 0.85, alpha: 1)
        categoryFilterButton.configuration = categoryConfig
        categoryFilterButton.showsMenuAsPrimaryAction = true

        searchTextField.borderStyle = .roundedRect
        searchTextField.placeholder = "Search notes/category"
        searchTextField.autocorrectionType = .no
        searchTextField.spellCheckingType = .no
        searchTextField.clearButtonMode = .whileEditing
        searchTextField.borderStyle = .none
        searchTextField.layer.cornerRadius = 16
        searchTextField.layer.masksToBounds = true
        searchTextField.backgroundColor = UIColor(red: 0.94, green: 0.90, blue: 0.85, alpha: 1)
        searchTextField.textColor = UIColor(red: 0.20, green: 0.14, blue: 0.09, alpha: 1)

        let placeholderColor = UIColor(red: 0.35, green: 0.27, blue: 0.19, alpha: 0.65)
        searchTextField.attributedPlaceholder = NSAttributedString(
            string: "Search notes/category",
            attributes: [.foregroundColor: placeholderColor]
        )

        let leadingSpacer = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 34))
        searchTextField.leftView = leadingSpacer
        searchTextField.leftViewMode = .always
        searchTextField.addTarget(self, action: #selector(searchTextChanged(_:)), for: .editingChanged)

        refreshButton.setTitleColor(accentColor, for: .normal)

        emptyStateLabel.textColor = UIColor(red: 0.30, green: 0.23, blue: 0.16, alpha: 1)
        emptyStateLabel.text = "Loading transactions..."
        emptyStateLabel.isHidden = false
    }

    private func configureTableView() {
        transactionsTableView.delegate = self
        transactionsTableView.dataSource = self
        transactionsTableView.backgroundColor = UIColor(white: 1, alpha: 0.2)
        transactionsTableView.separatorColor = UIColor(red: 0.58, green: 0.45, blue: 0.33, alpha: 0.3)
        transactionsTableView.keyboardDismissMode = .onDrag
        transactionsTableView.register(TransactionCell.self, forCellReuseIdentifier: TransactionCell.reuseIdentifier)
    }

    private func configureFilters() {
        refreshCategoryMenu()
    }

    private func loadTransactions(forceServer: Bool) {
        guard let userID = Auth.auth().currentUser?.uid else {
            allTransactions = []
            filteredTransactions = []
            transactionsTableView.reloadData()
            emptyStateLabel.text = "Please sign in to view transactions."
            emptyStateLabel.isHidden = false
            return
        }

        guard !isLoading else { return }
        setLoading(true)

        let query = firestore
            .collection("users")
            .document(userID)
            .collection("transactions")
            .order(by: "date", descending: true)

        let completion: (QuerySnapshot?, Error?) -> Void = { [weak self] snapshot, error in
            guard let self else { return }

            DispatchQueue.main.async {
                self.setLoading(false)

                if let error {
                    self.emptyStateLabel.text = "Unable to load transactions: \(error.localizedDescription)"
                    self.emptyStateLabel.isHidden = false
                    return
                }

                self.allTransactions = (snapshot?.documents ?? []).compactMap { doc in
                    let data = doc.data()
                    let type = (data["type"] as? String ?? "expense").lowercased()
                    let amount = Self.readAmount(from: data["amount"])
                    guard amount > 0 else { return nil }

                    let category = (data["category"] as? String ?? "Other")
                    let notes = (data["notes"] as? String ?? "")
                    let timestamp = (data["date"] as? Timestamp)
                        ?? (data["createdAt"] as? Timestamp)
                        ?? Timestamp(date: .distantPast)

                    return TransactionItem(
                        id: doc.documentID,
                        type: type,
                        amount: amount,
                        category: category,
                        notes: notes,
                        date: timestamp.dateValue()
                    )
                }

                self.refreshCategoryMenu()
                self.applyFilters()
            }
        }

        if forceServer {
            query.getDocuments(source: .server, completion: completion)
        } else {
            query.getDocuments(completion: completion)
        }
    }

    private func setLoading(_ loading: Bool) {
        isLoading = loading
        refreshButton.isEnabled = !loading
        typeSegmentedControl.isEnabled = !loading
        categoryFilterButton.isEnabled = !loading
        searchTextField.isEnabled = !loading
    }

    private func refreshCategoryMenu() {
        let categories = Array(Set(allTransactions.map { $0.category })).sorted()
        if selectedCategory != "All Categories" && !categories.contains(selectedCategory) {
            selectedCategory = "All Categories"
        }

        var actions: [UIAction] = []
        let allAction = UIAction(
            title: "All Categories",
            state: selectedCategory == "All Categories" ? .on : .off
        ) { [weak self] _ in
            guard let self else { return }
            self.selectedCategory = "All Categories"
            self.setCategoryFilterButtonTitle("All Categories")
            self.refreshCategoryMenu()
            self.applyFilters()
        }
        actions.append(allAction)

        actions.append(contentsOf: categories.map { category in
            UIAction(title: category, state: self.selectedCategory == category ? .on : .off) { [weak self] _ in
                guard let self else { return }
                self.selectedCategory = category
                self.setCategoryFilterButtonTitle(category)
                self.refreshCategoryMenu()
                self.applyFilters()
            }
        })

        categoryFilterButton.menu = UIMenu(children: actions)
        setCategoryFilterButtonTitle(selectedCategory)
    }

    private func setCategoryFilterButtonTitle(_ title: String) {
        categoryFilterButton.setTitle(title, for: .normal)
        categoryFilterButton.configuration?.title = title
    }

    private func applyFilters() {
        let search = (searchTextField.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        filteredTransactions = allTransactions.filter { item in
            let typeMatch: Bool
            switch typeSegmentedControl.selectedSegmentIndex {
            case 1:
                typeMatch = item.type == "expense"
            case 2:
                typeMatch = item.type == "income"
            default:
                typeMatch = true
            }

            let categoryMatch = selectedCategory == "All Categories" || item.category == selectedCategory
            let searchMatch = search.isEmpty
                || item.category.lowercased().contains(search)
                || item.notes.lowercased().contains(search)
                || dateFormatter.string(from: item.date).lowercased().contains(search)

            return typeMatch && categoryMatch && searchMatch
        }

        transactionsTableView.reloadData()

        if filteredTransactions.isEmpty {
            emptyStateLabel.text = allTransactions.isEmpty
                ? "No transactions yet."
                : "No transactions found for current filters."
            emptyStateLabel.isHidden = false
        } else {
            emptyStateLabel.isHidden = true
        }
    }

    private func deleteTransaction(at indexPath: IndexPath) {
        guard let userID = Auth.auth().currentUser?.uid else { return }

        let item = filteredTransactions[indexPath.row]
        firestore
            .collection("users")
            .document(userID)
            .collection("transactions")
            .document(item.id)
            .delete { [weak self] error in
                guard let self else { return }
                DispatchQueue.main.async {
                    if let error {
                        self.showAlert(title: "Delete Failed", message: error.localizedDescription)
                        return
                    }

                    self.allTransactions.removeAll { $0.id == item.id }
                    self.applyFilters()
                }
            }
    }

    private func editTransaction(at indexPath: IndexPath) {
        let item = filteredTransactions[indexPath.row]

        let alert = UIAlertController(title: "Edit Transaction", message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Amount"
            field.keyboardType = .decimalPad
            field.text = String(format: "%.2f", item.amount)
        }
        alert.addTextField { field in
            field.placeholder = "Category"
            field.text = item.category
        }
        alert.addTextField { field in
            field.placeholder = "Notes"
            field.text = item.notes
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self else { return }

            let amountText = alert.textFields?[0].text
            let categoryText = (alert.textFields?[1].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let notesText = (alert.textFields?[2].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            guard let amount = Self.parseAmount(from: amountText), amount > 0 else {
                self.showAlert(title: "Invalid Amount", message: "Enter a valid amount greater than 0.")
                return
            }

            guard !categoryText.isEmpty else {
                self.showAlert(title: "Missing Category", message: "Category cannot be empty.")
                return
            }

            self.updateTransaction(itemID: item.id, amount: amount, category: categoryText, notes: notesText)
        })

        present(alert, animated: true)
    }

    private func updateTransaction(itemID: String, amount: Double, category: String, notes: String) {
        guard let userID = Auth.auth().currentUser?.uid else { return }

        let payload: [String: Any] = [
            "amount": amount,
            "category": category,
            "notes": notes,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        firestore
            .collection("users")
            .document(userID)
            .collection("transactions")
            .document(itemID)
            .updateData(payload) { [weak self] error in
                guard let self else { return }

                DispatchQueue.main.async {
                    if let error {
                        self.showAlert(title: "Update Failed", message: error.localizedDescription)
                        return
                    }

                    if let index = self.allTransactions.firstIndex(where: { $0.id == itemID }) {
                        self.allTransactions[index].amount = amount
                        self.allTransactions[index].category = category
                        self.allTransactions[index].notes = notes
                    }

                    self.refreshCategoryMenu()
                    self.applyFilters()
                }
            }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func formatCurrency(_ amount: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: amount)) ?? "$0"
    }

    private static func parseAmount(from text: String?) -> Double? {
        let raw = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        let normalized = raw
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")

        return Double(normalized)
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

extension TransactionsViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredTransactions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: TransactionCell.reuseIdentifier,
            for: indexPath
        ) as? TransactionCell else {
            return UITableViewCell()
        }

        let item = filteredTransactions[indexPath.row]
        let sign = item.type == "expense" ? "-" : "+"
        let amountText = "\(sign)\(formatCurrency(item.amount))"
        let dateText = dateFormatter.string(from: item.date)
        let notesText = item.notes.isEmpty ? "No notes" : item.notes

        cell.textLabel?.text = "\(item.category)  \(amountText)"
        cell.textLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        cell.textLabel?.textColor = item.type == "expense" ? expenseColor : incomeColor

        cell.detailTextLabel?.text = "\(dateText) • \(item.type.capitalized) • \(notesText)"
        cell.detailTextLabel?.font = .systemFont(ofSize: 13, weight: .regular)
        cell.detailTextLabel?.textColor = UIColor(red: 0.32, green: 0.24, blue: 0.17, alpha: 1)
        cell.detailTextLabel?.numberOfLines = 2

        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        return cell
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            self?.deleteTransaction(at: indexPath)
            completion(true)
        }

        let edit = UIContextualAction(style: .normal, title: "Edit") { [weak self] _, _, completion in
            self?.editTransaction(at: indexPath)
            completion(true)
        }
        edit.backgroundColor = accentColor

        let config = UISwipeActionsConfiguration(actions: [delete, edit])
        config.performsFirstActionWithFullSwipe = false
        return config
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        66
    }
}

private final class TransactionCell: UITableViewCell {

    static let reuseIdentifier = "TransactionCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
