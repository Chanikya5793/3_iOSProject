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
    
    @IBOutlet weak var categoryField: UITextField!
    
    @IBOutlet weak var dateField: UITextField!
    
    @IBOutlet weak var notesField: UITextField!
    

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func saveTapped(_ sender: UIBarButtonItem) {
        
        let type = typeSegment.selectedSegmentIndex == 0 ? "Expense" : "Income"
        let amount = amountField.text ?? ""
        let category = categoryField.text ?? ""
        let date = dateField.text ?? ""
        let notes = notesField.text ?? ""
        
        print("Type: \(type)")
        print("Amount: \(amount)")
        print("Category: \(category)")
        print("Date: \(date)")
        print("Notes: \(notes)")
        
        navigationController?.popViewController(animated: true)
    }
}
