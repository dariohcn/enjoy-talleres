-- Recoverable removal: access is disabled while historical records remain intact.
alter table enjoy.workshops add column if not exists deleted_at timestamptz;
alter table enjoy.workshops add column if not exists is_demo boolean not null default false;
do $upgrade$
declare definition text; branch text;
begin
 branch:=$branch$
 if action in ('archive','restore') then
  if u.role<>'admin' then raise exception 'Permiso exclusivo del administrador.' using errcode='42501';end if;
  target:=(payload->>'id')::uuid;
  perform 1 from enjoy.workshops where id=target for update;
  if action='archive' then
   update enjoy.workshops set deleted_at=now() where id=target and status='approved' and deleted_at is null;
   if not found then raise exception 'El taller debe estar autorizado y activo.';end if;
   update enjoy.reminders set status='cancelled',error='Taller retirado de la red.',updated=now() where workshop=target and status in ('queued','blocked');
  else
   update enjoy.workshops set deleted_at=null where id=target and deleted_at is not null;
   if not found then raise exception 'El taller no se encuentra eliminado.';end if;
  end if;
  insert into enjoy.audit(workshop,actor,action) values(target,u.id,case when action='archive' then 'Taller eliminado de la red' else 'Taller restaurado en la red' end);
  return '{"ok":true}';
 end if;
$branch$;
 select pg_get_functiondef('public.enjoy_api(text,jsonb)'::regprocedure) into definition;
 if position('Taller eliminado de la red' in definition)=0 then
  definition:=replace(definition,'  if w.status<>''approved'' then','  if w.deleted_at is not null then raise exception ''El taller fue retirado de la plataforma. Consulte al administrador.'' using errcode=''42501'';end if;'||chr(10)||'  if w.status<>''approved'' then');
  definition:=replace(definition,' if action in (''decision'',''permission'') then',branch||' if action in (''decision'',''permission'') then');
  definition:=replace(definition,'where id=target for update;if not found','where id=target and deleted_at is null for update;if not found');
  execute definition;
 end if;
 select pg_get_functiondef('public.enjoy_claim_reminders(boolean)'::regprocedure) into definition;
 if position('w.deleted_at is not null' in definition)=0 then
  definition:=replace(definition,'or w.status<>''approved''','or w.deleted_at is not null or w.status<>''approved''');
  execute definition;
 end if;
end $upgrade$;
