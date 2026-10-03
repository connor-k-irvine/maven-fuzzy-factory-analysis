use maven_fuzzy_factory;
-- ========================================================
-- Marketing acquisition
-- ========================================================

	-- (1) how many website visits turned into orders by which campaign
select 	ws.utm_campaign,
		count(distinct ws.website_session_id) as session_count, -- number of visits for that campagin
        count(distinct o.order_id) as orders_count, -- number of orders based on each campaign
        round(
			count(distinct o.order_id) * 100
            / nullif(count(distinct ws.website_session_id), 0),
            2
        ) as conversion_rate_pct, -- pct of visits of that campaign that became orders
        round(
			count(distinct ws.website_session_id) * 100
            / nullif(sum(count(distinct ws.website_session_id)) over(), 0),
            2
        ) as share_of_campaign_traffic_pct -- pct of all tagged sessions belonging to that campaign
	from website_sessions ws
    left join orders o
		on o.website_session_id = ws.website_session_id
	where ws.utm_campaign is not null
	group by ws.utm_campaign
    order by session_count desc;


	-- (2) Product performance for each campaign
with campaign_product_sales as (
	select 	p.product_id,
			p.product_name,
			ws.utm_campaign,
			count(oi.order_item_id) as campaign_units,
            sum(oi.price_usd) as product_revenue,
            sum(oi.cogs_usd) as product_cogs,
            sum(oi.price_usd - oi.cogs_usd) as product_gross_profit
		from order_items oi
		join products p
			on p.product_id = oi.product_id
		join orders o
			on o.order_id = oi.order_id
		join website_sessions ws
			on ws.website_session_id = o.website_session_id
		where ws.utm_campaign is not null
		group by p.product_id,
				 p.product_name,
				 ws.utm_campaign
)

select 	*,
		round(
			campaign_units * 100
            / nullif(
				sum(campaign_units) over(partition by product_id),
				0),
            2
        ) as pct_product_units_by_campaign,
        round(
				campaign_units * 100
				/ nullif(
					sum(campaign_units) over(partition by utm_campaign),
                    0),
            2
        ) as pct_campaign_units_by_product
	from campaign_product_sales
	order by product_id, campaign_units desc;


	-- (3) How does campaign performance differ by device and source
select 	ws.utm_campaign,
		ws.device_type,
        ws.utm_source,
        
        round(
			count(distinct o.website_session_id) * 100
            / nullif(count(distinct ws.website_session_id), 0),
            2
        ) as conversion_rate_pct,
        
        count(distinct ws.website_session_id) as session_count,
        count(distinct o.order_id) as order_count,
        round(sum(o.price_usd),2) as revenue_usd,
        round(sum(o.cogs_usd), 2) as cogs_usd,
        round(sum(o.price_usd - o.cogs_usd), 2) as gross_profit_usd,
        
        round(
			sum(o.price_usd)
            / nullif(count(distinct ws.website_session_id), 0),
            2
        ) as revenue_per_session
	from website_sessions ws
    left join orders o
		on o.website_session_id = ws.website_session_id
	where ws.utm_campaign is not null
    group by 
			utm_campaign, 
            device_type, 
            utm_source
    order by 
			ws.utm_campaign,
            ws.utm_source,
            conversion_rate_pct desc;


-- ===========================================================
-- Wesbite pipeline
-- ===========================================================

	-- (4) How did pageview behavior and funnel progression differ
    -- between mobile and desktop sessions

