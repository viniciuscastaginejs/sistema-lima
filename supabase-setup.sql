-- LIMA SISTEMAS CONTRA INCÊNDIO
-- Execute este arquivo inteiro uma única vez no SQL Editor do Supabase.

create extension if not exists pgcrypto;

create type public.user_role as enum ('admin', 'employee');
create type public.report_status as enum ('valid', 'expiring', 'expired');
create type public.service_status as enum ('planned', 'in_progress', 'completed', 'cancelled');
create type public.quote_status as enum ('draft', 'sent', 'approved', 'rejected', 'expired');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  email text not null default '',
  role public.user_role not null default 'employee',
  active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.company_settings (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'LIMA Sistemas Contra Incêndio',
  legal_name text,
  cnpj text,
  phone text,
  whatsapp text,
  email text,
  website text,
  address text,
  technical_manager text,
  technical_registration text,
  logo_path text,
  updated_by uuid references public.profiles(id),
  updated_at timestamptz not null default now()
);

create table public.clients (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  document text,
  contact_name text,
  phone text,
  whatsapp text,
  email text,
  address text,
  city text,
  state text,
  notes text,
  created_by uuid not null references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.report_types (
  id uuid primary key default gen_random_uuid(),
  name text unique not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  report_number text unique not null,
  client_id uuid not null references public.clients(id) on delete restrict,
  type_id uuid references public.report_types(id) on delete set null,
  inspection_date date,
  issue_date date,
  expiry_date date not null,
  technical_manager text,
  inspection_address text,
  description text,
  notes text,
  created_by uuid not null references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.services (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text,
  client_id uuid not null references public.clients(id) on delete restrict,
  service_date date,
  responsible text,
  status public.service_status not null default 'planned',
  description text,
  value numeric(12,2) not null default 0,
  notes text,
  created_by uuid not null references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.quotes (
  id uuid primary key default gen_random_uuid(),
  quote_number text unique not null,
  client_id uuid not null references public.clients(id) on delete restrict,
  quote_date date not null default current_date,
  valid_until date,
  status public.quote_status not null default 'draft',
  payment_terms text,
  service_description text,
  notes text,
  discount numeric(12,2) not null default 0,
  total numeric(12,2) not null default 0,
  created_by uuid not null references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.quote_items (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references public.quotes(id) on delete cascade,
  reference text,
  description text not null,
  ncm text,
  quantity numeric(12,3) not null default 1,
  unit_price numeric(12,2) not null default 0,
  position integer not null default 0,
  created_at timestamptz not null default now()
);

create table public.documents (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references public.clients(id) on delete cascade,
  report_id uuid references public.reports(id) on delete cascade,
  service_id uuid references public.services(id) on delete cascade,
  quote_id uuid references public.quotes(id) on delete cascade,
  name text not null,
  storage_path text not null,
  mime_type text,
  file_size bigint,
  version integer not null default 1,
  active boolean not null default true,
  uploaded_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  constraint document_parent check (num_nonnulls(client_id, report_id, service_id, quote_id) >= 1)
);

create table public.audit_log (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles(id),
  action text not null,
  entity text not null,
  entity_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace view public.reports_with_status with (security_invoker = true) as
select r.*,
  case
    when r.expiry_date < current_date then 'expired'::public.report_status
    when r.expiry_date <= current_date + 30 then 'expiring'::public.report_status
    else 'valid'::public.report_status
  end as calculated_status
from public.reports r;

create or replace function public.is_active_user()
returns boolean language sql stable security definer set search_path = public
as $$ select exists(select 1 from public.profiles where id = auth.uid() and active = true); $$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public
as $$ select exists(select 1 from public.profiles where id = auth.uid() and active = true and role = 'admin'); $$;

create or replace function public.touch_updated_at()
returns trigger language plpgsql set search_path = public as $$
begin new.updated_at = now(); return new; end; $$;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles(id, name, email, role, active)
  values(new.id, coalesce(new.raw_user_meta_data->>'name',''), coalesce(new.email,''), 'employee', false);
  return new;
end; $$;

create or replace function public.audit_changes()
returns trigger language plpgsql security definer set search_path = public as $$
declare rid text;
begin
  rid := coalesce((case when tg_op = 'DELETE' then old.id else new.id end)::text, '');
  insert into public.audit_log(user_id, action, entity, entity_id, details)
  values(auth.uid(), lower(tg_op), tg_table_name, rid,
    case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end);
  return case when tg_op = 'DELETE' then old else new end;
end; $$;

create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

do $$ declare t text; begin
  foreach t in array array['profiles','company_settings','clients','reports','services','quotes'] loop
    execute format('create trigger %I_touch before update on public.%I for each row execute function public.touch_updated_at()', t, t);
  end loop;
  foreach t in array array['clients','reports','services','quotes','quote_items','documents'] loop
    execute format('create trigger %I_audit after insert or update or delete on public.%I for each row execute function public.audit_changes()', t, t);
  end loop;
end $$;

alter table public.profiles enable row level security;
alter table public.company_settings enable row level security;
alter table public.clients enable row level security;
alter table public.report_types enable row level security;
alter table public.reports enable row level security;
alter table public.services enable row level security;
alter table public.quotes enable row level security;
alter table public.quote_items enable row level security;
alter table public.documents enable row level security;
alter table public.audit_log enable row level security;

create policy "profile self read" on public.profiles for select to authenticated using (id = auth.uid() or public.is_admin());
create policy "admins update profiles" on public.profiles for update to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "active read settings" on public.company_settings for select to authenticated using (public.is_active_user());
create policy "admins manage settings" on public.company_settings for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "active read types" on public.report_types for select to authenticated using (public.is_active_user());
create policy "admins manage types" on public.report_types for all to authenticated using (public.is_admin()) with check (public.is_admin());

do $$ declare t text; begin
  foreach t in array array['clients','reports','services','quotes','quote_items','documents'] loop
    execute format('create policy "active users read %1$s" on public.%1$I for select to authenticated using (public.is_active_user())', t);
    execute format('create policy "active users insert %1$s" on public.%1$I for insert to authenticated with check (public.is_active_user())', t);
    execute format('create policy "active users update %1$s" on public.%1$I for update to authenticated using (public.is_active_user()) with check (public.is_active_user())', t);
    execute format('create policy "admins delete %1$s" on public.%1$I for delete to authenticated using (public.is_admin())', t);
  end loop;
end $$;

create policy "active read audit" on public.audit_log for select to authenticated using (public.is_active_user());

insert into public.report_types(name) values
('Laudo de porta corta-fogo'),('Laudo de sistema de hidrantes'),
('Laudo de iluminação de emergência'),('Laudo de sistema de alarme de incêndio'),
('Laudo de sprinklers'),('Laudo de instalações/equipamentos de segurança'),('Outro')
on conflict do nothing;

insert into public.company_settings(name, legal_name, cnpj, phone, whatsapp, email, website, address)
select 'LIMA Sistemas Contra Incêndio','LIMA Sistema Contra Incêndio','44.931.844/0001-21',
'(16) 99276-3885','(16) 99276-3885','grupolima3@gmail.com','https://limasistemas.com','Ribeirão Preto - SP'
where not exists(select 1 from public.company_settings);

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values('technical-documents','technical-documents',false,52428800,array['application/pdf','image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=false;

create policy "active users view files" on storage.objects for select to authenticated
using (bucket_id='technical-documents' and public.is_active_user());
create policy "active users upload files" on storage.objects for insert to authenticated
with check (bucket_id='technical-documents' and public.is_active_user());
create policy "active users update files" on storage.objects for update to authenticated
using (bucket_id='technical-documents' and public.is_active_user());
create policy "admins delete files" on storage.objects for delete to authenticated
using (bucket_id='technical-documents' and public.is_admin());

grant select on public.reports_with_status to authenticated;
grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

-- PROMOVER PRIMEIRO ADMINISTRADOR
-- Execute APÓS criar o usuário limasistemaofc@gmail.com em Authentication > Users:
-- update public.profiles set name='Lucas Lima', role='admin', active=true
-- where email='limasistemaofc@gmail.com';
