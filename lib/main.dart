import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'dart:io';

import 'package:in_app_review/in_app_review.dart';

import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'widgets/ad_banner.dart';
import 'utils/ad_manager.dart';
import 'utils/purchase_manager.dart';
import 'widgets/premium_unlock_card.dart';
import 'widgets/special_offer_dialog.dart';
import 'widgets/premium_upgrade_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  runApp(const MyApp());
}

// -----------------------------------------------------------------------------
// 0. Enums
// -----------------------------------------------------------------------------

enum QuizMode { shuffle, sequential }

// -----------------------------------------------------------------------------
// 1. Data Models & Helpers
// -----------------------------------------------------------------------------

class Quiz {
  final String question;
  final List<String> choices;
  final int correctIndex;
  final String explanation;
  final String? imagePath;

  Quiz({
    required this.question,
    required this.choices,
    required this.correctIndex,
    required this.explanation,
    this.imagePath,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      question: (json['question'] as String).replaceAll('\n', ''),
      choices: List<String>.from(json['choices'] ?? []),
      correctIndex: json['correctIndex'] as int,
      explanation: json['explanation'] as String,
      imagePath: json['imagePath'] as String?,
    );
  }
}

class PrefsHelper {
  static const String _keyWeakQuestions = 'weak_questions';
  static const String _keyAdCounter = 'ad_counter';

  static Future<bool> shouldShowInterstitial() async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt(_keyAdCounter) ?? 0;
    current++;
    await prefs.setInt(_keyAdCounter, current);
    return (current % 2 == 0);
  }

  static const String _keyCompleteQuizCount = 'complete_quiz_count';

  static Future<bool> shouldRequestReview() async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt(_keyCompleteQuizCount) ?? 0;
    current++;
    await prefs.setInt(_keyCompleteQuizCount, current);
    
    // 2回目の完了時のみレビュー依頼を表示
    return (current == 2);
  }
  
  static Future<void> saveHighScore(String categoryKey, int score) async {
    final prefs = await SharedPreferences.getInstance();
    final currentHigh = prefs.getInt(categoryKey) ?? 0;
    if (score > currentHigh) {
      await prefs.setInt(categoryKey, score);
    }
  }

  static Future<int> getHighScore(String categoryKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(categoryKey) ?? 0;
  }

  static Future<void> addWeakQuestions(List<String> questions) async {
    if (questions.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList(_keyWeakQuestions) ?? [];
    
    bool changed = false;
    for (final q in questions) {
      if (!current.contains(q)) {
        current.add(q);
        changed = true;
      }
    }
    
    if (changed) {
      await prefs.setStringList(_keyWeakQuestions, current);
    }
  }

  static Future<void> removeWeakQuestions(List<String> questions) async {
    if (questions.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList(_keyWeakQuestions) ?? [];
    
    bool changed = false;
    for (final q in questions) {
       if (current.remove(q)) {
         changed = true;
       }
    }
    
    if (changed) {
      await prefs.setStringList(_keyWeakQuestions, current);
    }
  }

  static Future<List<String>> getWeakQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyWeakQuestions) ?? [];
  }

  static const String _keyHasSeenSpecialOffer = 'has_seen_special_offer';

  static Future<bool> hasSeenSpecialOffer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasSeenSpecialOffer) ?? false;
  }

  static Future<void> setHasSeenSpecialOffer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenSpecialOffer, true);
  }
}

class QuizData {
  static Map<String, List<Quiz>> _data = {};

  static Future<void> load() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/quiz_data.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      _data = {};
      jsonData.forEach((key, value) {
        if (value is List) {
          _data[key] = value.map((q) => Quiz.fromJson(q)).toList();
        }
      });
    } catch (e) {
      debugPrint("Error loading quiz data: $e");
      _data = {};
    }
  }

  static List<Quiz> get part1 => _data['part1'] ?? [];
  static List<Quiz> get part2 => _data['part2'] ?? [];
  static List<Quiz> get part3 => _data['part3'] ?? [];
  static List<Quiz> get part4 => _data['part4'] ?? [];
  static List<Quiz> get part5 => _data['part5'] ?? [];

  static List<Quiz> getQuizzesFromTexts(List<String> texts) {
    final allQuizzes = [
      ...part1,
      ...part2,
      ...part3,
      ...part4,
      ...part5,
    ];
    return allQuizzes.where((q) => texts.contains(q.question)).toList();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '運行管理者 旅客',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD35400)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFD35400),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const HomePage(),
    );
  }
}