with ranked_pageviews as(
	select	wp.website_session_id,
			wp.website_pageview_id,
            wp.pageview_url,
            wp.created_at,
            row_number() over(
				partition by wp.website_session_id
                order by
					wp.created_at desc,
                    wp.website_pageview_id desc
            ) as pageview_rank,
            row_number() over(
				partition by wp.website_session_id
                order by
					wp.created_at,
                    wp.website_pageview_id
            ) as pageview_count
		from website_pageviews wp    
 )
 select	ws.device_type,
		count(distinct ws.website_session_id) as total_sessions,
        round(avg(rp.pageview_count), 2) as avg_pageviews_per_session,
        case
			when order_id is not null and rp.pageview_url = '/thank-you-for-your-order'
				then 'ORDER END ON THANK YOU PAGE'
			when order_id is not null and rp.pageview_url <> '/thank-you-for-your-order'
				then 'ORDER NOT END ON THANK YOU PAGE'
			when order_id is null and rp.pageview_url = '/thank-you-for-your-order'
				then 'NO ORDER END ON THANK YOU PAGE. POSSIBLE ERROR' -- none came out in error
			when order_id is null and rp.pageview_url <> '/thank-you-for-your-order'
				then 'WEBSITE VISIT NOT ENDING IN AN ORDER'
			else 'WEBSITE VISIT NOT ENDING IN AN ORDER'
		end as ending_result_error_check,
        case
			when order_id is not null
				then 1
			else 0
		end as order_complete_bool
	from website_sessions ws
    left join orders o
		on ws.website_session_id = o.website_session_id
	left join ranked_pageviews rp
		on ws.website_session_id = rp.website_session_id
        and rp.pageview_rank = 1
	group by 
		ws.device_type,
		ending_result_error_check,
        order_complete_bool
	order by 
		ws.device_type,
		avg_pageviews_per_session desc;


	-- (5) What was the furthest funnel stage reached by nonconverting sessions,
	-- broken down by device?
with funnel_ranks as(
	select	wp.website_session_id,
			wp.website_pageview_id,
			case
				when wp.pageview_url = '/home'
					or wp.pageview_url like '/lander-%'
                    then 1
                    
				when wp.pageview_url = '/products'
                    then 2
                    
				when wp.pageview_url like '/the-%'
                    then 3
                    
				when wp.pageview_url = '/cart'
                    then 4
                    
				when wp.pageview_url = '/shipping'
                    then 5
                    
				when wp.pageview_url like '/billing%'
                    then 6
				
                when wp.pageview_url = '/thank-you-for-your-order'
                    then 7
                    
				else 0
			end as funnel_stage,
			case
				when wp.pageview_url = '/home'
					or wp.pageview_url like '/lander-%'
                    then 'LANDING'
                    
				when wp.pageview_url = '/products'
                    then 'PRODUCT LISTING'
                    
				when wp.pageview_url like '/the-%'
                    then 'PRODUCT DETAIL'
                    
				when wp.pageview_url = '/cart'
                    then 'CART'
                    
				when wp.pageview_url = '/shipping'
                    then 'SHIPPING'
                    
				when wp.pageview_url like '/billing%'
                    then 'BILLING'
				
                when wp.pageview_url = '/thank-you-for-your-order'
                    then 'COMPLETED'
                    
				else 'ERROR'
			end as funnel_stage_desc
		from website_pageviews wp
),

max_websession_funnel as (
	select 	fr.website_session_id,
			max(fr.funnel_stage) as max_funnel_stage,
            case max(fr.funnel_stage)
				when 1 then 'LANDING'
                WHEN 2 THEN 'PRODUCT LISTING'
                WHEN 3 THEN 'PRODUCT DETAIL'
                WHEN 4 THEN 'CART'
                WHEN 5 THEN 'SHIPPING'
                WHEN 6 THEN 'BILLING'
                WHEN 7 THEN 'COMPLETED'
                ELSE 'ERROR'
            end as max_funnel_stage_desc
		from funnel_ranks fr
		group by fr.website_session_id
)
select	ws.device_type,
		mwf.max_funnel_stage,
        mwf.max_funnel_stage_desc,
        count(ws.website_session_id) as count_highest_funnel,
        round(
			count(ws.website_session_id) * 100
            / nullif(sum(Count(ws.website_session_id)) over(partition by ws.device_type), 0)
            ,2
        ) as pct_nonorders_by_device_type
	from website_sessions ws
	left join orders o
		on ws.website_session_id = o.website_session_id
	join max_websession_funnel mwf
		on ws.website_session_id = mwf.website_session_id
	where o.order_id is null
	group by
		ws.device_type,
        mwf.max_funnel_stage,
        mwf.max_funnel_stage_desc
	order by
		ws.device_type,
        mwf.max_funnel_stage;


	-- (6) At which funnel transition is the largest drop-off for desktop versus mobile
