# Masjid Timings Finder

Next.js 14 (App Router) + Tailwind + Supabase. Deploys on Vercel from GitHub.

- **Public (no login):** home, search by name/locality, nearby masjids with radius filter, list/map toggle, masjid detail (Timings / About / Location), search location, Salah Tracker, Hijri Calendar, English/Urdu.
- **Staff (Google login, approved by admin):** dashboard, update timings per date, holiday / no-jamaat, Friday khutbah times, success screen.
- **Super admin (Google login):** dashboard stats, masjid list, add/edit/delete masjid with map pin picker, manage users, pending requests (approve and assign a masjid).

Not built: announcements, gallery tab, admin "Settings".

## How login works

Only staff and the super admin log in, and only with **Continue with Google**.

1. Someone signs in with Google for the first time and gets a profile with status **pending**.
2. The super admin opens **Pending Requests**, picks that person's masjid, and taps **Approve**.
3. Approved staff can edit only their own masjid's timings. Access is enforced in the database (row-level security), not just in the UI.
4. Emails listed in the `admin_emails` table become **super admin** automatically on first sign-in.

## Setup

### 1. Supabase database
1. Open `supabase/schema.sql` and replace `YOUR-GMAIL@gmail.com` near the top with the Gmail you will sign in with.
2. Paste all of it into the Supabase **SQL Editor** and run it. It is safe to re-run on a database that already has the earlier version; it keeps your masjids and timings.
3. If you already signed in once before running it and are stuck as pending, run:
   ```sql
   update public.profiles set role = 'super_admin', status = 'active' where email = 'your-gmail@gmail.com';
   ```

### 2. Google sign-in
1. Google Cloud Console > **APIs & Services > Credentials > Create credentials > OAuth client ID** (type: Web application). If asked, set up the consent screen first.
2. Under **Authorized redirect URIs** add the callback shown in Supabase: **Authentication > Providers > Google** (looks like `https://<project-ref>.supabase.co/auth/v1/callback`).
3. Copy the Google **Client ID** and **Client secret** into that same Supabase Google provider page, enable it, and save.
4. In Supabase **Authentication > URL Configuration**:
   - Site URL: your Vercel URL, e.g. `https://my-masjids.vercel.app`
   - Redirect URLs: add `https://my-masjids.vercel.app/auth/callback` and `http://localhost:3000/auth/callback`

### 3. Vercel
1. Push this code to your GitHub repo; Vercel redeploys automatically.
2. In Vercel **Project > Settings > Environment Variables** add `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` (Supabase **Project Settings > API**), then redeploy.

### Run locally
```bash
npm install
cp .env.example .env.local   # fill in the two Supabase values (optional: empty = demo mode)
npm run dev
```
Without Supabase keys the public site runs on built-in sample masjids and login is disabled.

## Notes
- Timings are stored as 24-hour `HH:MM` and shown in 12-hour format.
- A date-specific entry overrides the masjid's default timings; with none, defaults are shown.
- Maps use OpenStreetMap through Leaflet (no API key). Your designs show Google Maps; switching needs a Google Maps API key.
- The Supabase anon key is meant to be public; the policies in `schema.sql` protect the data.
