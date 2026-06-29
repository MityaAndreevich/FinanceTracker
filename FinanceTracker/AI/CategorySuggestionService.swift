//
//  CategorySuggestionService.swift
//  FinanceTracker
//
//  On-device merchant → category suggestion. All logic stays on device; no network,
//  no analytics. Returns the canonical English category NAME so the caller can
//  match it against the user's actual seeded categories.
//
//  Match priority:
//  1. Word-boundary bare-word match (handles "gas", "lunch", "кофе")
//  2. Brand substring match (handles "Starbucks", "Shell", "Netflix")
//
//  TODO: v1.1 — replace lookup tables with trained Core ML NLClassifier model
//

import Foundation
import SwiftData

enum CategorySuggestionService {

    /// Returns a canonical category name (English) or nil if no confident match.
    /// Priority:
    ///   1. User-learned mapping (requires ModelContext)
    ///   2. Bare-word shortKeywords match
    ///   3. Brand substring lookup
    static func suggest(forMerchant merchant: String, in context: ModelContext?) -> String? {
        if let context,
           let learned = MerchantLearningService.suggestedCategoryName(for: merchant, in: context) {
            return learned
        }
        return suggest(forMerchant: merchant)
    }

    /// Context-free fallback — used by QuickAddParser (pure) and existing tests.
    static func suggest(forMerchant merchant: String) -> String? {
        let needle = merchant
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !needle.isEmpty else { return nil }

        // 1. Bare-word match — word-boundary aware, handles "gas", "lunch", "кофе"
        for (keyword, category) in shortKeywords where containsWord(needle, keyword) {
            return category
        }

        // 2. Brand substring match (longer keywords sorted first to avoid false partials)
        guard needle.count >= 2 else { return nil }
        for (keyword, category) in lookup where needle.contains(keyword) {
            return category
        }

        return nil
    }

    // MARK: - Word-boundary helper

    /// True when `word` appears in `haystack` as a whole word (not part of a longer word).
    /// "gas" matches in "67 gas" and "gas station" but NOT in "gassed" or "gaslight".
    private static func containsWord(_ haystack: String, _ word: String) -> Bool {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
        return haystack.range(of: pattern,
                              options: [.regularExpression, .caseInsensitive]) != nil
    }

    // MARK: - Bare-word table (checked before brand table)

