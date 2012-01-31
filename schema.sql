create table objects(id integer primary key autoincrement, name text, crc integer not null);
create index objects_idx on objects(crc);

create table symbols(id integer primary key autoincrement, name text, crc integer not null);
create index symbols_idx on symbols(crc);

create table provides(object_id integer not null, symbol_id integer not null);
create index provides_idx_sym on provides(symbol_id);
create index provides_idx_obj on provides(object_id);
create unique index provides_idx_key on provides(object_id, symbol_id);

create table depends(object_id integer not null, symbol_id integer not null);
create index depends_idx_sym on depends(symbol_id);
create index depends_idx_obj on depends(object_id);
create unique index depends_idx_key on depends(object_id,symbol_id);
