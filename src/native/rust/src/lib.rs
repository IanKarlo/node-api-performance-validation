#![deny(clippy::all)]

#[macro_use]
extern crate napi_derive;

#[napi]
pub fn say_hello() -> String {
  "Hello, World!".to_string()
}

#[napi]
pub fn say_hello_to(name: String) -> String {
  format!("Hello, {}!!!!", name)
}


#[cfg(test)]
mod tests {
  use super::*;

  #[test]
  fn test_say_hello() {
    assert_eq!(say_hello(), "Hello, World!".to_string());
  }

  #[test]
  fn test_say_hello_to() {
    assert_eq!(say_hello_to("John".to_string()), "Hello, John!!!!".to_string());
  }
}