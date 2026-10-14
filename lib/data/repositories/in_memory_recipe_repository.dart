import '../models/profile.dart';
import '../models/recipe.dart';
import '../models/recipe_image_upload.dart';
import 'recipe_repository.dart';

/// The repository used when no Supabase project is configured, and by the widget tests.
///
/// This is not a mock: it is the same contract as [SupabaseRecipeRepository], implemented in
/// memory, with the same ordering and the same pagination rules. That is what makes the web
/// preview and the widget tests exercise the *real* feed screen rather than a stub of it.
///
/// It cannot enforce the policies, because there is no database — so it deliberately implements
/// only the read side plus create/delete for the signed-in demo user. Image uploads fail loudly
/// rather than pretending binary data was persisted or returning a fabricated public URL.
class InMemoryRecipeRepository implements RecipeRepository {
  InMemoryRecipeRepository({
    List<Recipe>? recipes,
    List<Profile>? profiles,
    this.currentUserId,
  })  : _recipes = [...?recipes],
        _profiles = _indexById(profiles);

  /// Demo data: enough shape to exercise the feed (public and private, tags, times, difficulty,
  /// missing fields) without looking like real users.
  factory InMemoryRecipeRepository.seeded() {
    final now = DateTime.now().toUtc();
    const ana = Profile(
      id: 'demo-ana',
      username: 'ana_cooks',
      displayName: 'Ana',
      bio: 'Cooks for four, most days.',
    );
    const dev = Profile(
      id: 'demo-dev',
      username: 'dev_bakes',
      displayName: 'Dev',
    );

    return InMemoryRecipeRepository(
      currentUserId: ana.id,
      profiles: const [ana, dev],
      recipes: [
        Recipe(
          id: 'demo-1',
          authorId: ana.id,
          title: 'Everyday dal',
          description: 'The one that gets made when nobody can decide.',
          createdAt: now.subtract(const Duration(hours: 3)),
          servings: 4,
          prepMinutes: 10,
          cookMinutes: 35,
          difficulty: 'easy',
          tags: const ['vegetarian', 'weeknight'],
          ingredients: const [
            '1 cup red lentils',
            '1 tsp turmeric',
            '2 tbsp ghee',
            '1 tsp cumin seeds',
          ],
          steps: const [
            'Rinse the lentils until the water runs clear.',
            'Simmer with turmeric and 4 cups water for 25 minutes.',
            'Bloom the cumin in ghee and pour it over.',
          ],
          author: ana,
        ),
        Recipe(
          id: 'demo-2',
          authorId: dev.id,
          title: 'No-knead bread',
          description: 'Start it tonight, bake it tomorrow.',
          createdAt: now.subtract(const Duration(days: 1, hours: 2)),
          servings: 1,
          cookMinutes: 45,
          difficulty: 'medium',
          tags: const ['baking'],
          ingredients: const [
            '400 g bread flour',
            '1 tsp salt',
            '1/4 tsp yeast',
            '300 ml water'
          ],
          steps: const [
            'Mix everything. It will look wrong.',
            'Leave covered for 18 hours.',
            'Bake in a hot pot, lid on, then lid off.',
          ],
          author: dev,
        ),
        Recipe(
          id: 'demo-3',
          authorId: ana.id,
          title: 'Leftover rice fritters',
          createdAt: now.subtract(const Duration(days: 4)),
          difficulty: 'easy',
          ingredients: const ['2 cups cooked rice', '1 egg', 'Spring onion'],
          steps: const ['Mix.', 'Fry.', 'Eat standing up.'],
          isPublic: false,
          author: ana,
        ),
      ],
    );
  }

  final List<Recipe> _recipes;
  final Map<String, Profile> _profiles;

  /// Stands in for `auth.uid()`. When null the repository behaves like an anonymous client:
  /// public recipes only.
  final String? currentUserId;

  int _created = 0;

  @override
  Future<List<Recipe>> fetchFeed({int limit = 20, DateTime? before}) async {
    final visible = _recipes
        .where((recipe) => recipe.isPublic || recipe.authorId == currentUserId)
        .where((recipe) => before == null || recipe.createdAt.isBefore(before))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return List<Recipe>.unmodifiable(visible.take(limit));
  }

  @override
  Future<Recipe?> fetchById(String id) async {
    for (final recipe in _recipes) {
      if (recipe.id == id &&
          (recipe.isPublic || recipe.authorId == currentUserId)) {
        return recipe;
      }
    }
    return null;
  }

  @override
  Future<List<Recipe>> fetchMine(String authorId, {int limit = 50}) async {
    final mine = _recipes
        .where((recipe) => recipe.authorId == authorId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return List<Recipe>.unmodifiable(mine.take(limit));
  }

  @override
  Future<Recipe> create(RecipeDraft draft) async {
    if (currentUserId == null || draft.authorId != currentUserId) {
      throw StateError(
        'Signed-out or mismatched author: the insert policy would reject '
        'author_id=${draft.authorId} for this session.',
      );
    }

    final recipe = Recipe(
      id: 'demo-new-${++_created}',
      authorId: draft.authorId,
      title: draft.title,
      createdAt: DateTime.now().toUtc(),
      description: draft.description,
      imageUrl: draft.imageUrl,
      servings: draft.servings,
      prepMinutes: draft.prepMinutes,
      cookMinutes: draft.cookMinutes,
      difficulty: draft.difficulty,
      tags: draft.tags,
      ingredients: draft.ingredients,
      steps: draft.steps,
      isPublic: draft.isPublic,
      author: _profiles[draft.authorId],
    );

    _recipes.add(recipe);
    return recipe;
  }

  @override
  Future<String> uploadImage(RecipeImageUpload _) async {
    throw UnsupportedError(
      'Image uploads require a configured Supabase project; demo data is ephemeral.',
    );
  }

  @override
  Future<void> delete(String id) async {
    _recipes.removeWhere(
        (recipe) => recipe.id == id && recipe.authorId == currentUserId);
  }
}

Map<String, Profile> _indexById(List<Profile>? profiles) {
  final Map<String, Profile> index = <String, Profile>{};
  for (final Profile profile in profiles ?? const <Profile>[]) {
    index[profile.id] = profile;
  }
  return index;
}
