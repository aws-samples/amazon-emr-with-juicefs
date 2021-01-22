--
-- adjust the schema name if necessary
-- currently (tpcds_10000_parquet)
--

create database if not exists ${db_parquet} location '${location}';
use ${db_parquet};

--
-- unpartitioned tables
--
 create table if not exists call_center            like ${db_txt}.call_center            stored as parquet;
 create table if not exists catalog_page           like ${db_txt}.catalog_page           stored as parquet;
 create table if not exists customer               like ${db_txt}.customer               stored as parquet;
 create table if not exists customer_address       like ${db_txt}.customer_address       stored as parquet;
 create table if not exists customer_demographics  like ${db_txt}.customer_demographics  stored as parquet;
 create table if not exists date_dim               like ${db_txt}.date_dim               stored as parquet;
 create table if not exists household_demographics like ${db_txt}.household_demographics stored as parquet;
 create table if not exists income_band            like ${db_txt}.income_band            stored as parquet;
 create table if not exists item                   like ${db_txt}.item                   stored as parquet;
 create table if not exists promotion              like ${db_txt}.promotion              stored as parquet;
 create table if not exists reason                 like ${db_txt}.reason                 stored as parquet;
 create table if not exists ship_mode              like ${db_txt}.ship_mode              stored as parquet;
 create table if not exists store                  like ${db_txt}.store                  stored as parquet;
 create table if not exists time_dim               like ${db_txt}.time_dim               stored as parquet;
 create table if not exists warehouse              like ${db_txt}.warehouse              stored as parquet;
 create table if not exists web_page               like ${db_txt}.web_page               stored as parquet;
 create table if not exists web_site               like ${db_txt}.web_site               stored as parquet;
 create table if not exists inventory              like ${db_txt}.inventory              stored as parquet;
 create table if not exists store_sales            like ${db_txt}.store_sales            stored as parquet;
 create table if not exists store_returns          like ${db_txt}.store_returns          stored as parquet;
 create table if not exists catalog_returns        like ${db_txt}.catalog_returns        stored as parquet;
 create table if not exists catalog_sales          like ${db_txt}.catalog_sales          stored as parquet;
 create table if not exists web_returns            like ${db_txt}.web_returns            stored as parquet;
 create table if not exists web_sales              like ${db_txt}.web_sales              stored as parquet;
