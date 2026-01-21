import { Customer } from '../types';

/**
 * Mock customer service - in production this would fetch from a database
 */
export class CustomerService {
  private customers: Map<string, Customer> = new Map();

  /**
   * Get or create a customer
   */
  getCustomer(customerId: string): Customer {
    if (!this.customers.has(customerId)) {
      const age = 25 + Math.floor(Math.random() * 50);
      const relationshipYears = Math.floor(Math.random() * 10);
      const paymentHistory = Array.from({ length: 12 }, () => 
        Math.random() * 100
      );

      this.customers.set(customerId, {
        id: customerId,
        age,
        relationshipYears,
        paymentHistory,
      });
    }

    return this.customers.get(customerId)!;
  }
}
