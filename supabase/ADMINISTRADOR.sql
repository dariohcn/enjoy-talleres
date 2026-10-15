-- Después de registrar SU cuenta y confirmar el correo, sustituya el UUID.
-- Mantenga esta plantilla sin identificadores personales en el repositorio.
begin;
do $$
declare account_id uuid:='00000000-0000-0000-0000-000000000000';old_workshop uuid;
begin
 if account_id='00000000-0000-0000-0000-000000000000'::uuid then raise exception 'Sustituya el UUID por el de su cuenta en Authentication / Users.';end if;
 if exists(select 1 from enjoy.profiles where role='admin') then raise exception 'Ya existe el administrador.';end if;
 select workshop into old_workshop from enjoy.profiles where id=account_id and role='owner';
 if not found then raise exception 'Registre primero su cuenta desde el formulario.';end if;
 if exists(select 1 from enjoy.records where workshop=old_workshop) then raise exception 'Utilice una cuenta nueva sin registros de taller.';end if;
 update enjoy.profiles set role='admin',workshop=null where id=account_id;
 delete from enjoy.workshops where id=old_workshop and not exists(select 1 from enjoy.profiles where workshop=old_workshop);
end $$;
commit;
