-- Masjid Timings Finder — Supabase schema (Google login for staff + super admin)
-- Run this whole file in Supabase Dashboard > SQL Editor.
--
-- ============================================================================
-- STEP 1 (EDIT THIS): replace the email below with the Gmail YOU will sign in with.
-- That account becomes super admin automatically on its first Google sign-in.
-- ============================================================================
create table if not exists public.admin_emails (
  email text primary key
);
insert into public.admin_emails (email) values ('YOUR-GMAIL@gmail.com') on conflict do nothing;
-- ============================================================================

create table if not exists public.masjids (
  id text primary key,
  name text not null,
  name_urdu text,
  address text not null,
  area text not null,
  city text not null default 'Hyderabad',
  pincode text,
  lat double precision not null,
  lng double precision not null,
  phone text,
  description text,
  jumuah_khutbah1 text,
  jumuah_khutbah2 text,
  default_timings jsonb not null,
  created_at timestamptz not null default now()
);

-- Per-date timings set by staff. Falls back to masjids.default_timings when no row exists.
create table if not exists public.timing_overrides (
  masjid_id text not null references public.masjids(id) on delete cascade,
  date date not null,
  timings jsonb not null,
  holiday boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (masjid_id, date)
);

-- One profile per Google account that has ever signed in (staff or super admin).
create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text,
  avatar_url text,
  role text not null default 'staff' check (role in ('staff', 'super_admin')),
  status text not null default 'pending' check (status in ('pending', 'active', 'disabled')),
  masjid_id text references public.masjids(id) on delete set null,
  created_at timestamptz not null default now()
);

-- ---------- Helper functions (security definer so policies don't recurse) ----------

create or replace function public.is_admin() returns boolean
language sql security definer stable set search_path = public as $$
  select exists (
    select 1 from public.profiles
    where user_id = auth.uid() and role = 'super_admin' and status = 'active'
  );
$$;

create or replace function public.staff_masjid() returns text
language sql security definer stable set search_path = public as $$
  select masjid_id from public.profiles
  where user_id = auth.uid() and status = 'active';
$$;

-- ---------- Auto-create a profile when someone signs in with Google ----------

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  make_admin boolean;
begin
  select exists (select 1 from public.admin_emails where lower(email) = lower(new.email)) into make_admin;
  insert into public.profiles (user_id, email, full_name, avatar_url, role, status)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
    new.raw_user_meta_data->>'avatar_url',
    case when make_admin then 'super_admin' else 'staff' end,
    case when make_admin then 'active' else 'pending' end
  )
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- Row level security ----------

-- Remove policies from the earlier (password-login) version of this schema, if present.
drop policy if exists "staff update own masjid" on public.masjids;
drop policy if exists "staff insert own timings" on public.timing_overrides;
drop policy if exists "staff update own timings" on public.timing_overrides;
drop policy if exists "staff delete own timings" on public.timing_overrides;

alter table public.masjids enable row level security;
alter table public.timing_overrides enable row level security;
alter table public.profiles enable row level security;
alter table public.admin_emails enable row level security;  -- no policies: nobody can read it via the API

-- Masjids: public read; admin full control; active staff can update only their own masjid.
drop policy if exists "masjids are public" on public.masjids;
create policy "masjids are public" on public.masjids for select using (true);

drop policy if exists "admin insert masjids" on public.masjids;
create policy "admin insert masjids" on public.masjids for insert with check (public.is_admin());

drop policy if exists "admin or own update masjids" on public.masjids;
create policy "admin or own update masjids" on public.masjids for update
  using (public.is_admin() or public.staff_masjid() = id)
  with check (public.is_admin() or public.staff_masjid() = id);

drop policy if exists "admin delete masjids" on public.masjids;
create policy "admin delete masjids" on public.masjids for delete using (public.is_admin());

-- Timings: public read; admin or the masjid's active staff can write.
drop policy if exists "timings are public" on public.timing_overrides;
create policy "timings are public" on public.timing_overrides for select using (true);

drop policy if exists "write own timings" on public.timing_overrides;
create policy "write own timings" on public.timing_overrides for all
  using (public.is_admin() or public.staff_masjid() = masjid_id)
  with check (public.is_admin() or public.staff_masjid() = masjid_id);

