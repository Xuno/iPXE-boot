// Integration tests for hello-ipxe application
// These tests will be run by `cargo test`

use hello_ipxe::greet;

#[cfg(test)]
mod integration_tests {
    use super::*;

    #[test]
    fn test_greet_returns_valid_string() {
        let result = greet("TestUser");
        assert!(result.starts_with("Hello,"));
        assert!(result.ends_with("!"));
    }

    #[test]
    fn test_greet_with_special_characters() {
        let result = greet("User123!@#");
        assert_eq!(result, "Hello, User123!@#!");
    }

    #[test]
    fn test_greet_preserves_case() {
        let result = greet("Alice");
        assert_eq!(result, "Hello, Alice!");
    }
}