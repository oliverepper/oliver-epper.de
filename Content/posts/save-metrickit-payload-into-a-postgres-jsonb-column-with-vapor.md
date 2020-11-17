---
date: 2020-07-09 9:41
title: MetricKit and Vapor
description: Save MetricKit payload into a postgres jsonb column with vapor
tags: Swift, Server, Vapor, Fluent
typora-copy-images-to: ../../Resources/images
typora-root-url: ../../Resources
---

I recently learned about MetricKit from Apple and I thought this would be a good fit to learn something about my iOS code in the wild.

Using MetricKit could not be easier. After you conformed to `MXMetricManagerSubscriber` you can add yourself to the `MXMetricManager` 

```Swift
MXMetricManager.shared.add(self)
```

The most obvious place would be the AppDelegate's `didFinishLaunchingWithOptions` function. You can use `applicationWillTerminate` to remove yourself from the MXMetricManager

```Swift
MXMetricManager.shared.remove(self)
```

The only thing that's left is implementing the delegate method:

```Swift
extension AppDelegate: MXMetricManagerSubscriber {
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            let url = URL(string: "https://your.vapor.server/collect")!

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = payload.jsonRepresentation()

            let task = URLSession.shared.dataTask(with: request)
            task.resume()
        }
    }
}
```

All this and more is nicely documented on [NSHipster – MetricKit](https://nshipster.com/metrickit/).

## Vapor

So in Vapor we need a `/collect`-route that takes the payload. The easiest solution would be to build a struct that takes some (or all) of the information from the payload, but I wanted to do the same thing Matt did (in Ruby or JS) and just save the payload in a jsonb-column.

With the help of the really great people in the Vapor-Discord (namely: TypeBeta) I was able to achieve what I wanted with the following model-class

```Swift
import Vapor
import Fluent
import PostgresNIO

struct JsonWrapper: Codable, PostgresDataConvertible {
    let payload: String

    static var postgresDataType: PostgresDataType {
        .jsonb
    }

    init(_ payload: String) {
        self.payload = payload
    }

    init(from decoder: Decoder) throws {
        self.payload = try String.init(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        try payload.encode(to: encoder)
    }

    init?(postgresData: PostgresData) {
        guard let data = postgresData.jsonb else { return nil }
        guard let payload = String(data: data, encoding: .utf8) else { return nil }
        self.init(payload)
    }
    
    var postgresData: PostgresData? {
        guard let jsonString = self.payload.data(using: .utf8) else { return nil }
        return .init(jsonb: jsonString)
    }
}

final class Metric: Model, Content {
    static let schema = "metrics"

    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "payload")
    var payload: JsonWrapper

    init() { }

    init(id: UUID? = nil, payload: JsonWrapper) {
        self.id = id
        self.payload = payload
    }
}
```

In the `Metric`-class the member payload is of type `JsonWrapper`. This type tells postgres how to get the wrapped payload into postgres (`var postgresData`) and how to initialise the payload from the data that is saved in postgres (`init?(postgresData: PostgresData)`). The PostgresData-initializer (`.init(jsonb: jsonString)`) tells the type that it should treat `jsonString` as json.

Now the controller becomes a piece of cake 😎

```Swift
struct MetricController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let collect = routes.grouped("collect")
        collect.post(use: create)
    }

    func create(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let metric = Metric()
        let payload_string = try req.content.decode(String.self)
        metric.payload = JsonWrapper(payload_string)
        return metric.save(on: req.db).transform(to: HTTPStatus.noContent)
    }
}
```

## Heads up

Simulating MetricKit payload is only enabled on a real device. So you need to run your iOS code on a real device. Once you have data in the database you can query "into" your payload like this:

```sql
select payload->'appVersion' from metrics;
```

Or how about building a view:

```sql
CREATE VIEW app_versions AS SELECT id,payload->'appVersion' AS app_version,payload->'metaData'->>'deviceType' AS device_type FROM metrics;
```

Now you can do something like this:

```sql
select distinct(app_version) from app_versions;
```

## Question

This is completely unrelated, but: Is it a good idea to have UUID as primary keys? Does this have any performance implications?