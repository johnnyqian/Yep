//
//  BlackListViewController.swift
//  Yep
//
//  Created by nixzhu on 15/8/24.
//  Copyright (c) 2015年 Catch Inc. All rights reserved.
//

import UIKit
import YepKit
import YepConfig
import RealmSwift

final class BlackListViewController: BaseViewController {

    @IBOutlet private weak var blockedUsersTableView: UITableView!
    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!

    private let cellIdentifier = "ContactsCell"

    private var blockedUsers: [DiscoveredUser] = [] {
        willSet {
            if newValue.count == 0 {
                blockedUsersTableView.tableFooterView = InfoView(NSLocalizedString("No blocked users.", comment: ""))
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("Blocked Users", comment: "")

        blockedUsersTableView.separatorColor = UIColor.yepCellSeparatorColor()
        blockedUsersTableView.separatorInset = YepConfig.ContactsCell.separatorInset

        blockedUsersTableView.registerNib(UINib(nibName: cellIdentifier, bundle: nil), forCellReuseIdentifier: cellIdentifier)
        blockedUsersTableView.rowHeight = 80
        blockedUsersTableView.tableFooterView = UIView()


        activityIndicator.startAnimating()

        blockedUsersByMe(failureHandler: { [weak self] reason, errorMessage in
            dispatch_async(dispatch_get_main_queue()) {
                self?.activityIndicator.stopAnimating()
            }

            YepAlert.alertSorry(message: NSLocalizedString("Netword Error: Faild to get blocked users!", comment: ""), inViewController: self)

        }, completion: { blockedUsers in
            dispatch_async(dispatch_get_main_queue()) { [weak self] in
                self?.activityIndicator.stopAnimating()

                self?.blockedUsers = blockedUsers
                self?.blockedUsersTableView.reloadData()
            }
        })
    }

    // MARK: Navigation

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {

        guard let identifier = segue.identifier else {
            return
        }

        switch identifier {

        case "showProfile":
            let vc = segue.destinationViewController as! ProfileViewController

            if let discoveredUser = (sender as? Box<DiscoveredUser>)?.value {
                vc.profileUser = .DiscoveredUserType(discoveredUser)
            }

            vc.hidesBottomBarWhenPushed = true

            vc.setBackButtonWithTitle()
            
        default:
            break
        }
    }
}

extension BlackListViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return blockedUsers.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier) as! ContactsCell

        cell.selectionStyle = .None

        let discoveredUser = blockedUsers[indexPath.row]

        cell.configureWithDiscoveredUser(discoveredUser)

        return cell
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {

        defer {
            tableView.deselectRowAtIndexPath(indexPath, animated: true)
        }

        let discoveredUser = blockedUsers[indexPath.row]
        performSegueWithIdentifier("showProfile", sender: Box<DiscoveredUser>(discoveredUser))
    }

    // Edit (for Unblock)

    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }

    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {

        if editingStyle == .Delete {

            let discoveredUser = blockedUsers[indexPath.row]

            unblockUserWithUserID(discoveredUser.id, failureHandler: nil, completion: { success in
                println("unblockUserWithUserID \(success)")

                dispatch_async(dispatch_get_main_queue()) { [weak self] in

                    guard let realm = try? Realm() else {
                        return
                    }

                    if let user = userWithUserID(discoveredUser.id, inRealm: realm) {
                        let _ = try? realm.write {
                            user.blocked = false
                        }
                    }

                    if let strongSelf = self {
                        if let index = strongSelf.blockedUsers.indexOf(discoveredUser)  {

                            strongSelf.blockedUsers.removeAtIndex(index)

                            let indexPathToDelete = NSIndexPath(forRow: index, inSection: 0)
                            strongSelf.blockedUsersTableView.deleteRowsAtIndexPaths([indexPathToDelete], withRowAnimation: .Automatic)
                        }
                    }
                }
            })
        }
    }

    func tableView(tableView: UITableView, titleForDeleteConfirmationButtonForRowAtIndexPath indexPath: NSIndexPath) -> String? {
        return NSLocalizedString("Unblock", comment: "")
    }
}

