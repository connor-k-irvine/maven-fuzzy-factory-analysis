use maven_fuzzy_factory;

-- Row counts
WITH validate AS (
SELECT 
	'website_sessions' AS table_name, 
    COUNT(*) AS row_count,
    min(website_session_id) as PK_min,
    max(website_session_id) as PK_max, 
    max(website_session_id)-min(website_session_id)+1  
		AS seq_check
	FROM website_sessions
UNION ALL
SELECT 'website_pageviews', 
	COUNT(*),
    min(website_pageview_id),
    max(website_pageview_id),
	max(website_pageview_id)-min(website_pageview_id)+1
	FROM website_pageviews
UNION ALL
SELECT 'products', 
	COUNT(*),
    min(product_id),
    max(product_id),
    max(product_id)-min(product_id)+1
	FROM products
UNION ALL
SELECT 'orders', 
	COUNT(*),
    min(order_id),
    max(order_id),
    max(order_id)-min(order_id)+1
	FROM orders
UNION ALL
SELECT 'order_items', 
	COUNT(*),
    min(order_item_id),
    max(order_item_id),
    max(order_item_id)-min(order_item_id)+1
	FROM order_items
UNION ALL
SELECT 'order_item_refunds', 
	COUNT(*),
    min(order_item_refund_id),
    max(order_item_refund_id),
    max(order_item_refund_id)-min(order_item_refund_id)+1
	FROM order_item_refunds
UNION ALL
SELECT 'maven_fuzzy_factory_data_dictionary', 
	COUNT(*),
    null,
    null,
    null
	FROM maven_fuzzy_factory_data_dictionary
)

select table_name, row_count, PK_min, PK_max, seq_check,
	case
		when seq_check is null then 'N/A'
        when row_count = seq_check then 'SAME'
        else 'DIFF'
	end as validation_status
from validate;

-- Check relationships
select wp.website_pageview_id as wp_id, ws.website_session_id as ws_id
	from website_pageviews wp
    left join website_sessions ws
    on wp.website_session_id = ws.website_session_id
    where ws.website_session_id is null;

select 	o.order_id,
		'products' as problem_table,
        o.primary_product_id as missing_id
	from orders o
    where not exists (
		select 1
        from products p
        where p.product_id = o.primary_product_id
        )
        
union all

select 	o.order_id,
		'website_sessions' as problem_table,
        o.website_session_id as missing_id
	from orders o
	where not exists (
		select 1
        from website_sessions ws
        where ws.website_session_id = o.website_session_id
    );

select 	oi.order_item_id,
		'orders' as problem_table,
        oi.order_id as missing_id
	from order_items oi
    where not exists(
		select o.order_id
			from orders o
            where o.order_id = oi.order_id
    )

union all

select oi.order_item_id,
	'products' as problem_table,
    oi.product_id as missing_id
    from order_items oi
    where not exists(
		select p.product_id
			from products p
            where p.product_id = oi.product_id
    );
    
select 	oir.order_item_refund_id,
		'order_item' as problem_table,
		oir.order_item_id as missing_id
	from order_item_refunds oir
    where not exists(
		select oi.order_item_id
			from order_items oi
            where oi.order_item_id = oir.order_item_id
    )
    
union all

select 	oir.order_item_refund_id,
		'orders' as problem_table,
		oir.order_id as missing_id
	from order_item_refunds oir
    where not exists(
		select o.order_id
			from orders o
            where o.order_id = oir.order_id
    );

	-- Check to see if (orders and order_items):
		-- Total items puchases match up
        -- Exactly one primary item exists for each order
        -- primary item matches
        -- total price and cogs match
select 	o.order_id,
		o.primary_product_id as recorded_primary_product,
        o.items_purchased,
        count(oi.order_item_id) as total_items_count,
        max(case 
				when oi.is_primary_item = 1 then oi.product_id
			end) as actual_primary_product,
		count(case
				when oi.is_primary_item = 1 then 1
			end) as primary_count,
		o.price_usd as recorded_price,
        coalesce(sum(oi.price_usd), 0) as actual_price,
        
        o.cogs_usd as recorded_cogs,
        coalesce(sum(oi.cogs_usd), 0) as actual_cogs
	from orders o
    left join order_items oi
		on oi.order_id = o.order_id
    group by o.order_id
    having 	o.items_purchased <> total_items_count 
			or recorded_primary_product <> actual_primary_product
            or primary_count <> 1
            or recorded_price <> actual_price
            or recorded_cogs <> actual_cogs;	
	

	-- Make sure the refunds are accurate
		-- Every refund is associated with an actual order item
			-- Since order_item was checked with order, we know that order_item is accurately linked
		-- No refund happened before when the item was purchased
        -- Refund does not exceed the item's selling price
