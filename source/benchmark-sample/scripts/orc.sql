--
-- adjust the schema name if necessary
-- currently (tpcds_10000_parquet)
--

create database if not exists ${db_orc} location '${location}';
use ${db_orc};

--
-- unpartitioned tables
--
 create table if not exists call_center            like ${db_txt}.call_center            stored as orc;
 create table if not exists catalog_page           like ${db_txt}.catalog_page           stored as orc;
 create table if not exists customer               like ${db_txt}.customer               stored as orc;
 create table if not exists customer_address       like ${db_txt}.customer_address       stored as orc;
 create table if not exists customer_demographics  like ${db_txt}.customer_demographics  stored as orc;
 create table if not exists date_dim               like ${db_txt}.date_dim               stored as orc;
 create table if not exists household_demographics like ${db_txt}.household_demographics stored as orc;
 create table if not exists income_band            like ${db_txt}.income_band            stored as orc;
 create table if not exists item                   like ${db_txt}.item                   stored as orc;
 create table if not exists promotion              like ${db_txt}.promotion              stored as orc;
 create table if not exists reason                 like ${db_txt}.reason                 stored as orc;
 create table if not exists ship_mode              like ${db_txt}.ship_mode              stored as orc;
 create table if not exists store                  like ${db_txt}.store                  stored as orc;
 create table if not exists time_dim               like ${db_txt}.time_dim               stored as orc;
 create table if not exists warehouse              like ${db_txt}.warehouse              stored as orc;
 create table if not exists web_page               like ${db_txt}.web_page               stored as orc;
 create table if not exists web_site               like ${db_txt}.web_site               stored as orc;

--
-- partitioned tables
--

 create table if not exists inventory
(
  inv_item_sk                 int,
  inv_warehouse_sk            int,
  inv_quantity_on_hand        int
)
partitioned by (inv_date_sk int)
stored as orc;

 create table if not exists store_sales
(
  ss_sold_time_sk             int,
  ss_item_sk                  int,
  ss_customer_sk              int,
  ss_cdemo_sk                 int,
  ss_hdemo_sk                 int,
  ss_addr_sk                  int,
  ss_store_sk                 int,
  ss_promo_sk                 int,
  ss_ticket_number            bigint,
  ss_quantity                 int,
  ss_wholesale_cost           decimal(7,2),
  ss_list_price               decimal(7,2),
  ss_sales_price              decimal(7,2),
  ss_ext_discount_amt         decimal(7,2),
  ss_ext_sales_price          decimal(7,2),
  ss_ext_wholesale_cost       decimal(7,2),
  ss_ext_list_price           decimal(7,2),
  ss_ext_tax                  decimal(7,2),
  ss_coupon_amt               decimal(7,2),
  ss_net_paid                 decimal(7,2),
  ss_net_paid_inc_tax         decimal(7,2),
  ss_net_profit               decimal(7,2)
)
partitioned by (ss_sold_date_sk int)
stored as orc;

 create table if not exists store_returns
(
  sr_return_time_sk         int,
  sr_item_sk                int,
  sr_customer_sk            int,
  sr_cdemo_sk               int,
  sr_hdemo_sk               int,
  sr_addr_sk                int,
  sr_store_sk               int,
  sr_reason_sk              int,
  sr_ticket_number          bigint,
  sr_return_quantity        int,
  sr_return_amt             decimal(7,2),
  sr_return_tax             decimal(7,2),
  sr_return_amt_inc_tax     decimal(7,2),
  sr_fee                    decimal(7,2),
  sr_return_ship_cost       decimal(7,2),
  sr_refunded_cash          decimal(7,2),
  sr_reversed_charge        decimal(7,2),
  sr_store_credit           decimal(7,2),
  sr_net_loss               decimal(7,2)
)
partitioned by (sr_returned_date_sk int)
stored as orc;

 create table if not exists catalog_returns
(
  cr_returned_time_sk       int,
  cr_item_sk                int,
  cr_refunded_customer_sk   int,
  cr_refunded_cdemo_sk      int,
  cr_refunded_hdemo_sk      int,
  cr_refunded_addr_sk       int,
  cr_returning_customer_sk  int,
  cr_returning_cdemo_sk     int,
  cr_returning_hdemo_sk     int,
  cr_returning_addr_sk      int,
  cr_call_center_sk         int,
  cr_catalog_page_sk        int,
  cr_ship_mode_sk           int,
  cr_warehouse_sk           int,
  cr_reason_sk              int,
  cr_order_number           bigint,
  cr_return_quantity        int,
  cr_return_amount          decimal(7,2),
  cr_return_tax             decimal(7,2),
  cr_return_amt_inc_tax     decimal(7,2),
  cr_fee                    decimal(7,2),
  cr_return_ship_cost       decimal(7,2),
  cr_refunded_cash          decimal(7,2),
  cr_reversed_charge        decimal(7,2),
  cr_store_credit           decimal(7,2),
  cr_net_loss               decimal(7,2)
)
partitioned by (cr_returned_date_sk int)
stored as orc;

 create table if not exists catalog_sales
