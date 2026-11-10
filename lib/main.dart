import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app_scope.dart';
import 'firebase_options.dart';
import 'models/diary_entry.dart';
import 'models/entry.dart';
import 'models/reading_passage.dart';
import 'screens/login_screen.dart';
import 'screens/root_tabs.dart';
import 'services/auth_service.dart';
import 'services/diary_repository.dart';
import 'services/entry_repository.dart';
import 'services/reading_repository.dart';
import 'services/study_log_service.dart';
import 'services/sync_service.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await Hive.initFlutter();
  Hive.registerAdapter(EntryAdapter());
  Hive.registerAdapter(ReadingPassageAdapter());
  Hive.registerAdapter(DiaryEntryAdapter());
  final box = await Hive.openBox<Entry>(EntryRepository.boxName);
  final readingBox = await Hive.openBox<ReadingPassage>(ReadingRepository.boxName);
  final diaryBox = await Hive.openBox<DiaryEntry>(DiaryRepository.boxName);
  final studyLogBox = await Hive.openBox<dynamic>(StudyLogService.boxName);

  final repository = EntryRepository(box);
  await repository.seedIfEmpty();
  final readingRepository = ReadingRepository(readingBox);
  final diaryRepository = DiaryRepository(diaryBox);
  final studyLog = StudyLogService(studyLogBox);

  SyncService(
    entryBox: box,
    readingBox: readingBox,
    diaryBox: diaryBox,
    studyLogBox: studyLogBox,
  ).start();

  runApp(
    KchoApp(
      repository: repository,
      readingRepository: readingRepository,
      diaryRepository: diaryRepository,
      studyLog: studyLog,
    ),
  );
}

class KchoApp extends StatelessWidget {
  const KchoApp({
    required this.repository,
    required this.readingRepository,
    required this.diaryRepository,
    required this.studyLog,
    super.key,
  });

  final EntryRepository repository;
  final ReadingRepository readingRepository;
  final DiaryRepository diaryRepository;
  final StudyLogService studyLog;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      repository: repository,
      readingRepository: readingRepository,
      diaryRepository: diaryRepository,
      studyLog: studyLog,
      child: const CupertinoApp(
        title: 'K帳',
        debugShowCheckedModeBanner: false,
        theme: CupertinoThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: AppColors.paperBackground,
          barBackgroundColor: AppColors.cardBackground,
          primaryColor: AppColors.hankoRed,
          primaryContrastingColor: CupertinoColors.white,
          textTheme: CupertinoTextThemeData(
            primaryColor: AppColors.hankoRed,
            textStyle: TextStyle(color: AppColors.inkPrimary, fontSize: 17),
            navTitleTextStyle: TextStyle(
              color: AppColors.inkPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
            navLargeTitleTextStyle: TextStyle(
              color: AppColors.inkPrimary,
              fontSize: 34,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        home: _AuthGate(),
      ),
    );
  }
}

/// Shows [LoginScreen] until a Firebase user is signed in, then [RootTabs].
/// Study data itself stays local (Hive) regardless of auth state — signing
/// in only gates access to the app for now.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CupertinoPageScaffold(
            child: Center(child: CupertinoActivityIndicator()),
          );
        }
        return snapshot.data == null ? const LoginScreen() : const RootTabs();
      },
    );
  }
}
