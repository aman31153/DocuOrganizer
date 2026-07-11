import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/google_drive_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/starred_files_screen.dart';
import 'screens/all_files_screen.dart';
import 'screens/login_screen.dart';
import 'widgets/app_drawer.dart';
import 'widgets/create_new_sheet.dart';
import 'providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/sync_provider.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'package:documents_organizer/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final sharedPreferences = await SharedPreferences.getInstance();

  await NotificationService().init();
  await NotificationService().requestPermissions();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final authState = ref.watch(authStateProvider);
    
    return MaterialApp(
      title: 'DocuOrganizer',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue, 
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E1E1E),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      ),
      home: authState.when(
        data: (user) {
          if (user != null) return const MainContainer();
          return const LoginScreen();
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (err, stack) => Scaffold(
          body: Center(child: Text('Error: $err')),
        ),
      ),
    );
  }
}

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const AllFilesScreen(),
    const SizedBox.shrink(), // Placeholder for the middle button
    const StarredFilesScreen(),
    const GoogleDriveScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      drawer: const AppDrawer(),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue);
            }
            return TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]);
          }),
        ),
        child: NavigationBar(
          height: 65,
          elevation: 0,
          backgroundColor: theme.cardTheme.color,
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            if (index == 2) {
              _showCreateNewSheet(context);
            } else {
              setState(() {
                _currentIndex = index;
              });
            }
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: Colors.blue),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.access_time),
              selectedIcon: Icon(Icons.access_time_filled, color: Colors.blue),
              label: 'Recent',
            ),
            const NavigationDestination(
              icon: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blue,
                child: Icon(Icons.add, color: Colors.white),
              ),
              label: 'Add',
            ),
            const NavigationDestination(
              icon: Icon(Icons.star_outline),
              selectedIcon: Icon(Icons.star, color: Colors.blue),
              label: 'Starred',
            ),
            NavigationDestination(
              icon: Opacity(
                opacity: 0.7,
                child: Image.network(
                  'https://upload.wikimedia.org/wikipedia/commons/1/12/Google_Drive_icon_%282020%29.svg',
                  height: 22,
                  width: 22,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.drive_eta),
                ),
              ),
              selectedIcon: Image.network(
                'https://upload.wikimedia.org/wikipedia/commons/1/12/Google_Drive_icon_%282020%29.svg',
                height: 22,
                width: 22,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.drive_eta, color: Colors.blue),
              ),
              label: 'Drive',
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateNewSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateNewSheet(),
    );
  }
}
