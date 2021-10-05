---
date: 2021-08-17 9:41
title: BikeRR
description: Bike Ride Recorder - An automatic trip recorder
tags: bike, car, app, trip
typora-copy-images-to: ../../Resources/images
typora-root-url: ../../Resources
---

# BikeRR - Automatic Trip Recorder

![BikeRR](/images/BikeRR.png)

[AppStore](https://apps.apple.com/us/app/bikerr/id1563573465)

### What BikeRR does

BikeRR sets up a geofence or region monitor (a 100m circle) around your current location. When you leave that circle the app wakes up and immediatley starts recording location data. It queries the iPhone for your detected motion activity, too. If that motion is cycling (or what you configured it to be) BikeRR will continue to record a trip, if not BikeRR will stop and set up a new region monitor. You don't have to do anything.

### What BikeRR doesn't do
BikeRR does not collect any data about you. Your location data never leaves the device unless you decide to export a trip.

### Quality of Motion Activity Recognition
If you record the automotive activity and have your phone connected to carplay or the like it is super stable. You can sit in a traffic jam all day and the iphone will still "know" with a high confidence that you're driving. Running is a pretty stable state, too. You can adjust the grace period under Settings when you triple tap on the label "Autorecorded Activities".

### Manual Mode
If you want to see a trip saved to the database just triple-tap on the label Location Service. This will start BikeRR in manual mode. CAUTON! This will record forever or until you triple-tap Location Service, again. Wait until BikeRR has collected about 50 locations (you need five more then what you have configured as grace period) before you stop it and then you should have a trip in the trip list.

### Trip List
If you don't see a picture of your trip on a map, please triple tap any information of the trip summary. That will augment the trip with pictures for light and darkmode.

### Contact Information
If you have any questions please contact [me](mailto:oliep@bikerr.app)
