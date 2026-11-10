/*
 * the prototype's fuzzy match: the query's letters must appear in the text
 * in order. each adds 1, +3 when it follows the previous letter directly,
 * +4 when it starts a word; a shorter text wins a tie. none when a letter
 * is missing
 */
pub fn score(query: &str, text: &str) -> Option<f32> {
    let query: Vec<char> = query.to_lowercase().chars().collect();
    let text: Vec<char> = text.to_lowercase().chars().collect();

    let mut matched = 0;
    let mut score = 0.0;

    // -2 so the first letter never counts as following one
    let mut last: i64 = -2;

    for (index, letter) in text.iter().enumerate() {
        if matched == query.len() {
            break;
        }

        if *letter != query[matched] {
            continue;
        }

        score += 1.0;

        if index as i64 == last + 1 {
            score += 3.0;
        }

        if index == 0 || text[index - 1] == ' ' {
            score += 4.0;
        }

        last = index as i64;
        matched += 1;
    }

    (matched == query.len()).then_some(score - text.len() as f32 * 0.05)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn needs_every_letter_in_order() {
        assert!(score("zen", "Zen Browser").is_some());
        assert!(score("zb", "Zen Browser").is_some());
        assert!(score("nez", "Zen Browser").is_none());
        assert!(score("zq", "Zen Browser").is_none());
    }

    #[test]
    fn ignores_case() {
        assert_eq!(score("ZEN", "zen browser"), score("zen", "ZEN BROWSER"));
    }

    #[test]
    fn prefers_consecutive_letters_and_word_starts() {
        let direct = score("fire", "Firefox").unwrap();
        let scattered = score("fire", "Fox in a Rare Eclipse").unwrap();

        assert!(direct > scattered);

        // a word start beats a letter buried in a word
        assert!(score("b", "Zen Browser").unwrap() > score("o", "Zen Browser").unwrap());
    }

    #[test]
    fn a_shorter_text_wins_a_tie() {
        assert!(score("kit", "Kitty").unwrap() > score("kit", "Kitty Terminal Emulator").unwrap());
    }

    #[test]
    fn matches_the_prototype_numbers() {
        // k:1+4, i:1+3, t:1+3, t:1+3, y:1+3 = 21, minus 5 letters * 0.05
        assert!((score("kitty", "Kitty").unwrap() - 20.75).abs() < 1e-4);
    }
}