select 	oir.order_item_refund_id,
		oi.order_item_id as order_item_id_at_order_item,
		oir.order_item_id as order_item_id_at_refund,
        oi.order_id as item_order_id,
        oir.order_id as refund_order_id,
        oir.refund_amount_usd,
        oi.created_at as purchase_date,
        oir.created_at as refund_date,
        oir.refund_amount_usd
	from order_item_refunds oir
    left join order_items oi
	 	on oi.order_item_id = oir.order_item_id
	where oi.order_item_id is null 
		or oir.order_item_id is null
        or oir.order_id is null
		or oir.order_id <> oi.order_id
        or oir.created_at < oi.created_at
        or oir.refund_amount_usd > oi.price_usd
        or oir.refund_amount_usd <= 0;

	-- Check refund for partial refunds for an item
select 	oi.order_item_id,
		oi.price_usd as item_price,
        count(order_item_refund_id) as refund_count,
        sum(oir.refund_amount_usd) as total_refunded
	from order_items oi
	join order_item_refunds oir
    on oir.order_item_id = oi.order_item_id
    group by oi.order_item_id, item_price
    having total_refunded > oi.price_usd;

	-- S&Gs time range (19MAR2012 - 19MAR2015)
select min(created_at), max(created_at) from orders;

-- checking the nulls

select 	sum(order_id is null) as order_id_nulls,
		sum(created_at is null) as created_at_null,
		sum(website_session_id is null) as website_session_null,
        sum(user_id is null) as user_id_null,
        sum(primary_product_id is null) as primary_product_id_null,
        sum(items_purchased is null) as items_purchased_null,
        sum(price_usd is null) as price_usd_null,
        sum(cogs_usd is null) as cogs_usd_null
	from orders;

select	sum(order_item_refund_id is null) as order_item_refund_id_null,
		sum(created_at is null) as created_at_null,
        sum(order_item_id is null) as order_item_id_null,
        sum(order_id is null) as order_id_null,
        sum(refund_amount_usd is null) as refund_amount_usd_null
	from order_item_refunds;

select	sum(order_item_id is null) as order_item_id_null,
		sum(created_at is null) as created_at_null,
        sum(order_id is null) as order_id_null,
        sum(product_id is null) as product_id_null,
        sum(is_primary_item is null) as is_primary_item_null,
        sum(price_usd is null) as price_usd_null,
        sum(cogs_usd is null) as cogs_usd_null
	from order_items;

select	sum(product_id is null) as product_id_null,
		sum(created_at is null) as created_at_null,
        sum(product_name is null) as product_name_null
	from products;

select	sum(website_pageview_id is null) as website_pageview_id_null,
		sum(created_at is null) as created_at_null,
        sum(website_session_id is null) as website_session_id,
        sum(pageview_url is null) as pageview_url
	from website_pageviews;

select	sum(website_session_id is null) as website_session_id_null,
		sum(created_at is null) as created_at_null,
        sum(user_id is null) as user_id_null,
        sum(is_repeat_session is null) as is_repeat_session_null,
        sum(utm_source is null) as utm_source_null,
        sum(utm_campaign is null) as utm_campaign_null,
        sum(utm_content is null) as utm_content_null,
        sum(device_type is null) as device_type_null,
        sum(http_referer is null) as http_refrer_null
	from website_sessions;
    
select	sum(`table` is null) as table_name_null,
		sum(field is null) as field_name_null,
		sum(`description` is null) as description_null
	from maven_fuzzy_factory_data_dictionary;
    

-- check boolean
select 	is_repeat_session,
		count(*) as row_count
	from website_sessions
    group by is_repeat_session;

select 	is_primary_item,
		count(*) as row_count
        from order_items
        group by is_primary_item;

-- check prices

select *
	from order_items
    where price_usd < 0
    or cogs_usd < 0;

select * 
	from orders
    where items_purchased <= 0
    or price_usd < 0
    or cogs_usd < 0;

