-- ============================================================
--   ASSIGNMENT 05 — INDEXES, VIEWS & WINDOW FUNCTIONS
--   Database  : BikeStores
--   Topics    : Indexes (Clustered & Non-Clustered)
--               Views
--               ROW_NUMBER / RANK / DENSE_RANK
--               LAG / LEAD
--               COALESCE
-- ============================================================


-- ============================================================
--  SECTION A — INDEXES
-- ============================================================

-- Q1.
-- The marketing team frequently runs campaigns filtered by brand.
-- They search products like this:
--
--   SELECT product_id, product_name, list_price
--   FROM production.products
--   WHERE brand_id = 3;
--
-- This query is slow. Create an appropriate index to fix it.
-- Then run the query to confirm it returns results correctly.
	create nonclustered index idx_brand_id 
	on production.products(brand_id);


-- Q2.
-- The finance team runs a monthly report that filters orders
-- by a date range, for example:
--
--   SELECT order_id, customer_id, order_date
--   FROM sales.orders
--   WHERE order_date BETWEEN '2018-01-01' AND '2018-06-30';
--
-- Create an index to make this query more efficient.
	create nonclustered index idx_order_date 
	on sales.orders(order_date);


-- ============================================================
--  SECTION B — VIEWS
-- ============================================================

-- Q3.
-- The customer support team needs a daily list of all
-- pending and processing orders so they can follow up.
-- Create a view that shows:
--   order_id, customer full name, phone, email,
--   order_date, and order status as a readable label
--   (not a number — use 1=Pending, 2=Processing).
-- After creating it, query the view to see today's workload.
	create view sales.vw_pending_processing_orders
	as
	select 
	o.order_id,
	c.first_name + ' ' + c.last_name as customer_full_name,
	c.phone,
	c.email,
	o.order_date,
	case 
		when o.order_status = 1 then 'Pending'
		when o.order_status = 2 then 'Processing'
		else 'Other'
	end as order_status_label
	from sales.orders o
	join sales.customers c on o.customer_id = c.customer_id

	select * from sales.vw_pending_processing_orders
	  
-- Q4.
-- The inventory manager wants a single view to monitor stock
-- across all stores without writing complex joins every time.
-- Create a view that shows:
--   store_name, product_name, brand_name, category_name, quantity
-- After creating it, query the view to find all products
-- that have fewer than 3 units remaining in any store.
create view production.vw_store_stock
as
	select s.store_name,
	p.product_name,
	b.brand_name,
	c.category_name,
	st.quantity
	from production.stocks st
	join sales.stores s 
	on st.store_id = s.store_id
	join production.products p
	on st.product_id = p.product_id
	join production.brands b 
	on p.brand_id = b.brand_id
	join production.categories c
	on p.category_id = c.category_id
	 
	select * from production.vw_store_stock	
	where quantity < 3
	
-- ============================================================
--  SECTION C — ROW_NUMBER, RANK & DENSE_RANK
-- ============================================================

-- Q5.
-- The sales director wants to see the top 2 best-selling products
-- per store based on total quantity sold.
-- Show store_id, product_id, total_quantity, and their rank within the store.
-- Return only rank 1 and rank 2 for each store.
with sales_per_product as (
	select 
	o.store_id,
	oi.product_id,
	SUM(oi.quantity) as total_quantity
	from sales.orders o
	join sales.order_items oi
	on o.order_id = oi.order_id
	group by o.store_id, oi.product_id
	),
	ranked_sales as (
		select store_id, product_id, total_quantity,
	rank() over (partition by store_id 
	order by total_quantity desc) 
	as sales_rank
from sales_per_product
	)
	select store_id, product_id, total_quantity, sales_rank
	from ranked_sales
	where sales_rank in (1, 2)
	

