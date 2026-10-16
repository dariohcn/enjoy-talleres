-- Optimized JPEG thumbnails remain private behind the authorized application API.
create or replace function enjoy.valid_image(value text) returns boolean language sql immutable set search_path='' as $$
 select value='' or (octet_length(value)<=75000 and value ~ '^data:image/jpeg;base64,/9j/[A-Za-z0-9+/=]+$')
$$;
alter table enjoy.workshops add column if not exists image text not null default '' check(enjoy.valid_image(image));
alter table enjoy.workshops add column if not exists product_permission text not null default 'read' check(product_permission in ('read','publish','manage'));
create table if not exists enjoy.products(
 id uuid primary key default gen_random_uuid(), workshop uuid references enjoy.workshops(id),
 name text not null check(length(name) between 1 and 160), sku text not null default '' check(length(sku)<=80),
 category text not null check(length(category) between 1 and 100), description text not null default '' check(length(description)<=1500),
 price numeric(12,2) not null default 0 check(price>=0), stock integer not null default 0 check(stock between 0 and 1000000),
 image text not null default '' check(enjoy.valid_image(image)), active boolean not null default true,
 updated timestamptz not null default now()
);
create index if not exists products_workshop_updated on enjoy.products(workshop,updated desc);
alter table enjoy.products enable row level security;
revoke all on enjoy.products from public,anon,authenticated;
create or replace function enjoy.product_action(action text,payload jsonb) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare u enjoy.profiles; w enjoy.workshops; old enjoy.products; target uuid; image_value text;
begin
 select * into u from enjoy.profiles where id=auth.uid();
 if not found then raise exception 'Debe iniciar sesión.' using errcode='42501';end if;
 if u.role='owner' then
  select * into w from enjoy.workshops where id=u.workshop;
  if w.status<>'approved' or w.deleted_at is not null then raise exception 'El taller no tiene acceso autorizado.' using errcode='42501';end if;
 end if;
 if action='workshop-image' then
  if u.role<>'owner' then raise exception 'Operación exclusiva del propietario del taller.' using errcode='42501';end if;
  image_value:=coalesce(payload->>'image','');
  if not enjoy.valid_image(image_value) then raise exception 'La imagen debe ser una miniatura JPEG válida.';end if;
  update enjoy.workshops set image=image_value where id=u.workshop;
  insert into enjoy.audit(workshop,actor,action) values(u.workshop,u.id,'Imagen del taller actualizada');
  return '{"ok":true}';
 end if;
 if action='product-permission' then
  if u.role<>'admin' then raise exception 'Permiso exclusivo del administrador.' using errcode='42501';end if;
  if coalesce(payload->>'permission','') not in ('read','publish','manage') then raise exception 'Permiso inválido.';end if;
  target:=(payload->>'id')::uuid;
  update enjoy.workshops set product_permission=payload->>'permission' where id=target and status='approved' and deleted_at is null;
  if not found then raise exception 'El taller debe estar autorizado y activo.';end if;
  insert into enjoy.audit(workshop,actor,action) values(target,u.id,'Permiso de productos actualizado');
  return '{"ok":true}';
 end if;
 if action not in ('product-save','product-remove') then raise exception 'Operación no disponible.';end if;
 if u.role='owner' and w.product_permission='read' then raise exception 'El administrador no ha habilitado la publicación de productos.' using errcode='42501';end if;
 if nullif(payload->>'id','') is not null then
  select * into old from enjoy.products where id=(payload->>'id')::uuid for update;
  if not found then raise exception 'No existe el producto.';end if;
  if u.role='owner' and old.workshop is distinct from u.workshop then raise exception 'El producto no pertenece al taller.' using errcode='42501';end if;
 end if;
 if action='product-remove' then
  if old.id is null then raise exception 'No existe el producto.';end if;
  if u.role='owner' and w.product_permission<>'manage' then raise exception 'El permiso actual no permite retirar productos.' using errcode='42501';end if;
  update enjoy.products set active=false,updated=now() where id=old.id;
 else
  target:=case when old.id is not null then old.workshop when u.role='owner' then u.workshop else nullif(payload->>'workshop','')::uuid end;
  if target is not null and not exists(select 1 from enjoy.workshops where id=target and status='approved' and deleted_at is null) then raise exception 'El taller debe estar autorizado y activo.';end if;
  image_value:=coalesce(payload->>'image','');
  if not enjoy.valid_image(image_value) then raise exception 'La imagen debe ser una miniatura JPEG válida.';end if;
  if length(trim(coalesce(payload->>'name',''))) not between 1 and 160 or length(trim(coalesce(payload->>'category',''))) not between 1 and 100 then raise exception 'Complete nombre y categoría.';end if;
  if coalesce(payload->>'price','') !~ '^[0-9]+([.][0-9]{1,2})?$' or coalesce(payload->>'stock','') !~ '^[0-9]+$' then raise exception 'Revise precio y existencias.';end if;
  insert into enjoy.products(id,workshop,name,sku,category,description,price,stock,image,active)
   values(coalesce(old.id,gen_random_uuid()),target,trim(payload->>'name'),trim(coalesce(payload->>'sku','')),trim(payload->>'category'),coalesce(payload->>'description',''),(payload->>'price')::numeric,(payload->>'stock')::integer,image_value,coalesce((payload->>'active')::boolean,true))
   on conflict(id) do update set name=excluded.name,sku=excluded.sku,category=excluded.category,description=excluded.description,price=excluded.price,stock=excluded.stock,image=excluded.image,active=excluded.active,updated=now();
 end if;
 insert into enjoy.audit(workshop,actor,action) values(coalesce(old.workshop,target),u.id,case when action='product-remove' then 'Producto retirado del catálogo' else 'Producto guardado en el catálogo' end);
 return '{"ok":true}';
