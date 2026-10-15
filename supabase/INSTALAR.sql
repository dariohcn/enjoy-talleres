-- ENJOY: ejecutar una vez en un proyecto nuevo, desde SQL Editor.
begin;
create schema enjoy;
revoke all on schema enjoy from public,anon,authenticated;
create table enjoy.workshops(id uuid primary key default gen_random_uuid(),name text not null,owner text not null,email text not null,location text not null,status text not null default 'pending' check(status in ('pending','approved','rejected')),catalog boolean not null default false,phone text not null default '',whatsapp_optin boolean not null default false,created timestamptz not null default now(),check(not whatsapp_optin or phone ~ '^[1-9][0-9]{7,14}$'));
create table enjoy.profiles(id uuid primary key references auth.users(id) on delete cascade,email text not null,role text not null default 'owner' check(role in ('admin','owner')),workshop uuid references enjoy.workshops(id),check((role='admin' and workshop is null) or (role='owner' and workshop is not null)));
create unique index single_administrator on enjoy.profiles(role) where role='admin';
create table enjoy.records(workshop uuid not null references enjoy.workshops(id),collection text not null check(collection in ('clients','vehicles','appointments','plans','services','requests')),id text not null check(id ~ '^[A-Za-z0-9_-]{1,80}$'),payload jsonb not null check(jsonb_typeof(payload)='object' and octet_length(payload::text)<=50000),updated timestamptz not null default now(),primary key(workshop,id));
create index record_collections on enjoy.records(workshop,collection);
create table enjoy.audit(id bigint generated always as identity primary key,workshop uuid references enjoy.workshops(id),actor uuid references auth.users(id),action text not null,created timestamptz not null default now());
create table enjoy.reminders(id text primary key,workshop uuid not null references enjoy.workshops(id),appointment text not null,role text not null check(role in ('owner','client')),due timestamptz not null,appointment_at timestamptz not null,status text not null default 'queued' check(status in ('queued','blocked','sending','accepted','failed','uncertain','cancelled','expired')),message_id text,error text not null default '',updated timestamptz not null default now());
create index reminders_pending on enjoy.reminders(due) where status in ('queued','blocked');
create table enjoy.settings(id boolean primary key default true check(id),whatsapp_live boolean not null default false);
insert into enjoy.settings values(true,false);
alter table enjoy.workshops enable row level security;
alter table enjoy.profiles enable row level security;
alter table enjoy.records enable row level security;
alter table enjoy.audit enable row level security;
alter table enjoy.reminders enable row level security;
alter table enjoy.settings enable row level security;
revoke all on all tables in schema enjoy from public,anon,authenticated;
revoke all on all sequences in schema enjoy from public,anon,authenticated;

create function enjoy.signup() returns trigger language plpgsql security definer set search_path='' as $$
declare m jsonb:=coalesce(new.raw_user_meta_data,'{}');w uuid;
begin
 if length(trim(coalesce(m->>'name',''))) not between 1 and 160 or length(trim(coalesce(m->>'owner',''))) not between 1 and 160 or length(trim(coalesce(m->>'location',''))) not between 1 and 300 then raise exception 'Complete los datos del taller.';end if;
 insert into enjoy.workshops(name,owner,email,location,phone,whatsapp_optin) values(trim(m->>'name'),trim(m->>'owner'),new.email,trim(m->>'location'),regexp_replace(coalesce(m->>'phone',''),'[^0-9]','','g'),coalesce(m->>'whatsappOptIn','false')='true') returning id into w;
 insert into enjoy.profiles(id,email,role,workshop) values(new.id,new.email,'owner',w);
 return new;
end $$;
create trigger enjoy_signup after insert on auth.users for each row execute function enjoy.signup();

