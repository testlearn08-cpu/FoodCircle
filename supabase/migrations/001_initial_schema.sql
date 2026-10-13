-- Migration: initial schema for FoodCircle v0.2
-- Status: Implemented (file). Unverified (Supabase CLI not installed; SQL not executed).
-- Source: Inferred from standard Flutter/Supabase architecture (no handoff/prototype docs available).

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
  author_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  ingredients JSONB DEFAULT '[]',
  steps JSONB DEFAULT '[]',
  is_public BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Privacy rules: Row Level Security enabled on both tables.
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipes ENABLE ROW LEVEL SECURITY;

-- Profiles: users can read all public profiles; only owner can update/delete.
CREATE POLICY "profiles_read_all" ON public.profiles
  FOR SELECT USING (true);

CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles_delete_own" ON public.profiles
  FOR DELETE USING (auth.uid() = id);

-- Recipes: public recipes readable by anyone; private only by author.
CREATE POLICY "recipes_read_public" ON public.recipes
  FOR SELECT USING (is_public = true OR auth.uid() = author_id);

CREATE POLICY "recipes_insert_own" ON public.recipes
  FOR INSERT WITH CHECK (auth.uid() = author_id);

CREATE POLICY "recipes_update_own" ON public.recipes
  FOR UPDATE USING (auth.uid() = author_id) WITH CHECK (auth.uid() = author_id);

CREATE POLICY "recipes_delete_own" ON public.recipes
  FOR DELETE USING (auth.uid() = author_id);
