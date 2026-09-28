import AppDabServices
import Foundation

struct CustomerReviewsTextRenderer {
    func render(_ reviewList: ReviewList, style: TextStyle) -> String {
        var sections = [style.heading("Showing \(reviewList.reviews.count) of \(reviewList.pagination.total) review\(reviewList.pagination.total == 1 ? "" : "s")")]
        if reviewList.reviews.isEmpty {
            sections.append("No reviews found.")
        } else {
            sections.append(reviewList.reviews.map { render($0, style: style) }.joined(separator: "\n\n────────────────────\n\n"))
        }
        return sections.joined(separator: "\n\n")
    }

    func render(_ review: CustomerReview, style: TextStyle) -> String {
        let rating = min(max(review.rating, 0), 5)
        let stars = String(repeating: "★", count: rating) + String(repeating: "☆", count: 5 - rating)
        var sections = [
            style.reviewTitle("\(stars) \(rating)/5  \(review.title)"),
            "\(review.reviewerNickname) · \(review.territory) · \(review.createdDate.formatted(.iso8601)) · \(review.reviewID)",
            review.body
        ]
        if let response = review.response {
            sections.append(style.subheading("Response (\(response.state))"))
            sections.append(response.responseBody)
            sections.append("\(response.lastModifiedDate.formatted(.iso8601)) · \(response.responseID)")
        } else {
            sections.append(style.subheading("Response: None"))
        }
        return sections.joined(separator: "\n\n")
    }
}