create function enjoy.sync(w uuid,a jsonb) returns void language plpgsql security definer set search_path='' as $$
declare stamp timestamptz;prefix text;recipient text;
begin
 stamp:=((a->>'date')::date+(a->>'time')::time) at time zone 'America/Guayaquil';
 prefix:=w::text||':'||(a->>'id')||':'||(a->>'date')||':'||(a->>'time')||':';
 update enjoy.reminders set status='cancelled',updated=now() where workshop=w and appointment=a->>'id' and status in ('queued','blocked') and (left(id,length(prefix))<>prefix or a->>'status' in ('done','cancelled'));
 if a->>'status' in ('done','cancelled') then return;end if;
 if stamp<=now() then update enjoy.reminders set status='expired',updated=now() where workshop=w and appointment=a->>'id' and status in ('queued','blocked');return;end if;
 foreach recipient in array array['owner','client'] loop
  insert into enjoy.reminders(id,workshop,appointment,role,due,appointment_at) values(prefix||recipient,w,a->>'id',recipient,stamp-interval '1 hour',stamp) on conflict(id) do nothing;
 end loop;
end $$;

create function public.enjoy_api(action text,payload jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare u enjoy.profiles;w enjoy.workshops;r jsonb;old jsonb;linked jsonb;result jsonb;coll text;rid text;k text;sid text;required text[];target uuid;stamp timestamptz;minutes integer;
begin
 if auth.uid() is null then raise exception 'Debe iniciar sesión.' using errcode='42501';end if;
 select * into u from enjoy.profiles where id=auth.uid();if not found then raise exception 'No existe un perfil autorizado.' using errcode='42501';end if;
 if u.role='owner' then
  select * into w from enjoy.workshops where id=u.workshop;
  if w.status<>'approved' then raise exception '%',case when w.status='pending' then 'Su solicitud está pendiente de aprobación.' else 'Su solicitud fue rechazada.' end using errcode='42501';end if;
 end if;
 if action='session' then return jsonb_build_object('email',u.email,'role',u.role,'workshop',w.name);end if;
 if action='data' then
  result:='{}';
  foreach coll in array array['clients','vehicles','appointments','plans','services','requests'] loop
   result:=result||jsonb_build_object(coll,coalesce((select jsonb_agg(x.payload order by x.updated,x.id) from enjoy.records x where x.workshop=u.workshop and x.collection=coll),'[]'));
  end loop;
  result:=result||jsonb_build_object('catalogAllowed',u.role='admin' or w.catalog,'whatsappConnected',(select whatsapp_live from enjoy.settings where id),'workshopContact',case when u.role='owner' then jsonb_build_object('phone',w.phone,'whatsapp_optin',w.whatsapp_optin) else null end,
   'activity',coalesce((select jsonb_agg(to_jsonb(t)) from (select a.action,a.created from enjoy.audit a where a.workshop is not distinct from u.workshop order by a.id desc limit 30)t),'[]'),
   'reminders',coalesce((select jsonb_agg(to_jsonb(t)) from (select j.id,j.appointment,j.role,extract(epoch from j.due) as due,j.status,j.error from enjoy.reminders j where u.role='admin' or j.workshop=u.workshop order by j.due desc limit 100)t),'[]'));
  if u.role='admin' then
   result:=result||jsonb_build_object('workshops',coalesce((select jsonb_agg(to_jsonb(t)) from (select x.*,coalesce((select jsonb_object_agg(c.collection,c.n) from (select collection,count(*) n from enjoy.records where workshop=x.id group by collection)c),'{}') counts from enjoy.workshops x order by x.created)t),'[]'),
   'users',coalesce((select jsonb_agg(to_jsonb(t)) from (select p.id,p.email,p.role,p.workshop,x.name as "workshopName",x.owner as name,x.status from enjoy.profiles p left join enjoy.workshops x on p.workshop=x.id order by p.role,p.email)t),'[]'));
  end if;return result;
 end if;
 if action in ('decision','permission') then
  if u.role<>'admin' then raise exception 'Permiso exclusivo del administrador.' using errcode='42501';end if;
  target:=(payload->>'id')::uuid;perform 1 from enjoy.workshops where id=target for update;if not found then raise exception 'No existe el taller.';end if;
  if action='decision' then
   if payload->>'status' is null or payload->>'status' not in ('approved','rejected') then raise exception 'Estado inválido.';end if;
   update enjoy.workshops set status=payload->>'status' where id=target;
  else
   if jsonb_typeof(payload->'catalog') is distinct from 'boolean' then raise exception 'Permiso inválido.';end if;
   update enjoy.workshops set catalog=(payload->>'catalog')::boolean where id=target and status='approved';if not found then raise exception 'El taller debe estar autorizado.';end if;
  end if;
  insert into enjoy.audit(actor,action) values(u.id,'Permisos de taller actualizados');return '{"ok":true}';
 end if;
 if u.role<>'owner' then raise exception 'Operación exclusiva del propietario del taller.' using errcode='42501';end if;
 perform 1 from enjoy.workshops where id=u.workshop for update;
 if action='workshop-contact' then
  k:=regexp_replace(coalesce(payload->>'phone',''),'[^0-9]','','g');if k !~ '^[1-9][0-9]{7,14}$' then raise exception 'Ingrese un número con código de país.';end if;
  update enjoy.workshops set phone=k,whatsapp_optin=coalesce(payload->>'whatsappOptIn','false')='true' where id=u.workshop;return '{"ok":true}';
 end if;
 if action<>'save' then raise exception 'Operación no disponible.';end if;
 coll:=payload->>'collection';r:=payload->'record';rid:=coalesce(nullif(r->>'id',''),gen_random_uuid()::text);r:=r||jsonb_build_object('id',rid);
 if coll is null or coll not in ('clients','vehicles','appointments','plans','services','requests') then raise exception 'Registro no permitido.';end if;
 if jsonb_typeof(r) is distinct from 'object' or octet_length(r::text)>50000 then raise exception 'Registro inválido.';end if;
 if rid is null or rid !~ '^[A-Za-z0-9_-]{1,80}$' then raise exception 'Identificador inválido.';end if;
 perform 1 from enjoy.records where workshop=u.workshop and id=rid and collection<>coll;if found then raise exception 'Identificador ya utilizado.';end if;
 if coll='services' and not w.catalog then raise exception 'El administrador no ha habilitado la edición del catálogo.' using errcode='42501';end if;
 required:=case coll when 'clients' then array['name'] when 'vehicles' then array['plate','brand','model','clientId'] when 'appointments' then array['clientId','vehicleId','date','time','reason'] when 'plans' then array['vehicleId','service'] when 'services' then array['name','category'] else array['clientId','vehicleId','status','services'] end;
 foreach k in array required loop if coalesce(trim(r->>k),'')='' then raise exception 'Complete los datos requeridos.';end if;end loop;
 if r ? 'clientId' then perform 1 from enjoy.records where workshop=u.workshop and collection='clients' and id=r->>'clientId';if not found then raise exception 'El cliente no pertenece al taller.' using errcode='42501';end if;end if;
 if r ? 'vehicleId' then
  select x.payload into linked from enjoy.records x where workshop=u.workshop and collection='vehicles' and id=r->>'vehicleId';if not found then raise exception 'El vehículo no pertenece al taller.' using errcode='42501';end if;
  if r ? 'clientId' and linked->>'clientId'<>r->>'clientId' then raise exception 'El vehículo no pertenece al cliente seleccionado.';end if;
 end if;
 if coll='clients' then
  if r ? 'whatsappOptIn' and jsonb_typeof(r->'whatsappOptIn') is distinct from 'boolean' then raise exception 'Revise la autorización de mensajes.';end if;
  if coalesce(r->>'whatsappOptIn','false')='true' and regexp_replace(coalesce(r->>'phone',''),'[^0-9]','','g') !~ '^[1-9][0-9]{7,14}$' then raise exception 'Ingrese WhatsApp con código de país.';end if;
 end if;
 if coll='vehicles' then
  if coalesce(r->>'km','0') !~ '^\d+(\.\d+)?$' then raise exception 'El kilometraje no puede ser negativo.';end if;
  perform 1 from enjoy.records x where x.workshop=u.workshop and x.collection='vehicles' and x.id<>rid and upper(x.payload->>'plate')=upper(r->>'plate');if found then raise exception 'El vehículo ya está registrado.';end if;
  select x.payload into old from enjoy.records x where x.workshop=u.workshop and x.id=rid;
  if old is not null and old->>'clientId'<>r->>'clientId' then raise exception 'El cambio de propietario requiere conservar el historial. Registre otra ficha.';end if;
 end if;
 if coll='appointments' then
  if r->>'date' !~ '^\d{4}-\d{2}-\d{2}$' or r->>'time' !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then raise exception 'Fecha u hora inválida.';end if;
  stamp:=((r->>'date')::date+(r->>'time')::time) at time zone 'America/Guayaquil';minutes:=coalesce(r->>'duration','60')::integer;r:=r||jsonb_build_object('duration',minutes,'status',coalesce(r->>'status','scheduled'));
  if minutes not between 15 and 480 or r->>'status' not in ('scheduled','arrived','done','cancelled') then raise exception 'Revise duración y estado.';end if;
  if r->>'status' not in ('done','cancelled') then
   perform 1 from enjoy.records x where x.workshop=u.workshop and x.collection='appointments' and x.id<>rid and x.payload->>'vehicleId'=r->>'vehicleId' and x.payload->>'status' not in ('done','cancelled')
   and tstzrange((((x.payload->>'date')::date+(x.payload->>'time')::time) at time zone 'America/Guayaquil'),(((x.payload->>'date')::date+(x.payload->>'time')::time) at time zone 'America/Guayaquil')+coalesce(x.payload->>'duration','60')::integer*interval '1 minute','[)') && tstzrange(stamp,stamp+minutes*interval '1 minute','[)');
   if found then raise exception 'El vehículo ya tiene una cita en ese horario.';end if;
  end if;
 end if;
 if coll='plans' then
  if coalesce(r->>'date','')='' and coalesce(r->>'km','')='' then raise exception 'Indique fecha o kilometraje.';end if;
  if coalesce(r->>'date','')<>'' then perform (r->>'date')::date;end if;
  if coalesce(r->>'km','')<>'' and r->>'km' !~ '^\d+(\.\d+)?$' then raise exception 'El kilometraje no puede ser negativo.';end if;
 end if;
 if coll='services' then
  foreach k in array array['supplies','labor','discount'] loop if coalesce(r->>k,'0') !~ '^\d+(\.\d+)?$' then raise exception 'Los valores deben ser números positivos.';end if;end loop;
  if coalesce(r->>'discount','0')::numeric>100 then raise exception 'El descuento máximo es 100%%.';end if;
 end if;
 if coll='requests' then
  if r->>'status' not in ('draft','confirmed') or jsonb_typeof(r->'services') is distinct from 'array' then raise exception 'Solicitud inválida.';end if;
  select x.payload into old from enjoy.records x where x.workshop=u.workshop and x.id=rid;if old->>'status'='confirmed' then raise exception 'La solicitud confirmada no puede modificarse.';end if;
  for sid in select jsonb_array_elements_text(r->'services') loop perform 1 from enjoy.records where workshop=u.workshop and collection='services' and id=sid;if not found then raise exception 'Servicio no autorizado.';end if;end loop;
 end if;
 insert into enjoy.records(workshop,collection,id,payload) values(u.workshop,coll,rid,r) on conflict(workshop,id) do update set payload=excluded.payload,updated=now();
 if coll='appointments' then perform enjoy.sync(u.workshop,r);end if;
 insert into enjoy.audit(workshop,actor,action) values(u.workshop,u.id,'Registro actualizado: '||coll);return '{"ok":true}';
end $$;

create function public.enjoy_claim_reminders(live_mode boolean default false) returns jsonb language plpgsql security definer set search_path='' as $$
declare j enjoy.reminders;w enjoy.workshops;a jsonb;c jsonb;v jsonb;phone text;result jsonb:='[]';
begin
 if coalesce(auth.role(),'')<>'service_role' then raise exception 'Permiso denegado.' using errcode='42501';end if;
 update enjoy.settings set whatsapp_live=live_mode where id;
 update enjoy.reminders set status='uncertain',error='Procesamiento interrumpido; requiere revisión.',updated=now() where status='sending' and updated<now()-interval '5 minutes';
 update enjoy.reminders set status='expired',updated=now() where status in ('queued','blocked') and appointment_at<=now();
 for j in select * from enjoy.reminders where status in ('queued','blocked') and due<=now() and appointment_at>now() order by due for update skip locked limit 20 loop
  select * into w from enjoy.workshops where id=j.workshop;
  select payload into a from enjoy.records where workshop=j.workshop and collection='appointments' and id=j.appointment;
  if a is null or a->>'status' in ('done','cancelled') or w.status<>'approved' or (((a->>'date')::date+(a->>'time')::time) at time zone 'America/Guayaquil')<>j.appointment_at then update enjoy.reminders set status='cancelled',updated=now() where id=j.id;continue;end if;
  if not live_mode then update enjoy.reminders set status='blocked',error='Modo de prueba: no se envían mensajes reales.',updated=now() where id=j.id;continue;end if;
  select payload into c from enjoy.records where workshop=j.workshop and collection='clients' and id=a->>'clientId';
  select payload into v from enjoy.records where workshop=j.workshop and collection='vehicles' and id=a->>'vehicleId';
  phone:=regexp_replace(case when j.role='owner' then w.phone else coalesce(c->>'phone','') end,'[^0-9]','','g');
  if phone !~ '^[1-9][0-9]{7,14}$' or not(case when j.role='owner' then w.whatsapp_optin else coalesce(c->>'whatsappOptIn','false')='true' end) then update enjoy.reminders set status='blocked',error='Falta un contacto válido o su autorización.',updated=now() where id=j.id;continue;end if;
  update enjoy.reminders set status='sending',error='',updated=now() where id=j.id;
  result:=result||jsonb_build_array(jsonb_build_object('id',j.id,'phone',phone,'parameters',jsonb_build_array(w.name,c->>'name',v->>'plate',to_char((a->>'date')::date,'DD/MM/YYYY'),a->>'time',a->>'reason')));
 end loop;return result;
end $$;
create function public.enjoy_finish_reminder(job_id text,outcome text,provider_id text default null,detail text default '') returns void language plpgsql security definer set search_path='' as $$
begin
 if coalesce(auth.role(),'')<>'service_role' then raise exception 'Permiso denegado.' using errcode='42501';end if;
 if outcome not in ('accepted','failed','uncertain') then raise exception 'Estado inválido.';end if;
 update enjoy.reminders set status=outcome,message_id=left(provider_id,200),error=left(detail,250),updated=now() where id=job_id and status='sending';
end $$;
revoke all on all functions in schema enjoy from public,anon,authenticated;
revoke all on function public.enjoy_api(text,jsonb) from public,anon;
grant execute on function public.enjoy_api(text,jsonb) to authenticated;
revoke all on function public.enjoy_claim_reminders(boolean) from public,anon,authenticated;
revoke all on function public.enjoy_finish_reminder(text,text,text,text) from public,anon,authenticated;
grant execute on function public.enjoy_claim_reminders(boolean) to service_role;
grant execute on function public.enjoy_finish_reminder(text,text,text,text) to service_role;
commit;
