import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_store.dart';
import '../../auth/data/auth_repository.dart';
import '../data/task_repository.dart';
import '../domain/task.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final tokenStoreProvider = Provider<TokenStore>((ref) {
  return TokenStore(ref.watch(secureStorageProvider));
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    http.Client(),
    ref.read(tokenStoreProvider),
    onSessionExpired: () => ref.read(authStateProvider.notifier).signOut(),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider), ref.watch(tokenStoreProvider));
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(ref.watch(apiClientProvider));
});

class AuthStateNotifier extends StateNotifier<bool> {
  AuthStateNotifier(this._tokenStore) : super(false) {
    checkAuth();
  }

  final TokenStore _tokenStore;

  Future<void> checkAuth() async {
    final token = await _tokenStore.readAccessToken();
    state = token != null;
  }

  void setAuthenticated(bool authenticated) {
    state = authenticated;
  }

  void signOut() {
    state = false;
  }
}

final authStateProvider = StateNotifierProvider<AuthStateNotifier, bool>((ref) {
  return AuthStateNotifier(ref.watch(tokenStoreProvider));
});

class TasksState {
  const TasksState({
    this.loading = false,
    this.tasks = const [],
    this.errorMessage,
  });

  final bool loading;
  final List<Task> tasks;
  final String? errorMessage;

  TasksState copyWith({
    bool? loading,
    List<Task>? tasks,
    String? errorMessage,
  }) {
    return TasksState(
      loading: loading ?? this.loading,
      tasks: tasks ?? this.tasks,
      errorMessage: errorMessage,
    );
  }
}

class TaskController extends StateNotifier<TasksState> {
  TaskController(this._repository) : super(const TasksState(loading: true)) {
    loadTasks();
  }

  final TaskRepository _repository;

  Future<void> loadTasks() async {
    state = state.copyWith(loading: true, errorMessage: null);
    try {
      final tasks = await _repository.list();
      state = state.copyWith(loading: false, tasks: tasks, errorMessage: null);
    } catch (e) {
      state = state.copyWith(loading: false, errorMessage: e.toString());
    }
  }

  Future<void> toggleCompleted(Task task) async {
    try {
      final updated = await _repository.setCompleted(task, !task.completed);
      state = state.copyWith(
        tasks: state.tasks.map((t) => t.id == task.id ? updated : t).toList(),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> deleteTask(Task task) async {
    try {
      await _repository.delete(task.id);
      state = state.copyWith(
        tasks: state.tasks.where((t) => t.id != task.id).toList(),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> addTask(String title, String? description) async {
    try {
      final newTask = await _repository.create(title, description);
      state = state.copyWith(
        tasks: [newTask, ...state.tasks],
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }
}

final taskControllerProvider = StateNotifierProvider<TaskController, TasksState>((ref) {
  return TaskController(ref.watch(taskRepositoryProvider));
});
