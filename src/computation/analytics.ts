import { RiskEvent } from '../types';

/**
 * Calculate customer analytics summary from event history
 */
export function calculateCustomerAnalytics(
  customerId: string,
  events: RiskEvent[]
): {
  totalEvents: number;
  eventsByCategory: Record<string, number>;
  temporalAggregation: {
    lastMonth: number;
    lastQuarter: number;
    lastYear: number;
  };
  averageTimeBetweenEventsDays: number;
} {
  const now = new Date();
  const oneMonthAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
  const oneQuarterAgo = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);
  const oneYearAgo = new Date(now.getTime() - 365 * 24 * 60 * 60 * 1000);

  const eventsByCategory: Record<string, number> = {};
  let lastMonthCount = 0;
  let lastQuarterCount = 0;
  let lastYearCount = 0;

  const timestamps: number[] = [];

  for (const event of events) {
    eventsByCategory[event.type] = (eventsByCategory[event.type] || 0) + 1;

    const eventTime = event.timestamp.getTime();
    timestamps.push(eventTime);

    if (eventTime >= oneMonthAgo.getTime()) {
      lastMonthCount++;
    }
    if (eventTime >= oneQuarterAgo.getTime()) {
      lastQuarterCount++;
    }
    if (eventTime >= oneYearAgo.getTime()) {
      lastYearCount++;
    }
  }

  let averageTimeBetweenEventsDays = 0;
  if (timestamps.length > 1) {
    timestamps.sort((a, b) => a - b);
    let totalDiff = 0;
    for (let i = 1; i < timestamps.length; i++) {
      totalDiff += timestamps[i] - timestamps[i - 1];
    }
    averageTimeBetweenEventsDays = (totalDiff / (timestamps.length - 1)) / (24 * 60 * 60 * 1000);
  }

  return {
    totalEvents: events.length,
    eventsByCategory,
    temporalAggregation: {
      lastMonth: lastMonthCount,
      lastQuarter: lastQuarterCount,
      lastYear: lastYearCount,
    },
    averageTimeBetweenEventsDays,
  };
}
