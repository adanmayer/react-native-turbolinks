import WebKit
import Turbolinks

@objc(RNTurbolinksManager)
class RNTurbolinksManager: RCTEventEmitter {
    
    var tabBarController: TabBarController!
    var navigationController: NavigationController!
    var titleTextColor: UIColor?
    var subtitleTextColor: UIColor?
    var barTintColor: UIColor?
    var tintColor: UIColor?
    var tabBarBarTintColor: UIColor?
    var tabBarTintColor: UIColor?
    var tabBarBadgeColor: UIColor?
    var messageHandler: String?
    var userAgent: String?
    var customMenuIcon: UIImage?
    var loadingView: String?    
    lazy var processPool = WKProcessPool()
    fileprivate var _mountView: UIView?
    
    deinit {
        removeFromRootViewController()
    }
    
    var application: UIApplication {
        return UIApplication.shared
    }
    
    fileprivate var rootViewController: UIViewController {
        return application.keyWindow!.rootViewController!
    }
    
    fileprivate var navigation: NavigationController {
        return (navigationController ?? tabBarController.selectedViewController) as! NavigationController
    }
    
    fileprivate var session: TurbolinksSession {
        return navigation.session
    }
    
    fileprivate var visibleViewController: UIViewController {
        return navigation.visibleViewController!
    }
    
    @objc func replaceWith(_ route: Dictionary<AnyHashable, Any>,_ tabIndex: Int) {
        let nav = navigationController ?? getNavigationByIndex(tabIndex)
        let visitable = nav.visibleViewController as! WebViewController
        visitable.renderComponent(TurbolinksRoute(route))
    }
    
    @objc func reloadVisitable() {
        let visitable = visibleViewController as! WebViewController
        visitable.reload()
    }
    
    @objc func reloadSession() {
        session.cleanCookies()
        session.injectCookies()
        session.reload()
    }
    
    @objc func dismiss() {
        navigation.dismiss(animated: true)
    }
    
    @objc func popToRoot() {
        navigation.popToRootViewController(animated: true)
    }
    
    @objc func back() {
        navigation.popViewController(animated: true)
    }
    
    fileprivate func mountViewController(_ viewController: UIViewController) {
        removeFromRootViewController() // remove existing childViewController, in case of debug reloading...
        addToRootViewController(viewController)
    }
    
    @objc func startSingleScreenApp(_ route: Dictionary<AnyHashable, Any>,_ options: Dictionary<AnyHashable, Any>) {
        setAppOptions(options)
        navigationController = NavigationController(self, route, 0)
        mountViewController(navigationController)
        self.injectCookies {
            self.visit(route)
        }
    }
    
    @objc func startTabBasedApp(_ routes: Array<Dictionary<AnyHashable, Any>> ,_ options: Dictionary<AnyHashable, Any> ,_ selectedIndex: Int) {
        setAppOptions(options)
        tabBarController = TabBarController()
        tabBarController.viewControllers = routes.enumerated().map { (index, route) in NavigationController(self, route, index) }
        tabBarController.tabBar.barTintColor = tabBarBarTintColor ?? tabBarController.tabBar.barTintColor
        tabBarController.tabBar.tintColor = tabBarTintColor ?? tabBarController.tabBar.tintColor
        mountViewController(tabBarController)
        self.injectCookies {
            self.visitTabRoutes(routes)
        }
        tabBarController.selectedIndex = selectedIndex
    }
    
    @objc func startAppInView(_ reactTag: NSNumber!, _ route: Dictionary<AnyHashable, Any>,_ options: Dictionary<AnyHashable, Any>) {
        let manager:RCTUIManager =  self.bridge.uiManager!
        
        // we have to exec on methodQueue
        manager.methodQueue.async {
            manager.addUIBlock { (uiManager: RCTUIManager?, viewRegistry:[NSNumber : UIView]?) in
                self._mountView = uiManager!.view(forReactTag: reactTag)
                self.startSingleScreenApp(route, options)
                self._mountView = nil // reset mount view
            }
        }
    }
    
