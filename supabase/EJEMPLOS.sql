-- Optional fictitious workshops. No accounts, contact numbers, or messages are created.
do $examples$
declare w uuid; i integer; j integer; day date:=(now() at time zone 'America/Guayaquil')::date;
 names text[]:=array['Ejemplo · Mecánica del Sur','Ejemplo · Servicio Automotriz Norte','Ejemplo · Taller Integral Centro','Ejemplo · Diagnóstico del Valle'];
 locations text[]:=array['Loja','Cuenca','Quito','Ambato'];
begin
 for i in 1..4 loop
  select id into w from enjoy.workshops where name=names[i] and is_demo limit 1;
  if w is not null then continue;end if;
  insert into enjoy.workshops(name,owner,email,location,status,catalog,is_demo)
   values(names[i],'Responsable ficticio '||i,'taller'||i||'@example.invalid',locations[i],'approved',true,true) returning id into w;
  for j in 1..(i+2) loop
   insert into enjoy.records(workshop,collection,id,payload) values(w,'clients','demo-client-'||j,jsonb_build_object('id','demo-client-'||j,'name','Cliente ficticio '||j,'phone','','email','','notes','Registro de demostración','whatsappOptIn',false));
   insert into enjoy.records(workshop,collection,id,payload) values(w,'vehicles','demo-vehicle-'||j,jsonb_build_object('id','demo-vehicle-'||j,'clientId','demo-client-'||j,'plate','DEMO-'||i||'-'||j,'brand',case when j%2=0 then 'Chevrolet' else 'Toyota' end,'model',case when j%2=0 then 'Tracker' else 'Corolla' end,'year',2022,'km',30000+j*5000));
   insert into enjoy.records(workshop,collection,id,payload) values(w,'plans','demo-plan-'||j,jsonb_build_object('id','demo-plan-'||j,'vehicleId','demo-vehicle-'||j,'service','Mantenimiento preventivo de ejemplo','date',to_char(day+j-i,'YYYY-MM-DD'),'km',50000,'status','scheduled'));
  end loop;
  for j in 0..11 loop
   insert into enjoy.records(workshop,collection,id,payload) values(w,'appointments','demo-appointment-'||j,jsonb_build_object('id','demo-appointment-'||j,'clientId','demo-client-'||(1+j%(i+2)),'vehicleId','demo-vehicle-'||(1+j%(i+2)),'date',to_char(day+(case when j<8 then -j else j-7 end),'YYYY-MM-DD'),'time',lpad((9+j%6)::text,2,'0')||':00','duration',60,'reason','Revisión preventiva de ejemplo','status',case when j=0 then case when i%2=0 then 'arrived' else 'scheduled' end when j<6 then 'done' when j=6 then 'cancelled' else 'scheduled' end));
  end loop;
  insert into enjoy.records(workshop,collection,id,payload) values(w,'services','demo-service',jsonb_build_object('id','demo-service','name','Revisión general de ejemplo','category','Mantenimiento','labor',30,'supplies',20,'discount',0,'icon','⚙'));
  insert into enjoy.records(workshop,collection,id,payload) values(w,'requests','demo-request',jsonb_build_object('id','demo-request','clientId','demo-client-1','vehicleId','demo-vehicle-1','services',jsonb_build_array('demo-service'),'status','draft'));
  insert into enjoy.audit(workshop,action) values(w,'Taller de ejemplo incorporado con datos ficticios');
 end loop;
end $examples$;

-- Pending example makes the approval workflow available for evaluation.
insert into enjoy.workshops(name,owner,email,location,status,catalog,is_demo)
select 'Ejemplo · Taller en evaluación','Solicitante ficticio','solicitante@example.invalid','Loja','pending',false,true
where not exists(select 1 from enjoy.workshops where is_demo and name='Ejemplo · Taller en evaluación');
