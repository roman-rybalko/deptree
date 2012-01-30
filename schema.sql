create table objects(id integer primary key autoincrement, name text, crc integer not null);
create index objects_idx on objects(crc);

create table symbols(id integer primary key autoincrement, name text, crc integer not null);
create index symbols_idx on symbols(crc);

create table object_symbol_provides(object_id integer not null, symbol_id integer not null);
create index object_symbol_provides_idx on object_symbol_provides(object_id);
create unique index object_symbol_provides_idx_key on object_symbol_provides(object_id, symbol_id);

create table object_symbol_depends(object_id integer not null, symbol_id integer not null);
create index object_symbol_depends_idx on object_symbol_depends(object_id);
create unique index object_symbol_depends_idx_key on object_symbol_depends(object_id,symbol_id);

