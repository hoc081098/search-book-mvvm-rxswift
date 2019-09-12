//
//  DetailVC.swift
//  Search Book
//
//  Created by HOANG TAN DUY on 9/9/19.
//  Copyright © 2019 Petrus Nguyễn Thái Học. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import Kingfisher
import MaterialComponents.MaterialButtons

class DetailVC: UIViewController {
    var detailVM: DetailVM!
    var initialDetail: InitialBookDetail!

    private let disposeBag = DisposeBag()
    private let intentS = PublishRelay<DetailIntent>()

    // MARK: - Views

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageLarge: UIImageView!
    @IBOutlet weak var bottomView: UIView!
    @IBOutlet weak var imageThumbnail: UIImageView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var labelSubtitle: UILabel!
    @IBOutlet weak var labelPublishedDate: UILabel!
    @IBOutlet weak var labelDescription: UILabel!
    @IBOutlet weak var labelAuthors: UILabel!
    private weak var fab: MDCFloatingButton?
    private weak var refreshControl: UIRefreshControl!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupCardView()
        addBlurEffectToCardView()
        setupBackgroundColor()
        addRefreshControl()

        self.bindVM()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        addFab()
    }

    // MARK: - Bind VM

    private func bindVM() {
        self.detailVM
            .state$
            .drive(onNext: self.render)
            .disposed(by: self.disposeBag)
        
        detailVM
            .singleEvent$
            .emit(onNext: { event in
                print("Event=\(event)")
                
                let message = MDCSnackbarMessage().apply {
                    $0.duration = 2
                    
                    switch event {
                    case .addedToFavorited(let detail):
                        $0.text = "Added '\(detail.title ?? "")' to favorited"
                    case .removedFromFavorited(let detail):
                        $0.text = "Removed '\(detail.title ?? "")' from favorited"
                    case .refreshSuccess:
                        $0.text = "Refresh success"
                    case .refreshError(let error):
                        $0.text = "Refesh error: \(self.getMessage(from: error))"
                    case .getDetailError(let error):
                         $0.text = "Get detail error: \(self.getMessage(from: error))"
                    }
                }
                MDCSnackbarManager.show(message)
            })
            .disposed(by: disposeBag)

        self.detailVM
            .process(intent$: .merge([
                        .just(.initial(initialDetail)),
                    self.refreshControl
                        .rx
                        .controlEvent(.valueChanged)
                        .map { .refresh },
                    self.intentS.asObservable()
                    ]))
            .disposed(by: disposeBag)
    }
    
    private func getMessage(from error: DetailError) -> String {
        switch error {
        case .networkError:
            return "Network error"
        case .serverResponseError(_, let message):
            return "Server response error: \(message)"
        case .unexpectedError:
            return "An unexpected error"
        }
    }

    private func loadLargeImage(_ vs: DetailViewState) {
        let url = URL.init(string: vs.detail?.largeImage ?? "")

        let processor = DownsamplingImageProcessor(size: self.imageLarge.frame.size)

        self.imageLarge.kf.indicatorType = .activity
        self.imageLarge.kf.setImage(
            with: url,
            placeholder: UIImage.init(named: "no_image.png"),
            options: [
                    .processor(processor),
                    .scaleFactor(UIScreen.main.scale),
                    .transition(.fade(1)),
                    .cacheOriginalImage
            ]
        )
    }

    private func loadThumbnailImage(_ vs: DetailViewState) {
        let url = URL.init(string: vs.detail?.thumbnail ?? "")

        let processor = DownsamplingImageProcessor(size: self.imageThumbnail.frame.size) >> RoundCornerImageProcessor(cornerRadius: 12)

        self.imageThumbnail.kf.indicatorType = .activity
        self.imageThumbnail.kf.setImage(
            with: url,
            placeholder: UIImage.init(named: "no_image.png"),
            options: [
                    .processor(processor),
                    .scaleFactor(UIScreen.main.scale),
                    .transition(.fade(1)),
                    .cacheOriginalImage
            ]
        )
    }

    private func setText(_ vs: DetailViewState) {
        self.labelTitle.text = vs.isLoading ? "Loading..." : (vs.detail?.title ?? "No title")
        self.labelSubtitle.text = vs.isLoading ? "Loading" : (vs.detail?.subtitle ?? "No subtitle")

        let authors = vs.isLoading ? "Loading..." : (vs.detail?.authors?.joined(separator: ", ") ?? "N/A")
        self.labelAuthors.text = "Authors: \(authors)"
        let publishedDate = vs.isLoading ? "Loading..." : (vs.detail?.publishedDate ?? "N/A")
        self.labelPublishedDate.text = "PublishedDate: \(publishedDate)"

        let description = vs.isLoading ? "Loading..." : (vs.detail?.description ?? "No description")

        let descriptionHtml = description.htmlToAttributedString

        self.labelDescription.attributedText = descriptionHtml.map { NSMutableAttributedString.init(attributedString: $0) }?.with(font: UIFont.init(name: "Thonburi", size: 15)!)
    }

    private func setFabIcon(_ vs: DetailViewState) {
        if let fav = vs.detail?.isFavorited {
            let image = fav
                ? UIImage(named: "baseline_favorite_white_36pt")
                : UIImage(named: "baseline_favorite_border_white_36pt")
            self.fab?.setImage(image, for: .normal)
        }
    }

    private func render(_ vs: DetailViewState) {
        loadLargeImage(vs)
        loadThumbnailImage(vs)
        setText(vs)
        setFabIcon(vs)
        if !vs.isRefreshing {
            self.refreshControl.endRefreshing()
        }
    }
}

