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

    private let firestore = Firestore.firestore()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 34, weight: .bold)
        label.text = "Settings"
        label.textColor = UIColor(red: 0.16, green: 0.11, blue: 0.07, alpha: 1)
        return label
    }()

    private let budgetCard = UIView()
    private let budgetTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Monthly Budget"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        return label
    }()

    private let budgetTextField: UITextField = {
        let field = UITextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.borderStyle = .roundedRect
        field.placeholder = "Enter amount"
        field.keyboardType = .decimalPad
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        return field
    }()

    private let saveBudgetButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.configuration = .filled()
        button.configuration?.title = "Update Budget"
        button.configuration?.baseBackgroundColor = UIColor(red: 0.77, green: 0.48, blue: 0.27, alpha: 1)
        button.configuration?.baseForegroundColor = .white
        return button
    }()

    private let notificationCard = UIView()
    private let notificationTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Push Notifications"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        return label
    }()

    private let notificationDetailLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Get reminders and budgeting updates"
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        return label
    }()

    private let notificationSwitch: UISwitch = {
        let control = UISwitch()
        control.translatesAutoresizingMaskIntoConstraints = false
        control.onTintColor = UIColor(red: 0.77, green: 0.48, blue: 0.27, alpha: 1)
        return control
    }()

    private let logoutButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.configuration = .filled()
        button.configuration?.title = "Log Out"
        button.configuration?.baseBackgroundColor = UIColor.systemRed.withAlphaComponent(0.9)
        button.configuration?.baseForegroundColor = .white
        return button
    }()

    private let resetStatisticsButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.configuration = .filled()
        button.configuration?.title = "Reset Statistics"
        button.configuration?.baseBackgroundColor = UIColor.systemOrange.withAlphaComponent(0.9)
        button.configuration?.baseForegroundColor = .white
        return button
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private lazy var currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        buildInterface()
        wireActions()
        loadCurrentBudget()
        loadNotificationPreference()
    }

    private func buildInterface() {
        view.backgroundColor = UIColor(red: 0.91, green: 0.85, blue: 0.76, alpha: 1)

        view.addSubview(titleLabel)
        view.addSubview(budgetCard)
        view.addSubview(notificationCard)
        view.addSubview(resetStatisticsButton)
        view.addSubview(logoutButton)
        view.addSubview(statusLabel)

        [budgetCard, notificationCard].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.backgroundColor = UIColor(white: 1, alpha: 0.5)
            $0.layer.cornerRadius = 18
            $0.layer.masksToBounds = true
        }

        budgetCard.addSubview(budgetTitleLabel)
        budgetCard.addSubview(budgetTextField)
        budgetCard.addSubview(saveBudgetButton)

        notificationCard.addSubview(notificationTitleLabel)
        notificationCard.addSubview(notificationDetailLabel)
        notificationCard.addSubview(notificationSwitch)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),

            budgetCard.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            budgetCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            budgetCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            budgetTitleLabel.topAnchor.constraint(equalTo: budgetCard.topAnchor, constant: 18),
            budgetTitleLabel.leadingAnchor.constraint(equalTo: budgetCard.leadingAnchor, constant: 18),
            budgetTitleLabel.trailingAnchor.constraint(equalTo: budgetCard.trailingAnchor, constant: -18),

            budgetTextField.topAnchor.constraint(equalTo: budgetTitleLabel.bottomAnchor, constant: 12),
            budgetTextField.leadingAnchor.constraint(equalTo: budgetCard.leadingAnchor, constant: 18),
            budgetTextField.trailingAnchor.constraint(equalTo: budgetCard.trailingAnchor, constant: -18),

            saveBudgetButton.topAnchor.constraint(equalTo: budgetTextField.bottomAnchor, constant: 12),
            saveBudgetButton.leadingAnchor.constraint(equalTo: budgetCard.leadingAnchor, constant: 18),
            saveBudgetButton.trailingAnchor.constraint(equalTo: budgetCard.trailingAnchor, constant: -18),
            saveBudgetButton.bottomAnchor.constraint(equalTo: budgetCard.bottomAnchor, constant: -18),
            saveBudgetButton.heightAnchor.constraint(equalToConstant: 44),

            notificationCard.topAnchor.constraint(equalTo: budgetCard.bottomAnchor, constant: 16),
            notificationCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            notificationCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            notificationTitleLabel.topAnchor.constraint(equalTo: notificationCard.topAnchor, constant: 18),
            notificationTitleLabel.leadingAnchor.constraint(equalTo: notificationCard.leadingAnchor, constant: 18),

            notificationSwitch.centerYAnchor.constraint(equalTo: notificationTitleLabel.centerYAnchor),
            notificationSwitch.trailingAnchor.constraint(equalTo: notificationCard.trailingAnchor, constant: -18),

            notificationDetailLabel.topAnchor.constraint(equalTo: notificationTitleLabel.bottomAnchor, constant: 8),
            notificationDetailLabel.leadingAnchor.constraint(equalTo: notificationCard.leadingAnchor, constant: 18),
            notificationDetailLabel.trailingAnchor.constraint(equalTo: notificationCard.trailingAnchor, constant: -18),
            notificationDetailLabel.bottomAnchor.constraint(equalTo: notificationCard.bottomAnchor, constant: -18),

            resetStatisticsButton.topAnchor.constraint(equalTo: notificationCard.bottomAnchor, constant: 16),
            resetStatisticsButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            resetStatisticsButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            resetStatisticsButton.heightAnchor.constraint(equalToConstant: 48),

            logoutButton.topAnchor.constraint(equalTo: resetStatisticsButton.bottomAnchor, constant: 12),
            logoutButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            logoutButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            logoutButton.heightAnchor.constraint(equalToConstant: 48),

            statusLabel.topAnchor.constraint(equalTo: logoutButton.bottomAnchor, constant: 14),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
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