// -----------------------------------------------------------------------------
// 2. Home Page
// -----------------------------------------------------------------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _weaknessCount = 0;
  bool _isLoading = true;
  QuizMode _currentMode = QuizMode.shuffle;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestTrackingPermissionIfNeeded();
    });
  }
  
  Future<void> _initializeApp() async {
    try {
      await MobileAds.instance.initialize();
      await PurchaseManager.instance.init();

      AdManager.instance.preloadAd('quiz');

      await QuizData.load();
      await _loadUserData();
    } catch (e, st) {
      debugPrint('App initialization failed: $e');
      debugPrintStack(stackTrace: st);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _requestTrackingPermissionIfNeeded() async {
    if (!Platform.isIOS) return;

    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status != TrackingStatus.notDetermined) {
        debugPrint('ATT Status: $status');
        return;
      }

      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      final updatedStatus =
          await AppTrackingTransparency.requestTrackingAuthorization();
      debugPrint('ATT Status: $updatedStatus');
    } catch (e, st) {
      debugPrint('ATT request failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }
  
  Future<void> _loadUserData() async {
    final weakList = await PrefsHelper.getWeakQuestions();
    if (mounted) {
      setState(() {
        _weaknessCount = weakList.length;
      });
    }
  }

  void _startQuiz(BuildContext context, List<Quiz> quizList, String categoryKey, {bool isRandom10 = true}) async {
    List<Quiz> questionsToUse = List<Quiz>.from(quizList);
    
    if (isRandom10) {
      questionsToUse.shuffle();
      if (questionsToUse.length > 10) {
        questionsToUse = questionsToUse.take(10).toList();
      }
    } else {
      // Sequential mode: Just use original order
    }
    
    AdManager.instance.preloadAd('result');
    AdManager.instance.preloadInterstitial();
    
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QuizPage(
          quizzes: questionsToUse,
          categoryKey: categoryKey,
          totalQuestions: isRandom10 ? 10 : questionsToUse.length,
        ),
      ),
    );
    if (!mounted) return;
    _loadUserData();
  }

  void _startWeaknessReview(BuildContext context) async {
    final navigator = Navigator.of(context);
    final weakTexts = await PrefsHelper.getWeakQuestions();
    if (!mounted) return;
    if (weakTexts.isEmpty) return;

    final weakQuizzes = QuizData.getQuizzesFromTexts(weakTexts);
    
    AdManager.instance.preloadAd('result');
    AdManager.instance.preloadInterstitial();

    await navigator.push(
      MaterialPageRoute(
        builder: (context) => QuizPage(
          quizzes: weakQuizzes,
          isWeaknessReview: true,
          totalQuestions: weakQuizzes.length,
        ),
      ),
    );
    if (!mounted) return;
    _loadUserData();
  }

  void _startQuizByCategory(BuildContext context, String partKey, {bool isWeaknessOnly = false}) async {
    List<Quiz> quizzes;
    String highScoreKey;
    switch(partKey) {
      case 'part1': quizzes = QuizData.part1; highScoreKey = 'highscore_part1'; break;
      case 'part2': quizzes = QuizData.part2; highScoreKey = 'highscore_part2'; break;
      case 'part3': quizzes = QuizData.part3; highScoreKey = 'highscore_part3'; break;
      case 'part4': quizzes = QuizData.part4; highScoreKey = 'highscore_part4'; break;
      case 'part5': quizzes = QuizData.part5; highScoreKey = 'highscore_part5'; break;
      default: quizzes = []; highScoreKey = '';
    }
    
    if (isWeaknessOnly) {
      final weakTexts = await PrefsHelper.getWeakQuestions();
      quizzes = quizzes.where((q) => weakTexts.contains(q.question)).toList();
    }

    if (quizzes.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text("問題データがまだありません")),
       );
       return;
    }
    _startQuiz(
      context, 
      quizzes, 
      highScoreKey, 
      isRandom10: !isWeaknessOnly && _currentMode == QuizMode.shuffle,
    );
  }

  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder: (context) => PremiumUpgradeDialog(
        title: 'プレミアムアップグレード',
        buyNowText: '今すぐ購入',
        cancelText: 'キャンセル',
        unlockSequential: '「連続」モードの解放',
        unlockSequentialDesc: '1問目から順番にすべての問題を解くことができます。',
        hideAds: '広告を完全に非表示',
        hideAdsDesc: 'アプリ内のあらゆる広告（バナー、動画など）を非表示にします。',
        onPurchase: () {
          Navigator.pop(context);
          PurchaseManager.instance.buyPremium();
        },
      ),
    );
  }

  void _showCategoryReview() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CategoryReviewModal(
        onCategoryTap: (partKey) {
          Navigator.pop(context);
          _startQuizByCategory(context, partKey, isWeaknessOnly: true);
        },
      ),
    );
  }

  void _showReferralDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("姉妹アプリが登場！", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("より高速に学習できるスワイプ形式の姉妹アプリをチェックしてみませんか？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("キャンセル", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Open App Store
              final Uri url = Uri.parse('https://apps.apple.com/app/id6757635041'); 
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("開く", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "運行管理者 旅客 4択問題",
          style: GoogleFonts.notoSansJp(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: PurchaseManager.instance.isPremium,
        builder: (context, isPremium, child) {
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      // Pill Mode Toggle
                      Center(
                        child: _PillModeToggle(
                          currentMode: _currentMode,
                          isPremium: isPremium,
                          onChanged: (mode) {
                            if (mode == QuizMode.sequential && !isPremium) {
                              _showPremiumDialog();
                            } else {
                              setState(() {
                                _currentMode = mode;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      Text(
                        "スキマ時間でサクサク合格！4択問題",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                  
                  
                  // Part 1: 道路運送法
                  _MenuButton(
                    title: "道路運送法",
                    icon: Icons.directions_bus,
                    iconColor: Colors.blueAccent,
                    onTap: () => _startQuizByCategory(context, 'part1'),
                  ),
                  const SizedBox(height: 16),

                  // Part 2: 道路運送車両法
                  _MenuButton(
                    title: "道路運送車両法",
                    icon: Icons.build,
                    iconColor: Colors.orange,
                    onTap: () => _startQuizByCategory(context, 'part2'),
                  ),
                  const SizedBox(height: 16),

                  // Part 3: 道路交通法
                  _MenuButton(
                    title: "道路交通法",
                    icon: Icons.traffic,
                    iconColor: Colors.redAccent,
                    onTap: () => _startQuizByCategory(context, 'part3'),
                  ),
                  const SizedBox(height: 16),

                  // Part 4: 労働基準法 & 改善基準告示
                  _MenuButton(
                    title: "労働基準法 & 改善基準告示",
                    icon: Icons.work_history,
                    iconColor: Colors.green,
                    onTap: () => _startQuizByCategory(context, 'part4'),
                  ),
                  const SizedBox(height: 16),

                  // Part 5: 実務上の知識及び能力
                  _MenuButton(
                    title: "実務上の知識及び能力",
                    icon: Icons.map,
                    iconColor: Colors.purple,
                    onTap: () => _startQuizByCategory(context, 'part5'),
                  ),
                  const SizedBox(height: 40),

                  // Weakness Review
                  ElevatedButton.icon(
                    onPressed: () => _showCategoryReview(),
                    icon: const Icon(Icons.refresh),
                    label: Text("苦手を復習する ( $_weaknessCount問 )"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Sister App Referral Card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.1), width: 1),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showReferralDialog(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.touch_app, color: Colors.blueAccent, size: 32),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "スワイプ形式で高速学習",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "サクサク解ける\n姉妹アプリはこちら",
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.open_in_new, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                   const SizedBox(height: 24),
                   
                   // Premium Unlock Card
                   PremiumUnlockCard(onTap: () => _showPremiumDialog()),
                   const SizedBox(height: 40),
                ],
              ),
            ),
          ),
           if (isPremium) const SizedBox(height: 20),
         ],
       );
    },
   ),
  );
 }
}

// -----------------------------------------------------------------------------
// 2-1. Home Page Widgets
// -----------------------------------------------------------------------------

class _PillModeToggle extends StatelessWidget {
  final QuizMode currentMode;
  final bool isPremium;
  final ValueChanged<QuizMode> onChanged;

  const _PillModeToggle({
    required this.currentMode,
    required this.isPremium,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: currentMode == QuizMode.shuffle ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              width: 100,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF2C3E50),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(QuizMode.shuffle),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Icon(
                      Icons.shuffle,
                      color: currentMode == QuizMode.shuffle ? Colors.white : Colors.grey,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(QuizMode.sequential),
                  behavior: HitTestBehavior.opaque,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: Icon(
                          Icons.format_list_numbered,
                          color: currentMode == QuizMode.sequential ? Colors.white : Colors.grey,
                        ),
                      ),
                      if (!isPremium)
                        const Center(
                          child: Icon(
                            Icons.lock,
                            size: 32,
                            color: Colors.black45,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryReviewModal extends StatefulWidget {
  final Function(String) onCategoryTap;

  const _CategoryReviewModal({required this.onCategoryTap});

  @override
  State<_CategoryReviewModal> createState() => _CategoryReviewModalState();
}

class _CategoryReviewModalState extends State<_CategoryReviewModal> {
  final Map<String, int> _weaknessCounts = {};

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final weakTexts = await PrefsHelper.getWeakQuestions();
    final counts = <String, int>{};
    
    // Road Transport Law
    counts['part1'] = QuizData.part1.where((q) => weakTexts.contains(q.question)).length;
    counts['part2'] = QuizData.part2.where((q) => weakTexts.contains(q.question)).length;
    counts['part3'] = QuizData.part3.where((q) => weakTexts.contains(q.question)).length;
    counts['part4'] = QuizData.part4.where((q) => weakTexts.contains(q.question)).length;
    counts['part5'] = QuizData.part5.where((q) => weakTexts.contains(q.question)).length;

    setState(() {
      _weaknessCounts.addAll(counts);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "カテゴリーを選択",
            style: GoogleFonts.lora(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          _CategoryCard(
            title: "道路運送法",
            icon: Icons.directions_bus,
            iconColor: Colors.blueAccent,
            count: _weaknessCounts['part1'] ?? 0,
            onTap: () => widget.onCategoryTap('part1'),
          ),
          const SizedBox(height: 12),
          _CategoryCard(
            title: "道路運送車両法",
            icon: Icons.build,
            iconColor: Colors.orange,
            count: _weaknessCounts['part2'] ?? 0,
            onTap: () => widget.onCategoryTap('part2'),
          ),
          const SizedBox(height: 12),
          _CategoryCard(
            title: "道路交通法",
            icon: Icons.traffic,
            iconColor: Colors.redAccent,
            count: _weaknessCounts['part3'] ?? 0,
            onTap: () => widget.onCategoryTap('part3'),
          ),
          const SizedBox(height: 12),
          _CategoryCard(
            title: "労働基準法 & 改善基準告示",
            icon: Icons.work_history,
            iconColor: Colors.green,
            count: _weaknessCounts['part4'] ?? 0,
            onTap: () => widget.onCategoryTap('part4'),
          ),
          const SizedBox(height: 12),
          _CategoryCard(
            title: "実務上の知識及び能力",
            icon: Icons.map,
            iconColor: Colors.purple,
            count: _weaknessCounts['part5'] ?? 0,
            onTap: () => widget.onCategoryTap('part5'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final int count;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "$count問",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _MenuButton({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// -----------------------------------------------------------------------------
// 3. Quiz Page
// -----------------------------------------------------------------------------

class QuizPage extends StatefulWidget {
  final List<Quiz> quizzes;
  final String? categoryKey;
  final bool isWeaknessReview;
  final int totalQuestions;

  const QuizPage({
    super.key,
    required this.quizzes,
    this.categoryKey,
    this.isWeaknessReview = false,
    required this.totalQuestions,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();

  static String formatQuestionText(String text) {
    // Replace inline markers with newline + marker
    // Patterns: " ア.", " ア．", "ア.", "ア．" (preceded by spaces or punctuation)
    // We strictly look for [ア-エ] followed by . or ．
    
    String formatted = text;
    final regex = RegExp(r'(?<!\n)([ 　]*)([ア-エ][.．])');
    formatted = formatted.replaceAllMapped(regex, (match) {
        return '\n${match.group(2)}';
    });
    return formatted;
  }
}



class _QuizPageState extends State<QuizPage> {
  final AppinioSwiperController controller = AppinioSwiperController();
  
  int _score = 0;
  int _currentIndex = 1;
  final List<Quiz> _incorrectQuizzes = [];
  final List<Quiz> _correctQuizzesInReview = [];
  final List<Map<String, dynamic>> _answerHistory = [];
  Color _backgroundColor = const Color(0xFFF9F9F9);
  
  // New state for 4-choice
  int? _selectedChoiceIndex;
  int? _tempSelectedChoiceIndex; // Track selection before confirmation
  bool _isAnswered = false;
  // Feedback overlay state
  bool _showFeedback = false;
  bool _isCorrectFeedback = false;

  void _handleSwipeEnd(int previousIndex, int targetIndex, SwiperActivity activity) {
    if (activity is Swipe) {
      _resetCardState();

      setState(() {
        if (_currentIndex < widget.totalQuestions) {
          _currentIndex++;
        }
      });

      if (previousIndex == widget.quizzes.length - 1) {
        _finishQuiz();
      }
    }
  }
  
  void _resetCardState() {
    setState(() {
      _selectedChoiceIndex = null;
      _tempSelectedChoiceIndex = null;
      _isAnswered = false;
      _backgroundColor = const Color(0xFFF9F9F9);
    });
  }

  void _onChoiceSelected(int choiceIndex, Quiz quiz) {
    if (_isAnswered) return;
    
    // Just select, don't confirm yet
    setState(() {
      _tempSelectedChoiceIndex = choiceIndex;
    });
    HapticFeedback.selectionClick();
  }

  void _confirmAnswer(Quiz quiz) {
    if (_tempSelectedChoiceIndex == null || _isAnswered) return;
    
    final choiceIndex = _tempSelectedChoiceIndex!;
    bool isCorrect = (choiceIndex == quiz.correctIndex);
    
    _answerHistory.add({
      'quiz': quiz,
      'result': isCorrect,
      'selectedChoice': choiceIndex,
    });

    setState(() {
      _isAnswered = true;
      _selectedChoiceIndex = choiceIndex;
      
      if (isCorrect) {
        _score++;
        _backgroundColor = Colors.green.withValues(alpha: 0.2);
        HapticFeedback.lightImpact();
        
        if (widget.isWeaknessReview) {
          _correctQuizzesInReview.add(quiz);
        }
      } else {
        _backgroundColor = Colors.red.withValues(alpha: 0.2);
        _incorrectQuizzes.add(quiz);
        HapticFeedback.heavyImpact();
      }
      
      _showFeedback = true;
      _isCorrectFeedback = isCorrect;
    });

    // Hide overlay after 1.2 seconds
    Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
            setState(() {
                _showFeedback = false;
            });
        }
    });
  }

  Future<void> _finishQuiz() async {
    if (widget.categoryKey != null) {
      await PrefsHelper.saveHighScore(widget.categoryKey!, _score);
    }

    if (_incorrectQuizzes.isNotEmpty) {
      final incorrectTexts = _incorrectQuizzes.map((q) => q.question).toList();
      await PrefsHelper.addWeakQuestions(incorrectTexts);
    }

    if (widget.isWeaknessReview && _correctQuizzesInReview.isNotEmpty) {
      final correctTexts = _correctQuizzesInReview.map((q) => q.question).toList();
      await PrefsHelper.removeWeakQuestions(correctTexts);
    }
    
    if (mounted) {
      final shouldReview = await PrefsHelper.shouldRequestReview();
      if (shouldReview) {
        final InAppReview inAppReview = InAppReview.instance;
        if (await inAppReview.isAvailable()) {
          inAppReview.requestReview();
        }
      }

      final shouldShow = await PrefsHelper.shouldShowInterstitial();
      
      if (shouldShow) {
        AdManager.instance.showInterstitial(
          onComplete: () async {
            if (mounted) {
              // Check Special Offer Conditions
              final isPremium = PurchaseManager.instance.isPremium.value;
              final hasSeen = await PrefsHelper.hasSeenSpecialOffer();
              final now = DateTime.now();
              final limitDate = DateTime(2026, 3, 1);
              
              if (!isPremium && !hasSeen && now.isBefore(limitDate)) {
                 await showDialog(
                   context: context,
                   barrierDismissible: false,
                   builder: (reqContext) => const SpecialOfferDialog(),
                 );
                 await PrefsHelper.setHasSeenSpecialOffer();
              }

              if (mounted) {
                _navigateToResult();
              }
            }
          },
        );
      } else {
        _navigateToResult();
      }
    }
  }

  void _navigateToResult() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ResultPage(
          score: _score,
          total: widget.quizzes.length,
          history: _answerHistory,
          incorrectQuizzes: _incorrectQuizzes,
          originalQuizzes: widget.quizzes,
          categoryKey: widget.categoryKey,
          isWeaknessReview: widget.isWeaknessReview,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              color: _backgroundColor,
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Custom Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "第$_currentIndex問",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: Text(
                                        "$_currentIndex / ${widget.totalQuestions}",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: _currentIndex / widget.totalQuestions,
                                    minHeight: 4,
                                    backgroundColor: Colors.grey[300],
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                      ),
                    ),
                    // Swiper and Feedback Overlay
                    Expanded(
                      child: Stack(
                        children: [
                          AppinioSwiper(
                            controller: controller,
                            cardCount: widget.quizzes.length,
                            loop: false,
                            backgroundCardCount: 0,
                            isDisabled: !_isAnswered, // Block swipe until answered
                            swipeOptions: const SwipeOptions.all(),
                            onSwipeEnd: _handleSwipeEnd,
                            cardBuilder: (context, index) {
                              return _buildCard(widget.quizzes[index], index);
                            },
                          ),
                          
                          // Floating Feedback Overlay
                          if (_showFeedback)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: AnimatedOpacity(
                                  opacity: _showFeedback ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 300),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.95),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.1),
                                            blurRadius: 20,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _isCorrectFeedback ? Icons.check_circle : Icons.cancel,
                                            color: _isCorrectFeedback ? Colors.green : Colors.red,
                                            size: 64,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            _isCorrectFeedback ? "正解！" : "不正解...",
                                            style: TextStyle(
                                              fontSize: 32,
                                              fontWeight: FontWeight.bold,
                                              color: _isCorrectFeedback ? Colors.green[800] : Colors.red[800],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
          // Ad Banner in Quiz Page
          const SafeArea(
            top: false,
            child: SizedBox(
               height: 60,
               child: AdBanner(adKey: 'quiz'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Quiz quiz, int cardIndex) {
    bool hasImage = quiz.imagePath != null;
    bool isCurrentCard = (cardIndex == _currentIndex - 1);
    bool showResult = _isAnswered && isCurrentCard;

    return Container(
      key: ValueKey(cardIndex),
      margin: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasImage) ...[
                    AspectRatio(
                      aspectRatio: 16/9,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: AssetImage(quiz.imagePath!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  
                  Text(
                    QuizPage.formatQuestionText(quiz.question),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  ...List.generate(quiz.choices.length, (index) {
                    final choice = quiz.choices[index];
                    return _buildChoiceButton(index, choice, quiz, showResult, isCurrentCard);
                  }),
                  
                  // Confirm Button
                  if (!showResult && _tempSelectedChoiceIndex != null) ...[
                    const SizedBox(height: 32),
                    Center(
                      child: ElevatedButton(
                        onPressed: () => _confirmAnswer(quiz),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 4,
                        ),
                        child: const Text("回答する"),
                      ),
                    ),
                  ],

                  if (showResult) ...[
                    const SizedBox(height: 24),
                    // Static feedback removed.
                    
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue, size: 20),
                              SizedBox(width: 8),
                              Text("解説", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            quiz.explanation,
                            style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () => controller.swipeLeft(),
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text("次の問題へ"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildChoiceButton(int index, String text, Quiz quiz, bool showResult, bool isCurrentCard) {
    Color? backgroundColor;
    Color? borderColor;
    Color textColor = Colors.black87;
    
    if (showResult) {
      if (index == quiz.correctIndex) {
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        borderColor = Colors.green;
        textColor = Colors.green[800]!;
      } else if (index == _selectedChoiceIndex) {
        backgroundColor = Colors.red.withValues(alpha: 0.1);
        borderColor = Colors.red;
        textColor = Colors.red[800]!;
      } else {
        borderColor = Colors.grey[300];
        textColor = Colors.grey[500]!;
      }
    } else {
      // Not answered yet
      if (isCurrentCard && index == _tempSelectedChoiceIndex) {
        // Highlight pre-selected
        backgroundColor = Colors.orange.withValues(alpha: 0.1);
        borderColor = Colors.orange;
        textColor = Colors.orange[800]!;
      } else {
        borderColor = Colors.grey[300];
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _onChoiceSelected(index, quiz),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor ?? Colors.grey[300]!,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: backgroundColor != null
                      ? borderColor
                      : Colors.transparent,
                  border: Border.all(
                    color: borderColor ?? Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: showResult && index == quiz.correctIndex
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : showResult && index == _selectedChoiceIndex
                        ? const Icon(Icons.close, size: 18, color: Colors.white)
                        : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ResultPage extends StatelessWidget {
  final int score;
  final int total;
  final List<Map<String, dynamic>> history;
  final List<Quiz> incorrectQuizzes;
  final List<Quiz> originalQuizzes;
  final String? categoryKey;
  final bool isWeaknessReview;

  const ResultPage({
    super.key,
    required this.score,
    required this.total,
    required this.history,
    required this.incorrectQuizzes,
    required this.originalQuizzes,
    this.categoryKey,
    required this.isWeaknessReview,
  });

  @override
  Widget build(BuildContext context) {
    String messageText = "";
    Color messageColor = Colors.black;

    if (score == total) {
      messageText = "PERFECT! 🎉";
      messageColor = Colors.green;
    } else if (score >= 8) {
      messageText = "合格圏内！素晴らしい！";
      messageColor = Colors.green;
    } else {
      messageText = "あと少し！復習しよう";
      messageColor = Colors.redAccent;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Column(
          children: [
             const SizedBox(
               height: 60,
               child: AdBanner(adKey: 'result'),
             ),
             
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      const Text(
                        "正解数",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "$score/$total",
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    messageText,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: messageColor,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final item = history[index];
                  final Quiz quiz = item['quiz'];
                  final bool isCorrect = item['result'];
                  final bool hasImage = quiz.imagePath != null;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isCorrect ? Icons.check_circle : Icons.cancel,
                                color: isCorrect ? Colors.green : Colors.red,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      QuizPage.formatQuestionText(quiz.question),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                    if (hasImage)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Row(
                                          children: [
                                            Icon(Icons.image,
                                                size: 16, color: Colors.grey[500]),
                                            const SizedBox(width: 4),
                                            Text("画像問題",
                                                style: TextStyle(
                                                    color: Colors.grey[500],
                                                    fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECEFF1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "💡 ${quiz.explanation}",
                              style: TextStyle(
                                  color: Colors.blueGrey[800], fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              decoration: const BoxDecoration(
                color: Color(0xFFF9F9F9),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (incorrectQuizzes.isNotEmpty) ...[
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => QuizPage(
                                      quizzes: incorrectQuizzes,
                                      isWeaknessReview: true,
                                      totalQuestions: incorrectQuizzes.length,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text("ミスを確認"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                textStyle: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],

                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {
                               if (isWeaknessReview) {
                                Navigator.of(context).popUntil((route) => route.isFirst);
                              } else {
                                final shuffledAgain = List<Quiz>.from(originalQuizzes)..shuffle();
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => QuizPage(
                                      quizzes: shuffledAgain,
                                      categoryKey: categoryKey,
                                      totalQuestions: shuffledAgain.length,
                                    ),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.blueAccent,
                              elevation: 0,
                              side: const BorderSide(color: Colors.blueAccent, width: 2),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              textStyle: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            child: Text(isWeaknessReview ? "ホームに戻る" : "リトライ"),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    child: const Text(
                      "ホームに戻る",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
