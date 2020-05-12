---
date: 2020-02-20 9:41
description:  Use CoreData inside xcframework
tags: Swift, iOS, CoreData, xcframework
---
# How to use CoreData inside xcframework

The company I work for distributes a binary framework that records data on an iPhone. Since I am in charge of that framework and I enjoy working with CoreData I wanted to use it to store the collected data.
Sadly my first attempt of doing this resulted in an error when I tried to use the framework inside an actual app.

> @NSManaged not allowed on computed properties

This is coming from the generated .swiftinterface file so there is not much you can do about it. 
With a little research and some help I found the good news:

[[ModuleInterfaces] Don't diagnose @NSManaged properties with accessors #27676](https://github.com/apple/swift/pull/27676)

So there is a fix 🤗

## Get the fix
At the time of writing all you need to do is to download and use the Xcode beta (11.4) which comes with a newer version of the Swift compiler that already has the fix.
The rest is then pretty straight forward.

## Create the DataModel
You can use File->New and then search for „Data Model“ in the template chooser. I will call it `MyDataModel for demo purpose.

## Create an instance of NSPersistentContainer in your framework code
This might not be obvious at first, but it is not hard. When you create an app with core data you get the following code inside your AppDelegate:

```Swift
lazy var persistentContainer: NSPersistentContainer = {
  let container = NSPersistentContainer(name: "DemoApp")
  container.loadPersistentStores(completionHandler: { (storeDescription, error) in
    if let error = error as NSError? {
      fatalError("Unresolved error \(error), \(error.userInfo)")
    }
  })
  return container
}()
```

While the initializer `init(name: String)` of `NSPersistentContainer` is pretty convenient we can’t use it, because in the context of the running app it simply couldn’t find the model. We need to use `init(name: String, managedObjectModel: NSManagedObjectModel)` to get the container. `NSManagedObjectModel` has an initializer that takes an `URL`.

So update the above to this instead:

```Swift
lazy var persistentContainer: NSPersistentContainer = {
    let modelName = "MyDataModel"
    guard let modelDir = Bundle(for: type(of: self)).url(forResource: modelName, withExtension: "momd") else { fatalError() }
    guard let mom = NSManagedObjectModel(contentsOf: modelDir) else { fatalError() }

    let container = NSPersistentContainer(name: modelName, managedObjectModel: mom)
    container.loadPersistentStores(completionHandler: { (storeDescription, error) in
        if let error = error as NSError? {
            fatalError("Unresolved error \(error), \(error.userInfo)")
        }
    })
    return container
}()
```

## Final
Please be aware, that a CoreData App has a `saveContext` function that gets automatically called by the `SceneDelegate` when the scene enters the background. If you want to use CoreData in a framework I guess you’ll decide when to save by yourself, anyways.

