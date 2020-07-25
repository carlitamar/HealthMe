//
//  ChatbotController.swift
//  gameofchats
//
//  Created by Paula on 25-06-20.
//  Copyright © 2020 letsbuildthatapp. All rights reserved.
//

//alias: PedirDrinks

//TODO
//button to end conversation --> delete chatlog information (so when you press the chatbot again, its a new try)
//when chatbot is done (if response = XXX, -->) que aparezca un boton para see el resumen del diagnostico
//resumen de respuestas del paciente y al final el diagnóstico del bot.
//estos "resumen" pueden ser guardados en alguna parte y que se vean en algun table view los datos, y cuando apretas un cell
//te lleva al resumen completo (lo mismo que aparece despues de terminar la conversacion con el chatbot)


import UIKit
import Firebase
import MobileCoreServices
import AVFoundation
import AWSLex

class ChatbotController: UICollectionViewController, UITextFieldDelegate, UICollectionViewDelegateFlowLayout, UINavigationControllerDelegate, AWSLexInteractionDelegate {
        
    var interactionKit: AWSLexInteractionKit?
    
    func setUpLex(){
        self.interactionKit = AWSLexInteractionKit.init(forKey: "chatConfig")
    self.interactionKit?.interactionDelegate = self
    }

    var user: User? {
            didSet {
                observeMessages()
            }
        }
        
    var messages = [Message]()
        
    func observeMessages() {
            let toId = "chatbot"
            guard let uid = Auth.auth().currentUser?.uid else { return }
            
            let userMessagesRef = Database.database().reference().child("chatbot-user-messages").child(uid).child(toId)
            userMessagesRef.observe(.childAdded, with: { (snapshot) in
                
                let messageId = snapshot.key
                let messagesRef = Database.database().reference().child("chatbot-messages").child(messageId)
                messagesRef.observeSingleEvent(of: .value, with: { (snapshot) in
                    
                    guard let dictionary = snapshot.value as? [String: AnyObject] else {
                        return
                    }
                    
                    self.messages.append(Message(dictionary: dictionary))
                    DispatchQueue.main.async(execute: {
                        self.collectionView?.reloadData()
                    })
                    
                }, withCancel: nil)
                
            }, withCancel: nil)
        }

        
    let cellId = "cellId"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Chatbot"
        collectionView?.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        collectionView?.alwaysBounceVertical = true
        collectionView?.backgroundColor = UIColor.white
        collectionView?.register(ChatMessageCell.self, forCellWithReuseIdentifier: cellId)
        collectionView?.keyboardDismissMode = .interactive
        setupKeyboardObservers()
        setUpLex()
        
