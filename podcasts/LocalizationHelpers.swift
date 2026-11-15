import Foundation

public extension String {
    /// This allows us to split a strong and localize the first instance. This is particularly helpful with Podcast Categories.
    func localized(seperatingWith seperator: (Character) throws -> Bool) -> String? {
        if let substring = try? split(whereSeparator: seperator).first {
            return String(substring).localized
        } else {
            return localized
        }
    }

    /// The localized name of a podcast category, as podcast feeds report it in English.
    var localized: String {
        switch lowercased() {
        case "arts":
            return L10n.discoverBrowseByCategoryArt
        case "business":
            return L10n.discoverBrowseByCategoryBusiness
        case "comedy":
            return L10n.discoverBrowseByCategoryComedy
        case "education":
            return L10n.discoverBrowseByCategoryEducation
        case "fiction":
            return L10n.discoverBrowseByCategoryFiction
        case "games & hobbies":
            return L10n.discoverBrowseByCategoryGamesAndHobbies
        case "government":
            return L10n.discoverBrowseByCategoryGovernment
        case "government & organizations":
            return L10n.discoverBrowseByCategoryGovernmentAndOrganizations
        case "health":
            return L10n.discoverBrowseByCategoryHealth
        case "health & fitness":
            return L10n.discoverBrowseByCategoryHealthAndFitness
        case "history":
            return L10n.discoverBrowseByCategoryHistory
        case "kids & family":
            return L10n.discoverBrowseByCategoryKidsAndFamily
        case "leisure":
            return L10n.discoverBrowseByCategoryLeisure
        case "music":
            return L10n.discoverBrowseByCategoryMusic
        case "news & politics":
            return L10n.discoverBrowseByCategoryNewsAndPolitics
        case "news":
            return L10n.discoverBrowseByCategoryNews
        case "religion & spirituality":
            return L10n.discoverBrowseByCategoryReligionAndSpirituality
        case "science":
            return L10n.discoverBrowseByCategoryScience
        case "science & medicine":
            return L10n.discoverBrowseByCategoryScienceAndMedicine
        case "society":
            return L10n.discoverBrowseByCategorySociety
        case "society & culture":
            return L10n.discoverBrowseByCategorySocietyAndCulture
        case "sports":
            return L10n.discoverBrowseByCategorySports
        case "sports & recreation":
            return L10n.discoverBrowseByCategorySportsAndRecreation
        case "technology":
            return L10n.discoverBrowseByCategoryTechnology
        case "true crime":
            return L10n.discoverBrowseByCategoryTrueCrime
        case "tv & film":
            return L10n.discoverBrowseByCategoryTvAndFilm

        // Abbreviated categories
        case "family":
            return L10n.discoverBrowseByCategoryFamily
        case "spirituality":
            return L10n.discoverBrowseByCategorySpirituality
        case "culture":
            return L10n.discoverBrowseByCategorySocietyAndCulture

        // Catch all
        default:
            return self
        }
    }
}