    private static let shortKeywords: [(String, String)] = [

        // ── Food & Drink ────────────────────────────────────────────────────────
        // EN — meals & eating out
        ("lunch", "Food & Drink"), ("dinner", "Food & Drink"), ("breakfast", "Food & Drink"),
        ("brunch", "Food & Drink"), ("food", "Food & Drink"), ("meal", "Food & Drink"),
        ("snack", "Food & Drink"),
        // EN — coffee & drinks
        ("coffee", "Food & Drink"), ("latte", "Food & Drink"), ("espresso", "Food & Drink"),
        ("cappuccino", "Food & Drink"), ("tea", "Food & Drink"),
        // EN — groceries & market
        ("groceries", "Food & Drink"), ("grocery", "Food & Drink"),
        ("market", "Food & Drink"), ("supermarket", "Food & Drink"),
        // EN — alcohol & bars
        ("beer", "Food & Drink"), ("wine", "Food & Drink"), ("bar", "Food & Drink"),
        ("drinks", "Food & Drink"), ("cocktail", "Food & Drink"), ("pub", "Food & Drink"),
        // EN — restaurants & delivery
        ("restaurant", "Food & Drink"), ("delivery", "Food & Drink"),
        ("pizza", "Food & Drink"), ("burger", "Food & Drink"), ("sushi", "Food & Drink"),
        // RU
        ("еда", "Food & Drink"), ("обед", "Food & Drink"), ("ужин", "Food & Drink"),
        ("завтрак", "Food & Drink"), ("кофе", "Food & Drink"), ("чай", "Food & Drink"),
        ("продукты", "Food & Drink"), ("магазин", "Food & Drink"),
        ("пиво", "Food & Drink"), ("вино", "Food & Drink"), ("бар", "Food & Drink"),
        ("ресторан", "Food & Drink"), ("кафе", "Food & Drink"), ("доставка", "Food & Drink"),
        ("пицца", "Food & Drink"), ("суши", "Food & Drink"),
        // ── Food & Drink — common grocery items (v1.0) ───────────────────────────
        // NB: "water" intentionally omitted — it already maps to Housing (utilities).
        // EN
        ("eggs", "Food & Drink"), ("egg", "Food & Drink"),
        ("bread", "Food & Drink"), ("milk", "Food & Drink"),
        ("cheese", "Food & Drink"), ("yogurt", "Food & Drink"), ("butter", "Food & Drink"),
        ("meat", "Food & Drink"), ("chicken", "Food & Drink"),
        ("fish", "Food & Drink"), ("beef", "Food & Drink"), ("pork", "Food & Drink"),
        ("vegetables", "Food & Drink"), ("veggies", "Food & Drink"),
        ("fruit", "Food & Drink"), ("fruits", "Food & Drink"),
        ("rice", "Food & Drink"), ("pasta", "Food & Drink"), ("noodles", "Food & Drink"),
        ("salad", "Food & Drink"), ("soup", "Food & Drink"),
        ("juice", "Food & Drink"), ("soda", "Food & Drink"),
        ("chocolate", "Food & Drink"), ("candy", "Food & Drink"), ("ice cream", "Food & Drink"),
        // RU
        ("яйца", "Food & Drink"), ("яйцо", "Food & Drink"),
        ("хлеб", "Food & Drink"), ("молоко", "Food & Drink"),
        ("сыр", "Food & Drink"), ("йогурт", "Food & Drink"), ("масло", "Food & Drink"),
        ("мясо", "Food & Drink"), ("курица", "Food & Drink"),
        ("рыба", "Food & Drink"), ("говядина", "Food & Drink"), ("свинина", "Food & Drink"),
        ("овощи", "Food & Drink"), ("фрукты", "Food & Drink"),
        ("рис", "Food & Drink"), ("макароны", "Food & Drink"),
        ("салат", "Food & Drink"), ("суп", "Food & Drink"),
        ("сок", "Food & Drink"), ("шоколад", "Food & Drink"), ("конфеты", "Food & Drink"),
        ("мороженое", "Food & Drink"),
        // ES — common groceries + meals & drinks (Bug 1 P0)
        ("huevos", "Food & Drink"), ("pan", "Food & Drink"), ("leche", "Food & Drink"),
        ("queso", "Food & Drink"), ("carne", "Food & Drink"), ("pollo", "Food & Drink"),
        ("pescado", "Food & Drink"), ("frutas", "Food & Drink"), ("verduras", "Food & Drink"),
        ("café", "Food & Drink"), ("cafe", "Food & Drink"), ("té", "Food & Drink"), ("te", "Food & Drink"),
        ("almuerzo", "Food & Drink"), ("cena", "Food & Drink"), ("desayuno", "Food & Drink"),
        ("cerveza", "Food & Drink"), ("vino", "Food & Drink"), ("pizza", "Food & Drink"),
        // DE
        ("eier", "Food & Drink"), ("brot", "Food & Drink"), ("milch", "Food & Drink"),
        ("käse", "Food & Drink"), ("fleisch", "Food & Drink"), ("hähnchen", "Food & Drink"),
        ("fisch", "Food & Drink"), ("obst", "Food & Drink"), ("gemüse", "Food & Drink"),
        // FR
        ("œufs", "Food & Drink"), ("oeufs", "Food & Drink"), ("pain", "Food & Drink"),
        ("lait", "Food & Drink"), ("fromage", "Food & Drink"), ("viande", "Food & Drink"),
        ("poulet", "Food & Drink"), ("poisson", "Food & Drink"),
        ("légumes", "Food & Drink"),
        // PT — groceries + meals & drinks (Bug 1 P0)
        ("ovos", "Food & Drink"), ("pão", "Food & Drink"), ("leite", "Food & Drink"),
        ("queijo", "Food & Drink"), ("frango", "Food & Drink"),
        ("peixe", "Food & Drink"),
        ("café", "Food & Drink"), ("cafe", "Food & Drink"), ("chá", "Food & Drink"), ("cha", "Food & Drink"),
        ("almoço", "Food & Drink"), ("jantar", "Food & Drink"),
        ("cerveja", "Food & Drink"), ("vinho", "Food & Drink"), ("pizza", "Food & Drink"),

        // ── Transport ───────────────────────────────────────────────────────────
        // EN — fuel
        ("gas", "Transport"), ("fuel", "Transport"), ("gasoline", "Transport"),
        ("petrol", "Transport"), ("diesel", "Transport"),
        // EN — car maintenance
        ("parking", "Transport"), ("toll", "Transport"),
        ("mechanic", "Transport"), ("tires", "Transport"),
        // EN — rideshare & transit
        ("taxi", "Transport"), ("cab", "Transport"), ("ride", "Transport"),
        ("bus", "Transport"), ("train", "Transport"), ("subway", "Transport"),
        ("metro", "Transport"), ("flight", "Transport"),
        // EN — travel
        ("hotel", "Transport"), ("airbnb", "Transport"),
        ("trip", "Transport"), ("vacation", "Transport"),
        // RU
        ("бензин", "Transport"), ("заправка", "Transport"), ("азс", "Transport"),
        ("такси", "Transport"), ("автобус", "Transport"), ("метро", "Transport"),
        ("шиномонтаж", "Transport"), ("парковка", "Transport"),
        ("отель", "Transport"), ("гостиница", "Transport"), ("перелёт", "Transport"),
        ("поезд", "Transport"), ("рынок", "Food & Drink"),
        // ES — fuel & transit (Bug 12: ES/PT had no Transport coverage)
        ("gasolina", "Transport"), ("billete", "Transport"),
        ("autobús", "Transport"), ("autobus", "Transport"),
        ("tren", "Transport"), ("estacionamiento", "Transport"),
        // PT — fuel & transit (Bug 12)
        ("bilhete", "Transport"), ("ônibus", "Transport"), ("onibus", "Transport"),
        ("trem", "Transport"), ("metrô", "Transport"), ("estacionamento", "Transport"),

        // ── Housing ─────────────────────────────────────────────────────────────
        ("rent", "Housing"), ("mortgage", "Housing"), ("landlord", "Housing"),
        ("electric", "Housing"), ("electricity", "Housing"), ("water", "Housing"),
        ("internet", "Housing"), ("wifi", "Housing"),
        ("аренда", "Housing"), ("квартплата", "Housing"), ("ипотека", "Housing"),
        ("свет", "Housing"), ("вода", "Housing"), ("интернет", "Housing"),
        ("коммуналка", "Housing"), ("газ", "Housing"),
        // ES/PT — utilities (Bug 12: ES/PT had no Housing coverage). "gas" is
        // intentionally omitted because the EN "gas"→Transport (fuel) entry wins
        // first; Spanish/PT fuel is covered by "gasolina".
        ("luz", "Housing"), ("agua", "Housing"), ("água", "Housing"),

        // ── Shopping ────────────────────────────────────────────────────────────
        ("clothes", "Shopping"), ("clothing", "Shopping"),
        ("shirt", "Shopping"), ("shoes", "Shopping"), ("boots", "Shopping"),
        ("books", "Shopping"), ("electronics", "Shopping"), ("gift", "Shopping"),
        ("одежда", "Shopping"), ("обувь", "Shopping"), ("подарок", "Shopping"),

        // ── Entertainment ───────────────────────────────────────────────────────
        ("movie", "Entertainment"), ("cinema", "Entertainment"),
        ("concert", "Entertainment"), ("game", "Entertainment"),
        ("ticket", "Entertainment"), ("show", "Entertainment"),
        ("кино", "Entertainment"), ("концерт", "Entertainment"),
        ("билет", "Entertainment"),

        // ── Health ──────────────────────────────────────────────────────────────
        ("doctor", "Health"), ("dentist", "Health"),
        ("medicine", "Health"), ("pills", "Health"), ("pharmacy", "Health"),
        ("gym", "Health"), ("fitness", "Health"), ("haircut", "Health"),
        ("врач", "Health"), ("аптека", "Health"), ("лекарства", "Health"),
        ("спортзал", "Health"), ("стрижка", "Health"),

        // ── Subscriptions ───────────────────────────────────────────────────────
        ("subscription", "Subscriptions"), ("подписка", "Subscriptions"),

        // ── Income ──────────────────────────────────────────────────────────────
        ("salary", "Income"), ("paycheck", "Income"), ("freelance", "Income"),
        ("bonus", "Income"), ("refund", "Income"), ("dividend", "Income"),
        ("зарплата", "Income"), ("аванс", "Income"), ("гонорар", "Income"),
    ]