    @objc func setCookies(_ cookies: Dictionary<AnyHashable, Any>, _ url: String) {
        var cookieArray: [HTTPCookie] = []
        for key in cookies.keys {
            let values:Dictionary<AnyHashable, String> = RCTConvert.nsDictionary(cookies[key])! as! Dictionary<AnyHashable, String>
            let cookie = HTTPCookie(properties: [
                .domain: values["domain"]! as String,
                .path: "/",
                .name: key,
                .value: values["value"]! as String,
                .secure: "TRUE",
                .discard: "FALSE",
                .expires:  Date.init(timeIntervalSinceNow:3600 * 365), // 1 year in the future
                .version: 1
                ])!
            cookieArray.append(cookie)
        }
        let cookies = HTTPCookieStorage.shared.cookies(for: URL.init(string: url)!) ?? []
        for (cookie) in cookies {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
        HTTPCookieStorage.shared.setCookies(cookieArray, for: URL.init(string: url)!, mainDocumentURL: nil)
    }

    @objc func visit(_ route: Dictionary<AnyHashable, Any>) {
        let tRoute = TurbolinksRoute(route)
        if tRoute.url != nil {
            presentVisitableForSession(tRoute)
        } else {
            presentNativeView(tRoute)
        }
    }
    
    @objc func renderTitle(_ title: String,_ subtitle: String,_ tabIndex: Int) {
        let nav = navigationController ?? getNavigationByIndex(tabIndex)
        guard let visitable = nav.visibleViewController as? GenricViewController else { return }
        visitable.route.title = title
        visitable.route.subtitle = subtitle
        visitable.renderTitle()
    }
    
    @objc func renderActions(_ actions: Array<Dictionary<AnyHashable, Any>>,_ tabIndex: Int) {
        let nav = navigationController ?? getNavigationByIndex(tabIndex)
        guard let visitable = nav.visibleViewController as? GenricViewController else { return }
        visitable.route.actions = actions
        visitable.renderActions()
    }
    
    @objc func evaluateJavaScript(_ script: String,_ tabIndex: Int,_ resolve: @escaping RCTPromiseResolveBlock,_ reject: @escaping RCTPromiseRejectBlock) {
        let nav = navigationController ?? getNavigationByIndex(tabIndex)
        nav.session.webView.evaluateJavaScript(script) {(result, error) in
            if error != nil {
                reject("js_error", error!.localizedDescription, error)
            } else {
                resolve(result)
            }
        }
    }
    
    @objc func notifyTabItem(_ value: String?,_ tabIndex: Int) {
        let tabItem = tabBarController.tabBar.items![tabIndex]
        tabItem.badgeValue = value
    }

    fileprivate func injectCookies(_ completionHandler: (() -> Swift.Void)? = nil) {
        // Force the creation of the datastore, before injecting cookies.
        // issue introduced in iOS 11.3 see thread here: https://forums.developer.apple.com/thread/99674
        
        // delete cookies
        let dataStore = self.navigation.session.webView.configuration.websiteDataStore
        dataStore.fetchDataRecords(ofTypes: [WKWebsiteDataTypeCookies], completionHandler: { (records) -> Void in
            dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { (records) in
                // first remove all cookies
                dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: records, completionHandler: {

                    // after removing data we have to wait a little until we can add new stuff
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        let cookies = HTTPCookieStorage.shared.cookies ?? []
                        for (cookie) in cookies {
                            if #available(iOS 11.0, *) {
                                dataStore.httpCookieStore.setCookie(cookie)
                            }
                        }
                        
                        // finished removing and adding cookies
                        DispatchQueue.main.async {
                            if (completionHandler != nil) {
                                completionHandler!()
                            }
                        }
                    }
                })
            }
        })
    }
   
    fileprivate func presentVisitableForSession(_ route: TurbolinksRoute) {
        let visitable = WebViewController(self, route)
        if route.action == .Advance {
            navigation.pushViewController(visitable, animated: true)
        } else if route.action == .Replace {
            if navigation.isAtRoot {
                navigation.setViewControllers([visitable], animated: false)
            } else {
                navigation.popViewController(animated: false)
                navigation.pushViewController(visitable, animated: false)
            }
        }
        session.visit(visitable)
    }
    
    fileprivate func presentNativeView(_ route: TurbolinksRoute) {
        let viewController = NativeViewController(self, route)
        if route.modal {
            navigation.present(viewController, animated: true)
        } else if route.action == .Advance {
            navigation.pushViewController(viewController, animated: true)
        } else if route.action == .Replace {
            if navigation.isAtRoot {
                navigation.setViewControllers([viewController], animated: false)
            } else {
                navigation.popViewController(animated: false)
                navigation.pushViewController(viewController, animated: false)
            }
        }
    }
    
    fileprivate func getNavigationByIndex(_ index: Int) -> NavigationController {
        return tabBarController.viewControllers![index] as! NavigationController
    }
    
    fileprivate func setAppOptions(_ options: Dictionary<AnyHashable, Any>) {
        self.userAgent = RCTConvert.nsString(options["userAgent"])
        self.messageHandler = RCTConvert.nsString(options["messageHandler"])
        self.loadingView = RCTConvert.nsString(options["loadingView"])
        if (options["navBarStyle"] != nil) { setNavBarStyle(RCTConvert.nsDictionary(options["navBarStyle"])) }
        if (options["tabBarStyle"] != nil) { setTabBarStyle(RCTConvert.nsDictionary(options["tabBarStyle"])) }
    }
    
    fileprivate func setNavBarStyle(_ style: Dictionary<AnyHashable, Any>) {
        barTintColor = RCTConvert.uiColor(style["barTintColor"])
        tintColor = RCTConvert.uiColor(style["tintColor"])
        titleTextColor = RCTConvert.uiColor(style["titleTextColor"])
        subtitleTextColor = RCTConvert.uiColor(style["subtitleTextColor"])
        customMenuIcon = RCTConvert.uiImage(style["menuIcon"])
    }
    
    fileprivate func setTabBarStyle(_ style: Dictionary<AnyHashable, Any>) {
        tabBarBarTintColor = RCTConvert.uiColor(style["barTintColor"])
        tabBarTintColor = RCTConvert.uiColor(style["tintColor"])
        tabBarBadgeColor = RCTConvert.uiColor(style["badgeColor"])
    }
    
    fileprivate func visitTabRoutes(_ routes: Array<Dictionary<AnyHashable, Any>>) {
        for (index, route) in routes.enumerated() {
            tabBarController.selectedIndex = index
            visit(route)
        }
    }
    
    fileprivate func addToRootViewController(_ viewController: UIViewController) {
        rootViewController.addChildViewController(viewController)
        if (_mountView != nil) {
            _mountView!.addSubview(viewController.view)
        } else {
            rootViewController.view.addSubview(viewController.view)
        }
    }
    
    fileprivate func removeFromRootViewController() {
        var viewController: UIViewController?
        rootViewController.childViewControllers.forEach { (child) in
            if (child is NavigationController) || (child is TabBarController) {
                viewController = child
            }
        }
        
        if let vc = viewController {
            vc.view.removeFromSuperview()
            vc.removeFromParentViewController()
        }
    }
    
    func handleTitlePress(_ URL: URL?,_ component: String?) {
        sendEvent(withName: "turbolinksTitlePress", body: ["url": URL?.absoluteString, "path": URL?.path, "component": component])
    }
    
    func handleActionPress(_ actionId: Int) {
        sendEvent(withName: "turbolinksActionPress", body: actionId)
    }
    
    func handleLeftButtonPress(_ URL: URL?,_ component: String?) {
        sendEvent(withName: "turbolinksLeftButtonPress", body: ["url": URL?.absoluteString, "path": URL?.path, "component": component])
    }
    
    func handleRightButtonPress(_ URL: URL?,_ component: String?) {
        sendEvent(withName: "turbolinksRightButtonPress", body: ["url": URL?.absoluteString, "path": URL?.path, "component": component])
    }
    
    func handleVisitCompleted(_ URL: URL,_ tabIndex: Int) {
        sendEvent(withName: "turbolinksVisitCompleted", body: ["url": URL.absoluteString, "path": URL.path, "tabIndex": tabIndex])
    }
    
    override static func requiresMainQueueSetup() -> Bool {
        return true;
    }
    
    override var methodQueue: DispatchQueue {
        return DispatchQueue.main
    }
    
    override func constantsToExport() -> [AnyHashable: Any]! {
        return [
            "ErrorCode": [
                "httpFailure": ErrorCode.httpFailure.rawValue,
                "networkFailure": ErrorCode.networkFailure.rawValue,
            ],
            "Action": [
                "advance": Action.Advance.rawValue,
                "replace": Action.Replace.rawValue,
                "restore": Action.Restore.rawValue,
            ]
        ]
    }
    
    override func supportedEvents() -> [String]! {
        return ["turbolinksVisit", "turbolinksMessage", "turbolinksError", "turbolinksTitlePress", "turbolinksActionPress", "turbolinksLeftButtonPress", "turbolinksRightButtonPress", "turbolinksVisitCompleted"]
    }
}

extension RNTurbolinksManager: SessionDelegate {
    func session(_ session: Session, didProposeVisitToURL URL: URL, withAction action: Action) {
        sendEvent(withName: "turbolinksVisit", body: ["url": URL.absoluteString, "path": URL.path, "action": action.rawValue])
    }
    
    func session(_ session: Session, didFailRequestForVisitable visitable: Visitable, withError error: NSError) {
        let session = session as! TurbolinksSession
        sendEvent(withName: "turbolinksError", body: ["code": error.code, "statusCode": error.userInfo["statusCode"] ?? 0, "description": error.localizedDescription, "tabIndex": session.index])
    }
    
    func sessionDidStartRequest(_ session: Session) {
        application.isNetworkActivityIndicatorVisible = true
    }
    
    func sessionDidFinishRequest(_ session: Session) {
        application.isNetworkActivityIndicatorVisible = false
    }
}

extension RNTurbolinksManager: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let message = message.body as? String { sendEvent(withName: "turbolinksMessage", body: message) }
    }
}
