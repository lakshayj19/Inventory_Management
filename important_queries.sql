------------------------------------------------------
------------------------------------------------------
-- DATABASE OPTIMISATION
------------------------------------------------------
------------------------------------------------------
-- normalizing the database to improve data integrity and reduce redundancy:
	-- for relating weather and inventory on Weather ID
	ALTER TABLE inventory ADD `Weather ID` VARCHAR(10);
	UPDATE inventory i
	JOIN weather w ON i.`Weather Condition` = w.weather_type
	SET i.`Weather ID` = w.weather_id;
	ALTER TABLE inventory DROP COLUMN `Weather Condition`;
	ALTER TABLE weather ADD PRIMARY KEY (weather_id);
	ALTER TABLE inventory
	ADD CONSTRAINT fk_weather
	FOREIGN KEY (`Weather ID`) REFERENCES weather(weather_id);

---------------------------------------------------
	-- for relating product_category and inventory on Category ID
	ALTER TABLE inventory ADD `Category ID` VARCHAR(10);
	UPDATE inventory i
	JOIN  product_category pc ON i.`Category` = pc.category_type
	SET i.`Category ID` = pc.category_id;
	ALTER TABLE inventory DROP COLUMN `Category`;
	ALTER TABLE product_category ADD PRIMARY KEY (category_id);
	ALTER TABLE inventory
	ADD CONSTRAINT fk_category
	FOREIGN KEY (`Category ID`) REFERENCES product_category(category_id);

---------------------------------------------------
	-- For relating region and inventory on Region ID
	ALTER TABLE inventory ADD `Region ID` VARCHAR(10);
	UPDATE inventory i
	JOIN region r ON i.`Region` = r.region_type
	SET i.`Region ID` = r.region_id;
	ALTER TABLE inventory DROP COLUMN `Region`;
	ALTER TABLE region ADD PRIMARY KEY (region_id);
	ALTER TABLE inventory
	ADD CONSTRAINT fk_region
	FOREIGN KEY (`Region ID`) REFERENCES region(region_id);

---------------------------------------------------
	-- For relating season and inventory on SeasonID
	ALTER TABLE inventory ADD `Season ID` VARCHAR(10);
	UPDATE inventory i
	JOIN Season s ON i.`Seasonality` = s.season_type
	SET i.`Season ID` = s.season_id;
	ALTER TABLE inventory DROP COLUMN `Seasonality`;
	ALTER TABLE season ADD PRIMARY KEY (season_id);
	ALTER TABLE inventory
	ADD CONSTRAINT fk_season
	FOREIGN KEY (`Season ID`) REFERENCES season(season_id);

-- CREATING INDEXES------------------
		CREATE INDEX `PRIMARY` ON product_category(category_id);
		CREATE INDEX `PRIMARY` ON region(region_id);
		CREATE INDEX `PRIMARY` ON season(season_id);
		CREATE INDEX `PRIMARY` ON weather(weather_id);
        
--------------------------------------------
---------------------------------------------
-- TECHNICAL CLEANING
---------------------------------------------
---------------------------------------------

-- Detect duplicates -----------------
		SELECT `Store ID`, `Product ID`, `Date`, COUNT(*)
		FROM `inventory`
		GROUP BY `Store ID`, `Product ID`, `Date`
		HAVING COUNT(*) > 1;

-- Delete duplicates-------------------
		DELETE FROM inventory
		WHERE (`Store ID`, `Product ID`, `Date`) IN (
		  SELECT `Store ID`, `Product ID`, `Date`, COUNT(*)
		  FROM `inventory`
		  GROUP BY `Store ID`, `Product ID`, `Date`
		  HAVING COUNT(*) > 1
		  );
  
-- Identifying Null values--------------------------
-- Check for missing Units Sold,Units Ordered,Price,Competitor Pricing,Demand Forecast,Inventory Level,Discount
		SELECT * FROM inventory WHERE `Units Sold` IS NULL;
		SELECT * FROM inventory WHERE `Units Ordered` IS NULL;
		SELECT * FROM inventory WHERE `Price` IS NULL;
		SELECT * FROM inventory WHERE `Competitor Pricing` IS NULL;
		SELECT * FROM inventory WHERE `Demand Forecast` IS NULL;
		SELECT * FROM inventory WHERE `Inventory Level` IS NULL;
		SELECT * FROM inventory WHERE `Discount` IS NULL;

