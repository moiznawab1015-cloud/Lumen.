# Lumen — Social Platform

A responsive social-media web app built with Next.js 15, React 19, Tailwind CSS and Supabase.

## Current setup status

The Supabase project and all four database migrations are already created/applied. The Vercel project and its two Supabase environment variables are also configured. The source repository still needs to be connected to Vercel, and a successful production build/deployment has not yet been verified.

See `SETUP-NEXT-STEPS.txt` for the exact remaining publishing steps and project details.

## Features in this source

- Sign-up, login and onboarding
- Profiles, private accounts, follow requests, blocking and reporting
- Feed, photo/video posts, likes, nested comments and saves
- Stories and Reels (maximum 60 seconds)
- Reel editor with trim, filters, brightness/contrast/saturation, audio and browser-side export
- Explore, search, hashtags and mentions
- Direct messages, shared posts and notifications
- Admin dashboard and moderation controls

## Local development

```bash
cp .env.example .env.local
# Fill in NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY
npm install
npm run dev
```

## Production build

```bash
npm install
npm run build
npm start
```

A successful production build has not yet been verified in this environment. Test all user flows and review storage/privacy settings before inviting users.
