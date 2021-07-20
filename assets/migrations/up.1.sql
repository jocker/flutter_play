-- TABLE SCHEMA columns



create table if not exists columns(
	id integer not null,
	column_name varchar(255) not null ,
	planogram_id integer not null ,
	product_id integer,
	location_id integer,
	display_name varchar(255),
	last_fill integer,
	capacity integer,
	max_capacity integer,
	last_visit timestamp,
	tray_id integer not null ,
	coil_notes varchar(255),
	set_price float,
	sts_coils text,
	active boolean,
    primary key(id)
);

-- TABLE SCHEMA locations
create table if not exists  locations(
	id integer not null,
	location_name varchar(255),
	location_address varchar(255),
	location_address2 varchar(255),
	location_city varchar(255),
	location_state varchar(255),
	location_zip varchar(255),
	location_type varchar(255),
	last_visit timestamp,
	planogram_id integer,
	flags integer,
	lat float,
	long float,
	account varchar(255),
	route varchar(255),
	location_make varchar(255),
	location_model varchar(255),
	machine_serial varchar(255),
	cardreader_serial varchar(255),
    primary key(id)
);


-- TABLE SCHEMA products
create table if not exists  products(
	id integer not null,
	name varchar(255),
	costbasis float,
	pricepercase float,
	casesize integer,
	source_category_name varchar(255),
	category_name varchar(255),
	roc float,
	inventory_unit_count integer,
	required_unit_count integer,
	archived boolean,
	wh_order integer,
    primary key(id)
);

-- TABLE SCHEMA location_products
create table if not exists  productlocation(
    id integer not null,
	product_id integer,
	location_id integer,
	unitcount integer,
    primary key(id)
);





-- TABLE SCHEMA machine_column_sales
create table if not exists  machine_column_sales(
	id integer not null,
	machine_column varchar(255),
	location_id integer,
	last_sale_cash_amount float,
	last_sale_unit_count float,
	units_sold_since integer,
	cash_amount_since float,
	last_sale_date timestamp,
    primary key(id)
);


-- TABLE SCHEMA notes
create table if not exists notes(
    id integer not null,
	content text,
    primary key(id)
);


-- TABLE SCHEMA order_delivery_requests
create table if not exists  order_delivery_requests(
    id integer not null,
	source_category_name varchar(255),
	type integer,
	owner_id integer,
	flags integer,
    primary key(id)
);









-- TABLE SCHEMA packs
create table if not exists packs(
	id integer not null,
	location_id integer,
	restock_id integer,
    primary key(id)
);

-- TABLE SCHEMA pack_entries
create table if not exists pack_entries(
    id integer not null,

	product_id integer,
	location_id integer,
	column_id integer,
	pack_id integer,
	restock_id integer,
	unitcount integer,
    primary key(id)
);

-- TABLE SCHEMA stock_requests
create table if not exists  restocks(
    id integer not null,
	location_id integer,
    primary key(id)
);


-- TABLE SCHEMA restock_entries
create table if not exists  restock_entries(
    id integer not null,
	location_id integer,
	column_id integer,
	product_id integer,
	restock_id integer,
	unit_count integer,
    primary key(id)
);


create table if not exists  _schema_info(
	schema_name varchar(255) not null,
	local_revision_num integer not null default 0,
	id_counter integer not null default -1,
	primary key(schema_name)
);

create table if not exists  _sync_pending_remote_mutations(
    unique_id varchar(255) not null,
    schema_name varchar(255) not null,
    object_id integer not null,
    mutation_type tinyint not null,
    data text,
    error_messages text,
    status tinyint not null default 0,
    rev_num integer not null,
    unique(schema_name, object_id, rev_num)
);

create table if not exists  _sync_object_resolved_ids(
    schema_name varchar(255) not null,
    local_id integer not null,
    remote_id integer not null default 0,
    primary key(schema_name, local_id)
);

create table if not exists  _sync_object_snapshots(
    schema_name varchar(255) not null,
    record_id integer not null,
    rev_num integer not null,
    data text not null,
    primary key(schema_name, record_id)
);

-- tracks the amount of product that was sold for each column
-- note that column_id is not unique because during 2 restocks, the coil product may change, thus we have may sales with different products for the same coil
create view product_column_sales as
select
    machine_column_sales.product_id as product_id,
    columns.id as column_id,
    sum(ifnull(case when columns.last_visit is null or columns.last_visit < machine_column_sales.last_sale_date then machine_column_sales.units_sold_since else 0 end, 0)) as sold_units_count,
    sum(case when columns.last_visit is null or columns.last_visit < machine_column_sales.last_sale_date then machine_column_sales.cash_amount_since else 0 end) as sold_units_amount,
    case when max(ifnull(machine_column_sales.last_sale_date, 0))=0 then null else max(ifnull(machine_column_sales.last_sale_date, 0)) end as last_sale_date,
    sum(machine_column_sales.last_sale_unit_count) as last_sale_unit_count,
    sum(machine_column_sales.last_sale_cash_amount) as last_sale_cash_amount
    from columns join machine_column_sales on columns.name = machine_column_sales.machine_column and machine_column_sales.location_uid = columns.location_uid
    group by 1, 2;



