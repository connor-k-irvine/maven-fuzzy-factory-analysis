create database if not exists maven_fuzzy_factory;

use maven_fuzzy_factory;

-- drop table if exists website_sessions;

create table website_sessions(
	website_session_id int primary key,
    created_at datetime,
    user_id int,
    is_repeat_session boolean,
    utm_source varchar(100),
    utm_campaign varchar(100),
    utm_content varchar(100),
    device_type varchar(100),
    http_referer varchar(500)
);

-- drop table if exists website_pageviews;

create table website_pageviews(
		website_pageview_id int primary key,
        created_at datetime,
        website_session_id int,
        pageview_url varchar(100),
        
        foreign key (website_session_id)
			references website_sessions(website_session_id)
);

-- drop table if exists products;

create table products(
		product_id int primary key,
        created_at datetime,
        product_name varchar(100)
);

-- drop table if exists orders;

create table orders(
		order_id int primary key,
		created_at datetime,
        website_session_id int,
        user_id int,
        primary_product_id int,
        items_purchased int,
        price_usd decimal(10,2),
        cogs_usd decimal(10,2),
        
        foreign key (website_session_id)
			references website_sessions(website_session_id),
		foreign key(primary_product_id)
			references products(product_id)
);

-- drop table if exists order_items;

create table order_items(
		order_item_id int primary key,
		created_at datetime,
        order_id int,
        product_id int,
        is_primary_item boolean,
        price_usd decimal(10,2),
        cogs_usd decimal(10,2),
        
        foreign key (order_id)
			references orders(order_id),
		foreign key (product_id)
			references products(product_id)
);

-- drop table if exists order_item_refunds;

create table order_item_refunds(
		order_item_refund_id int primary key,
        created_at datetime,
        order_item_id int,
		order_id int,
        refund_amount_usd decimal(10, 2),
        
        foreign key (order_item_id)
			references order_items(order_item_id),
		foreign key (order_id)
			references orders(order_id)
);

-- drop table if exists maven_fuzzy_factory_data_dictionary;

create table maven_fuzzy_factory_data_dictionary(
		`table` varchar(100),
        field varchar(100),
		`description` text,
        primary key (`table`, field)
);