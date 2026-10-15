-- Después de desplegar la función, cree en Vault:
-- enjoy_reminder_url: URL HTTPS de appointment-reminders.
-- enjoy_reminder_job_secret: secreto aleatorio de al menos 32 caracteres.
-- La función obtiene este secreto con su identidad de servidor.
create or replace function public.enjoy_reminder_secret() returns text
language sql security definer set search_path='' as $$
 select decrypted_secret from vault.decrypted_secrets where name='enjoy_reminder_job_secret' limit 1
$$;
revoke all on function public.enjoy_reminder_secret() from public,anon,authenticated;
grant execute on function public.enjoy_reminder_secret() to service_role;
create extension if not exists pg_cron;
create extension if not exists pg_net;
do $$
begin
 if not exists(select 1 from vault.decrypted_secrets where name='enjoy_reminder_url') or not exists(select 1 from vault.decrypted_secrets where name='enjoy_reminder_job_secret') then raise exception 'Configure primero los dos secretos en Vault.';end if;
 if not exists(select 1 from cron.job where jobname='enjoy-appointment-reminders') then
  perform cron.schedule('enjoy-appointment-reminders','* * * * *',$job$
   select net.http_post(url := (select decrypted_secret from vault.decrypted_secrets where name='enjoy_reminder_url' limit 1),headers := jsonb_build_object('Content-Type','application/json','x-job-secret',(select decrypted_secret from vault.decrypted_secrets where name='enjoy_reminder_job_secret' limit 1)),body := '{}'::jsonb,timeout_milliseconds := 10000);
  $job$);
 end if;
end $$;