        observeMessages()
    }
    
    //equivalent of questionTextField
    lazy var inputContainerView: ChatInputContainerView = {
        let chatInputContainerView = ChatInputContainerView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: 50))
        chatInputContainerView.chatbotController = self
        return chatInputContainerView
    }()
    
    override var inputAccessoryView: UIView? {
        get {
            return inputContainerView
        }
    }
    
    override var canBecomeFirstResponder : Bool {
        return true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardDidShow), name: UIResponder.keyboardDidShowNotification, object: nil)
            
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc func handleKeyboardDidShow() {
        if messages.count > 0 {
          let indexPath = IndexPath(item: messages.count - 1, section: 0)
          collectionView?.scrollToItem(at: indexPath, at: .top, animated: true)
        }
    }
    
    @objc func handleKeyboardWillShow(_ notification: Notification) {
        let keyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as AnyObject).cgRectValue
        let keyboardDuration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as AnyObject).doubleValue
        
        containerViewBottomAnchor?.constant = -keyboardFrame!.height
        UIView.animate(withDuration: keyboardDuration!, animations: {
            self.view.layoutIfNeeded()
        })
    }
    
    @objc func handleKeyboardWillHide(_ notification: Notification) {
        let keyboardDuration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as AnyObject).doubleValue
        
        containerViewBottomAnchor?.constant = 0
        UIView.animate(withDuration: keyboardDuration!, animations: {
            self.view.layoutIfNeeded()
        })
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellId, for: indexPath) as! ChatMessageCell
        
        cell.chatbotController = self
        let message = messages[indexPath.item]
        cell.message = message
        cell.textView.text = message.text
        setupCell(cell, message: message)
        let text = message.text
        //a text message
        cell.bubbleWidthAnchor?.constant = estimateFrameForText(text!).width + 32
        cell.textView.isHidden = false
        cell.playButton.isHidden = message.videoUrl == nil
        
        return cell
    }
    
    fileprivate func setupCell(_ cell: ChatMessageCell, message: Message) {
            
        cell.profileImageView.image = UIImage(named: "chatbot")
        
        if message.fromId == Auth.auth().currentUser?.uid {
            //outgoing blue
            cell.bubbleView.backgroundColor = ChatMessageCell.blueColor
            cell.textView.textColor = UIColor.white
            cell.profileImageView.isHidden = true
            
            cell.bubbleViewRightAnchor?.isActive = true
            cell.bubbleViewLeftAnchor?.isActive = false
            
        } else {
            //incoming gray
            cell.bubbleView.backgroundColor = UIColor(r: 240, g: 240, b: 240)
            cell.textView.textColor = UIColor.black
            cell.profileImageView.isHidden = false
            
            cell.bubbleViewRightAnchor?.isActive = false
            cell.bubbleViewLeftAnchor?.isActive = true
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        collectionView?.collectionViewLayout.invalidateLayout()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        var height: CGFloat = 80
        
        let message = messages[indexPath.item]
        let text = message.text
        height = estimateFrameForText(text!).height + 20

        let width = UIScreen.main.bounds.width
        return CGSize(width: width, height: height)
    }
    
    fileprivate func estimateFrameForText(_ text: String) -> CGRect {
        let size = CGSize(width: 200, height: 1000)
        let options = NSStringDrawingOptions.usesFontLeading.union(.usesLineFragmentOrigin)
        return NSString(string: text).boundingRect(with: size, options: options, attributes: convertToOptionalNSAttributedStringKeyDictionary([convertFromNSAttributedStringKey(NSAttributedString.Key.font): UIFont.systemFont(ofSize: 16)]), context: nil)
    }
    
    var containerViewBottomAnchor: NSLayoutConstraint?
    
    @objc func handleSend() {
        let properties = ["text": inputContainerView.inputTextField.text!]
        sendMessageToFirebaseWithProperties(properties as [String : AnyObject])
        sendToLex(text: inputContainerView.inputTextField.text!)
    }
    
    fileprivate func sendMessageToFirebaseWithProperties(_ properties: [String: Any]) {
        let ref = Database.database().reference().child("chatbot-messages")
        let childRef = ref.childByAutoId()
        let toId = "chatbot"
        let fromId = Auth.auth().currentUser!.uid
        let timestamp = Int(Date().timeIntervalSince1970)
        
        var values: [String: Any] = ["toId": toId, "fromId": fromId, "timestamp": timestamp]
        
        properties.forEach({values[$0] = $1})
        
        childRef.updateChildValues(values) { (error, ref) in
            if error != nil {
                print(error!)
                return
            }
            
            self.inputContainerView.inputTextField.text = nil
            
            guard let messageId = childRef.key else { return }
            
            let userMessagesRef = Database.database().reference().child("chatbot-user-messages").child(fromId).child(toId).child(messageId)
            userMessagesRef.setValue(1)
            
            let recipientUserMessagesRef = Database.database().reference().child("chatbot-user-messages").child(toId).child(fromId).child(messageId)
            recipientUserMessagesRef.setValue(1)
        }
    }
    
    fileprivate func sendChatbotMessageToFirebaseWithProperties(_ properties: [String: Any]) {
        let ref = Database.database().reference().child("chatbot-messages")
        let childRef = ref.childByAutoId()
        let toId = Auth.auth().currentUser!.uid
        let fromId = "chatbot"
        let timestamp = Int(Date().timeIntervalSince1970)
        
        var values: [String: Any] = ["toId": toId, "fromId": fromId, "timestamp": timestamp]
        
        properties.forEach({values[$0] = $1})
        
        childRef.updateChildValues(values) { (error, ref) in
            if error != nil {
                print(error!)
                return
            }
            
            self.inputContainerView.inputTextField.text = nil
            
            guard let messageId = childRef.key else { return }
            
            let userMessagesRef = Database.database().reference().child("chatbot-user-messages").child(fromId).child(toId).child(messageId)
            userMessagesRef.setValue(1)
            
            let recipientUserMessagesRef = Database.database().reference().child("chatbot-user-messages").child(toId).child(fromId).child(messageId)
            recipientUserMessagesRef.setValue(1)
        }
    }
    
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        handleSend()
        return true
    }
    
    
    //AWS Lex
    //For Lex error handling, include this delegate function
    func interactionKit(_ interactionKit: AWSLexInteractionKit, onError error: Error) {
        print("interactionKit error: \(error)")
    }
    
    //where we actually send the question to Lex. It takes two paramaters — a String input aka the question and “sessionAttributes” which we set to nil as we don’t need to send any.
    func sendToLex(text : String){
        self.interactionKit?.text(inTextOut: text, sessionAttributes: nil)
    }
    
    //handle incoming message from chatbot (the response)
    func interactionKit(_ interactionKit: AWSLexInteractionKit, switchModeInput: AWSLexSwitchModeInput, completionSource: AWSTaskCompletionSource<AWSLexSwitchModeResponse>?) {
        guard let response = switchModeInput.outputText else {
            let response = "No reply from bot"
            print("Response: \(response)")
            return
        }
    //show response on screen
        DispatchQueue.main.async{
            //self.answerLabel.text = response
            let properties = ["text": response]
            self.sendChatbotMessageToFirebaseWithProperties(properties as [String : AnyObject])
        }
    }

    
// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToOptionalNSAttributedStringKeyDictionary(_ input: [String: Any]?) -> [NSAttributedString.Key: Any]? {
    guard let input = input else { return nil }
    return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSAttributedString.Key(rawValue: key), value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSAttributedStringKey(_ input: NSAttributedString.Key) -> String {
    return input.rawValue
}


}
