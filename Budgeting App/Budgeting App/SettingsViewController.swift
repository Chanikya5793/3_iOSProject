//
//  SettingsViewController.swift
//  Budgeting App
//
//  Created by Thotakura Chanakya on 4/10/26.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore
import UserNotifications

class SettingsViewController: UIViewController {

    @IBOutlet weak var titleLabel: UILabel!

    @IBOutlet weak var budgetCard: UIView!
    @IBOutlet weak var budgetTitleLabel: UILabel!
    @IBOutlet weak var budgetTextField: UITextField!
    @IBOutlet weak var saveBudgetButton: UIButton!

    @IBOutlet weak var notificationCard: UIView!
    @IBOutlet weak var notificationTitleLabel: UILabel!
    @IBOutlet weak var notificationDetailLabel: UILabel!
    @IBOutlet weak var notificationSwitch: UISwitch!

    @IBOutlet weak var resetStatisticsButton: UIButton!
    @IBOutlet weak var logoutButton: UIButton!
    @IBOutlet weak var statusLabel: UILabel!

    private let firestore = Firestore.firestore()

    private lazy var currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureInterfaceAppearance()
        wireActions()
        loadCurrentBudget()
        loadNotificationPreference()
    }

    private func configureInterfaceAppearance() {
        view.backgroundColor = UIColor(red: 0.91, green: 0.85, blue: 0.76, alpha: 1)

        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)
        titleLabel.text = "Settings"
        titleLabel.textColor = UIColor(red: 0.16, green: 0.11, blue: 0.07, alpha: 1)

        [budgetCard, notificationCard].forEach {
            $0.backgroundColor = UIColor(white: 1, alpha: 0.5)
            $0.layer.cornerRadius = 18
            $0.layer.masksToBounds = true
        }

        budgetTitleLabel.text = "Monthly Budget"
        budgetTitleLabel.font = .systemFont(ofSize: 18, weight: .semibold)

        budgetTextField.borderStyle = .roundedRect
        budgetTextField.placeholder = "Enter amount"
        budgetTextField.keyboardType = .decimalPad
        budgetTextField.autocorrectionType = .no
        budgetTextField.autocapitalizationType = .none

        var budgetConfig = UIButton.Configuration.filled()
        budgetConfig.title = "Update Budget"
        budgetConfig.baseBackgroundColor = UIColor(red: 0.77, green: 0.48, blue: 0.27, alpha: 1)
        budgetConfig.baseForegroundColor = .white
        saveBudgetButton.configuration = budgetConfig

        notificationTitleLabel.text = "Push Notifications"
        notificationTitleLabel.font = .systemFont(ofSize: 18, weight: .semibold)

        notificationDetailLabel.text = "Get reminders and budgeting updates"
        notificationDetailLabel.font = .systemFont(ofSize: 14, weight: .regular)
        notificationDetailLabel.textColor = .secondaryLabel

        notificationSwitch.onTintColor = UIColor(red: 0.77, green: 0.48, blue: 0.27, alpha: 1)

        var resetConfig = UIButton.Configuration.filled()
        resetConfig.title = "Reset Statistics"
        resetConfig.baseBackgroundColor = UIColor.systemOrange.withAlphaComponent(0.9)
        resetConfig.baseForegroundColor = .white
        resetStatisticsButton.configuration = resetConfig

        var logoutConfig = UIButton.Configuration.filled()
        logoutConfig.title = "Log Out"
        logoutConfig.baseBackgroundColor = UIColor.systemRed.withAlphaComponent(0.9)
        logoutConfig.baseForegroundColor = .white
        logoutButton.configuration = logoutConfig

        statusLabel.font = .systemFont(ofSize: 14, weight: .regular)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0
    }

    private func wireActions() {
        saveBudgetButton.addTarget(self, action: #selector(saveBudgetTapped), for: .touchUpInside)
        notificationSwitch.addTarget(self, action: #selector(notificationSwitchChanged), for: .valueChanged)
        resetStatisticsButton.addTarget(self, action: #selector(resetStatisticsTapped), for: .touchUpInside)
        logoutButton.addTarget(self, action: #selector(logoutTapped), for: .touchUpInside)
    }

    private func loadCurrentBudget() {
        guard let userID = Auth.auth().currentUser?.uid else {
            statusLabel.text = "Not signed in."
            return
        }

        firestore.collection("users").document(userID).getDocument { [weak self] snapshot, error in
            guard let self else { return }

            DispatchQueue.main.async {
                if let error {
                    self.statusLabel.text = "Could not load budget: \(error.localizedDescription)"
                    return
                }

                let budgetValue = Self.readAmount(from: snapshot?.data()?["budget"])
                if budgetValue > 0 {
                    self.budgetTextField.text = self.currencyFormatter.string(from: NSNumber(value: budgetValue))
                }
            }
        }
    }

    private func loadNotificationPreference() {
        guard let userID = Auth.auth().currentUser?.uid else { return }

        firestore.collection("users").document(userID).getDocument { [weak self] snapshot, _ in
            guard let self else { return }
            let storedPreference = snapshot?.data()?["notificationsEnabled"] as? Bool

            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    let enabledBySystem = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
                    self.notificationSwitch.isOn = (storedPreference ?? false) && enabledBySystem
                }
            }
        }
    }

    @objc private func saveBudgetTapped() {
        guard let userID = Auth.auth().currentUser?.uid else {
            statusLabel.text = "Please sign in first."
            return
        }

        guard let value = parseBudget(from: budgetTextField.text), value > 0 else {
            statusLabel.text = "Enter a valid budget greater than 0."
            return
        }

        saveBudgetButton.isEnabled = false

        firestore.collection("users").document(userID).setData([
            "budget": value,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true) { [weak self] error in
            guard let self else { return }

            DispatchQueue.main.async {
                self.saveBudgetButton.isEnabled = true

                if let error {
                    self.statusLabel.textColor = .systemRed
                    self.statusLabel.text = "Budget update failed: \(error.localizedDescription)"
                    return
                }

                self.budgetTextField.text = self.currencyFormatter.string(from: NSNumber(value: value))
                self.statusLabel.textColor = UIColor.systemGreen
                self.statusLabel.text = "Budget updated successfully."
            }
        }
    }

    @objc private func notificationSwitchChanged() {
        if notificationSwitch.isOn {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
                guard let self else { return }

                DispatchQueue.main.async {
                    if let error {
                        self.notificationSwitch.setOn(false, animated: true)
                        self.statusLabel.textColor = .systemRed
                        self.statusLabel.text = "Notification permission failed: \(error.localizedDescription)"
                        self.persistNotificationPreference(enabled: false)
                        return
                    }

                    if granted {
                        self.statusLabel.textColor = .systemGreen
                        self.statusLabel.text = "Push notifications enabled."
                        self.persistNotificationPreference(enabled: true)
                    } else {
                        self.notificationSwitch.setOn(false, animated: true)
                        self.statusLabel.textColor = .systemRed
                        self.statusLabel.text = "Permission denied. Enable notifications in iOS Settings."
                        self.persistNotificationPreference(enabled: false)
                    }
                }
            }
        } else {
            statusLabel.textColor = .secondaryLabel
            statusLabel.text = "Push notifications disabled for this account."
            persistNotificationPreference(enabled: false)
        }
    }

    @objc private func logoutTapped() {
        do {
            try Auth.auth().signOut()
            routeToLoginScreen()
        } catch {
            statusLabel.textColor = .systemRed
            statusLabel.text = "Logout failed: \(error.localizedDescription)"
        }
    }

    @objc private func resetStatisticsTapped() {
        let alert = UIAlertController(
            title: "Reset Statistics?",
            message: "This starts a new calculation period from now. Existing transactions will be kept.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive) { [weak self] _ in
            self?.performStatisticsReset()
        })

        present(alert, animated: true)
    }

    private func performStatisticsReset() {
        guard let userID = Auth.auth().currentUser?.uid else {
            statusLabel.textColor = .systemRed
            statusLabel.text = "Please sign in first."
            return
        }

        resetStatisticsButton.isEnabled = false
        statusLabel.textColor = .secondaryLabel
        statusLabel.text = "Resetting statistics..."

        let resetNow = Date()

        firestore.collection("users").document(userID).setData([
            "statsResetAt": resetNow,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true) { [weak self] error in
            guard let self else { return }

            DispatchQueue.main.async {
                self.resetStatisticsButton.isEnabled = true
                if let error {
                    self.statusLabel.textColor = .systemRed
                    self.statusLabel.text = "Reset failed: \(error.localizedDescription)"
                    return
                }

                self.statusLabel.textColor = .systemGreen
                self.statusLabel.text = "Statistics period reset. Past transactions are preserved."
            }
        }
    }

    private func persistNotificationPreference(enabled: Bool) {
        guard let userID = Auth.auth().currentUser?.uid else { return }

        firestore.collection("users").document(userID).setData([
            "notificationsEnabled": enabled,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    private func routeToLoginScreen() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let rootController = storyboard.instantiateInitialViewController() else { return }

        guard
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let sceneDelegate = windowScene.delegate as? SceneDelegate,
            let window = sceneDelegate.window
        else {
            return
        }

        UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve) {
            window.rootViewController = rootController
            window.makeKeyAndVisible()
        }
    }

    private func parseBudget(from text: String?) -> Double? {
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
