//
//  CategorySuggestionService.swift
//  FinanceTracker
//
//  On-device merchant → category suggestion. v1.0 is a static lookup table with
//  case-insensitive substring matching. NO data leaves the device; no network,
//  no analytics. The returned value is a canonical English category NAME — the
//  caller is responsible for matching it against the user's actual categories.
//
//  TODO: v1.1: replace lookup table with trained Core ML NLClassifier model
//

import Foundation

enum CategorySuggestionService {

    /// Suggest a canonical category name for a merchant string, or nil if no
    /// confident match. Case-insensitive substring match against known merchants.
    static func suggest(forMerchant merchant: String) -> String? {
        let needle = merchant
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard needle.count >= 2 else { return nil }

        for (keyword, category) in lookup where needle.contains(keyword) {
            return category
        }
        return nil
    }

    /// Merchant keyword (lowercased) → canonical category name.
    /// Ordered longest-first so more specific keywords win over generic substrings.
    private static let lookup: [(String, String)] = rawLookup
        .sorted { $0.0.count > $1.0.count }

    private static let rawLookup: [(String, String)] = [
        // Coffee
        ("starbucks", "Coffee"), ("blue bottle", "Coffee"), ("peet's", "Coffee"),
        ("peets", "Coffee"), ("dunkin", "Coffee"), ("philz", "Coffee"),
        ("costa coffee", "Coffee"), ("tim hortons", "Coffee"), ("caribou coffee", "Coffee"),

        // Food / groceries / restaurants
        ("whole foods", "Food"), ("trader joe's", "Food"), ("trader joes", "Food"),
        ("kroger", "Food"), ("sweetgreen", "Food"), ("safeway", "Food"),
        ("aldi", "Food"), ("costco", "Food"), ("publix", "Food"),
        ("wegmans", "Food"), ("chipotle", "Food"), ("mcdonald", "Food"),
        ("burger king", "Food"), ("wendy's", "Food"), ("wendys", "Food"),
        ("taco bell", "Food"), ("panera", "Food"), ("doordash", "Food"),
        ("grubhub", "Food"), ("instacart", "Food"), ("kfc", "Food"),
        ("pizza", "Food"), ("domino", "Food"), ("five guys", "Food"),
        ("shake shack", "Food"), ("popeyes", "Food"), ("in-n-out", "Food"),
        ("albertsons", "Food"), ("food lion", "Food"), ("h-e-b", "Food"),
        ("heb", "Food"), ("ralphs", "Food"),

        // Gas / fuel
        ("shell", "Gas"), ("chevron", "Gas"), ("exxon", "Gas"),
        ("mobil", "Gas"), ("bp ", "Gas"), ("texaco", "Gas"),
        ("valero", "Gas"), ("arco", "Gas"), ("76 ", "Gas"),
        ("circle k", "Gas"), ("speedway", "Gas"), ("marathon", "Gas"),
        ("sunoco", "Gas"), ("citgo", "Gas"), ("phillips 66", "Gas"),

        // Transit / rideshare / travel
        ("uber", "Transit"), ("lyft", "Transit"), ("subway transit", "Transit"),
        ("metro", "Transit"), ("amtrak", "Transit"), ("bart", "Transit"),
        ("mta", "Transit"), ("caltrain", "Transit"), ("transit", "Transit"),
        ("parking", "Transit"), ("toll", "Transit"), ("delta air", "Transit"),
        ("united airlines", "Transit"), ("american airlines", "Transit"),
        ("southwest air", "Transit"), ("turo", "Transit"), ("hertz", "Transit"),
        ("enterprise rent", "Transit"),

        // Subscriptions / digital
        ("spotify", "Subscriptions"), ("netflix", "Subscriptions"),
        ("youtube premium", "Subscriptions"), ("apple one", "Subscriptions"),
        ("icloud", "Subscriptions"), ("hulu", "Subscriptions"),
        ("disney+", "Subscriptions"), ("disney plus", "Subscriptions"),
        ("hbo", "Subscriptions"), ("max ", "Subscriptions"),
        ("amazon prime", "Subscriptions"), ("prime video", "Subscriptions"),
        ("audible", "Subscriptions"), ("patreon", "Subscriptions"),
        ("dropbox", "Subscriptions"), ("notion", "Subscriptions"),
        ("adobe", "Subscriptions"), ("microsoft 365", "Subscriptions"),
        ("office 365", "Subscriptions"), ("github", "Subscriptions"),
        ("openai", "Subscriptions"), ("chatgpt", "Subscriptions"),
        ("twitch", "Subscriptions"), ("paramount+", "Subscriptions"),
        ("peacock", "Subscriptions"), ("apple music", "Subscriptions"),

        // Entertainment
        ("amc", "Entertainment"), ("regal", "Entertainment"),
        ("cinemark", "Entertainment"), ("bookstore", "Entertainment"),
        ("barnes & noble", "Entertainment"), ("ticketmaster", "Entertainment"),
        ("stubhub", "Entertainment"), ("steam", "Entertainment"),
        ("playstation", "Entertainment"), ("xbox", "Entertainment"),
        ("nintendo", "Entertainment"), ("fandango", "Entertainment"),
        ("eventbrite", "Entertainment"), ("dave & buster", "Entertainment"),

        // Health / pharmacy / fitness
        ("walgreens", "Health"), ("cvs", "Health"), ("rite aid", "Health"),
        ("gym", "Health"), ("planet fitness", "Health"), ("equinox", "Health"),
        ("la fitness", "Health"), ("24 hour fitness", "Health"),
        ("pharmacy", "Health"), ("gnc", "Health"), ("walgreen", "Health"),
        ("crunch fitness", "Health"), ("orangetheory", "Health"),
        ("dental", "Health"), ("clinic", "Health"), ("hospital", "Health"),

        // Shopping / supplies
        ("amazon", "Supplies"), ("walmart", "Supplies"), ("target", "Supplies"),
        ("best buy", "Supplies"), ("home depot", "Supplies"),
        ("lowe's", "Supplies"), ("lowes", "Supplies"), ("ikea", "Supplies"),
        ("staples", "Supplies"), ("office depot", "Supplies"),
        ("etsy", "Supplies"), ("ebay", "Supplies"), ("apple store", "Supplies"),

        // Housing / utilities / rent
        ("rent", "Rent"), ("landlord", "Rent"), ("apartments", "Rent"),
        ("comcast", "Rent"), ("xfinity", "Rent"), ("at&t", "Rent"),
        ("verizon", "Rent"), ("t-mobile", "Rent"), ("pg&e", "Rent"),
        ("con edison", "Rent"), ("water bill", "Rent"), ("electric", "Rent"),
    ]
}