-- Replace NULLs and negatives with 0-------------------------
		UPDATE inventory SET `Units Sold` = 0 WHERE `Units Sold`<0 or `Units Sold` IS NULL;
		UPDATE inventory SET `Units Ordered` = 0 WHERE `Units Ordered`<0 or `Units Ordered` IS NULL;
		UPDATE inventory SET `Price` = 0 WHERE `Price`<0 or `Price` IS NULL;
		UPDATE inventory SET `Competitor Pricing` = 0 WHERE `Competitor Pricing` or `Competitor Pricing` IS NULL;
		UPDATE inventory SET `Demand Forecast` = 0 WHERE `Demand Forecast`<0 or `Demand Forecast` IS NULL;
		UPDATE inventory SET `Inventory Level` = 0 WHERE `Inventory Level`<0 or `Inventory Level` IS NULL;
		UPDATE inventory SET `Discount` = 0 WHERE `Discount`<0 or `Discount` IS NULL;

-- fixing decimals for columns having float datatype----------------------
		ALTER TABLE inventory 
		  MODIFY `Price` DECIMAL(10,2),
		  MODIFY `Competitor Pricing` DECIMAL(10,2),
		  MODIFY `Demand Forecast` DECIMAL(10,2);

----------------------------------------------------------
----------------------------------------------------------
-- SQL QUERIES FOR ANALYTICAL OUTPUTS
----------------------------------------------------------
----------------------------------------------------------
-- total inventory data grouped by month, store, and product
		SELECT  
		  DATE_FORMAT(`Date`, '%b %Y') AS months,
		  `Store ID`, 
		  `Product ID`,
		  SUM(`Inventory Level`) AS total_inventory,
		  SUM(`Demand Forecast`) AS total_demand,
		  SUM(`Units Ordered`) AS total_ordered
		FROM inventory
		GROUP BY DATE_FORMAT(`Date`, '%b %Y'), `Store ID`, `Product ID`
		ORDER BY DATE_FORMAT(`Date`, '%b %Y'), `Store ID`, `Product ID`;

-- for identifying supply vs. demand status(overstock or stockout) on a monthly basis
		SELECT  
		DATE_FORMAT(`Date`, '%b %Y') AS months,
		`Store ID`, 
		`Product ID`,
		SUM(`Inventory Level`) + SUM(`Units Ordered`) AS total_supply,
		SUM(`Demand Forecast`) AS total_demand,
		IF(
			SUM(`Demand Forecast`) - (SUM(`Inventory Level`) + SUM(`Units Ordered`)) < 0,
			'overstock',
			'stockout'
		) AS fullfillment_status
		FROM inventory
		GROUP BY  
		DATE_FORMAT(`Date`, '%b %Y'),`Store ID`, `Product ID`
		ORDER BY 
		months, `Store ID`, `Product ID`;

-- how many times overstocking and stockout happens
		SELECT 
			fullfillment_status,
			COUNT(*) AS status_count
		FROM (
			SELECT  
				DATE_FORMAT(`Date`, '%b %Y') AS months,
				`Store ID`, 
				`Product ID`,
				SUM(`Inventory Level`) + SUM(`Units Ordered`) AS total_supply,
				SUM(`Demand Forecast`) AS total_demand,
				-- Determine fulfillment status
				IF(
					SUM(`Demand Forecast`) - (SUM(`Inventory Level`) + SUM(`Units Ordered`)) < 0,
					'overstock',
					'stockout'
				) AS fullfillment_status
				FROM inventory
				GROUP BY 
				DATE_FORMAT(`Date`, '%b %Y'), `Store ID`, `Product ID`
		) AS monthly_status
		GROUP BY fullfillment_status;
        
-- Total Inventory Across All Stores
		SELECT 
			`Product ID`, 
			SUM(`Inventory Level`) AS total_stock
		FROM inventory
		GROUP BY `Product ID`;
        
-- Inventory Turnover Rate
		SELECT 
			`Product ID` ,
			ROUND(SUM(`Units Sold`) / NULLIF(AVG(`Inventory Level`), 0), 2) AS turnover_ratio
		FROM inventory
		GROUP BY `Product ID`;

-- Stockout Rate Per Product
		SELECT 
			`Product ID`,
			ROUND(
				COUNT(CASE WHEN `Inventory Level` = 0 THEN 1 END) / COUNT(*),
				2
			) AS stockout_rate
		FROM inventory
		GROUP BY `Product ID`;
        
-- Most Frequently Sold Products
		SELECT 
			`Product ID` , 
			SUM(`Units Sold`) AS total_sales
		FROM inventory
		GROUP BY `Product ID`
		ORDER BY total_sales DESC
		LIMIT 10;
-- Slow moving products
        SELECT 
			`Product ID` , 
			SUM(`Units Sold`) AS total_sales
		FROM inventory
		GROUP BY `Product ID`
		ORDER BY total_sales ASC
		LIMIT 10;
        
-- Overstock Alert (Idle Inventory)
		SELECT 
			`Product ID` , 
			AVG(`Inventory Level`) AS avg_stock,
			SUM(`Units Sold`) AS total_units_sold
		FROM inventory
		GROUP BY `Product ID`
		HAVING avg_stock > 1000 AND total_units_sold < 100;

