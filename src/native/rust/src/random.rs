pub struct SeededRandom {
  seed: f64,
}

impl SeededRandom {
  pub fn new(seed: Option<f64>) -> Self {
    let s = seed.unwrap_or_else(|| {
      // Fallback to time-based seed if not provided (simplified)
      // In a real scenario we'd use system time, but for now fixed or simple
      12345.0 
    });
    SeededRandom { seed: s }
  }

  pub fn next(&mut self) -> f64 {
    self.seed = (self.seed * 9301.0 + 49297.0) % 233280.0;
    self.seed / 233280.0
  }

  pub fn next_int(&mut self, min: i32, max: i32) -> i32 {
    (self.next() * (max - min) as f64).floor() as i32 + min
  }

  pub fn next_float(&mut self, min: f64, max: f64) -> f64 {
    self.next() * (max - min) + min
  }

  pub fn choice<T: Clone>(&mut self, array: &[T]) -> T {
    let idx = self.next_int(0, array.len() as i32);
    array[idx as usize].clone()
  }
}