with funnel_ranks as(
	select 	wp.website_session_id,
			wp.pageview_url,
			case
				when wp.pageview_url = '/home'
					or wp.pageview_url like '/lander%'
                    then 1
				when wp.pageview_url = '/products'
					then 2
				when wp.pageview_url like '/the-%'
					then 3
				when wp.pageview_url = '/cart'
					then 4
				when wp.pageview_url = '/shipping'
					then 5
				when wp.pageview_url like '/billing%'
					then 6
				when wp.pageview_url = '/thank-you-for-your-order'
					then 7
				else 0
			end as funnel_rank
		from website_pageviews wp
), 

max_funnel_ranks as(
	select fr.website_session_id,
			max(funnel_rank) as max_funnel_stage
		from funnel_ranks as fr
        group by
			fr.website_session_id
),

funnel_rank_and_max as(
	select 	mfr.website_session_id,
            case when mfr.max_funnel_stage >= 1 then 1 else 0 end as reached_landing,
			case when mfr.max_funnel_stage >= 2 then 1 else 0 end as reached_product_listing,
			case when mfr.max_funnel_stage >= 3 then 1 else 0 end as reached_product_detail,
			case when mfr.max_funnel_stage >= 4 then 1 else 0 end as reached_cart,
			case when mfr.max_funnel_stage >= 5 then 1 else 0 end as reached_shipping,
			case when mfr.max_funnel_stage >= 6 then 1 else 0 end as reached_billing,
			case when mfr.max_funnel_stage >= 7 then 1 else 0 end as reached_completion
		from max_funnel_ranks as mfr
)

select 	ws.device_type,
        sum(frm.reached_landing) as reached_landing,
        sum(frm.reached_product_listing) as reached_product_listing,
        sum(frm.reached_product_detail) as reached_product_detail,
        sum(frm.reached_cart) as reached_cart,
        sum(frm.reached_shipping) as reached_shipping,
        sum(frm.reached_billing) as reached_billing,
        sum(frm.reached_completion) as reached_completion,
        
        
        round(sum(frm.reached_product_listing)*100/
			nullif(sum(frm.reached_landing), 0) ,2) 
				as landing_to_product_listing_pct,
        
        round(sum(frm.reached_product_detail)*100/
			nullif(sum(frm.reached_product_listing), 0) ,2) 
				as product_listing_to_product_detail_pct,
		
        round(sum(frm.reached_cart)*100/
			nullif(sum(frm.reached_product_detail), 0) ,2) 
				as product_detail_to_cart_pct,
                
		round(sum(frm.reached_shipping)*100/
			nullif(sum(frm.reached_cart), 0) ,2) 
				as cart_to_shipping_pct,
                
		round(sum(frm.reached_billing)*100/
			nullif(sum(frm.reached_shipping), 0) ,2) 
				as shipping_to_billing_pct,
                
		round(sum(frm.reached_completion)*100/
			nullif(sum(frm.reached_billing), 0) ,2) 
				as billing_to_completion_pct
	from website_sessions ws
	left join funnel_rank_and_max as frm
		on ws.website_session_id = frm.website_session_id
    group by
		ws.device_type;        
        
-- ==============================================================
-- Revenue
-- ==============================================================

	-- (7) Which products generate the most revenue and gross profit, 
    -- and which have the strongest margins
select
		p.product_name,
        count(oi.order_item_id) as units_sold,
        sum(oi.price_usd) as revenue_usd,
        sum(oi.cogs_usd) as cogs_usd,
        sum(oi.price_usd) - sum(oi.cogs_usd) as gross_profit_usd,
        round(
			(sum(oi.price_usd) - sum(oi.cogs_usd)) * 100
            / nullif(sum(oi.price_usd), 0)
            ,2
        ) as gross_margin_pct
	from order_items oi
    join products p
		on oi.product_id = p.product_id
	group by 
		oi.product_id,
        p.product_name
	order by
		gross_margin_pct desc;


	-- (8) Which products lose the most value through refunds
