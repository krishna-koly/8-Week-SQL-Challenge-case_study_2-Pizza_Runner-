select * from customer_orders;
select * from pizza_names;
select * from pizza_recipes;
select * from pizza_toppings;
select * from runner_orders;
select * from runners;

#SQL mode changing for group by clase -- important --
SET @@sql_mode = SYS.LIST_ADD(@@sql_mode, 'ONLY_FULL_GROUP_BY');
SELECT @@sql_mode;

-- Data Cleaning --
update customer_orders
set exclusions  = 'null'
where exclusions = '' or exclusions is null;
  
update customer_orders
set extras = 'null'
where extras = '' or extras is null;

update runner_orders
set cancellation = 'null'
where cancellation = '' or cancellation is null;

-- End of Data Cleaning -- 

-- Questions With Answers--
-- 1 How many pizzas were ordered?--
select count(pizza_id) as Total_pizza_ordered
from customer_orders;
-- 2 How many unique customer orders were made? --

select count(distinct(customer_id)) as unique_orders
from customer_orders;

-- 3 How many successful orders were delivered by each runner?

select runner_id, count(distinct(order_id)) as successful_orders
from runner_orders
where pickup_time <> 'null'
group by runner_id;

-- Explanation : As the orders are cancelled either by reataurant or by customer they dont have any pickup time.
#cause they are cancelled . so here we can also calculate the sucessful orders that are delivered from
#pickup_time or even it can be calculated by distance also. --

-- Alternative Solution :

select runner_id, count(*) as successful_orders
from pizza_runner.runner_orders
where cancellation = 'null'
group by runner_id;

-- Explanation : as we updated the runner_orders table(cancellation columb  with null value)before
# so by using calncellation columb we can solve this problem.

-- 04 How many of each type of pizza was delivered?

select p.pizza_name, count(*) as delivered
from runner_orders r
join customer_orders  co using(order_id)
join pizza_names p  using(pizza_id)
where cancellation = 'null'
group by p.pizza_name;

-- 05 How many Vegetarian and Meatlovers were ordered by each customer? --
select distinct(customer_id),pizza_name, count(*) as total_ordered_pizza 
from customer_orders
join pizza_names using(pizza_id)
group by customer_id,pizza_name
order by customer_id, total_ordered_pizza desc;

-- 06 -- What was the maximum number of pizzas delivered in a single order?
select co.order_id, count(*) as max_delivered_pizza
from runner_orders r
join customer_orders co using(order_id)
where cancellation = 'null'
group by co.order_id
order by max_delivered_pizza desc
limit 1;

-- 07 -- For each customer, how many delivered pizzas had at least 1 change and
# how many had no changes?

select distinct(customer_id),
sum(case when (exclusions <> 'null' and exclusions !=0 ) or (extras is not null and extras!=0) then 1
else 0
end) as At_least_one_change,
sum(case 
  when (exclusions is null or exclusions = 0) and (extras is null or extras = 0) then 1
        else 0
        end ) as NoChange
from customer_orders c
join runner_orders r using (order_id)
where r.cancellation = 'null'
group by customer_id;

-- 08 -How many pizzas were delivered that had both exclusions and extras?--

select customer_id,pizza_id
from customer_orders c 
join runner_orders  r using(order_id)
where exclusions <> 'null' and extras <>'null' and r.cancellation = 'null';

-- 09 What was the total volume of pizzas ordered for each hour of the day?

select extract(hour from order_time) as Hour_wise_order, count(pizza_id) as Ordered_pizza
from customer_orders
group by Hour_wise_order
order by Hour_wise_order;

-- 10 What was the volume of orders for each day of the week?
select dayname(order_time) as Weekdays, count(order_id)as Order_volume
from customer_orders
group by Weekdays
order by Order_volume desc;


-- ----------------------B. Runner and Customer Experience ---------------------------

-- 01 How many runners signed up for each 1 week period? --
select extract(week from registration_date + 3) as weeks , count(runner_id) as register_runner
from runners
group by weeks;

-- 02 What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
select runner_id, round(avg(timestampdiff(minute,order_time, pickup_time)),1) as AvgTime
from runner_orders
join customer_orders using (order_id)
group by runner_id
order by AvgTime;

-- 03 Is there any relationship between the number of pizzas and how long the order takes to prepare? --
 with cte as (
 select c.order_time,count(c.order_id) as ordered_pizza,
round(timestampdiff(minute, order_time,pickup_time),1) as Prepared_time
from runner_orders r
join customer_orders c using (order_id)
where cancellation is null
group by c.order_time
)
select ordered_pizza, Prepared_time
from cte
group by ordered_pizza
order by Prepared_time;

-- Alternative Solution --
WITH CTE AS (SELECT c.order_id,
                    COUNT(c.order_id) as pizza_order,
                    order_time, pickup_time, 
                    round(timestampdiff(minute, order_time,pickup_time),1) as time
            FROM customer_orders as c 
            INNER JOIN runner_orders as r 
            ON c.order_id = r.order_id
            WHERE r.cancellation IS NULL 
            GROUP BY  c.order_id,order_time, pickup_time
            )
SELECT pizza_order,
       AVG(time) AS avg_time_per_order, 
      (AVG(time)/ pizza_order) AS avg_time_per_pizza
FROM CTE
GROUP BY pizza_order;

-- -- -- 
-- 04 What was the average distance travelled for each customer?

select c.customer_id, round(Avg(distance),2)as average
from customer_orders c
join runner_orders r
using(order_id)
where r.distance <> 'null'
group by c.customer_id;

-- 05 What was the difference between the longest and shortest delivery times for all orders? --

with cte as 
(
select c.order_id,order_time, pickup_time, timestampdiff(minute,order_time,pickup_time) as difference
from customer_orders c
join runner_orders r using (order_id)
where r.cancellation = 'null'
group by c.order_id,order_time,pickup_time
)
select max(difference) as longest, min(difference)as shortest,max(difference)- min(difference) as total_time_difference
from cte;

-- 06 What was the average speed for each runner for each delivery and do you notice any trend for these values? --

select runner_id,order_id,distance,duration,round(distance *60/duration,1) AS average_speed
from runner_orders r
where r.cancellation = 'null'
order by runner_id;

-- 07 -- What is the successful delivery percentage for each runner? --

with cte as(
select runner_id, sum(case
when distance != 0 then 1
else 0
end) as percsucc, count(order_id) as TotalOrders
from runner_orders
group by runner_id)
select runner_id,round((percsucc/TotalOrders)*100) as Successfulpercentage 
from cte
order by runner_id;
-- -------------------------Ingredient Optimisation -- -----------------------------------

-- 01 What are the standard ingredients for each pizza?

-- Normalize Pizza Recipe table
drop table if exists pizza_recipes1;
create table pizza_recipes1 
(
 pizza_id int,
    toppings int);
insert into pizza_recipes1
(pizza_id, toppings) 
values
(1,1),
(1,2),
(1,3),
(1,4),
(1,5),
(1,6),
(1,8),
(1,10),
(2,4),
(2,6),
(2,7),
(2,9),
(2,11),
(2,12);

select * from pizza_names;
select * from pizza_recipes1;
select * from pizza_toppings;

-- Main Solution --

select pn.pizza_name, group_concat(pt.topping_name) as StandardToppings
from pizza_names pn
join pizza_recipes1  pr using(pizza_id)
join pizza_toppings pt on pr.toppings = pt.topping_id
GROUP BY pn.pizza_name;

-- End Solution --


-- 02 --What was the most commonly added extra?

#Easy Solution Coming Soon --
