-- Migration: initial schema for FoodCircle v0.2
-- Status: Implemented (file). Unverified (Supabase CLI not installed; SQL not executed).
-- Source: Inferred from standard Flutter/Supabase architecture (no handoff/prototype docs available).
--
-- Hardening pass: policies are preceded by DROP POLICY IF EXISTS so a partially
-- applied migration can be re-run, `recipes.author_id` is NOT NULL (the insert
-- policy requires it to equal auth.uid()), and profiles gained the missing
-- INSERT policy that a client needs to create its own profile row.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Profiles table (extends auth.users via foreign key)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE NOT NULL,
  display_name TEXT,
  avatar_url TEXT,
  bio TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Recipes table
CREATE TABLE IF NOT EXISTS public.recipes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  ingredients JSONB DEFAULT '[]',
  steps JSONB DEFAULT '[]',
  is_public BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Privacy rules: Row Level Security enabled on both tables.
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipes ENABLE ROW LEVEL SECURITY;

-- Profiles: everyone can read profiles; only the owner can create, update or
-- delete their own row.
DROP POLICY IF EXISTS "profiles_read_all" ON public.profiles;
CREATE POLICY "profiles_read_all" ON public.profiles
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
CREATE POLICY "profiles_insert_own" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_delete_own" ON public.profiles;
CREATE POLICY "profiles_delete_own" ON public.profiles
  FOR DELETE USING (auth.uid() = id);

-- Recipes: public recipes readable by anyone; private only by author.
DROP POLICY IF EXISTS "recipes_read_public" ON public.recipes;
CREATE POLICY "recipes_read_public" ON public.recipes
  FOR SELECT USING (is_public = true OR auth.uid() = author_id);

DROP POLICY IF EXISTS "recipes_insert_own" ON public.recipes;
CREATE POLICY "recipes_insert_own" ON public.recipes
  FOR INSERT WITH CHECK (auth.uid() = author_id);

DROP POLICY IF EXISTS "recipes_update_own" ON public.recipes;
CREATE POLICY "recipes_update_own" ON public.recipes
  FOR UPDATE USING (auth.uid() = author_id) WITH CHECK (auth.uid() = author_id);

DROP POLICY IF EXISTS "recipes_delete_own" ON public.recipes;
CREATE POLICY "recipes_delete_own" ON public.recipes
  FOR DELETE USING (auth.uid() = author_id);