end $$;
revoke all on function enjoy.valid_image(text),enjoy.product_action(text,jsonb) from public,anon,authenticated;
do $upgrade$
declare definition text;
begin
 select pg_get_functiondef('public.enjoy_api(text,jsonb)'::regprocedure) into definition;
 if position('enjoy.product_action' in definition)=0 then
  definition:=replace(definition,' if action=''session'' then',
   ' if action in (''product-save'',''product-remove'',''product-permission'',''workshop-image'') then return enjoy.product_action(action,payload);end if;'||chr(10)||' if action=''session'' then');
  definition:=replace(definition,'  result:=''{}'';',
   '  result:=jsonb_build_object(''workshopId'',u.workshop,''workshopImage'',coalesce(w.image,''''),''productPermission'',case when u.role=''admin'' then ''manage'' else w.product_permission end,''products'',coalesce((select jsonb_agg(to_jsonb(p)) from (select * from enjoy.products where u.role=''admin'' or workshop is null or workshop=u.workshop order by updated desc limit 200)p),''[]''::jsonb));');
  execute definition;
 end if;
 select pg_get_functiondef('enjoy.signup()'::regprocedure) into definition;
 if position('image=coalesce' in definition)=0 then
  definition:=replace(definition,' return new;', ' update enjoy.workshops set image=coalesce(m->>''image'','''') where id=w;'||chr(10)||' update auth.users set raw_user_meta_data=raw_user_meta_data-''image'' where id=new.id;'||chr(10)||' return new;');
  execute definition;
 end if;
end $upgrade$;

do $strip$
declare definition text;
begin
 select pg_get_functiondef('enjoy.signup()'::regprocedure) into definition;
 if position('raw_user_meta_data=raw_user_meta_data-' in definition)=0 then
  definition:=replace(definition,' return new;',' update auth.users set raw_user_meta_data=raw_user_meta_data-''image'' where id=new.id;'||chr(10)||' return new;');execute definition;
 end if;
end $strip$;

do $scope$
declare definition text;
begin
 select pg_get_functiondef('public.enjoy_api(text,jsonb)'::regprocedure) into definition;
 if position('''workshopId''' in definition)=0 then
  definition:=replace(definition,'''workshopImage'',coalesce(w.image','''workshopId'',u.workshop,''workshopImage'',coalesce(w.image');execute definition;
 end if;
end $scope$;
