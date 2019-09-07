//
//  DiaryController.swift
//  MyDiary
//
//  Created by Jinwoo Kim on 27/03/2019.
//  Copyright © 2019 jinuman. All rights reserved.
//

import UIKit

class DiaryController: UIViewController {
    
    // MARK:- Properties
    var viewModel: DiaryViewModel?
    
    // MARK:- Screen properties
    private let saveEditButton = UIBarButtonItem()
    private let removeButton = UIBarButtonItem()
    
    private let diaryTextView: UITextView = {
        let tv = UITextView()
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        tv.returnKeyType = .continue
        tv.keyboardType = .default
        return tv
    }()
    
    private var diaryTextViewBottomConstraint: NSLayoutConstraint?
    
    // MARK:- Life Cycle methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSubviews()
        setupNavigationBarItems()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let nc = NotificationCenter.default
        nc.addObserver(self,
                       selector: #selector(handleKeyboardAppear(_:)),
                       name: UIResponder.keyboardWillShowNotification,
                       object: nil)
        nc.addObserver(self,
                       selector: #selector(handleKeyboardAppear(_:)),
                       name: UIResponder.keyboardWillHideNotification,
                       object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let viewModel = viewModel else { return }
        if viewModel.isEditing {
            diaryTextView.becomeFirstResponder()
        }
    }
    
    // In order to fix Notification memory leak.
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    deinit {
        print("Diary Controller \(#function)")
    }
    
    // MARK:- Screen setup methods
    private func setupSubviews() {
        guard let viewModel = viewModel else { return }
        view.backgroundColor = .white
        title = viewModel.diaryTitle
        // Add gesture to view
        let tapGesture = UITapGestureRecognizer()
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
        
        // + 버튼을 통해 일기 추가면, 에디팅부터 시작하게 한다.
        if viewModel.hasDiary == false {
            viewModel.startEditing()
        }
        updateSubviews()
        
        let guide = view.safeAreaLayoutGuide
        view.addSubview(diaryTextView)
        let diaryTextviewConstraints = diaryTextView.anchor(top: guide.topAnchor,
                                                            leading: guide.leadingAnchor,
                                                            bottom: guide.bottomAnchor,
                                                            trailing: guide.trailingAnchor,
                                                            padding: UIEdgeInsets(top: 8, left: 12, bottom: 0, right: 12))
        diaryTextViewBottomConstraint = diaryTextviewConstraints.bottom
        
        setAttributedDiaryTextView()
    }
    
    private func setAttributedDiaryTextView() {
        guard let viewModel = viewModel else { return }
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 20
        let atributes = [
            NSAttributedString.Key.paragraphStyle: style,
            NSAttributedString.Key.font: viewModel.diaryTextViewFont
        ]
        diaryTextView.attributedText = NSAttributedString(string: viewModel.diaryTextViewText ?? " ", attributes: atributes)
    }
    
    // MARK:- Handling methods
    @objc private func handleRemove() {
        guard
            let viewModel = viewModel,
            viewModel.hasDiary else { return }
        
        let alertController = UIAlertController(title: "현재 일기를 삭제할까요?",
                                                message: "이 동작은 되돌릴 수 없습니다.",
                                                preferredStyle: .actionSheet)
        
        let removeAction: UIAlertAction = UIAlertAction(title: "삭제", style: .destructive) { (_) in
            guard let _ = viewModel.removeDiary() else { return }  // 나중에 최근 삭제한 내용 저장할 때 필요할지도 모른다.
            self.navigationController?.popViewController(animated: true)
        }
        
        let cancelAction: UIAlertAction = UIAlertAction(title: "취소", style: .cancel, handler: nil)
        
        alertController.addAction(removeAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
    }
    
    
    @objc private func handleEdit() {
        guard let viewModel = viewModel else { return }
        viewModel.startEditing()
        updateSubviews()
        diaryTextView.becomeFirstResponder()    // 키보드 올리기
    }
    
    @objc private func handleSave() {
        guard
            let viewModel = viewModel,
            let text = diaryTextView.text else { return }
        
        viewModel.completeEditing(with: text)
        
        let alertController = UIAlertController(title: "저장 되었습니다.",
                                                message: nil,
                                                preferredStyle: .alert)
        
        present(alertController, animated: true) { [weak self] in
            guard let self = self else { return }
            self.dismiss(animated: true, completion: nil)
        }
        
        updateSubviews()
        diaryTextView.resignFirstResponder()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    @objc private func handleKeyboardAppear(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let keyboardFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as?
                NSValue),
            let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as?
                TimeInterval),
            let curve = (userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as?
                UInt)
            else { return }
        
        let isKeyboardWillShow: Bool = notification.name == UIResponder.keyboardWillShowNotification
        let keyboardHeight = isKeyboardWillShow
            ? keyboardFrame.cgRectValue.height
            : 0
        let animationOption = UIView.AnimationOptions.init(rawValue: curve)
        
        UIView.animate(
            withDuration:  duration,
            delay: 0.0,
            options: animationOption,
            animations: {
                self.diaryTextViewBottomConstraint?.constant = -keyboardHeight
                self.view.layoutIfNeeded()
        },
            completion: nil)
    }
    
    // 뷰모델에 따라 UI 업데이트
    private func updateSubviews() {
        guard let viewModel = viewModel else { return }
        saveEditButton.image = viewModel.saveEditButtonImage
        saveEditButton.target = self
        saveEditButton.action = viewModel.isEditing
            ? #selector(handleSave)
            : #selector(handleEdit)
        removeButton.isEnabled = viewModel.removeButtonEnabled
        diaryTextView.isEditable = viewModel.diaryTextViewEditable
    }
    
    private func setupNavigationBarItems() {
        removeButton.image = #imageLiteral(resourceName: "baseline_delete_black_24pt")
        removeButton.style = .plain
        removeButton.target = self
        removeButton.action = #selector(handleRemove)
        
        navigationItem.rightBarButtonItems = [
            removeButton,
            saveEditButton
        ]
    }
}

// MARK:- Regarding Gesture Recognizer
extension DiaryController: UIGestureRecognizerDelegate {
    // view 를 탭하면 키보드를 내린다.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        self.view.endEditing(true)
        return true
    }
}