import UIKit
import Flutter
import Quickblox

// To update the QuickBlox credentials, please see the READMe file.(You must create application in admin.quickblox.com)
struct CredentialsConstant {
    static let applicationID:UInt = 77430
    static let authKey = "fDEZ4a2t6OyTEY9"
    static let authSecret = "dnBQmDfn-q-DNnR"
    static let accountKey = "2MsAAseyLd62sFeZB78Y"
}

enum ErrorDomain: UInt {
    case signUp
    case logIn
    case logOut
    case chat
}

struct LoginConstant {
    static let notSatisfyingDeviceToken = "Invalid parameter not satisfying: deviceToken != nil"
    static let enterToChat = NSLocalizedString("Enter to chat", comment: "")
    static let fullNameDidChange = NSLocalizedString("Full Name Did Change", comment: "")
    static let login = NSLocalizedString("Login", comment: "")
    static let checkInternet = NSLocalizedString("Please check your Internet connection", comment: "")
    static let enterUsername = NSLocalizedString("Please enter your login and username.", comment: "")
    static let shouldContainAlphanumeric = NSLocalizedString("Field should contain alphanumeric characters only in a range 3 to 20. The first character must be a letter.", comment: "")
    static let shouldContainAlphanumericWithoutSpace = NSLocalizedString("Field should contain alphanumeric characters only in a range 8 to 15, without space. The first character must be a letter.", comment: "")
    static let showDialogs = "ShowDialogsViewController"
    static let defaultPassword = "testuserpassword"
    static let infoSegue = "ShowInfoScreen"
}


