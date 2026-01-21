/**
 * Seeded pseudo-random number generator for reproducibility
 */
export class SeededRandom {
  private seed: number;

  constructor(seed: number = Date.now()) {
    this.seed = seed;
  }

  /**
   * Generate a random number between 0 and 1
   */
  next(): number {
    this.seed = (this.seed * 9301 + 49297) % 233280;
    return this.seed / 233280;
  }

  /**
   * Generate a random integer between min (inclusive) and max (exclusive)
   */
  nextInt(min: number, max: number): number {
    return Math.floor(this.next() * (max - min)) + min;
  }

  /**
   * Generate a random number between min (inclusive) and max (exclusive)
   */
  nextFloat(min: number, max: number): number {
    return this.next() * (max - min) + min;
  }

  /**
   * Select a random element from an array
   */
  choice<T>(array: T[]): T {
    return array[this.nextInt(0, array.length)];
  }
}
