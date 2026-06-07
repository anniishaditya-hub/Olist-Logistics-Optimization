Actual Lead Time 

SELECT 
    seller_city,
    COUNT(o.order_id) AS total_orders,
    -- Time it takes for seller to hand over to carrier (The "Warehouse" phase)
    AVG(DATE_DIFF(DATE(order_delivered_carrier_date), DATE(order_purchase_timestamp), DAY)) AS avg_processing_time,
    -- Time it takes for carrier to deliver to customer (The "Road" phase)
    AVG(DATE_DIFF(DATE(order_delivered_customer_date), DATE(order_delivered_carrier_date), DAY)) AS avg_transit_time,
    -- Total actual days elapsed
    AVG(DATE_DIFF(DATE(order_delivered_customer_date), DATE(order_purchase_timestamp), DAY)) AS total_actual_lead_time
FROM `k-project-495709.Olist_Project.Olist_Orders` AS o
JOIN `k-project-495709.Olist_Project.Olist_Items` AS i ON o.order_id = i.order_id
JOIN `k-project-495709.Olist_Project.Olist_Sellers` AS s ON i.seller_id = s.seller_id
WHERE o.order_status = 'delivered' 
  AND o.order_delivered_carrier_date IS NOT NULL
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY seller_city
HAVING total_orders > 20 
ORDER BY total_actual_lead_time DESC
LIMIT 10;

Average Delay per City

SELECT 
    o.order_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    -- 1. Calculating Lead Time (Days from Purchase to Delivery)
    DATE_DIFF(DATE(o.order_delivered_customer_date), DATE(o.order_purchase_timestamp), DAY) AS actual_delivery_days,
    -- 2. Calculating the SLA Gap (Positive = Late, Negative = Early)
    DATE_DIFF(DATE(o.order_delivered_customer_date), DATE(o.order_estimated_delivery_date), DAY) AS sla_gap_days,
    i.price,
    i.freight_value,
    s.seller_city,
    s.seller_state
FROM `k-project-495709.Olist_Project.Olist_Orders` AS o
JOIN `k-project-495709.Olist_Project.Olist_Items` AS i ON o.order_id = i.order_id
JOIN `k-project-495709.Olist_Project.Olist_Sellers` AS s ON i.seller_id = s.seller_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL

Cost vs Actual Lead Time

SELECT 
    ROUND(i.freight_value, -1) AS freight_cost_bucket,
    COUNT(o.order_id) AS total_orders,
    AVG(DATE_DIFF(DATE(o.order_delivered_customer_date), DATE(o.order_purchase_timestamp), DAY)) AS avg_actual_lead_time
FROM `k-project-495709.Olist_Project.Olist_Orders` AS o
JOIN `k-project-495709.Olist_Project.Olist_Items` AS i ON o.order_id = i.order_id
WHERE o.order_status = 'delivered' 
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY freight_cost_bucket
HAVING total_orders > 100
ORDER BY freight_cost_bucket ASC
LIMIT 10;

Overall Performance

CREATE OR REPLACE VIEW `k-project-495709.Olist_Project.Final_Logistics_Master` AS
SELECT 
    o.order_id,
    o.order_purchase_timestamp, 
    s.seller_city,
    s.seller_state,
    i.price,
    i.freight_value,
    DATE_DIFF(DATE(o.order_delivered_customer_date), DATE(o.order_purchase_timestamp), DAY) AS total_lead_time,
    DATE_DIFF(DATE(o.order_delivered_carrier_date), DATE(o.order_purchase_timestamp), DAY) AS processing_time,
    DATE_DIFF(DATE(o.order_delivered_customer_date), DATE(o.order_delivered_carrier_date), DAY) AS transit_time,
    DATE_DIFF(DATE(o.order_delivered_customer_date), DATE(o.order_estimated_delivery_date), DAY) AS sla_gap,
    CASE 
        WHEN DATE_DIFF(DATE(o.order_delivered_customer_date), DATE(o.order_estimated_delivery_date), DAY) > 0 THEN 'Late'
        ELSE 'On-Time/Early'
    END AS delivery_status
FROM `k-project-495709.Olist_Project.Olist_Orders` AS o
JOIN `k-project-495709.Olist_Project.Olist_Items` AS i ON o.order_id = i.order_id
JOIN `k-project-495709.Olist_Project.Olist_Sellers` AS s ON i.seller_id = s.seller_id
WHERE o.order_status = 'delivered' 
  AND o.order_delivered_customer_date IS NOT NULL;

Golden Table 
    
SELECT 
  o.order_id,
  i.seller_id,
  s.seller_city,
  o.order_status,
  -- Time calculations mapped for Excel pivot tables
  DATE_DIFF(DATE(o.order_delivered_customer_date), DATE(o.order_purchase_timestamp), DAY) AS actual_delivery_days,
  DATE_DIFF(DATE(o.order_estimated_delivery_date), DATE(o.order_purchase_timestamp), DAY) AS estimated_delivery_days,
  -- SLA Breach Flag (1 = Late, 0 = On Time)
  CASE 
    WHEN DATE(o.order_delivered_customer_date) > DATE(o.order_estimated_delivery_date) THEN 1 
    ELSE 0 
  END AS sla_breach_flag,
  ROUND(i.price, 2) AS item_revenue

FROM 
  `k-project-495709.Olist_Project.Olist_Orders` AS o
INNER JOIN 
  `k-project-495709.Olist_Project.Olist_Items` AS i 
  ON o.order_id = i.order_id
INNER JOIN 
  `k-project-495709.Olist_Project.Olist_Sellers` AS s 
  ON i.seller_id = s.seller_id

WHERE 
  o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL;