(
  cs_sold_time_sk           int,
  cs_ship_date_sk           int,
  cs_bill_customer_sk       int,
  cs_bill_cdemo_sk          int,
  cs_bill_hdemo_sk          int,
  cs_bill_addr_sk           int,
  cs_ship_customer_sk       int,
  cs_ship_cdemo_sk          int,
  cs_ship_hdemo_sk          int,
  cs_ship_addr_sk           int,
  cs_call_center_sk         int,
  cs_catalog_page_sk        int,
  cs_ship_mode_sk           int,
  cs_warehouse_sk           int,
  cs_item_sk                int,
  cs_promo_sk               int,
  cs_order_number           bigint,
  cs_quantity               int,
  cs_wholesale_cost         decimal(7,2),
  cs_list_price             decimal(7,2),
  cs_sales_price            decimal(7,2),
  cs_ext_discount_amt       decimal(7,2),
  cs_ext_sales_price        decimal(7,2),
  cs_ext_wholesale_cost     decimal(7,2),
  cs_ext_list_price         decimal(7,2),
  cs_ext_tax                decimal(7,2),
  cs_coupon_amt             decimal(7,2),
  cs_ext_ship_cost          decimal(7,2),
  cs_net_paid               decimal(7,2),
  cs_net_paid_inc_tax       decimal(7,2),
  cs_net_paid_inc_ship      decimal(7,2),
  cs_net_paid_inc_ship_tax  decimal(7,2),
  cs_net_profit             decimal(7,2)
)
partitioned by (cs_sold_date_sk bigint)
stored as orc;

 create table if not exists web_returns
(
  wr_returned_time_sk       int,
  wr_item_sk                int,
  wr_refunded_customer_sk   int,
  wr_refunded_cdemo_sk      int,
  wr_refunded_hdemo_sk      int,
  wr_refunded_addr_sk       int,
  wr_returning_customer_sk  int,
  wr_returning_cdemo_sk     int,
  wr_returning_hdemo_sk     int,
  wr_returning_addr_sk      int,
  wr_web_page_sk            int,
  wr_reason_sk              int,
  wr_order_number           bigint,
  wr_return_quantity        int,
  wr_return_amt             decimal(7,2),
  wr_return_tax             decimal(7,2),
  wr_return_amt_inc_tax     decimal(7,2),
  wr_fee                    decimal(7,2),
  wr_return_ship_cost       decimal(7,2),
  wr_refunded_cash          decimal(7,2),
  wr_reversed_charge        decimal(7,2),
  wr_account_credit         decimal(7,2),
  wr_net_loss               decimal(7,2)
)
partitioned by (wr_returned_date_sk int)
stored as orc;

 create table if not exists web_sales
(
  ws_sold_time_sk           int,
  ws_ship_date_sk           int,
  ws_item_sk                int,
  ws_bill_customer_sk       int,
  ws_bill_cdemo_sk          int,
  ws_bill_hdemo_sk          int,
  ws_bill_addr_sk           int,
  ws_ship_customer_sk       int,
  ws_ship_cdemo_sk          int,
  ws_ship_hdemo_sk          int,
  ws_ship_addr_sk           int,
  ws_web_page_sk            int,
  ws_web_site_sk            int,
  ws_ship_mode_sk           int,
  ws_warehouse_sk           int,
  ws_promo_sk               int,
  ws_order_number           bigint,
  ws_quantity               int,
  ws_wholesale_cost         decimal(7,2),
  ws_list_price             decimal(7,2),
  ws_sales_price            decimal(7,2),
  ws_ext_discount_amt       decimal(7,2),
  ws_ext_sales_price        decimal(7,2),
  ws_ext_wholesale_cost     decimal(7,2),
  ws_ext_list_price         decimal(7,2),
  ws_ext_tax                decimal(7,2),
  ws_coupon_amt             decimal(7,2),
  ws_ext_ship_cost          decimal(7,2),
  ws_net_paid               decimal(7,2),
  ws_net_paid_inc_tax       decimal(7,2),
  ws_net_paid_inc_ship      decimal(7,2),
  ws_net_paid_inc_ship_tax  decimal(7,2),
  ws_net_profit             decimal(7,2)
)
partitioned by (ws_sold_date_sk int)
stored as orc;
