//
//  FlashcardsSet.swift
//  Memorize
//

import Foundation
import SQLite

struct FlashcardsSet: Identifiable {

    let id: Int64
    let dbms: Database
    var name: String
    // swiftlint:disable discouraged_optional_collection
    var keywords: [Int64]?
    var tags: [Int64]?
    var studyTags: [Int64]?
    var testTags: [Int64]?
    // swiftlint:enable discouraged_optional_collection
    var flashcards: [Flashcard]
    var flashcardsExpired: Bool
    var test: [Int64] = []
    var answerSide: Flashcard.Side = .back
    // swiftlint:disable discouraged_optional_boolean
    var studyAllFlashcards: Bool?
    var testAllFlashcards: Bool?
    // swiftlint:enable discouraged_optional_boolean
    var numberOfQuestions: Int?

    var answerWithBack: Bool {
        get {
            answerSide == .back
        }
        set {
            answerSide = newValue ? .back : .front
        }
    }

    /// TODO #37: Load flashcard data from database via id (Int64) instead of cards array loaded to memory
    var studyFlashcards: [Int64] {
        if answerSide == .back {
            return flashcards(tags: studyAllFlashcards.nonOptional ? nil : studyTags.nonOptional)
        } else {
            return flashcards(tags: studyAllFlashcards.nonOptional ? nil : studyTags.nonOptional).map { flashcard in
                var newCard = flashcard
                newCard.front = flashcard.back
                newCard.back = flashcard.front
                return newCard
            }
        }
    }

    /// TODO #37: Load flashcard data from database via id (Int64) instead of cards array loaded to memory
    var testFlashcards: [Int64] {
        get {
            if answerSide == .back {
                return flashcards(tags: testAllFlashcards.nonOptional ? nil : testTags.nonOptional)
            } else {
                return flashcards(tags: testAllFlashcards.nonOptional ? nil : testTags.nonOptional).map { flashcard in
                    var newCard = flashcard
                    newCard.front = flashcard.back
                    newCard.back = flashcard.front
                    return newCard
                }
            }
        }
        set {
            for flashcard in newValue {
                flashcards[safe: flashcards.firstIndex { $0.id == flashcard.id }]?.gameData = flashcard.gameData
            }
        }
    }

    var score: Int? {
        let testFlashcards = testFlashcards.filter { test.contains($0.id) }
        guard testFlashcards.first?.gameData.lastInput != nil else {
            return nil
        }
        var score = 0
        for flashcard in testFlashcards where flashcard.back == flashcard.gameData.lastInput {
            score += 1
        }
        return score
    }

    /**
     * TODO #37: Move to SQL via SELECT query
     * var filteredStudyCards: [Int64] {
     *     studyFlashcards.filter { $0.gameData.difficulty != 0 }.map { $0.id }
     * }
     */

    init(
        id: Int64,
        dbms: Database,
        name: String,
        keywords: [Int64] = [],
        tags: [Int64] = []
    ) {
        self.id = id
        self.dbms = dbms
        self.name = name
        flashcardsExpired = true
        dbms.loadFlashcards(toSet: &self)
        self.keywords = keywords
        self.tags = tags
    }

    /// Count total amount of flashcards in set
    /// - Returns: The amount.
    func completedCardsCount() -> Int {
        var amount = 0

        guard let database = dbms.connection else {
            return amount
        }
        do {
            for _ in try database.prepare(
                dbms.tableFlashcards
                .select(dbms.flashcardsSet)
                .filter(dbms.flashcardsSet == self.id)
            ) {
                amount += 1
            }
        } catch {
            print("Error counting flashcards: \(error)")
        }

        return amount
    }

    // TODO #37: Decide if nesting dbms.setDifficulty in resetStudyProgress is necessary
    mutating func resetStudyProgress() {
        dbms.setDifficulty(0, inSet: &self)
    }

    /**
     * TODO #37: Move to SQL: search/filter via SELECT queries
     * func score(_ query: String?) -> Int {
     *     var totalScore = 1
     *     if let query, !query.isEmpty {
     *         totalScore = name.search(query) ? 5 : 0
     *         for keyword in keywords.nonOptional {
     *             totalScore += keyword.search(query) ? 1 : 0
     *         }
     *     }
     *     return totalScore
     * }
     *
     * mutating func filterTags() {
     *     for (index, flashcard) in flashcards.enumerated() {
     *         flashcards[safe: index]?.tags.nonOptional = flashcard.tags.nonOptional
     *             .filter { tags.nonOptional.contains($0) }
     *     }
     *     studyTags.nonOptional = studyTags.nonOptional.filter { tags.nonOptional.contains($0) }
     *     testTags.nonOptional = testTags.nonOptional.filter { tags.nonOptional.contains($0) }
     * }
     *
     * // swiftlint:disable discouraged_optional_collection
     * func flashcards(tags: [String]?) -> [Flashcard] {
     *     if let tags {
     *         return flashcards.filter { $0.tags.nonOptional.contains { tags.contains($0) } }
     *     }
     *     return flashcards
     * }
     * // swiftlint:enable discouraged_optional_collection
     */

}