// MARK: - Setup UI
private extension DetailVC {
    func setupCardView() {
        self.cardView.letIt {
            $0.backgroundColor = .clear
            $0.layer.shadowColor = UIColor.black.withAlphaComponent(0.13).cgColor
            $0.layer.shadowOpacity = 1
            $0.layer.shadowOffset = .init(width: 0, height: 10)
            $0.layer.shadowRadius = 10
            $0.layer.shadowPath = UIBezierPath(rect: $0.bounds).cgPath
        }
    }

    func addBlurEffectToCardView() {
        let blurEffect = UIBlurEffect(style: .light)
        let blurEffectView = UIVisualEffectView(effect: blurEffect).apply {
            $0.frame = self.cardView.bounds
            $0.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            $0.alpha = 0.9
            $0.clipsToBounds = true
            $0.layer.cornerRadius = 16
        }
        self.cardView.insertSubview(blurEffectView, at: 0)
    }

    func setupBackgroundColor() {
        let color = self.view.backgroundColor!
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let gradientLayer = CAGradientLayer().apply {
                $0.colors = [
                    color.withAlphaComponent(0),
                    color
                ].map { $0.cgColor }
                $0.startPoint = CGPoint(x: 0, y: 0)
                $0.endPoint = CGPoint(x: 0, y: 1)
                $0.locations = [0.1, 0.9]
                $0.frame = self.bottomView.bounds
                $0.repeatCount = 1
            }

            self.bottomView.layer.insertSublayer(gradientLayer, at: 0)
        }
    }

    func addFab() {
        guard self.fab == nil else { return }

        let fabSize = CGFloat(64)
        let fabMarginBottom = CGFloat(64)
        let fabMarginRight = CGFloat(12)

        let frame = CGRect(
            x: self.view.frame.width - fabSize - fabMarginRight,
            y: self.view.frame.height - fabSize - self.view.safeAreaInsets.bottom - fabMarginBottom,
            width: fabSize,
            height: fabSize
        )

        let button = MDCFloatingButton.init(frame: frame).apply {
            $0.setElevation(ShadowElevation(rawValue: 4), for: .normal)
            $0.setElevation(ShadowElevation(rawValue: 8), for: .highlighted)
            $0.tintColor = .white
            $0.backgroundColor = Colors.tintColor
            $0.setShadowColor(UIColor.black.withAlphaComponent(0.13), for: .normal)
        }
        
        button.rx
            .tap
            .map { .toggleFavorite }
            .bind(to: self.intentS)
            .disposed(by: self.disposeBag)

        self.view.addSubview(button)
        self.fab = button
    }

    func addRefreshControl() {
        self.refreshControl = UIRefreshControl().apply {
            let color = UIColor.black
            $0.tintColor = color
            $0.backgroundColor = self.view.backgroundColor?.withAlphaComponent(0.4)
            let attributes = [
                NSAttributedString.Key.font: UIFont.init(name: "Thonburi", size: 15)!,
                NSAttributedString.Key.foregroundColor: color
            ]
            $0.attributedTitle = NSAttributedString.init(
                string: "Refreshing...",
                attributes: attributes
            )
            self.scrollView.refreshControl = $0
        }
    }
}
