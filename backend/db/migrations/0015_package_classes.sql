-- Package -> class model (PKG): a class belongs to at most one package type; a renewal request remembers the chosen class.
alter table classes add column package_type_id uuid references package_types(id);
create index ix_classes_package on classes (package_type_id) where is_active;
alter table renewal_requests add column class_id uuid references classes(id);
