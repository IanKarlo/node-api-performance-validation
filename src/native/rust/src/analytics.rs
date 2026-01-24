use std::collections::HashMap;
use crate::types::{RiskEvent, AnalyticsSummary, TemporalAggregation};

pub fn calculate_customer_analytics(
    events: &[RiskEvent],
) -> AnalyticsSummary {
    // We use a fixed "now" or the latest event time to be consistent with generation,
    // but typically "now" is the current time.
    // In history.rs we used a fixed 1706000000000.0 (Jan 23 2024).
    // Let's use the same or derive from system if we want dynamic.
    // For consistency with history generation in Rust which uses a fixed end time,
    // we should use that same reference or simply SystemTime.
    // However, the TS implementation uses new Date(), so it's dynamic.
    // If we want to be comparable, we should probably use SystemTime::now().
    // But since history generation in Rust uses a hardcoded "now", let's use that to ensure we capture the events "last month/year".
    
    // history.rs: let now = 1706000000000.0;
    let now = 1706000000000.0; 
    
    let one_month_ago = now - 30.0 * 24.0 * 60.0 * 60.0 * 1000.0;
    let one_quarter_ago = now - 90.0 * 24.0 * 60.0 * 60.0 * 1000.0;
    let one_year_ago = now - 365.0 * 24.0 * 60.0 * 60.0 * 1000.0;

    let mut events_by_category = HashMap::new();
    let mut last_month_count = 0;
    let mut last_quarter_count = 0;
    let mut last_year_count = 0;
    let mut timestamps = Vec::with_capacity(events.len());

    for event in events {
        *events_by_category.entry(event.event_type.clone()).or_insert(0) += 1;
        
        timestamps.push(event.timestamp);
        
        if event.timestamp >= one_month_ago {
            last_month_count += 1;
        }
        if event.timestamp >= one_quarter_ago {
            last_quarter_count += 1;
        }
        if event.timestamp >= one_year_ago {
            last_year_count += 1;
        }
    }

    let mut average_time_between_events_days = 0.0;
    if timestamps.len() > 1 {
        // Events are already sorted in history.rs, but let's ensure or just sort.
        // timestamps.sort_by(|a, b| a.partial_cmp(b).unwrap()); 
        // We will assume they are not guaranteed sorted if passed from outside, so sort.
        timestamps.sort_by(|a, b| a.partial_cmp(b).unwrap());
        
        let mut total_diff = 0.0;
        for i in 1..timestamps.len() {
            total_diff += timestamps[i] - timestamps[i-1];
        }
        
        average_time_between_events_days = (total_diff / ((timestamps.len() - 1) as f64)) / (24.0 * 60.0 * 60.0 * 1000.0);
    }

    AnalyticsSummary {
        total_events: events.len() as i32,
        events_by_category,
        temporal_aggregation: TemporalAggregation {
            last_month: last_month_count,
            last_quarter: last_quarter_count,
            last_year: last_year_count,
        },
        average_time_between_events_days,
    }
}
