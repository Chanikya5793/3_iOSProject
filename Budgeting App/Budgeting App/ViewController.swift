//
//  ViewController.swift
//  Budgeting App
//
//  Created by Thotakura Chanakya on 3/30/26.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class ViewController: UIViewController {

    @IBOutlet weak var authModeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var budgetPromptLabel: UILabel!
    @IBOutlet weak var budgetTextField: UITextField!
    @IBOutlet weak var primaryButton: UIButton!
    @IBOutlet weak var statusLabel: UILabel!

    private enum AuthMode: Int {
        case login = 0
        case signUp = 1
    }

    private let homeSegueIdentifier = "result"
    private var isSubmitting = false
    private var allowSegue = false
    private var hasAutoRouted = false
    private lazy var firestore = Firestore.firestore()

    private var currentMode: AuthMode {
        AuthMode(rawValue: authModeSegmentedControl.selectedSegmentIndex) ?? .login
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureFields()
        configureSegmentedControl()
        updateUIForCurrentMode()
        showStatus("Enter your credentials to continue.", isError: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !hasAutoRouted else { return }
        hasAutoRouted = true

        if Auth.auth().currentUser != nil {
            showStatus("Welcome back. Redirecting...", isError: false)
            navigateToMainApp()
        }
    }

    @IBAction func authModeChanged(_ sender: UISegmentedControl) {
        updateUIForCurrentMode()
    }

    @IBAction func primaryButtonTapped(_ sender: UIButton) {
        handlePrimaryAction()
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        guard identifier == homeSegueIdentifier else { return true }

        if allowSegue {
            allowSegue = false
            return true
        }

        handlePrimaryAction()
        return false
    }

    private func configureFields() {
        emailTextField.keyboardType = .emailAddress
        emailTextField.autocapitalizationType = .none
        emailTextField.autocorrectionType = .no
        emailTextField.textContentType = .emailAddress
        emailTextField.returnKeyType = .next
        emailTextField.delegate = self

        passwordTextField.isSecureTextEntry = true
        passwordTextField.autocapitalizationType = .none
        passwordTextField.autocorrectionType = .no
        passwordTextField.textContentType = .password
        passwordTextField.returnKeyType = .done
        passwordTextField.delegate = self

        budgetTextField.keyboardType = .decimalPad
        budgetTextField.returnKeyType = .done
        budgetTextField.delegate = self

        statusLabel.numberOfLines = 0
    }

    private func configureSegmentedControl() {
        if authModeSegmentedControl.numberOfSegments >= 2 {
            authModeSegmentedControl.setTitle("Login", forSegmentAt: 0)
            authModeSegmentedControl.setTitle("Sign Up", forSegmentAt: 1)
        }

        authModeSegmentedControl.selectedSegmentIndex = AuthMode.login.rawValue
    }

    private func updateUIForCurrentMode() {
        let isSignup = currentMode == .signUp

        budgetPromptLabel.isHidden = !isSignup
        budgetTextField.isHidden = !isSignup
        budgetTextField.isEnabled = isSignup

        if !isSignup {
            budgetTextField.text = ""
            passwordTextField.returnKeyType = .done
        } else {
            passwordTextField.returnKeyType = .next
        }

        let buttonTitle = isSignup ? "Sign Up" : "Login"
        primaryButton.setTitle(buttonTitle, for: .normal)
        showStatus(isSignup ? "Create an account with your starting budget." : "Log in with your registered email and password.", isError: false)
    }

    private func handlePrimaryAction() {
        guard !isSubmitting else { return }

        let email = (emailTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let password = passwordTextField.text ?? ""

        guard !email.isEmpty, isValidEmail(email) else {
            showStatus("Please enter a valid email address.", isError: true)
            return
        }

        guard !password.isEmpty else {
            showStatus("Please enter your password.", isError: true)
            return
        }

        switch currentMode {
        case .login:
            login(email: email, password: password)
        case .signUp:
            guard password.count >= 6 else {
                showStatus("Password must be at least 6 characters.", isError: true)
                return
            }

            guard let budget = parseBudget(), budget > 0 else {
                showStatus("Budget is required and must be greater than 0.", isError: true)
                return
            }

            signUp(email: email, password: password, budget: budget)
        }
    }

    private func login(email: String, password: String) {
        setSubmitting(true)

        Auth.auth().signIn(withEmail: email, password: password) { [weak self] _, error in
            guard let self else { return }
            DispatchQueue.main.async {
                self.setSubmitting(false)

                if let error {
                    self.showStatus(error.localizedDescription, isError: true)
                    return
                }

                self.showStatus("Login successful.", isError: false)
                self.navigateToMainApp()
            }
        }
    }

    private func signUp(email: String, password: String, budget: Double) {
        setSubmitting(true)

        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self else { return }
            DispatchQueue.main.async {
                if let error {
                    self.setSubmitting(false)
                    self.showStatus(error.localizedDescription, isError: true)
                    return
                }

                guard let user = authResult?.user else {
                    self.setSubmitting(false)
                    self.showStatus("Unable to complete sign up. Please try again.", isError: true)
                    return
                }

                user.getIDTokenForcingRefresh(true) { _, tokenError in
                    DispatchQueue.main.async {
                        if let tokenError {
                            self.setSubmitting(false)
                            self.showStatus("Account created, but session setup failed: \(tokenError.localizedDescription)", isError: true)
                            return
                        }

                        self.saveBudget(userID: user.uid, email: email, budget: budget)
                    }
                }
            }
        }
    }

    private func saveBudget(userID: String, email: String, budget: Double) {
        let payload: [String: Any] = [
            "email": email,
            "budget": budget,
            "updatedAt": FieldValue.serverTimestamp(),
            "createdAt": FieldValue.serverTimestamp()
        ]

        firestore.collection("users").document(userID).setData(payload, merge: true) { [weak self] error in
            guard let self else { return }
            DispatchQueue.main.async {
                self.setSubmitting(false)

                if let error {
                    let nsError = error as NSError
                    if nsError.domain == FirestoreErrorDomain, nsError.code == 7 {
                        self.showStatus("Account created, but budget save is blocked by Firestore rules/App Check. Enable signed-in writes for users/{uid} and register simulator App Check debug token.", isError: true)
                        return
                    }

                    self.showStatus("Account created, but budget sync failed: \(error.localizedDescription)", isError: true)
                    return
                }

                self.showStatus("Sign up successful.", isError: false)
                self.navigateToMainApp()
            }
        }
    }

    private func navigateToMainApp() {
        allowSegue = true
        performSegue(withIdentifier: homeSegueIdentifier, sender: self)
    }

    private func setSubmitting(_ submitting: Bool) {
        isSubmitting = submitting
        primaryButton.isEnabled = !submitting
        authModeSegmentedControl.isEnabled = !submitting
        view.isUserInteractionEnabled = !submitting

        if submitting {
            showStatus("Please wait...", isError: false)
        }
    }

    private func showStatus(_ message: String, isError: Bool) {
        statusLabel.text = message
        statusLabel.textColor = isError ? .systemRed : .label
    }

    private func parseBudget() -> Double? {
        let rawValue = (budgetTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawValue.isEmpty else { return nil }

        let normalized = rawValue
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")

        return Double(normalized)
    }

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: email)
    }

}

extension ViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case emailTextField:
            passwordTextField.becomeFirstResponder()
        case passwordTextField where currentMode == .signUp:
            budgetTextField.becomeFirstResponder()
        default:
            textField.resignFirstResponder()
            handlePrimaryAction()
        }

        return true
    }

}