    // MARK: - Brand lookup table (sorted longest-first to prefer specific keywords)

    private static let lookup: [(String, String)] = rawLookup
        .sorted { $0.0.count > $1.0.count }

    private static let rawLookup: [(String, String)] = [

        // Food & Drink — coffee brands
        ("starbucks", "Food & Drink"), ("blue bottle", "Food & Drink"),
        ("peet's", "Food & Drink"), ("peets", "Food & Drink"),
        ("dunkin", "Food & Drink"), ("philz", "Food & Drink"),
        ("costa coffee", "Food & Drink"), ("tim hortons", "Food & Drink"),
        ("caribou coffee", "Food & Drink"),

        // Food & Drink — groceries
        ("whole foods", "Food & Drink"), ("trader joe's", "Food & Drink"),
        ("trader joes", "Food & Drink"), ("kroger", "Food & Drink"),
        ("safeway", "Food & Drink"), ("aldi", "Food & Drink"),
        ("costco", "Food & Drink"), ("publix", "Food & Drink"),
        ("wegmans", "Food & Drink"), ("albertsons", "Food & Drink"),
        ("food lion", "Food & Drink"), ("h-e-b", "Food & Drink"),
        ("heb", "Food & Drink"), ("ralphs", "Food & Drink"),
        ("instacart", "Food & Drink"),

        // Food & Drink — restaurants & delivery
        ("sweetgreen", "Food & Drink"), ("chipotle", "Food & Drink"),
        ("mcdonald", "Food & Drink"), ("burger king", "Food & Drink"),
        ("wendy's", "Food & Drink"), ("wendys", "Food & Drink"),
        ("taco bell", "Food & Drink"), ("panera", "Food & Drink"),
        ("doordash", "Food & Drink"), ("grubhub", "Food & Drink"),
        ("kfc", "Food & Drink"), ("domino", "Food & Drink"),
        ("five guys", "Food & Drink"), ("shake shack", "Food & Drink"),
        ("popeyes", "Food & Drink"), ("in-n-out", "Food & Drink"),

        // Transport — fuel stations
        ("shell", "Transport"), ("chevron", "Transport"), ("exxon", "Transport"),
        ("mobil", "Transport"), ("bp ", "Transport"), ("texaco", "Transport"),
        ("valero", "Transport"), ("arco", "Transport"), ("76 ", "Transport"),
        ("circle k", "Transport"), ("speedway", "Transport"), ("marathon", "Transport"),
        ("sunoco", "Transport"), ("citgo", "Transport"), ("phillips 66", "Transport"),

        // Transport — rideshare & transit
        ("uber", "Transport"), ("lyft", "Transport"),
        ("subway transit", "Transport"), ("amtrak", "Transport"),
        ("bart", "Transport"), ("mta", "Transport"), ("caltrain", "Transport"),
        ("delta air", "Transport"), ("united airlines", "Transport"),
        ("american airlines", "Transport"), ("southwest air", "Transport"),
        ("turo", "Transport"), ("hertz", "Transport"), ("enterprise rent", "Transport"),

        // Housing — utilities & landlord
        ("comcast", "Housing"), ("xfinity", "Housing"),
        ("at&t", "Housing"), ("verizon", "Housing"), ("t-mobile", "Housing"),
        ("pg&e", "Housing"), ("con edison", "Housing"),
        ("water bill", "Housing"), ("apartments", "Housing"),

        // Shopping
        ("amazon", "Shopping"), ("walmart", "Shopping"), ("target", "Shopping"),
        ("best buy", "Shopping"), ("home depot", "Shopping"),
        ("lowe's", "Shopping"), ("lowes", "Shopping"), ("ikea", "Shopping"),
        ("staples", "Shopping"), ("office depot", "Shopping"),
        ("etsy", "Shopping"), ("ebay", "Shopping"), ("apple store", "Shopping"),

        // Entertainment
        ("amc", "Entertainment"), ("regal", "Entertainment"),
        ("cinemark", "Entertainment"), ("bookstore", "Entertainment"),
        ("barnes & noble", "Entertainment"), ("ticketmaster", "Entertainment"),
        ("stubhub", "Entertainment"), ("steam", "Entertainment"),
        ("playstation", "Entertainment"), ("xbox", "Entertainment"),
        ("nintendo", "Entertainment"), ("fandango", "Entertainment"),
        ("eventbrite", "Entertainment"), ("dave & buster", "Entertainment"),

        // Health
        ("walgreens", "Health"), ("cvs", "Health"), ("rite aid", "Health"),
        ("planet fitness", "Health"), ("equinox", "Health"),
        ("la fitness", "Health"), ("24 hour fitness", "Health"),
        ("pharmacy", "Health"), ("gnc", "Health"), ("walgreen", "Health"),
        ("crunch fitness", "Health"), ("orangetheory", "Health"),
        ("dental", "Health"), ("clinic", "Health"), ("hospital", "Health"),

        // Subscriptions
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
    ]
}
