import Skein

enum ServiceEnvironment: SkeinQualifier {
    case production
    case staging
}

struct ServiceEndpoint {
    let baseURL: String
}

let endpointModule = module {
    single(ServiceEndpoint.self, qualifier: ServiceEnvironment.production, provider: { _ in
        ServiceEndpoint(baseURL: "https://api.example.com")
    })
    single(ServiceEndpoint.self, qualifier: ServiceEnvironment.staging, provider: { _ in
        ServiceEndpoint(baseURL: "https://staging.example.com")
    })
}

do {
    try startSkein {
        endpointModule
    }
    defer { stopSkein() }

    let production = try get(
        ServiceEndpoint.self,
        qualifier: ServiceEnvironment.production
    )
    let staging = try get(
        ServiceEndpoint.self,
        qualifier: ServiceEnvironment.staging
    )

    print("Production: \(production.baseURL)")
    print("Staging: \(staging.baseURL)")
} catch {
    print("Skein setup or resolution failed: \(error)")
}
