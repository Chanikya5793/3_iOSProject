import UIKit
import FirebaseAuth
import FirebaseFirestore

class AnalysisViewController: UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var periodSegmentedControl: UISegmentedControl!
    @IBOutlet weak var monthLabel: UILabel!
    @IBOutlet weak var overviewCardView: UIView!
    @IBOutlet weak var comparisonCardView: UIView!
    @IBOutlet weak var comparisonTitleLabel: UILabel!
    @IBOutlet weak var comparisonPercentageLabel: UILabel!
    @IBOutlet weak var comparisonDetailLabel: UILabel!
    @IBOutlet weak var savingsCardView: UIView!

    @IBOutlet weak var comparisonTrendImageView: UIImageView!
    @IBOutlet weak var pieChartPlaceholderImageView: UIImageView!
    @IBOutlet weak var barChartPlaceholderImageView: UIImageView!
    @IBOutlet weak var foodCategoryLabel: UILabel!
    @IBOutlet weak var travelCategoryLabel: UILabel!
    @IBOutlet weak var billsCategoryLabel: UILabel!
    @IBOutlet weak var shoppingCategoryLabel: UILabel!
    @IBOutlet weak var foodValueLabel: UILabel!
    @IBOutlet weak var travelValueLabel: UILabel!
    @IBOutlet weak var billsValueLabel: UILabel!
    @IBOutlet weak var shoppingValueLabel: UILabel!
    @IBOutlet weak var savingsMonthsLabel: UILabel!
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var refreshButton: UIButton!

    private enum AnalysisPeriod: Int {
        case daily = 0
        case weekly = 1
        case monthly = 2
        case yearly = 3

        var shiftComponent: Calendar.Component {
            switch self {
            case .daily: return .day
            case .weekly: return .weekOfYear
            case .monthly: return .month
            case .yearly: return .year
            }
        }

        var previousPeriodDescription: String {
            switch self {
            case .daily: return "yesterday"
            case .weekly: return "last week"
            case .monthly: return "last month"
            case .yearly: return "last year"
            }
        }

        var comparisonTitle: String {
            switch self {
            case .daily: return "Compared to Yesterday"
            case .weekly: return "Compared to Last Week"
            case .monthly: return "Compared to Last Month"
            case .yearly: return "Compared to Last Year"
            }
        }
    }

    private struct Transaction {
        let type: String
        let category: String
        let amount: Double
        let date: Date
    }

    private let firestore = Firestore.firestore()
    private let calendar = Calendar.current
    private var selectedDate = Date()
    private var transactions: [Transaction] = []
    private var statsResetAt: Date?

    private let pieChartView = PieChartView()
    private let barChartView = BarChartView()

    private let foodColor = UIColor(red: 0.87, green: 0.35, blue: 0.26, alpha: 1)
    private let travelColor = UIColor(red: 0.93, green: 0.57, blue: 0.26, alpha: 1)
    private let billsColor = UIColor(red: 0.73, green: 0.40, blue: 0.20, alpha: 1)
    private let shoppingColor = UIColor(red: 0.60, green: 0.29, blue: 0.16, alpha: 1)

    private var isRefreshing = false
    private var lastManualRefreshAt: Date?
    private let refreshCooldown: TimeInterval = 10
    private var currentTrendValues: [Double] = []
    private var currentTrendLabels: [String] = []
    private var tooltipHideTask: DispatchWorkItem?

    private let barTooltipLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .white
        label.backgroundColor = UIColor(white: 0.15, alpha: 0.84)
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        label.textAlignment = .center
        label.numberOfLines = 2
        label.isHidden = true
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
        configureCards()
        configureCharts()
        configureFiltersAndRefresh()
        selectedDate = Date()
        periodSegmentedControl.selectedSegmentIndex = AnalysisPeriod.monthly.rawValue
        datePicker.date = selectedDate
        applyEmptyState(message: "Loading analysis...")
        loadTransactions(forceServer: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshAnalysis()
    }

    @IBAction func notificationTapped(_ sender: UIButton) {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    @IBAction func periodChanged(_ sender: UISegmentedControl) {
        refreshAnalysis()
    }

    @IBAction func refreshTapped(_ sender: UIButton) {
        let now = Date()
        if let lastManualRefreshAt {
            let elapsed = now.timeIntervalSince(lastManualRefreshAt)
            if elapsed < refreshCooldown {
                let remaining = Int(ceil(refreshCooldown - elapsed))
                showPopup(title: "Please wait", message: "You can refresh again in \(remaining)s.")
                return
            }
        }

        guard !isRefreshing else {
            showPopup(title: "Refresh in progress", message: "Analytics is already refreshing.")
            return
        }

        lastManualRefreshAt = now
        loadTransactions(forceServer: true)
    }

    @IBAction func previousMonthTapped(_ sender: UIButton) {
        shiftSelection(by: -1)
    }

    @IBAction func nextMonthTapped(_ sender: UIButton) {
        shiftSelection(by: 1)
    }

    private var currentPeriod: AnalysisPeriod {
        AnalysisPeriod(rawValue: periodSegmentedControl.selectedSegmentIndex) ?? .monthly
    }

    private func configureCards() {
        [overviewCardView, comparisonCardView, savingsCardView].forEach {
            $0?.layer.cornerRadius = 20
            $0?.layer.masksToBounds = true
        }
        comparisonDetailLabel.numberOfLines = 2
        configureCategoryLegendColors()
    }

    private func configureCategoryLegendColors() {
        foodCategoryLabel.textColor = foodColor
        travelCategoryLabel.textColor = travelColor
        billsCategoryLabel.textColor = billsColor
        shoppingCategoryLabel.textColor = shoppingColor
    }

    private func configureFiltersAndRefresh() {
        if periodSegmentedControl.numberOfSegments >= 4 {
            periodSegmentedControl.setTitle("Daily", forSegmentAt: 0)
            periodSegmentedControl.setTitle("Weekly", forSegmentAt: 1)
            periodSegmentedControl.setTitle("Monthly", forSegmentAt: 2)
            periodSegmentedControl.setTitle("Yearly", forSegmentAt: 3)
        }

        datePicker.datePickerMode = .date
        if #available(iOS 13.4, *) {
            datePicker.preferredDatePickerStyle = .compact
        }
        datePicker.addTarget(self, action: #selector(datePickerChanged(_:)), for: .valueChanged)
    }

    @objc private func datePickerChanged(_ sender: UIDatePicker) {
        selectedDate = sender.date
        refreshAnalysis()
    }

    private func configureCharts() {
        pieChartPlaceholderImageView.image = nil
        pieChartPlaceholderImageView.tintColor = .clear
        pieChartPlaceholderImageView.isUserInteractionEnabled = false

        pieChartView.translatesAutoresizingMaskIntoConstraints = false
        pieChartPlaceholderImageView.addSubview(pieChartView)
        NSLayoutConstraint.activate([
            pieChartView.leadingAnchor.constraint(equalTo: pieChartPlaceholderImageView.leadingAnchor),
            pieChartView.trailingAnchor.constraint(equalTo: pieChartPlaceholderImageView.trailingAnchor),
            pieChartView.topAnchor.constraint(equalTo: pieChartPlaceholderImageView.topAnchor),
            pieChartView.bottomAnchor.constraint(equalTo: pieChartPlaceholderImageView.bottomAnchor)
        ])

        barChartPlaceholderImageView.image = nil
        barChartPlaceholderImageView.tintColor = .clear
        barChartPlaceholderImageView.isUserInteractionEnabled = true

        barChartView.translatesAutoresizingMaskIntoConstraints = false
        barChartPlaceholderImageView.addSubview(barChartView)
        NSLayoutConstraint.activate([
            barChartView.leadingAnchor.constraint(equalTo: barChartPlaceholderImageView.leadingAnchor),
            barChartView.trailingAnchor.constraint(equalTo: barChartPlaceholderImageView.trailingAnchor),
            barChartView.topAnchor.constraint(equalTo: barChartPlaceholderImageView.topAnchor),
            barChartView.bottomAnchor.constraint(equalTo: barChartPlaceholderImageView.bottomAnchor)
        ])

        configureBarChartInteractions()
    }

    private func configureBarChartInteractions() {
        barChartView.isUserInteractionEnabled = true

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(barChartTapped(_:)))
        barChartView.addGestureRecognizer(tapGesture)

        if #available(iOS 13.4, *) {
            let hoverGesture = UIHoverGestureRecognizer(target: self, action: #selector(barChartHovered(_:)))
            barChartView.addGestureRecognizer(hoverGesture)
        }

        guard barTooltipLabel.superview == nil else { return }
        savingsCardView.addSubview(barTooltipLabel)
        NSLayoutConstraint.activate([
            barTooltipLabel.topAnchor.constraint(equalTo: savingsCardView.topAnchor, constant: 10),
            barTooltipLabel.trailingAnchor.constraint(equalTo: savingsCardView.trailingAnchor, constant: -10),
            barTooltipLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 190)
        ])
    }

    @objc private func barChartTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: barChartView)
        guard let index = barIndex(for: location) else { return }
        showBarTooltip(for: index, autoHideAfter: 2.2)
    }

    @available(iOS 13.4, *)
    @objc private func barChartHovered(_ gesture: UIHoverGestureRecognizer) {
        switch gesture.state {
        case .began, .changed:
            let location = gesture.location(in: barChartView)
            guard let index = barIndex(for: location) else { return }
            showBarTooltip(for: index, autoHideAfter: nil)
        default:
            tooltipHideTask?.cancel()
            barTooltipLabel.isHidden = true
        }
    }

    private func barIndex(for point: CGPoint) -> Int? {
        guard !currentTrendValues.isEmpty else { return nil }
        guard barChartView.bounds.width > 0 else { return nil }

        let slotWidth = barChartView.bounds.width / CGFloat(currentTrendValues.count)
        guard slotWidth > 0 else { return nil }

        var index = Int(floor(point.x / slotWidth))
        index = max(0, min(currentTrendValues.count - 1, index))
        return index
    }

    private func showBarTooltip(for index: Int, autoHideAfter delay: TimeInterval?) {
        guard index >= 0, index < currentTrendValues.count, index < currentTrendLabels.count else { return }

        let label = currentTrendLabels[index]
        let value = currentTrendValues[index]
        let summary: String

        if value > 0 {
            summary = "\(label): +\(formatCurrency(value)) saved"
        } else if value < 0 {
            summary = "\(label): -\(formatCurrency(abs(value))) overspent"
        } else {
            summary = "\(label): \(formatCurrency(0)) net"
        }

        barTooltipLabel.text = "  \(summary)  "
        barTooltipLabel.isHidden = false

        tooltipHideTask?.cancel()
        guard let delay else { return }

        let task = DispatchWorkItem { [weak self] in
            self?.barTooltipLabel.isHidden = true
        }
        tooltipHideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: task)
    }

    private func loadTransactions(forceServer: Bool) {
        guard let userID = Auth.auth().currentUser?.uid else {
            applyEmptyState(message: "Sign in to view analysis.")
            return
        }

        setRefreshing(true)

        let userDocument = firestore
            .collection("users")
            .document(userID)

        let fetchTransactions: () -> Void = { [weak self] in
            guard let self else { return }

            let query = self.firestore
                .collection("users")
                .document(userID)
                .collection("transactions")
                .order(by: "date", descending: true)

            let completion: (QuerySnapshot?, Error?) -> Void = { [weak self] snapshot, error in
                guard let self else { return }

                DispatchQueue.main.async {
                    self.setRefreshing(false)

                    if let error {
                        self.applyEmptyState(message: "Unable to load analysis: \(error.localizedDescription)")
                        return
                    }

                    self.transactions = (snapshot?.documents ?? []).compactMap { doc in
                        let data = doc.data()
                        let type = (data["type"] as? String ?? "expense").lowercased()
                        let category = (data["category"] as? String ?? "Other")
                        let amount = Self.readAmount(from: data["amount"])

                        guard amount > 0 else { return nil }

                        let timestamp = (data["date"] as? Timestamp)
                            ?? (data["createdAt"] as? Timestamp)
                            ?? Timestamp(date: .distantPast)

                        let transactionDate = timestamp.dateValue()
                        if let statsResetAt = self.statsResetAt, transactionDate < statsResetAt {
                            return nil
                        }

                        return Transaction(
                            type: type,
                            category: category,
                            amount: amount,
                            date: transactionDate
                        )
                    }

                    self.refreshAnalysis()
                }
            }

            if forceServer {
                query.getDocuments(source: .server, completion: completion)
            } else {
                query.getDocuments(completion: completion)
            }
        }

        let userCompletion: (DocumentSnapshot?, Error?) -> Void = { [weak self] snapshot, _ in
            guard let self else { return }
            self.statsResetAt = Self.readDate(from: snapshot?.data()?["statsResetAt"])
            fetchTransactions()
        }

        if forceServer {
            userDocument.getDocument(source: .server, completion: userCompletion)
        } else {
            userDocument.getDocument(completion: userCompletion)
        }
    }

    private func shiftSelection(by value: Int) {
        guard let next = calendar.date(byAdding: currentPeriod.shiftComponent, value: value, to: selectedDate) else {
            return
        }
        selectedDate = next
        datePicker.date = next
        refreshAnalysis()
    }

    private func refreshAnalysis() {
        comparisonTitleLabel.text = currentPeriod.comparisonTitle
        updateMonthLabel()

        let currentInterval = interval(for: currentPeriod, at: selectedDate)
        let previousDate = calendar.date(byAdding: currentPeriod.shiftComponent, value: -1, to: selectedDate) ?? selectedDate
        let previousInterval = interval(for: currentPeriod, at: previousDate)

        let currentExpenses = expenses(in: currentInterval)
        let previousExpenses = expenses(in: previousInterval)

        updateOverview(using: currentExpenses)
        updateComparison(currentExpenses: currentExpenses, previousExpenses: previousExpenses)
        updateSavingsChart()
    }

    private func updateMonthLabel() {
        let formatter = DateFormatter()

        switch currentPeriod {
        case .daily:
            formatter.dateStyle = .medium
            monthLabel.text = formatter.string(from: selectedDate)
        case .weekly:
            let interval = interval(for: .weekly, at: selectedDate)
            let endDate = calendar.date(byAdding: .day, value: 6, to: interval.start) ?? interval.end
            formatter.dateFormat = "MMM d"
            monthLabel.text = "\(formatter.string(from: interval.start)) - \(formatter.string(from: endDate))"
        case .monthly:
            formatter.dateFormat = "MMMM yyyy"
            monthLabel.text = formatter.string(from: selectedDate)
        case .yearly:
            formatter.dateFormat = "yyyy"
            monthLabel.text = formatter.string(from: selectedDate)
        }
    }

    private func updateOverview(using expenses: [Transaction]) {
        let total = expenses.reduce(0) { $0 + $1.amount }
        let food = categoryTotal(named: "food", in: expenses)
        let travel = categoryTotal(named: "travel", in: expenses)
        let bills = categoryTotal(named: "bills", in: expenses)
        let shopping = categoryTotal(named: "shopping", in: expenses)

        foodValueLabel.text = formattedBreakdown(amount: food, total: total)
        travelValueLabel.text = formattedBreakdown(amount: travel, total: total)
        billsValueLabel.text = formattedBreakdown(amount: bills, total: total)
        shoppingValueLabel.text = formattedBreakdown(amount: shopping, total: total)

        pieChartView.segments = [
            .init(value: food, color: foodColor),
            .init(value: travel, color: travelColor),
            .init(value: bills, color: billsColor),
            .init(value: shopping, color: shoppingColor)
        ]
    }

    private func updateComparison(currentExpenses: [Transaction], previousExpenses: [Transaction]) {
        let currentTotal = currentExpenses.reduce(0) { $0 + $1.amount }
        let previousTotal = previousExpenses.reduce(0) { $0 + $1.amount }

        if currentTotal == 0, previousTotal == 0 {
            comparisonTrendImageView.image = UIImage(systemName: "minus.circle.fill")
            comparisonTrendImageView.tintColor = .secondaryLabel
            comparisonPercentageLabel.textColor = .secondaryLabel
            comparisonPercentageLabel.text = "0%"
            comparisonDetailLabel.text = "No spending in this period yet."
            return
        }

        let delta = previousTotal - currentTotal
        let percentage: Double
        if previousTotal > 0 {
            percentage = (abs(delta) / previousTotal) * 100
        } else {
            percentage = 100
        }

        comparisonPercentageLabel.text = "\(Int(round(percentage)))%"

        if delta > 0 {
            comparisonTrendImageView.image = UIImage(systemName: "arrow.down.circle.fill")
            comparisonTrendImageView.tintColor = UIColor.systemGreen
            comparisonPercentageLabel.textColor = UIColor.systemGreen
            comparisonDetailLabel.text = "You spent \(formatCurrency(delta)) less than \(currentPeriod.previousPeriodDescription). Keep it up!"
        } else if delta < 0 {
            comparisonTrendImageView.image = UIImage(systemName: "arrow.up.circle.fill")
            comparisonTrendImageView.tintColor = UIColor.systemRed
            comparisonPercentageLabel.textColor = UIColor.systemRed
            comparisonDetailLabel.text = "You spent \(formatCurrency(abs(delta))) more than \(currentPeriod.previousPeriodDescription)."
        } else {
            comparisonTrendImageView.image = UIImage(systemName: "equal.circle.fill")
            comparisonTrendImageView.tintColor = UIColor.systemOrange
            comparisonPercentageLabel.textColor = UIColor.systemOrange
            comparisonDetailLabel.text = "Spending is unchanged compared to \(currentPeriod.previousPeriodDescription)."
        }
    }

    private func updateSavingsChart() {
        let trend = savingsTrendData()
        currentTrendValues = trend.values
        currentTrendLabels = trend.labels
        barChartView.values = trend.values
        barChartView.positiveColor = UIColor(red: 0.84, green: 0.64, blue: 0.17, alpha: 1)
        barChartView.negativeColor = UIColor.systemRed
        savingsMonthsLabel.text = trend.labels.joined(separator: "   ")

        if trend.values.isEmpty {
            barTooltipLabel.isHidden = true
        }
    }

    private func savingsTrendData() -> (values: [Double], labels: [String]) {
        switch currentPeriod {
        case .daily:
            return hourlySavingsTrend()
        case .weekly:
            return dailySavingsTrend()
        case .monthly:
            return monthlySavingsTrend()
        case .yearly:
            return yearlySavingsTrend()
        }
    }

    private func hourlySavingsTrend() -> (values: [Double], labels: [String]) {
        var values: [Double] = []
        var labels: [String] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"

        for offset in -6...0 {
            guard let hour = calendar.date(byAdding: .hour, value: offset, to: selectedDate) else { continue }
            let start = calendar.date(bySetting: .minute, value: 0, of: hour) ?? hour
            let end = calendar.date(byAdding: .hour, value: 1, to: start) ?? start
            let interval = DateInterval(start: start, end: end)
            values.append(netSavings(in: interval))
            labels.append(formatter.string(from: start))
        }

        return (values, labels)
    }

    private func dailySavingsTrend() -> (values: [Double], labels: [String]) {
        var values: [Double] = []
        var labels: [String] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "E"

        for offset in -6...0 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: selectedDate) else { continue }
            let dayInterval = calendar.dateInterval(of: .day, for: day) ?? DateInterval(start: day, duration: 86400)
            values.append(netSavings(in: dayInterval))
            labels.append(formatter.string(from: day))
        }

        return (values, labels)
    }

    private func monthlySavingsTrend() -> (values: [Double], labels: [String]) {
        var values: [Double] = []
        var labels: [String] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        for offset in -6...0 {
            guard let month = calendar.date(byAdding: .month, value: offset, to: selectedDate) else { continue }
            let monthInterval = interval(for: .monthly, at: month)
            values.append(netSavings(in: monthInterval))
            labels.append(formatter.string(from: month))
        }

        return (values, labels)
    }

    private func yearlySavingsTrend() -> (values: [Double], labels: [String]) {
        var values: [Double] = []
        var labels: [String] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "yy"

        for offset in -6...0 {
            guard let year = calendar.date(byAdding: .year, value: offset, to: selectedDate) else { continue }
            let yearInterval = interval(for: .yearly, at: year)
            values.append(netSavings(in: yearInterval))
            labels.append(formatter.string(from: year))
        }

        return (values, labels)
    }

    private func netSavings(in interval: DateInterval) -> Double {
        let entries = transactions.filter { interval.contains($0.date) }
        let income = entries.filter { $0.type == "income" }.reduce(0) { $0 + $1.amount }
        let expense = entries.filter { $0.type == "expense" }.reduce(0) { $0 + $1.amount }
        return income - expense
    }

    private func expenses(in interval: DateInterval) -> [Transaction] {
        transactions.filter { $0.type == "expense" && interval.contains($0.date) }
    }

    private func interval(for period: AnalysisPeriod, at date: Date) -> DateInterval {
        switch period {
        case .daily:
            return calendar.dateInterval(of: .day, for: date) ?? DateInterval(start: date, duration: 24 * 60 * 60)
        case .weekly:
            return calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 7 * 24 * 60 * 60)
        case .monthly:
            return calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 30 * 24 * 60 * 60)
        case .yearly:
            return calendar.dateInterval(of: .year, for: date) ?? DateInterval(start: date, duration: 365 * 24 * 60 * 60)
        }
    }

    private func setRefreshing(_ refreshing: Bool) {
        isRefreshing = refreshing
        refreshButton.isEnabled = !refreshing
    }

    private func showPopup(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func formattedBreakdown(amount: Double, total: Double) -> String {
        guard total > 0 else { return "\(formatCurrency(0)) (0%)" }
        let percent = Int(round((amount / total) * 100))
        return "\(formatCurrency(amount)) (\(percent)%)"
    }

    private func categoryTotal(named category: String, in values: [Transaction]) -> Double {
        values
            .filter { $0.category.lowercased() == category }
            .reduce(0) { $0 + $1.amount }
    }

    private func applyEmptyState(message: String) {
        comparisonTitleLabel.text = currentPeriod.comparisonTitle
        comparisonTrendImageView.image = UIImage(systemName: "minus.circle.fill")
        comparisonTrendImageView.tintColor = .secondaryLabel
        comparisonPercentageLabel.text = "0%"
        comparisonPercentageLabel.textColor = .secondaryLabel
        comparisonDetailLabel.text = message

        foodValueLabel.text = "\(formatCurrency(0)) (0%)"
        travelValueLabel.text = "\(formatCurrency(0)) (0%)"
        billsValueLabel.text = "\(formatCurrency(0)) (0%)"
        shoppingValueLabel.text = "\(formatCurrency(0)) (0%)"

        pieChartView.segments = []
        barChartView.values = []
        currentTrendValues = []
        currentTrendLabels = []
        barTooltipLabel.isHidden = true
        savingsMonthsLabel.text = "-"
    }

    private func formatCurrency(_ value: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? "$0"
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

    private static func readDate(from rawValue: Any?) -> Date? {
        if let timestamp = rawValue as? Timestamp {
            return timestamp.dateValue()
        }
        if let date = rawValue as? Date {
            return date
        }
        return nil
    }
}
