import UIKit

class AnalysisViewController: UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var periodSegmentedControl: UISegmentedControl!
    @IBOutlet weak var monthLabel: UILabel!
    @IBOutlet weak var overviewCardView: UIView!
    @IBOutlet weak var comparisonCardView: UIView!
    @IBOutlet weak var comparisonPercentageLabel: UILabel!
    @IBOutlet weak var comparisonDetailLabel: UILabel!
    @IBOutlet weak var savingsCardView: UIView!
    @IBOutlet weak var bottomBarView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func backTapped(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction func notificationTapped(_ sender: UIButton) {
        // Placeholder handler to keep storyboard action wiring valid.
    }

    @IBAction func periodChanged(_ sender: UISegmentedControl) {
        // Placeholder handler to keep storyboard action wiring valid.
    }

    @IBAction func previousMonthTapped(_ sender: UIButton) {
        // Placeholder handler to keep storyboard action wiring valid.
    }

    @IBAction func nextMonthTapped(_ sender: UIButton) {
        // Placeholder handler to keep storyboard action wiring valid.
    }
}