@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    private let chatManager = ChatManager.instance
    private var dialog: QBChatDialog!
    
    private var dialogs: [QBChatDialog] = []
    private var messages: [QBChatMessage] = []

    private var channel: FlutterMethodChannel? = nil
    let userDefaults = UserDefaults.standard

    //MARK: - Properties
    private lazy var dataSource: ChatDataSource = {
        let dataSource = ChatDataSource()
//        dataSource.delegate = self as! ChatDataSourceDelegate
        return dataSource
    }()
    
    private var user: QBUUser? = nil
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?
        ) -> Bool {
        
        application.applicationIconBadgeNumber = 0
        window?.backgroundColor = .white;
        // Set QuickBlox credentials (You must create application in admin.quickblox.com).
        QBSettings.applicationID = CredentialsConstant.applicationID
        QBSettings.authKey = CredentialsConstant.authKey
        QBSettings.authSecret = CredentialsConstant.authSecret
        QBSettings.accountKey = CredentialsConstant.accountKey
        // enabling carbons for chat
        QBSettings.carbonsEnabled = true
        // Enables Quickblox REST API calls debug console output.
        QBSettings.logLevel = .debug
        // Enables detailed XMPP logging in console output.
        QBSettings.enableXMPPLogging()
        
        print("print test")
        login(fullName: "", login: "testuserlogin10")
        
        let controller = window?.rootViewController as! FlutterViewController

        channel = FlutterMethodChannel(name: "quickbloxbridge", binaryMessenger: controller)
        channel?.setMethodCallHandler({
            (call: FlutterMethodCall, result: FlutterResult) -> Void in
            // TODO : Put switch case here
            
            guard call.method == "getChatMessageEntered" else {
                result(FlutterMethodNotImplemented)
                return
            }
            self.receiveBatteryLevel(result: result)
        })

        GeneratedPluginRegistrant.register(with: self)
        return true
    }
    
    private func receiveBatteryLevel(result: FlutterResult) {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        if device.batteryState == UIDeviceBatteryState.unknown {
            result(FlutterError(code: "Unavailable", message: "Battery info unavailable", details: nil))
        } else {
            result(Int(device.batteryLevel * 100))
        }
    }
    
    override func applicationDidEnterBackground(_ application: UIApplication) {
        application.applicationIconBadgeNumber = 0
        // Logging out from chat.
        ChatManager.instance.disconnect()
    }
    
    override func applicationWillEnterForeground(_ application: UIApplication) {
        // Logging in to chat.
        print("Inside one")
        ChatManager.instance.connect { (error) in
            if let error = error {
//                SVProgressHUD.showError(withStatus: error.localizedDescription)
                return
            }
        }
    }
    
    override func applicationWillTerminate(_ application: UIApplication) {
        // Logging out from chat.
        ChatManager.instance.disconnect()
    }
    
    override func applicationDidFinishLaunching(_ application: UIApplication) {
        // Logging in to chat.
        print("Inside Two")

    }
    
    private func login(fullName: String, login: String, password: String = LoginConstant.defaultPassword) {
//        beginConnect()
        QBRequest.logIn(withUserLogin: login,
                        password: password,
                        successBlock: { [weak self] response, user in
                            guard let self = self else {
                                return
                            }
                            
                            user.password = password
                            Profile.synchronize(user)
                            
                            self.user = user

                            
//                            if user.fullName != fullName {
//                                self.updateFullName(fullName: fullName, login: login)
//                            } else {
                                self.connectToChat(user: user)
//                            }
                            
            }, errorBlock: { [weak self] response in
                self?.handleError(response.error?.error, domain: ErrorDomain.logIn)
                if response.status == QBResponseStatusCode.unAuthorized {
                    // Clean profile
                    Profile.clearProfile()
                    self?.defaultConfiguration()
                }
        })
    }
    
    /**
     *  connectToChat
     */
    private func connectToChat(user: QBUUser) {
//        infoText = LoginStatusConstant.intoChat
        QBChat.instance.connect(withUserID: user.id,
                                password: LoginConstant.defaultPassword,
                                completion: { [weak self] error in
                                    guard let self = self else { return }
                                    if let error = error {
                                        if error._code == QBResponseStatusCode.unAuthorized.rawValue {
                                            // Clean profile
                                            Profile.clearProfile()
                                            self.defaultConfiguration()
                                        } else {
                                            self.handleError(error, domain: ErrorDomain.logIn)
                                        }
                                    } else {
                                        
//                                        self.chatManager.delegate = self as? ChatManagerDelegate
                                        if QBChat.instance.isConnected == true {
                                            self.chatManager.updateStorage(){ result in
                                                self.dialogs = self.chatManager.storage.dialogsSortByUpdatedAt()
                                                self.dialog = self.dialogs[1]

                                                var dialogID: String! =  self.dialog.id
                                                self.loadMessages(dialogID: dialogID)

                                                print("Inside the Connect to chat " + dialogID)
                                            }
                                        }

//                                        self.registerForRemoteNotifications()
//                                        //did Login action
//                                        self.performSegue(withIdentifier: LoginConstant.showDialogs, sender: nil)
                                    }
        })
    }
    
    private func loadMessages(dialogID: String, with skip: Int = 0) {
//        QBChat.instance.addDelegate(self as! QBChatDelegate)
        chatManager.messages(withID: dialogID, skip: skip, successCompletion: { [weak self] (messages, cancel) in
//            self?.cancel = cancel
            self?.dataSource.addMessages(messages)
            self?.messages = messages
            self?.sendToFlutterChatHistory()
//            SVProgressHUD.dismiss()
            }, errorHandler: { [weak self] (error) in
                if error == ChatManagerConstant.notFound {
//                    self?.dataSource.clear()
//                    self?.dialog.clearTypingStatusBlocks()
//                    self?.inputToolbar.isUserInteractionEnabled = false
//                    self?.collectionView.isScrollEnabled = false
//                    self?.collectionView.reloadData()
//                    self?.title = ""
//                    self?.navigationItem.rightBarButtonItem?.isEnabled = false
                }
//                SVProgressHUD.showError(withStatus: error)
        })
    }
    
    private func sendToFlutterChatHistory() {
        var hashMapArguments = [String : Any]()

        var arrayMessage = [String]()
        var isMessageCurrentUserArray = [Bool]()

//        guard let decodedUser  = userDefaults.object(forKey: UserProfileConstant.curentProfile) as? Data,
//            let user = NSKeyedUnarchiver.unarchiveObject(with: decodedUser) as? QBUUser else {
//        }
        
        for qbMessage in self.messages {
            arrayMessage.append(qbMessage.text!)
            
            var isMessageOfCurrentUser = false
            if(qbMessage.senderID == self.user?.id) {
                isMessageOfCurrentUser = true
            }
            
            isMessageCurrentUserArray.append(isMessageOfCurrentUser)
        }
        
        hashMapArguments["messageList"] = arrayMessage
        hashMapArguments["isCurrentUserMessage"] = isMessageCurrentUserArray
        
        print(self.messages[0].text ?? "")
//        self.channel?.invokeMethod("getChatHistory", arguments: <#T##Any?#>)
        
        self.channel?.invokeMethod("getChatHistory", arguments: hashMapArguments)
    }
    
    // MARK: - Handle errors
    private func handleError(_ error: Error?, domain: ErrorDomain) {
        guard let error = error else {
            return
        }
        var infoText = error.localizedDescription
        if error._code == NSURLErrorNotConnectedToInternet {
            infoText = LoginConstant.checkInternet
        }
//        inputEnabled = true
//        loginButton.hideLoading()
//        validate(userNameTextField)
//        validate(loginTextField)
//        loginButton.isEnabled = isValid(userName: userNameTextField.text) && isValid(login: loginTextField.text)
//        self.infoText = infoText
    }
    
    //MARK - Setup
    private func defaultConfiguration() {
//        loginButton.hideLoading()
//        loginButton.setTitle(LoginConstant.login, for: .normal)
//        loginButton.isEnabled = false
//        userNameTextField.text = ""
//        loginTextField.text = ""
//        inputEnabled = true
//
        //MARK: - Reachability
        let updateLoginInfo: ((_ status: NetworkConnectionStatus) -> Void)? = { [weak self] status in
            let notConnection = status == .notConnection
//            let loginInfo = notConnection ? LoginConstant.checkInternet : LoginConstant.enterUsername
//            self?.infoText = loginInfo
        }
        
        Reachability.instance.networkStatusBlock = { status in
            updateLoginInfo?(status)
        }
        updateLoginInfo?(Reachability.instance.networkConnectionStatus())
    }
    
}
