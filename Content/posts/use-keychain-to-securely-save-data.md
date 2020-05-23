---
date: 2020-05-23 9:41
title: Use Keychain to securely save data
description: Save an item in keychain without a third party framework
tags: Swift, iOS, Keychain
typora-copy-images-to: ../../Resources/images
typora-root-url: ../../Resources
---

If you need to save sensible information like a user password in an iOS app you should use Keychain instead of UserDefaults. While the UserDefaults-API is user-friendly and straight forward the Keychain-API is not. It took me a while to find some information because nearly everyone suggested to use a third-party-framework and I ended up with downloading [SwiftKeyChainWrapper](https://github.com/jrendel/SwiftKeychainWrapper), too.

But still I want to be able to save data into Keychain without a third-party solution. So I used the library as documentation.

## Save a string to the Keychain

```Swift
import Foundation

struct KeyChain {
    static private func getQueryDict() -> [String:Any] {
        var keyChainQueryDict: [String:Any] = [kSecClass as String:kSecClassGenericPassword]
        keyChainQueryDict[kSecAttrService as String] = "MyService"
        return keyChainQueryDict
    }

    static func save(_ message: String) {
        if let data = message.data(using: .utf8) {
            var keyChainQueryDict = getQueryDict()

            keyChainQueryDict[kSecValueData as String] = data
            keyChainQueryDict[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked

            let status: OSStatus = SecItemAdd(keyChainQueryDict as CFDictionary, nil)

            if status == errSecSuccess {
                print("Message saved")
            } else if status == errSecDuplicateItem {
                update(message)
            } else {
                print(SecCopyErrorMessageString(status, nil) ?? "Unknown error")
            }
        }
    }
}
```

You add an Item to the KeyChain with the function `SecItemAdd(_ attributes: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus`.

So you pass in a dictionary and receive a result code. If the result code equals `errSecSuccess` you're golden! `errSecDuplicateItem` tells you that an entry for the key you provided already exists.

So how do you pass in the key and the data? It's all in the query dictionary. The first entry `[kSecClass as String:kSecClassGenericPassword]` tells the system that you want to save a generic password. Other options would be a `kSecClassInternetPassword` or a `kSecClassIdentity` and there're even more. The other required keys for the dictionary depend on the type you choose here.

For the generic password I declared a service specifier `kSecAttrService` with the value `"MyService"`. By the way since all these keys are CFStrings you need to cast them to a Swift String.

With the key `kSecValueData` you pass in the `Data` that you want to be saved. The key `kSecAttrAccessible` is used to specify when an item can be retrieved from the secure store. In the case of `kSecAttrAccessibleWhenUnlocked` we can receive the item when the device is unlocked. Other possible values are:

- `kSecAttrAccessibleAfterFirstUnlock` Item data can only be accessed once the device has been unlocked after a restart. This is recommended for items that need to be accesible by background applications. Items with this attribute will migrate to a new device when using encrypted backups.
- `kSecAttrAccessibleAlways` Item data can always be accessed regardless of the lock state of the device. This is not recommended for anything except system use. Items with this attribute will migrate to a new device when using encrypted backups.
- `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` Item data can only be accessed while the device is unlocked. This is recommended for items that only need to be accessible while the application is in the foreground and requires a passcode to be set on the device. Items with this attribute will never migrate to a new device, so after a backup is restored to a new device, these items will be missing. This attribute will not be available on devices without a passcode. Disabling the device passcode will cause all previously protected items to be deleted.
- `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` Item data can only be accessed while the device is unlocked. This is recommended for items that only need be accessible while the application is in the foreground. Items with this attribute will never migrate to a new device, so after a backup is restored to a new device, these items will be missing.
- `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` Item data can only be accessed once the device has been unlocked after a restart. This is recommended for items that need to be accessible by background applications. Items with this attribute will never migrate to a new device, so after a backup is restored to a new device these items will be missing.
- `kSecAttrAccessibleAlwaysThisDeviceOnly` Item data can always be accessed regardless of the lock state of the device. This option is not recommended for anything except system use. Items with this attribute will never migrate to a new device, so after a backup is restored to a new device, these items will be missing.

So after the dictionary is properly configured we can call `SecItemAdd` and by this save an item in the Keychain. That's all there is to it 😎

## Update an item in the Keychain

If the key for your item already exists you'll receive `errSecDuplicateItem` as the result of callling `SecItemAdd`. You can update your item like this:

```Swift
    static func update(_ message: String) {
        if let data = message.data(using: .utf8) {
            let keyChainQueryDict = getQueryDict()

            let updateDict = [kSecValueData:data]

            let status: OSStatus = SecItemUpdate(keyChainQueryDict as CFDictionary, updateDict as CFDictionary)

            if status == errSecSuccess {
                print("Entry updated.")
            } else {
                print(SecCopyErrorMessageString(status, nil) ?? "Unknown error")
            }
        }
    }
```

So now we need a second dictionary since calling `SecItemUpdate`requires us to provide two dictionaries as parameter. The second just contains the data that we want to update for the key `kSecValueData`.

## Reading an item from the Keychain

```Swift
static func load() -> String? {
        var keyChainQueryDict = getQueryDict()

        keyChainQueryDict[kSecMatchLimit as String] = kSecMatchLimitOne
        keyChainQueryDict[kSecReturnData as String] = kCFBooleanTrue

        var result: AnyObject?
        let status = SecItemCopyMatching(keyChainQueryDict as CFDictionary, &result)

        if status == noErr {
            if let data = result as? Data {
                return String(data: data, encoding: .utf8)
            } else {
                print("Could not retrieve data")
            }
        } else {
            print(SecCopyErrorMessageString(status, nil) ?? "Unknown error")
        }

        return nil
    }
```

The function `SecItemCopyMatching(_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus` copies an Item into its second parameter if the item matches the query dictionary passed in the first parameter. The query dictionary is configured to return only one item and return it as `Data`. This is configured with the keys `kSecMatchLimit` and `kSecReturnData`. If the operations succeeded you can cast the result object to data and build the String you originally saved from it.

So after looking into this I would suggest you simply use [SwiftKeyChainWrapper](https://github.com/jrendel/SwiftKeychainWrapper) like everyone else suggests 😃