-- Profiles: you can read your own; admin can read and change everyone's. Nobody can edit their own role/status.
drop policy if exists "read own profile" on public.profiles;
create policy "read own profile" on public.profiles for select using (auth.uid() = user_id);

drop policy if exists "admin read profiles" on public.profiles;
create policy "admin read profiles" on public.profiles for select using (public.is_admin());

drop policy if exists "admin update profiles" on public.profiles;
create policy "admin update profiles" on public.profiles for update
  using (public.is_admin()) with check (public.is_admin());

drop policy if exists "admin delete profiles" on public.profiles;
create policy "admin delete profiles" on public.profiles for delete using (public.is_admin());

-- ---------- Sample masjids ----------

insert into public.masjids (id, name, name_urdu, address, area, city, pincode, lat, lng, jumuah_khutbah1, jumuah_khutbah2, description, default_timings) values
('masjid-e-bilal','Masjid e Bilal','مسجد بلال','Borabanda, Hyderabad','Borabanda','Hyderabad','500018',17.4585,78.4116,'12:45','13:30','A neighbourhood masjid serving the local community with daily congregational prayers and Friday Jumu''ah.',
 '{"fajr":{"azan":"04:45","jamaat":"05:15"},"zuhr":{"azan":"12:30","jamaat":"13:00"},"asr":{"azan":"16:45","jamaat":"17:00"},"maghrib":{"azan":"18:18","jamaat":"18:23"},"isha":{"azan":"19:45","jamaat":"20:15"}}'),
('masjid-al-furqan','Masjid Al Furqan','مسجد الفرقان','Sanjeeva Reddy Nagar, Hyderabad','Sanath Nagar','Hyderabad','500038',17.4519,78.4338,'12:45','13:30','A neighbourhood masjid serving the local community with daily congregational prayers and Friday Jumu''ah.',
 '{"fajr":{"azan":"04:47","jamaat":"05:17"},"zuhr":{"azan":"12:32","jamaat":"13:02"},"asr":{"azan":"16:47","jamaat":"17:02"},"maghrib":{"azan":"18:20","jamaat":"18:25"},"isha":{"azan":"19:47","jamaat":"20:17"}}'),
('masjid-e-noor','Masjid e Noor','مسجد نور','Erragadda, Hyderabad','Erragadda','Hyderabad','500018',17.4482,78.4332,'12:45','13:30','A neighbourhood masjid serving the local community with daily congregational prayers and Friday Jumu''ah.',
 '{"fajr":{"azan":"04:44","jamaat":"05:14"},"zuhr":{"azan":"12:29","jamaat":"12:59"},"asr":{"azan":"16:44","jamaat":"16:59"},"maghrib":{"azan":"18:17","jamaat":"18:22"},"isha":{"azan":"19:44","jamaat":"20:14"}}'),
('masjid-al-hidaya','Masjid Al Hidaya','مسجد الہدایہ','Ameerpet, Hyderabad','Ameerpet','Hyderabad','500016',17.4375,78.4482,'12:45','13:30','A neighbourhood masjid serving the local community with daily congregational prayers and Friday Jumu''ah.',
 '{"fajr":{"azan":"04:48","jamaat":"05:18"},"zuhr":{"azan":"12:33","jamaat":"13:03"},"asr":{"azan":"16:48","jamaat":"17:03"},"maghrib":{"azan":"18:21","jamaat":"18:26"},"isha":{"azan":"19:48","jamaat":"20:18"}}'),
('masjid-e-rahman','Masjid e Rahman','مسجد رحمان','SR Nagar, Hyderabad','S.R. Nagar','Hyderabad','500038',17.4399,78.4426,'12:45','13:30','A neighbourhood masjid serving the local community with daily congregational prayers and Friday Jumu''ah.',
 '{"fajr":{"azan":"04:46","jamaat":"05:16"},"zuhr":{"azan":"12:31","jamaat":"13:01"},"asr":{"azan":"16:46","jamaat":"17:01"},"maghrib":{"azan":"18:19","jamaat":"18:24"},"isha":{"azan":"19:46","jamaat":"20:16"}}')
on conflict (id) do nothing;

-- ---------- Only if you signed in BEFORE running this file and are stuck as "pending" ----------
-- update public.profiles set role = 'super_admin', status = 'active' where email = 'your-gmail@gmail.com';
