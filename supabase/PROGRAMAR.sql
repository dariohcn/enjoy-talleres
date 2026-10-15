-- Después de desplegar la función, cree en Vault:
-- enjoy_reminder_url: URL HTTPS de appointment-reminders.
-- enjoy_reminder_job_secret: el mismo valor de REMINDER_JOB_SECRET.
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
