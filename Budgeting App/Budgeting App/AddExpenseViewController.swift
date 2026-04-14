//
//  AddExpenseViewController.swift
//  
//
//  Created by Graves,August M on 3/30/26.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class AddExpenseViewController: UIViewController {
    
    @IBOutlet weak var typeSegment: UISegmentedControl!
    
    @IBOutlet weak var amountField: UITextField!
    
    @IBOutlet weak var datePicker: UIDatePicker!
    
    @IBOutlet weak var notesField: UITextField!
    @IBOutlet weak var categoryBTN: UIButton!
    @IBOutlet weak var doneButton: UIButton!

    private enum EntryType: String {
        case expense
        case income
    }

    private let firestore = Firestore.firestore()
    private let expenseCategories = ["Food", "Travel", "Bills", "Shopping"]
    private let incomeCategories = ["Salary", "Bonus", "Other"]
    private var selectedCategory: String?
    private var isSaving = false
    private let primaryButtonColor = UIColor(red: 0.77, green: 0.48, blue: 0.27, alpha: 1)
    
    private var currentEntryType: EntryType {
        typeSegment.selectedSegmentIndex == 0 ? .expense : .income
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
    }

    @IBAction func saveTapped(_ sender: Any) {
        saveTransaction()
    }

    @objc private func typeChanged(_ sender: UISegmentedControl) {
        updateCategoryMenu(resetSelection: true)
    }

    private func configureView() {
        amountField.keyboardType = .decimalPad
        amountField.delegate = self
        amountField.textAlignment = .center

        notesField.delegate = self

        datePicker.datePickerMode = .dateAndTime
        if #available(iOS 13.4, *) {
            datePicker.preferredDatePickerStyle = .compact
        }

        typeSegment.addTarget(self, action: #selector(typeChanged(_:)), for: .valueChanged)

        categoryBTN.showsMenuAsPrimaryAction = true
        updateCategoryMenu(resetSelection: true)

        configureDoneButtonAppearance()
    }

    private func configureDoneButtonAppearance() {
        var config = doneButton.configuration ?? UIButton.Configuration.filled()
        config.title = "Done"
        config.baseBackgroundColor = primaryButtonColor
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        doneButton.configuration = config
    }

    private func updateCategoryMenu(resetSelection: Bool) {
        let categories = currentEntryType == .expense ? expenseCategories : incomeCategories

        if resetSelection || selectedCategory == nil || !categories.contains(selectedCategory ?? "") {
            selectedCategory = nil
            setCategoryButtonTitle("Category")
        } else if let selectedCategory {
            setCategoryButtonTitle(selectedCategory)
        }

        let actions = categories.map { category in
            UIAction(title: category, state: selectedCategory == category ? .on : .off) { [weak self] _ in
                guard let self else { return }
                self.selectedCategory = category
                self.setCategoryButtonTitle(category)
                self.updateCategoryMenu(resetSelection: false)
            }
        }

        categoryBTN.menu = UIMenu(children: actions)
    }

    private func saveTransaction() {
        guard !isSaving else { return }

        guard let userID = Auth.auth().currentUser?.uid else {
            showAlert(title: "Not Signed In", message: "Please log in again before saving a transaction.")
            return
        }

        guard let amount = parseAmount(from: amountField.text), amount > 0 else {
            showAlert(title: "Invalid Amount", message: "Enter an amount greater than 0.")
            return
        }

        var category = selectedCategory ?? ""
        if currentEntryType == .expense && category.isEmpty {
            showAlert(title: "Choose Category", message: "Please select a category for this expense.")
            return
        }

        if currentEntryType == .income && category.isEmpty {
            category = "Income"
        }

        let notes = (notesField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let payload: [String: Any] = [
            "type": currentEntryType.rawValue,
            "amount": amount,
            "category": category,
            "notes": notes,
            "date": Timestamp(date: datePicker.date),
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        setSaving(true)

        firestore
            .collection("users")
            .document(userID)
            .collection("transactions")
            .addDocument(data: payload) { [weak self] error in
                guard let self else { return }

                DispatchQueue.main.async {
                    self.setSaving(false)

                    if let error {
                        self.showAlert(title: "Save Failed", message: error.localizedDescription)
                        return
                    }

                    self.clearFormAfterSave()
                    self.tabBarController?.selectedIndex = 0
                }
            }
    }

    private func setSaving(_ saving: Bool) {
        isSaving = saving
        typeSegment.isEnabled = !saving
        amountField.isEnabled = !saving
        categoryBTN.isEnabled = !saving
        datePicker.isEnabled = !saving
        notesField.isEnabled = !saving
        doneButton.isEnabled = !saving
        navigationItem.rightBarButtonItem?.isEnabled = !saving
    }

    private func clearFormAfterSave() {
        amountField.text = ""
        notesField.text = ""
        datePicker.date = Date()
        selectedCategory = nil
        updateCategoryMenu(resetSelection: true)
    }

    private func setCategoryButtonTitle(_ title: String) {
        categoryBTN.setTitle(title, for: .normal)
        categoryBTN.configuration?.title = title
    }

    private func parseAmount(from value: String?) -> Double? {
        let raw = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        let normalized = raw
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")

        return Double(normalized)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension AddExpenseViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
