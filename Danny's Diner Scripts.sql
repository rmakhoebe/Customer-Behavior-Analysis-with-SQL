SELECT*
FROM members

SELECT*
FROM menu

SELECT*
FROM sales

--1. What is the total amount each customer spent at the restaurant?

SELECT sales.customer_id, SUM(menu.price) AS Total_Spend
FROM menu
JOIN sales
ON menu.product_id = sales.product_id
GROUP BY sales.customer_id

-- 2. How many days has each customer visited the restaurant?

SELECT customer_id, COUNT(DISTINCT order_date) as Days_visited
FROM sales
GROUP BY customer_id


-- 3. What was the first item from the menu purchased by each customer?

WITH CTE AS (
			SELECT sales.customer_id, MIN(sales.order_date) as FOD
			FROM sales
			GROUP BY sales.customer_id
			)
SELECT CTE.customer_id,CTE.FOD,menu.product_name
FROM CTE
JOIN sales
ON CTE.customer_id = sales.customer_id
AND CTE.FOD = sales.order_date
JOIN menu
ON menu.product_id = sales.product_id

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT TOP 1 sales.product_id, menu.product_name, COUNT(sales.product_id) as Count_Of_sales
FROM sales
JOIN menu
ON sales.product_id = menu.product_id
GROUP BY sales.product_id, menu.product_name
ORDER BY 3 DESC


-- 5. Which item was the most popular for each customer?
WITH CTE AS ( 
			SELECT sales.customer_id, menu.product_name, COUNT(sales.product_id) as Count_Of_Sales,
			RANK() OVER (PARTITION BY sales.customer_id ORDER BY COUNT(sales.product_id) DESC) as rank_num
			FROM sales
			JOIN menu
			ON menu.product_id = sales.product_id
			GROUP BY sales.customer_id, menu.product_name
			--ORDER BY sales.customer_id
			)
SELECT customer_id, product_name
FROM CTE
WHERE rank_num = 1

-- 6. Which item was purchased first by the customer after they became a member?
WITH CTE AS (
			SELECT sales.customer_id, sales.order_date,sales.product_id, menu.product_name,
			RANK() OVER (PARTITION BY sales.customer_id ORDER BY sales.order_date) AS ranking
			FROM members
			JOIN sales
			ON members.customer_id = sales.customer_id
			AND members.join_date <= sales.order_date --This is also valid without the equal sign because
													--it is not clear whether customer made a purchase before joining on the same day or after
			JOIN menu
			ON sales.product_id = menu.product_id
			)
SELECT customer_id,product_name
FROM CTE
WHERE ranking = 1;



-- 7. Which item was purchased just before the customer became a member?

WITH CTE AS (
				SELECT sales.customer_id,sales.order_date, menu.product_name,
				RANK() OVER (PARTITION BY sales.customer_id ORDER BY sales.order_date DESC) as ranking
				FROM sales
				JOIN members
				ON members.customer_id = sales.customer_id
				AND 
				members.join_date > sales.order_date
				JOIN menu
				ON menu.product_id = sales.product_id
			)
SELECT customer_id,product_name
FROM CTE
WHERE ranking = 1;

-- 8. What is the total items and amount spent for each member before they became a member?

SELECT sales.customer_id, count(*) as total_items, sum(menu.price) as Amount_spent
FROM sales
JOIN members
ON sales.customer_id = members.customer_id
AND
sales.order_date < members.join_date
JOIN menu
ON menu.product_id = sales.product_id
GROUP BY sales.customer_id



-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

WITH CTE AS (
				SELECT 
					CASE 
						WHEN menu.product_name = 'sushi' THEN (menu.price*20)
						ELSE (menu.price*10)
						END As Points,
				sales.customer_id, menu.product_name, menu.price
				FROM sales
				JOIN menu
				ON menu.product_id = sales.product_id
			)
SELECT customer_id, sum(Points) as Total_points
FROM CTE
GROUP BY customer_id

/* 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - 
how many points do customer A and B have at the end of January?*/

WITH CTE AS (
			SELECT sales.customer_id, sales.order_date,members.join_date, menu.product_name,
					CASE
						WHEN sales.order_date BETWEEN members.join_date AND DATEADD(day,7,members.join_date)
						THEN menu.price*20
						WHEN menu.product_name = 'sushi' THEN (menu.price*20)
						ELSE (menu.price*10)
						END As Points
			FROM sales
			LEFT JOIN members
			ON members.customer_id = sales.customer_id
			--AND sales.order_date = members.join_date
			JOIN menu
			ON sales.product_id = menu.product_id
			WHERE MONTH(sales.order_date) = '01' AND sales.customer_id IN ('A','B') --OR 'members.join_date is not NULL'
			)
SELECT customer_id, SUM(Points) as TotalPoints
FROM CTE
GROUP BY customer_id;

--11. Recreate the table output using the available data

SELECT sales.customer_id, sales.order_date, menu.product_name, menu.price,
		CASE
			WHEN sales.order_date >= members.join_date THEN 'Y'
			ELSE 'N'
		END As Member_Status
from sales
JOIN menu
ON menu.product_id = sales.product_id
LEFT JOIN members
ON members.customer_id = sales.customer_id


--12. Rank all the things based on results from question 11. If Member_status is 'N' then ranking is NULL:

WITH CTE AS (
			SELECT sales.customer_id, sales.order_date, menu.product_name, menu.price,
					CASE
						WHEN sales.order_date >= members.join_date THEN 'Y'
						ELSE 'N'
					END As Member_Status
			from sales
			JOIN menu
			ON menu.product_id = sales.product_id
			LEFT JOIN members
			ON members.customer_id = sales.customer_id
			)
SELECT*,
	CASE
		WHEN Member_Status = 'N' THEN NULL
		ELSE RANK() OVER (PARTITION BY customer_id, Member_Status ORDER BY order_date)
	END as Ranking
FROM CTE