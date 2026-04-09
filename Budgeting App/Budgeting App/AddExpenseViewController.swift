//
//  AddExpenseViewController.swift
//  
//
//  Created by Graves,August M on 3/30/26.
//

import UIKit

class AddExpenseViewController: UIViewController {
    
    @IBOutlet weak var typeSegment: UISegmentedControl!
    
    @IBOutlet weak var amountField: UITextField!
    
    
    
    @IBOutlet weak var datePicker: UIDatePicker!
    
    @IBOutlet weak var notesField: UITextField!
    
    func handleSelection(_ value: String) {
        categoryBTN.setTitle(value, for: .normal)
    }
    @IBOutlet weak var categoryBTN: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        categoryBTN.menu = UIMenu(children: [
            UIAction(title: "Food", handler: { _ in self.handleSelection("Food") }),
            UIAction(title: "Travel", handler: { _ in self.handleSelection("Travel") }),
            UIAction(title: "Bills", handler: { _ in self.handleSelection("Bills") }),
            UIAction(title: "Shopping", handler: { _ in self.handleSelection("Shopping") })
        ])
        
        func saveTapped(_ sender: UIBarButtonItem) {
            
            let type = typeSegment.selectedSegmentIndex == 0 ? "Expense" : "Income"
            let amount = amountField.text ?? ""
            let category = categoryBTN.currentTitle ?? ""
            let formatter = DateFormatter()
            formatter.dateStyle = .short

            let date = formatter.string(from: datePicker.date)
            let notes = notesField.text ?? ""
            
            print("Type: \(type)")
            print("Amount: \(amount)")
            print("Category: \(category)")
            print("Date: \(date)")
            print("Notes: \(notes)")
            
            navigationController?.popViewController(animated: true)
        }
    }
}