-- Aging Inventory by Product
		SELECT 
			`Product ID` ,
			DATEDIFF('2024-01-01', `Date`) AS age_in_days
		FROM inventory
		GROUP BY `Product ID`;

-- Daily Sales Trend
		SELECT 
			`Date`, 
			SUM(`Units Sold`) AS total_daily_sales
		FROM inventory
		GROUP BY `Date`
		ORDER BY `Date`;

-- Top Performing Stores
		SELECT 
			`Store ID`, 
			SUM(`Units Sold`) AS total_sales
		FROM inventory
		GROUP BY `Store ID`
		ORDER BY total_sales DESC;

-- % Contribution of Each Store
		SELECT 
			`Store ID`, 
			SUM(`Units Sold`) AS total_sales,
			ROUND(100.0 * SUM(`Units Sold`) / (SELECT SUM(`Units Sold`) FROM inventory), 2) AS sales_percentage
		FROM inventory
		GROUP BY `Store ID`
		ORDER BY total_sales DESC;

-- Average Discount per Product
		SELECT 
			`Product ID` , 
			ROUND(AVG(`Discount`), 2) AS avg_discount
		FROM inventory
		GROUP BY `Product ID`;

-- Weather Impact on Sales
		SELECT 
			i.`Weather ID`, 
			w.weather_type, 
			ROUND(AVG(i.`Units Sold`), 2) AS avg_units_sold
		FROM inventory i
		JOIN weather w ON i.`Weather ID` = w.weather_id
		GROUP BY i.`Weather ID`
		ORDER BY avg_units_sold DESC;
        
-- Sales by Product Category
		SELECT 
			pc.category_type, 
			SUM(i.`Units Sold`) AS total_sales,
            ROUND(100.0 * SUM(i.`Units Sold`) / (SELECT SUM(`Units Sold`) FROM inventory),2
					) AS 'category_sales_%'
		FROM inventory i
		JOIN product_category pc 
			ON i.`Category ID` = pc.category_id
		GROUP BY pc.category_type
		ORDER BY total_sales DESC;

-- Regional Inventory Summary and units sold
		SELECT 
			r.region_type, 
			ROUND(AVG(i.`Inventory Level`), 2) AS avg_inventory,
            SUM(i.`Units Sold`) AS total_units_sold
		FROM inventory i
		JOIN region r 
			ON i.`Region` = r.region_id
		GROUP BY r.region_type
		ORDER BY avg_inventory DESC;

-- Store-wise Seasonal Performance
		SELECT 
			s.season_type, 
			i.`Store ID` , 
			SUM(i.`Units Sold`) AS seasonal_sales
		FROM inventory i
		JOIN season s 
			ON i.`Seasonality` = s.season_id
		GROUP BY s.season_type, i.`Store ID`
		ORDER BY seasonal_sales DESC;

--  average price vs. competitor pricing per product, per store, per month 
		SELECT 
			DATE_FORMAT(`Date`, '%b %Y') AS months,
			`Store ID`, 
			`Product ID`,
			ROUND(AVG(`Price`), 2) AS avg_price,
			ROUND(AVG(`Competitor Pricing`), 2) AS avg_competitor_price,
			ROUND(AVG(`Competitor Pricing`) - AVG(`Price`), 2) AS price_gap
		FROM inventory
		GROUP BY 
			DATE_FORMAT(`Date`, '%b %Y'), 
			`Store ID`, 
			`Product ID`
		ORDER BY 
			months, 
			`Store ID`, 
			`Product ID`;

-- deviation of demand forecast from units sold by rmse
		SELECT 
			DATE_FORMAT(`Date`, '%b %Y') AS month,
			`Product ID`,
			ROUND(SQRT(AVG(POW(`Demand Forecast` - `Units Sold`, 2))), 2) AS rmse
		FROM inventory
		GROUP BY month, `Product ID`
		ORDER BY month, `Product ID`;

--  revenue and discount metrics per product and store by month
		SELECT 
		  DATE_FORMAT(`Date`, '%b %Y') AS month_year,
		  `Store ID`,
		  `Product ID`,

		  SUM(`Units Sold`) AS total_units_sold,
		  ROUND(AVG(`Price`), 2) AS avg_unit_price,
		  ROUND(AVG(`Discount`), 2) AS avg_discount_percent,

		  -- Net revenue after discount
		  ROUND(SUM(`Units Sold` * `Price` * (1 - `Discount` / 100)), 2) AS net_revenue,

		  -- Revenue lost due to discounting
		  ROUND(
			SUM(`Units Sold` * `Price`) - SUM(`Units Sold` * `Price` * (1 - `Discount` / 100)),
			2
		  ) AS revenue_lost_to_discount,

		  -- Net unit revenue (average price after discount)
		  ROUND(
			SUM(`Price` * (1 - `Discount` / 100)) / NULLIF(SUM(`Units Sold`), 0),
			2
		  ) AS net_unit_revenue
		FROM inventory
        GROUP BY 
		  DATE_FORMAT(`Date`, '%b %Y'),
		  `Store ID`,
		  `Product ID`
		ORDER BY net_revenue DESC;
        