with refunds_by_products as (
	select 	oi.product_id,
			p.product_name,
			count(distinct oir.order_item_id) as units_refunded,
            sum(oir.refund_amount_usd) as refund_amount_usd
		from order_items oi
        inner join order_item_refunds oir
			on oi.order_item_id = oir.order_item_id
		left join products p
			on oi.product_id = p.product_id
		group by
			oi.product_id,
            p.product_name
),   
revenue_values as (
	select
			p.product_name,
            oi.product_id,
			count(oi.order_item_id) as units_sold,
			sum(oi.price_usd) as revenue_usd,
			sum(oi.cogs_usd) as cogs_usd,
			sum(oi.price_usd) - sum(oi.cogs_usd) as gross_profit_usd
		from order_items oi
		join products p
			on oi.product_id = p.product_id
		group by 
			oi.product_id,
			p.product_name
)
select 	rv.product_name,
		rv.units_sold,
        rbp.units_refunded,
        round((rbp.units_refunded / rv.units_sold)*100, 2) as unit_refund_rate,
        rbp.refund_amount_usd,
        round((rbp.refund_amount_usd / rv.revenue_usd)*100, 2) as refund_as_pct_of_revenue,
        rv.revenue_usd - rbp.refund_amount_usd as revenue_aft_refund
	from revenue_values rv
    join refunds_by_products rbp
		on rv.product_id = rbp.product_id
	order by refund_as_pct_of_revenue desc;


	-- (9) How did the monthly sales perform by device
    -- Date note: Sales recorded during that month compared with refunds processed during that month.
with refund_by_date_and_device as(
	select 	date_format(oir.created_at, '%Y-%m') as `year_month_refund`,
			ws.device_type,
			sum(oir.refund_amount_usd) as refund_amount_usd,
			count(distinct oir.order_item_id) as units_refunded
	from orders o
	join website_sessions ws
		on o.website_session_id = ws.website_session_id
	left join order_item_refunds oir
		on o.order_id = oir.order_id
	group by
		ws.device_type,
		`year_month_refund`
	having refund_amount_usd <> 0
),

orders_by_date_and_device as(
	select	date_format(o.created_at, '%Y-%m') as `year_month_orders`,
			ws.device_type,
            count(distinct o.order_id) as orders,
			sum(o.items_purchased) as units_sold,
			sum(o.price_usd) as revenue_usd,
			sum(o.cogs_usd) as cogs_usd,
			sum(o.price_usd) - sum(o.cogs_usd) as gross_profit_usd,
			round(((sum(o.price_usd) - sum(o.cogs_usd))/nullif(sum(o.price_usd), 0))*100, 2) as gross_margin_pct,
			round((sum(o.price_usd)/nullif(count(distinct o.order_id), 0)), 2) as average_order_value
	from orders o
    join website_sessions ws
		on o.website_session_id = ws.website_session_id
	group by
		ws.device_type,
        `year_month_orders`
)

select	odd.device_type,
		odd.year_month_orders as `year_month`,
        odd.orders,
        odd.units_sold,
        coalesce(rdd.units_refunded, 0) as units_refunded,
        odd.units_sold - coalesce(rdd.units_refunded, 0) as net_units_aft_refunds,
        coalesce(round((rdd.units_refunded / nullif(odd.units_sold, 0))*100, 2), 0) as refund_rate,
        coalesce(
					round((odd.revenue_usd - coalesce(rdd.refund_amount_usd, 0))*100
					/nullif(odd.revenue_usd, 0), 
					2), 
				0) as revenue_remained_aft_refund_pct,
        odd.revenue_usd,
        odd.cogs_usd,
        odd.gross_profit_usd,
        round(odd.revenue_usd / odd.units_sold, 2) as average_sale_amount,
        odd.gross_margin_pct,
        odd.average_order_value,
        coalesce(rdd.refund_amount_usd, 0) as refund_amount_usd,
        odd.revenue_usd - coalesce(rdd.refund_amount_usd, 0) as revenue_aft_refunds
	from orders_by_date_and_device odd
	left join refund_by_date_and_device rdd
		on 	odd.year_month_orders = rdd.year_month_refund
			and odd.device_type = rdd.device_type
	order by
		odd.device_type,
        `year_month`;