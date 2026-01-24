use std::collections::HashMap;
use crate::types::{RiskEvent, AnalyticsSummary, TemporalAggregation};

pub fn calculate_customer_analytics(
    events: &[RiskEvent],
) -> AnalyticsSummary {
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