-- calculate a dynamic reorder point for each product by month
		SELECT 
			`Product ID`,
			YEAR(`Date`) AS 'year',
			MONTH(`Date`) AS 'month',
			
			-- Dynamic reorder point as 1.5x monthly sales
			ROUND(SUM(`Units Sold`) * 1.5, 0) AS dynamic_reorder_point,
			SUM(`Inventory Level`) AS total_inventory,

			-- Reorder status based on comparison
			CASE 
				WHEN SUM(`Inventory Level`) <= ROUND(SUM(`Units Sold`) * 1.5, 0)
				THEN 'Reorder Needed'
				ELSE 'Stock Sufficient'
			END AS status
            FROM inventory
			GROUP BY 
			`Product ID`,
			YEAR(`Date`),
			MONTH(`Date`)
			ORDER BY `year`, `month`, `Product ID`;

-- product whose reorder needed
		SELECT *
		FROM (
		  SELECT 
			`Product ID`,
			YEAR(`Date`) AS 'year',
			MONTH(`Date`) AS 'month',
			
			ROUND(SUM(`Units Sold`) * 1.5, 0) AS dynamic_reorder_point,
			SUM(`Inventory Level`) AS total_inventory,

			CASE 
			  WHEN SUM(`Inventory Level`) <= ROUND(SUM(`Units Sold`) * 1.5, 0)
			  THEN 'Reorder Needed'
			  ELSE 'Stock Sufficient'
			END AS status
		  FROM inventory
		  GROUP BY 
			`Product ID`, 
			YEAR(`Date`), 
			MONTH(`Date`)
		) AS monthly_status
		WHERE status = 'Reorder Needed'
		ORDER BY `year`, `month`, `Product ID`;

-- Fast-Selling vs Slow-Moving Products
		SELECT 
		  `Product ID`,
		  ROUND(SUM(`Units Sold`) / COUNT(DISTINCT `Date`), 2) AS avg_daily_sales,
		  CASE 
			WHEN ROUND(SUM(`Units Sold`) / COUNT(DISTINCT `Date`), 2) >= 50 THEN 'Fast-Selling'
			WHEN ROUND(SUM(`Units Sold`) / COUNT(DISTINCT `Date`), 2) < 10 THEN 'Slow-Moving'
			ELSE 'Moderate'
		  END AS product_speed
		FROM inventory
		GROUP BY `Product ID`
		ORDER BY avg_daily_sales DESC;

-- Stock Adjustments to Reduce Holding Cost
		SELECT 
		  `Product ID`,
		  SUM(`Inventory Level`) AS total_inventory,
		  ROUND(SUM(`Units Sold`) / COUNT(DISTINCT `Date`), 2) AS avg_daily_sales,
		  ROUND(SUM(`Inventory Level`) / NULLIF(SUM(`Units Sold`), 0), 1) AS stock_days_coverage,
		  CASE 
			WHEN SUM(`Inventory Level`) > 1000 AND SUM(`Units Sold`) < 100 
			  THEN 'Reduce Stock'
			WHEN SUM(`Inventory Level`) < 100 AND SUM(`Units Sold`) > 500 
			  THEN 'Increase Stock'
			ELSE 'Stock OK'
		  END AS stock_adjustment_recommendation
		FROM inventory
		GROUP BY `Product ID`;

-- Forecast Demand Trends Based on Seasonal/Cyclical Data
		SELECT 
		  `Product ID`,
		  `Season`,
		  ROUND(AVG(`Demand Forecast`), 2) AS avg_forecast_demand,
		  ROUND(AVG(`Units Sold`), 2) AS avg_actual_demand,
		  ROUND(AVG(`Demand Forecast`) - AVG(`Units Sold`), 2) AS avg_forecast_error
		FROM inventory
		GROUP BY `Product ID`, `Season`
		ORDER BY `Product ID`, `Season`;

-- Reorder Frequency as Proxy for Reliability
		SELECT 
		  `Product ID`,
		  COUNT(*) AS reorder_events,
		  COUNT(DISTINCT `Date`) AS active_days,
		  ROUND(COUNT(*) / COUNT(DISTINCT `Date`), 2) AS reorder_frequency_ratio
		FROM inventory
		WHERE `Reorder Quantity` > 0
		GROUP BY `Product ID`
		ORDER BY reorder_frequency_ratio DESC;
