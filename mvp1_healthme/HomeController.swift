//
//  HomeController.swift
//  gameofchats
//
//  Created by Paula on 25-06-20.
//  Copyright © 2020 letsbuildthatapp. All rights reserved.
//

import UIKit
import Firebase

class HomeController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(r: 61, g: 91, b: 151)
        
        let image = UIImage(named: "new_message_icon")
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(handleChatbot))
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Logout", style: .plain, target: self, action: #selector(handleLogout))
        
        checkIfUserIsLoggedIn()

        
    }
    
    @objc func handleChatbot() {
        let chatbotController = ChatbotController(collectionViewLayout: UICollectionViewFlowLayout())
        navigationController?.pushViewController(chatbotController, animated: true)
    }
    
    @objc func handleLogout() {

        do {
            try Auth.auth().signOut()
        } catch let logoutError {
            print(logoutError)
        }

        let loginController = LoginController()
        present(loginController, animated: true, completion: nil)
    }
    
    func checkIfUserIsLoggedIn() {
            if Auth.auth().currentUser?.uid == nil {
                perform(#selector(handleLogout), with: nil, afterDelay: 0)
            } else {
                print("is logged in")
            }
        }
    
}
