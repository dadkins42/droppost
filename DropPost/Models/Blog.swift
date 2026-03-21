import Foundation

struct Blog: Codable, Identifiable, Hashable {
    var slug: String
    var title: String
    var description: String
    var emoji: String
    var createdAt: String

    var id: String { slug }
}

struct BlogManifest: Codable {
    var blogs: [Blog]
}

struct Post: Codable, Identifiable {
    var slug: String
    var title: String
    var date: String
    var excerpt: String
    var content: String
    var location: String?
    var images: [String]
    var videos: [String]

    var id: String { slug }
}

struct PostsManifest: Codable {
    var posts: [Post]
}
