-- Explore each table in database .

select * from gdb023.dim_customer;
select * from gdb023.dim_product;
select * from  gdb023.fact_gross_price;
select * from gdb023.fact_manufacturing_cost;
select * from gdb023.fact_pre_invoice_deductions ;
select * from gdb023.fact_sales_monthly;

-- 1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.

select market 
from gdb023.dim_customer 
where customer = 'Atliq Exclusive' and region = 'APAC' 
group by market;

-- 2. What is the percentage of unique product increase in 2021 vs 2020?
With productCount_2020 as 
(select count(distinct (product_code)) as unique_products_2020
from gdb023.fact_sales_monthly
where fiscal_year = 2020
),
productCount2021 as 
(select count(distinct(product_code)) as unique_products_2021
from gdb023.fact_sales_monthly 
where fiscal_year = 2021 
)
select unique_products_2020,
	   unique_products_2021,
       round(100* (unique_products_2021 -  unique_products_2020)/unique_products_2020 ,2) as percentage_chg
from productCount_2020 ,productCount2021 ;

-- 3. Provide a report with all the unique product counts for each segment and  sort them in descending order of product counts.
select segment ,count(distinct(product_code)) as product_count
from gdb023.dim_product 
group by segment
order by product_count desc;

-- 4. Follow-up: Which segment had the most increase in unique products in 2021 vs 2020?
with  product_unique_count_2020  as 
(select segment ,count(distinct(p.product_code)) as unique_product_2020 
from gdb023.dim_product p
join gdb023.fact_sales_monthly s on p.product_code = s.product_code
where s.fiscal_year = 2020
group by p.segment 
),
product_unique_count_2021 as 
(select segment, count(distinct(p.product_code) )as unique_product_2021
from gdb023.dim_product p
join gdb023.fact_sales_monthly s on p.product_code = s.product_code
where s.fiscal_year = 2021 
group by p.segment 
)
select p_21.segment, unique_product_2020, unique_product_2021 ,
   (unique_product_2021 - p_20.unique_product_2020 )as difference 
from product_unique_count_2020 p_20
join product_unique_count_2021 p_21 
on p_20.segment = p_21.segment 
ORDER BY difference DESC;



-- 5.Get the products that have the highest and lowest manufacturing costs?

select p.product_code , p.product , manufacturing_cost
from gdb023.dim_product p
join gdb023.fact_manufacturing_cost m
on p.product_code = m.product_code 
where manufacturing_cost 
in ((select max(manufacturing_cost) from gdb023.fact_manufacturing_cost ) ,
	( select min(manufacturing_cost) from gdb023.fact_manufacturing_cost ));
                            
/* 6. Generate a report which contains the top 5 customers who received an
average high pre_invoice_discount_pct for the fiscal year 2021 and in the
Indian market */

SELECT c.customer_code, c.customer, 
round(AVG(pre_invoice_discount_pct),4) AS average_discount_percentage
FROM gdb023.fact_pre_invoice_deductions d
JOIN gdb023.dim_customer c
ON d.customer_code = c.customer_code
WHERE c.market = "India" AND fiscal_year = "2021"
GROUP BY 1,2
ORDER BY average_discount_percentage DESC
LIMIT 5;



/*7. Get the complete report of the Gross sales amount for the customer “Atliq
Exclusive” for each month. This analysis helps to get an idea of low and
high-performing months and take strategic decisions.
The final report contains these columns: Month , Year , Gross sales Amount */

select year(date) as Year  ,  month(date) as Month , 
	   round(sum(gross_price*sold_quantity),2) as gross_sale
from gdb023.fact_sales_monthly m
join gdb023.dim_customer c 
on m.customer_code = c.customer_code 
join gdb023.fact_gross_price  g
on m.fiscal_year = g.fiscal_year
where c.customer = 'Atliq Exclusive'
group by 1,2
order by 1,2 ;


/* 8. In which quarter of 2020, got the maximum total_sold_quantity? The final
output contains these fields sorted by the total_sold_quantity, Quarter , total_sold_quantity */

with 2020_quntity_sold as 
(select quarter(date) as Quarter , 
  sum(sold_quantity) as  total_sold_quantity
from gdb023.fact_sales_monthly 
where year(date) = '2020'
group by  Quarter
)
select Quarter , total_sold_quantity
from 2020_quntity_sold
order by total_sold_quantity  desc ;

/* 9. Which channel helped to bring more gross sales in the fiscal year 2021
and the percentage of contribution? The final output contains these fields,
channel, gross_sales_mln , percentage */ 

with gross_sales_2021 as 
(select  channel ,
	  sum(gross_price*sold_quantity) as gross_sales_mln 
from gdb023.fact_sales_monthly m
join gdb023.dim_customer c  
on m.customer_code = c.customer_code 
join gdb023.fact_gross_price  g
on m.fiscal_year = g.fiscal_year
where m.fiscal_year = '2021' 
group by c.channel
order by gross_sales_mln 
)
select  channel , gross_sales_mln,  
round(gross_sales_mln * 100 / sum(gross_sales_mln) over() ,2) as percent 
from  gross_sales_2021
order by gross_sales_mln  desc
limit 3;


/*10. Get the Top 3 products in each division that have a high
total_sold_quantity in the fiscal_year 2021? The final output contains these
fields,
division
product_code
product
total_sold_quantity
rank_order */


WITH quantity_sold_2021 AS
 ( SELECT p.product_code, p.division,
        p.product, SUM(m.sold_quantity) AS total_sold_quantity,
        RANK() OVER (PARTITION BY p.division ORDER BY SUM(m.sold_quantity) DESC) AS rank_order
    FROM gdb023.dim_product p
    JOIN gdb023.fact_sales_monthly m 
    ON p.product_code = m.product_code
    WHERE m.fiscal_year = '2021'
    GROUP BY p.product_code, p.division, p.product
)
SELECT
    product_code, division,product,total_sold_quantity, rank_order
FROM quantity_sold_2021
WHERE rank_order <= 3
ORDER BY rank_order;

