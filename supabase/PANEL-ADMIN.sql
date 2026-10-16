-- Aggregate operational data for the existing administrator only.
create or replace function enjoy.admin_monitor() returns jsonb
language plpgsql security invoker set search_path='' as $$
declare result jsonb; today text:=to_char(now() at time zone 'America/Guayaquil','YYYY-MM-DD');
begin
 if not exists(select 1 from enjoy.profiles where id=auth.uid() and role='admin') then
  raise exception 'Permiso exclusivo del administrador.' using errcode='42501';
 end if;
 select jsonb_build_object('updated',now(),'today',today,
 'workshops',coalesce((select jsonb_agg(to_jsonb(s)) from (
  select w.id,
   count(*) filter(where r.collection='appointments' and r.payload->>'date'=today and coalesce(r.payload->>'status','scheduled')<>'cancelled') as today,
   count(*) filter(where r.collection='appointments' and r.payload->>'status'='arrived') as arrived,
   count(*) filter(where r.collection='plans' and coalesce(r.payload->>'status','scheduled')<>'done') as plans,
   count(*) filter(where r.collection='plans' and coalesce(r.payload->>'status','scheduled')<>'done' and (
    (nullif(r.payload->>'date','') is not null and r.payload->>'date'<=today) or
    (nullif(r.payload->>'km','') is not null and exists(select 1 from enjoy.records v where v.workshop=w.id and v.collection='vehicles' and v.id=r.payload->>'vehicleId' and nullif(v.payload->>'km','')::numeric>=nullif(r.payload->>'km','')::numeric)))) as overdue,
   count(*) filter(where r.collection='requests' and r.payload->>'status'='draft') as drafts,
   max(r.updated) as last
  from enjoy.workshops w left join enjoy.records r on r.workshop=w.id group by w.id
 )s),'[]'::jsonb),
 'appointments',coalesce((select jsonb_agg(to_jsonb(s)) from (
  select r.workshop,r.payload->>'date' as date,coalesce(r.payload->>'status','scheduled') as status,count(*) as n
  from enjoy.records r where r.collection='appointments' and r.payload->>'date'>=to_char((now() at time zone 'America/Guayaquil')::date-29,'YYYY-MM-DD')
   and r.payload->>'date'<=to_char((now() at time zone 'America/Guayaquil')::date+30,'YYYY-MM-DD')
  group by r.workshop,r.payload->>'date',coalesce(r.payload->>'status','scheduled')
 )s),'[]'::jsonb),
 'reminders',coalesce((select jsonb_agg(to_jsonb(s)) from (
  select workshop,status,count(*) as n from enjoy.reminders group by workshop,status
 )s),'[]'::jsonb),
 'activity',coalesce((select jsonb_agg(to_jsonb(s)) from (
  select a.workshop,a.action,a.created from enjoy.audit a order by a.id desc limit 100
 )s),'[]'::jsonb)) into result;
 return result;
end $$;
revoke all on function enjoy.admin_monitor() from public,anon,authenticated;
do $upgrade$
declare definition text;
begin
 select pg_get_functiondef('public.enjoy_api(text,jsonb)'::regprocedure) into definition;
 if position('enjoy.admin_monitor()' in definition)=0 then
  if position('  if u.role=''admin'' then' in definition)=0 then raise exception 'No se encontró el punto de actualización.';end if;
  definition:=replace(definition,'  if u.role=''admin'' then','  if u.role=''admin'' then'||chr(10)||'   result:=result||jsonb_build_object(''monitor'',enjoy.admin_monitor());');
  execute definition;
 end if;
end $upgrade$;
