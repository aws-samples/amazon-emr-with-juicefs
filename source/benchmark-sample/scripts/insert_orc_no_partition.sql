--
-- adjust the source/text schema (tpcds_10000_text)
-- and target/parquet schema (tpcds_10000_parquet)
-- if necessary
--

use ${db_orc};

insert overwrite table call_center            select * from ${db_txt}.call_center;
insert overwrite table catalog_page           select * from ${db_txt}.catalog_page;
insert overwrite table customer               select * from ${db_txt}.customer;
insert overwrite table customer_address       select * from ${db_txt}.customer_address;
insert overwrite table customer_demographics  select * from ${db_txt}.customer_demographics;
insert overwrite table date_dim               select * from ${db_txt}.date_dim;
insert overwrite table household_demographics select * from ${db_txt}.household_demographics;
insert overwrite table income_band            select * from ${db_txt}.income_band;
insert overwrite table item                   select * from ${db_txt}.item;
insert overwrite table promotion              select * from ${db_txt}.promotion;
insert overwrite table reason                 select * from ${db_txt}.reason;
insert overwrite table ship_mode              select * from ${db_txt}.ship_mode;
insert overwrite table store                  select * from ${db_txt}.store;
insert overwrite table time_dim               select * from ${db_txt}.time_dim;
insert overwrite table warehouse              select * from ${db_txt}.warehouse;
insert overwrite table web_page               select * from ${db_txt}.web_page;
insert overwrite table web_site               select * from ${db_txt}.web_site;
insert overwrite table inventory              select * from ${db_txt}.inventory;
insert overwrite table catalog_sales          select * from ${db_txt}.catalog_sales;
insert overwrite table catalog_returns        select * from ${db_txt}.catalog_returns;
insert overwrite table store_sales            select * from ${db_txt}.store_sales;
insert overwrite table store_returns          select * from ${db_txt}.store_returns;
insert overwrite table web_sales              select * from ${db_txt}.web_sales;
insert overwrite table web_returns            select * from ${db_txt}.web_returns;

