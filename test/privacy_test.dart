// Privacy and authorization rules, asserted against the SQL migrations.
//
// These RUN in CI (python3 tool/check_sql_expectations.py mirrors them as a fast local
// check), but they are *static* assertions over the migration text: they catch a policy
// being weakened or deleted in review, and they cannot prove the policy behaves as written.
// Behavioural RLS tests against a real PostgreSQL service container are Phase 0.5 of
// docs/ANALYSIS_AND_ROADMAP.md and are what will close that gap.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Collapses whitespace and lowercases, so assertions survive reformatting.
String _normalize(String sql) =>
    sql.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

void main() {
  late String schema;
  late String indexesAndTriggers;
  late String authHelpers;
  late String searchMigration;
  late String imageStorage;

  setUpAll(() {
    String readMigration(String name) {
      final file = File('supabase/migrations/$name');
      if (!file.existsSync()) {
        fail(
          'Missing ${file.path} — run `flutter test` from the package root.',
        );
      }
      return _normalize(file.readAsStringSync());
    }

    schema = readMigration('001_initial_schema.sql');
    indexesAndTriggers = readMigration('002_indexes_and_triggers.sql');
    authHelpers = readMigration('003_auth_helpers.sql');
    searchMigration = readMigration('006_recipe_search.sql');
    imageStorage = readMigration('005_storage.sql');
  });

  group('Row Level Security is enabled', () {
    test('on profiles', () {
      expect(
        schema,
        contains('alter table public.profiles enable row level security'),
      );
    });

    test('on recipes', () {
      expect(
        schema,
        contains('alter table public.recipes enable row level security'),
      );
    });
  });

  group('profiles policies', () {
    test('the username is unique and required', () {
      // The edit screen's "That username is taken." is a translation of this constraint's 23505.
      // Without it the message would be unreachable and two people could share a handle.
      expect(schema, contains('username text unique not null'));
    });

    test('readable by anyone', () {
      expect(
        schema,
        contains(
          'create policy "profiles_read_all" on public.profiles '
          'for select using (true)',
        ),
      );
    });

    test('insert restricted to the owner', () {
      expect(
        schema,
        contains(
          'create policy "profiles_insert_own" on public.profiles '
          'for insert with check (auth.uid() = id)',
        ),
      );
    });

    test('update restricted to the owner on both USING and WITH CHECK', () {
      expect(
        schema,
        contains(
          'create policy "profiles_update_own" on public.profiles '
          'for update using (auth.uid() = id) with check (auth.uid() = id)',
        ),
      );
    });

    test('delete restricted to the owner', () {
      expect(
        schema,
        contains(
          'create policy "profiles_delete_own" on public.profiles '
          'for delete using (auth.uid() = id)',
        ),
      );
    });
  });

  group('recipes policies', () {
    test('public recipes readable by anyone, private ones only by author', () {
      expect(
        schema,
        contains(
          'create policy "recipes_read_public" on public.recipes '
          'for select using (is_public = true or auth.uid() = author_id)',
        ),
      );
    });

    test('insert restricted to the author', () {
      expect(
        schema,
        contains(
          'create policy "recipes_insert_own" on public.recipes '
          'for insert with check (auth.uid() = author_id)',
        ),
      );
    });

    test('update restricted to the author', () {
      expect(
        schema,
        contains(
          'create policy "recipes_update_own" on public.recipes '
          'for update using (auth.uid() = author_id) '
          'with check (auth.uid() = author_id)',
        ),
      );
    });

    test('delete restricted to the author', () {
      expect(
        schema,
        contains(
          'create policy "recipes_delete_own" on public.recipes '
          'for delete using (auth.uid() = author_id)',
        ),
      );
    });
  });

  group('schema integrity', () {
    test('a recipe always has an author', () {
      expect(schema, contains('author_id uuid not null references auth.users'));
    });
  });

  group('auth helpers do not leak auth.users', () {
    for (final migration in {
      '001_initial_schema.sql': () => schema,
      '002_indexes_and_triggers.sql': () => indexesAndTriggers,
      '003_auth_helpers.sql': () => authHelpers,
    }.entries) {
      test('${migration.key} creates no view', () {
        final sql = migration.value();
        expect(sql, isNot(contains('create view')));
        expect(sql, isNot(contains('create or replace view')));
      });
    }

    test('the old auth_users view is dropped, not recreated', () {
      expect(authHelpers, contains('drop view if exists public.auth_users'));
    });

    test('the signup trigger runs as a hardened SECURITY DEFINER function', () {
      expect(
        authHelpers,
        contains('create or replace function public.handle_new_user()'),
      );
      expect(authHelpers, contains('security definer'));
      // An empty search_path plus schema-qualified identifiers stops a caller
      // from shadowing `profiles` with an object they control.
      expect(authHelpers, contains("set search_path = ''"));
    });

    test('the signup trigger is attached to auth.users', () {
      expect(
        authHelpers,
        contains(
          'after insert on auth.users for each row execute function '
          'public.handle_new_user()',
        ),
      );
    });

    test('clients cannot call the SECURITY DEFINER function directly', () {
      expect(
        authHelpers,
        contains('revoke all on function public.handle_new_user() from public'),
      );
    });
  });

  group('search is not a second authorization boundary', () {
    test('runs as the caller, so the policies decide what it returns', () {
      expect(searchMigration, contains('security invoker'));
      // An empty search_path plus schema-qualified identifiers, the same hardening 003 applies
      // to the signup trigger: nobody can shadow `public.recipes` with an object they control.
      expect(searchMigration, contains("set search_path = ''"));

      // The visibility rule must live in the policies and nowhere else — one boundary is
      // debuggable, two that disagree are not. These are negative *and scoped to this file*,
      // which is what check_sql_expectations.py's negative checks had to learn: 001 spells out
      // `is_public` and `auth.uid()` on purpose, and 003 is a SECURITY DEFINER function.
      expect(searchMigration, isNot(contains('is_public')));
      expect(searchMigration, isNot(contains('auth.uid')));
      expect(searchMigration, isNot(contains('security definer')));
    });

    test('creates no view', () {
      expect(searchMigration, isNot(contains('create view')));
      expect(searchMigration, isNot(contains('create or replace view')));
    });
  });

  group('indexes and triggers', () {
    test('the author foreign key is indexed', () {
      expect(
        indexesAndTriggers,
        contains(
          'create index if not exists idx_recipes_author '
          'on public.recipes(author_id)',
        ),
      );
    });

    test('updated_at is maintained by a trigger on profiles', () {
      expect(
        indexesAndTriggers,
        contains(
          'create trigger update_profiles_updated_at '
          'before update on public.profiles for each row execute function '
          'public.update_updated_at()',
        ),
      );
    });

    test('updated_at is maintained by a trigger on recipes', () {
      expect(
        indexesAndTriggers,
        contains(
          'create trigger update_recipes_updated_at '
          'before update on public.recipes for each row execute function '
          'public.update_updated_at()',
        ),
      );
    });
  });

  group('recipe image storage policies', () {
    test('bucket is public and limited to supported image uploads', () {
      expect(
        imageStorage,
        contains(
          "values ( 'recipe-images', 'recipe-images', true, 10485760, "
          "array['image/jpeg', 'image/png', 'image/webp'] )",
        ),
      );
    });

    test('public clients can read recipe images', () {
      expect(
        imageStorage,
        contains(
          "create policy recipe_images_read_public on storage.objects "
          "for select to public using (bucket_id = 'recipe-images')",
        ),
      );
    });

    test('uploads are restricted to the signed-in user folder', () {
      expect(
        imageStorage,
        contains(
          "create policy recipe_images_insert_own on storage.objects "
          "for insert to authenticated with check ( bucket_id = 'recipe-images' "
          'and (storage.foldername(name))[1] = (select auth.uid())::text )',
        ),
      );
    });

    test('updates cannot move an image outside the owner folder', () {
      expect(
        imageStorage,
        contains(
          "create policy recipe_images_update_own on storage.objects "
          "for update to authenticated using ( bucket_id = 'recipe-images' "
          'and (storage.foldername(name))[1] = (select auth.uid())::text ) '
          "with check ( bucket_id = 'recipe-images' "
          'and (storage.foldername(name))[1] = (select auth.uid())::text )',
        ),
      );
    });

    test('deletes are restricted to the signed-in user folder', () {
      expect(
        imageStorage,
        contains(
          "create policy recipe_images_delete_own on storage.objects "
          "for delete to authenticated using ( bucket_id = 'recipe-images' "
          'and (storage.foldername(name))[1] = (select auth.uid())::text )',
        ),
      );
    });
  });
}