-- Q6.
-- The pricing team wants to find the 2nd most expensive product
-- in each category.
-- Show category_id, product_name, list_price, and their price rank
-- within the category.
-- Return only the products ranked 2nd in their category.
with ranked_products as (
	select category_id, product_name, list_price,
	RANK() over (partition by category_id
	order by list_price desc) as price_rank
	from production.products
	)
	select category_id, product_name, list_price, price_rank
	from ranked_products
	where price_rank = 2
	


-- Q7.
-- The data team suspects there are duplicate customer records.
-- Use the test table below (already has duplicates built in).
-- Write a query to identify the duplicate rows
-- (same first_name, last_name, and phone).
-- Return only the duplicates — not the original/first occurrence.
--
-- Run this setup first:
--
-- CREATE TABLE test_customers (
--     customer_id  INT,
--     first_name   VARCHAR(50),
--     last_name    VARCHAR(50),
--     phone        VARCHAR(20),
--     city         VARCHAR(50)
-- );
--
-- INSERT INTO test_customers VALUES
--     (1,  'Ali',    'Khan',    '0300-1111111', 'Karachi'),
--     (2,  'Sara',   'Ahmed',   '0321-2222222', 'Lahore'),
--     (3,  'Ali',    'Khan',    '0300-1111111', 'Karachi'),   -- duplicate of 1
--     (4,  'Usman',  'Malik',   '0333-3333333', 'Islamabad'),
--     (5,  'Sara',   'Ahmed',   '0321-2222222', 'Lahore'),   -- duplicate of 2
--     (6,  'Sara',   'Ahmed',   '0321-2222222', 'Lahore'),   -- 3rd copy of 2
--     (7,  'Hina',   'Raza',    '0312-4444444', 'Peshawar');
--
-- Now write your query to find the duplicate rows.
	 
	 
	with duplicate_customers as (
	  select *, ROW_NUMBER() over (partition by first_name, last_name, phone
	  order by customer_id )
	  as rn
	  from test_customers
	  )
	  select customer_id, first_name, last_name, phone, city
	  from duplicate_customers
	  where rn > 1

	   


-- ============================================================
--  SECTION D — LAG, LEAD & COALESCE
-- ============================================================

-- Q8.
-- The finance team wants a month-by-month revenue report for 2017.
-- For each month, show total net sales and how much it grew or
-- dropped compared to the previous month.
-- Show month, net_sales, previous_month_sales, and the difference.
-- Net sales = SUM( quantity * list_price * (1 - discount) )
	
with monthly_sales as (
	select 
	FORMAT(o.order_date, 'yyyy-MM') as month,
	sum(oi.quantity * oi.list_price * (1 - oi.discount)) as net_sales
	from sales.orders o
	join sales.order_items oi
	on o.order_id = oi.order_id
	where YEAR(o.order_date) = 2017
	group by FORMAT(o.order_date, 'yyyy-MM')
	)
	select month, net_sales,
	lag(net_sales) over (order by month) as previous_month_sales,
	net_sales - lag(net_sales) over (order by month) as difference
	from monthly_sales



-- Q9.
-- The product team wants to see each product's price compared to
-- the next cheaper product in the same category.
-- Show product_name, list_price, and the next lower price
-- in the same category.
-- Sort by category_id and list_price descending.

	select 
	p.product_name,
	list_price,
	LEAD(list_price) over (partition by category_id order by list_price desc) 
	as next_lower_price
	from production.products p
	order by category_id, list_price desc

-- Q10.
-- The CRM team is cleaning up customer records.
-- Some customers have no phone number on file.
-- Show each customer's full name, phone, and email.
-- Replace any missing phone with their email address instead.
-- If both are missing, show 'No Contact Info'.
-- Sort by last_name, first_name.
	
	select 
	first_name + ' ' + last_name as full_name,
	COALESCE (phone, email, 'No Contact Info') as contact_info,
	email
	from sales.customers
	ORDER BY last_name, first_name


-- ============================================================
--  END OF ASSIGNMENT 05
-- ============================================================
