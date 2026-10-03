-- (1) how many website visits turned into orders by which campaign
select * 
	from vw_campaign_conversion 
    order by session_count desc;

-- (2) Product performance for each campaign
select *
	from vw_product_by_campaign
    order by product_id, campaign_units desc;

-- (3) How does campaign performance differ by device and source
select *
	from vw_campaign_device_and_source_success
    order by 
		utm_campaign,
		utm_source,
		conversion_rate_pct desc;
        
-- (4) How did pageview behavior and funnel progression differ
-- between mobile and desktop sessions
select *
	from vw_page_ending_validation
    order by 
		device_type,
		avg_pageviews_per_session desc;

	-- (5) What was the furthest funnel stage reached by nonconverting sessions,
	-- broken down by device?
select *
	from vw_furthest_stage_for_non_orders
    order by
		device_type,
		max_funnel_stage;

-- (6) At which funnel transition is the largest drop-off for desktop versus mobile
select * from vw_device_funnel;

-- (7) Which products generate the most revenue and gross profit, 
-- and which have the strongest margins
select *
	from vw_product_profitability
    order by
		gross_margin_pct desc;
        
-- (8) Which products lose the most value through refunds
select *
	from vw_product_refunds
    order by refund_as_pct_of_revenue desc;
 
-- (9) How did the monthly sales perform by device
-- Date note: Sales recorded during that month compared with refunds processed during that month.
select *
	from vw_monthly_device_performance
    order by
		device_type,
		`year_month`;