drop view if exists column_product_inventory;
create view column_product_inventory as
select
    column_id,
    location_id,
    product_id,
    par_value,
    active,
    last_fill,
    ifnull(pack_units_count, 0) as pack_units_count,
    ifnull(local_pack_units_count, 0) as local_pack_units_count,
    ifnull(restock_units_count, 0) as restock_units_count,
    case when active=1 then ifnull(sold_units_count, 0) else 0 end as sold_units_count,
-- if there are any local restocks, then the current fill is going to be the sum of all local restocks
    ifnull(restock_units_count, max(0, last_fill-ifnull(sold_units_count, 0))) as product_fill,
    ifnull(restock_units_count, max(last_fill-ifnull(sold_units_count, 0), 0)) as current_fill
from
(
select
    columns.id as column_id,
    columns.location_id as location_id,
    columns.product_id as product_id,
    ifnull(columns.capacity, 0) as par_value,
    columns.active as active,
    columns.last_fill as last_fill,
    (select sum(unit_count) from pack_entries where column_id=columns.id and ifnull(restock_id, 0)=0 ) as pack_units_count,
    (select sum(unit_count) from pack_entries where column_id=columns.id and ifnull(restock_id, 0)=0 and ifnull(pack_id, 0) <= 0 ) as local_pack_units_count,
    (select sum(unit_count) from restock_entries where column_id=columns.id ) as restock_units_count,
    case when active=1 then (select sum(units_sold_since) from machine_column_sales where machine_column_sales.location_id=columns.location_id and machine_column_sales.machine_column=columns.column_name and last_sale_date > columns.last_visit) else 0 end as sold_units_count
from columns
left join products on products.id = columns.product_id
) buffer;

drop view if exists location_product_inventory;
create view location_product_inventory as
select
    location_id,
    product_id,
    sum(par_value) as par_value,
    sum(last_fill) as last_fill,
    sum(pack_units_count) as pack_units_count,
    sum(local_pack_units_count) as local_pack_units_count,
    sum(restock_units_count) as restock_units_count,
    sum(sold_units_count) as sold_units_count,
    sum(product_fill) as product_fill,
    sum(current_fill) as current_fill,
    count(*) as coil_count,
    group_concat(column_id) as coil_ids
from column_product_inventory
where active=1
group by location_id,product_id;



drop view if exists product_breakdown;
create view product_breakdown as
select
    products.id as product_id,
    products.archived as archived,
    coalesce(products.inventory_unit_count, warehouse_units.unit_count, 0) as warehouse_units,
    ifnull(column_units.last_fill, 0) as column_fill_units,
    ifnull(column_units.pack_units_count, 0) as pack_units,
    ifnull(column_units.local_pack_units_count, 0) as local_pack_units,
    ifnull(product_sales.sold_units_count, 0) as sold_units,
    ifnull(order_delivery_units.delivered_units, 0) as delivered_units,
    ifnull(products.required_unit_count, 0) as required_unit_count,
    ifnull(products.roc, 0) as roc,
        -- add warehouse_units
        coalesce(products.inventory_unit_count, warehouse_units.unit_count, 0)
        -- add units in columns
        + ifnull(column_units.last_fill, 0) +
        -- add delivered units
        + ifnull(order_delivery_units.delivered_units, 0) +
        -- subtract pack units
        - ifnull(column_units.pack_units_count, 0)
        -- add all stock units
        + ifnull(column_units.restock_units_count, 0)
        -- subtract sold_units
        - ifnull(product_sales.sold_units_count, 0)

    as total_inventory_units
from
products
left join (
    select
        product_id,
        sum(unit_count) as unit_count
    from location_products join locations on location_id=locations.id and locations.flags & 7 = 1 group by 1
) warehouse_units -- location of type warehouse
on warehouse_units.product_id = products.id
left join (
    select
        product_id,
        sum(last_fill) as last_fill,
        sum(pack_units_count) as pack_units_count,
        sum(local_pack_units_count) as local_pack_units_count,
        sum(restock_units_count) as restock_units_count
    from column_product_inventory
    group by 1
) as column_units
on column_units.product_id = products.id
left join (
    select null as product_id, null as ordered_units, null as delivered_units
) order_delivery_units
on order_delivery_units.product_id = products.id
left join(
select
    product_uid,
    sum(sold_units_count) as sold_units_count
    from product_column_sales
    group by 1
) product_sales
on product_sales.product_id = products.id;

drop view if exists warehouse_product_inventory;
create view warehouse_product_inventory as
select
    product_uid,
    warehouse_units+delivered_units-local_pack_units as warehouse_units,
    column_fill_units as column_fill_units,
    pack_units as pack_units,
    sold_units as sold_units,
    total_inventory_units as total_inventory_units,
    required_unit_count as required_inventory_units,
    case when roc=0 then null else max(total_inventory_units/roc, 0) end as days_remaining
from product_breakdown where archived=0;