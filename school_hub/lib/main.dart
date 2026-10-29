import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'screens/product_list_screen.dart';

const _ink = Color(0xFF101828);
const _blue = Color(0xFF315CFF);
const _muted = Color(0xFF667085);
const _canvas = Color(0xFFF5F7FC);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Safe loading para hindi mag-white screen kung may issue sa pagbasa ng .env sa web
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("Error loading .env: $e");
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SchoolHub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _canvas,
        colorScheme: ColorScheme.fromSeed(seedColor: _blue),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: _ink,
          surfaceTintColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const List<Map<String, dynamic>> categories = [
    {'name': 'Notebooks', 'icon': Icons.menu_book_rounded, 'color': Color(0xFF315CFF), 'image': 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=500&q=80'},
    {'name': 'Writing Supplies', 'icon': Icons.edit_rounded, 'color': Color(0xFF6C5CE7), 'image': 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRDL0_8OKrvj91TdGcUKa8z-NogMnpN7tc1vx5pZp9X-g&s=10'},
    {'name': 'Art Materials', 'icon': Icons.palette_rounded, 'color': Color(0xFF00A884), 'image': 'https://images.unsplash.com/photo-1513364776144-60967b0f800f?w=500&q=80'},
    {'name': 'Paper Products', 'icon': Icons.note_rounded, 'color': Color(0xFF8B5CF6), 'image': 'https://images.unsplash.com/photo-1517842645767-c639042777db?w=500&q=80'},
    {'name': 'Office & School', 'icon': Icons.folder_shared_rounded, 'color': Color(0xFF0891B2), 'image': 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=500&q=80'},
    {'name': 'Bags', 'icon': Icons.backpack_rounded, 'color': Color(0xFFF05A7E), 'image': 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=500&q=80'},
    {'name': 'Bags & Folders', 'icon': Icons.folder_open_rounded, 'color': Color(0xFFD97706), 'image': 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=500&q=80'},
    {'name': 'Electronics', 'icon': Icons.calculate_rounded, 'color': Color(0xFF0284C7), 'image': 'https://images.unsplash.com/photo-1594980598776-8f7422f7787d?w=500&q=80'},
    {'name': 'Measuring Tools', 'icon': Icons.straighten_rounded, 'color': Color(0xFF4338CA), 'image': 'https://images.unsplash.com/photo-1583485088034-697b5bc54ccd?w=500&q=80'},
  ];

  void _openCatalog(BuildContext context, {String category = 'All'}) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ProductListScreen(initialCategory: category),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 78,
        titleSpacing: 24,
        title: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_blue, Color(0xFF755BFF)]),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: _blue.withOpacity(.25), blurRadius: 14, offset: const Offset(0, 6))],
            ),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 25),
          ),
          const SizedBox(width: 12),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('SchoolHub', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -.6, color: _ink)),
            SizedBox(height: 3),
            Text('YOUR CAMPUS ESSENTIALS', style: TextStyle(fontSize: 9, letterSpacing: 1.5, fontWeight: FontWeight.w800, color: _blue)),
          ]),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 22),
            child: FilledButton.icon(
              onPressed: () => _openCatalog(context),
              icon: const Icon(Icons.storefront_rounded, size: 18),
              label: const Text('Explore store'),
              style: FilledButton.styleFrom(
                backgroundColor: _blue, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 800;
        final padding = constraints.maxWidth < 600 ? 18.0 : 32.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(padding, 24, padding, 42),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _hero(context, wide),
                const SizedBox(height: 22),
                Row(children: [
                  Expanded(child: _feature(Icons.local_shipping_outlined, 'Easy shopping', 'Your essentials in one place', const Color(0xFFE9EFFF), _blue)),
                  const SizedBox(width: 12),
                  Expanded(child: _feature(Icons.verified_user_outlined, 'Secure checkout', 'A smoother way to pay', const Color(0xFFE4F8F1), const Color(0xFF079669))),
                  if (wide) ...[
                    const SizedBox(width: 12),
                    Expanded(child: _feature(Icons.auto_awesome_outlined, 'Made for students', 'Study-ready supplies', const Color(0xFFF1EAFE), const Color(0xFF805AD5))),
                  ],
                ]),
                const SizedBox(height: 36),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Shop by category', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -.7, color: _ink)),
                    SizedBox(height: 5),
                    Text('Find the right tools for your next big idea.', style: TextStyle(color: _muted, fontSize: 14)),
                  ])),
                  Text('${categories.length} COLLECTIONS', style: const TextStyle(color: _muted, fontSize: 10, letterSpacing: 1.1, fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 18),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: categories.length,
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: wide ? 330 : 420,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: wide ? 1.85 : 1.65,
                  ),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final color = cat['color'] as Color;
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(23),
                      child: InkWell(
                        onTap: () => _openCatalog(context, category: cat['name'] as String),
                        borderRadius: BorderRadius.circular(23),
                        child: Container(
                          padding: const EdgeInsets.all(17),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(23),
                            border: Border.all(color: const Color(0xFFE7EBF4)),
                            boxShadow: [BoxShadow(color: const Color(0xFF1C2B50).withOpacity(.035), blurRadius: 22, offset: const Offset(0, 8))],
                          ),
                          child: Row(children: [
                            Container(
                              width: 76, height: 76,
                              decoration: BoxDecoration(color: color.withOpacity(.09), borderRadius: BorderRadius.circular(19)),
                              clipBehavior: Clip.antiAlias,
                              child: Image.network(cat['image'] as String, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(cat['icon'] as IconData, size: 32, color: color)),
                            ),
                            const SizedBox(width: 15),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(cat['name'] as String, maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 15, height: 1.2, fontWeight: FontWeight.w900, color: _ink)),
                              const SizedBox(height: 8),
                              Row(children: [
                                Text('Explore collection', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
                                const SizedBox(width: 5),
                                Icon(Icons.arrow_forward_rounded, size: 14, color: color),
                              ]),
                            ])),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 19),
                  decoration: BoxDecoration(color: const Color(0xFF111B35), borderRadius: BorderRadius.circular(22)),
                  child: Row(children: [
                    Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white.withOpacity(.1), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFB9C9FF))),
                    const SizedBox(width: 14),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Ready to get started?', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                      SizedBox(height: 4),
                      Text('Browse the full SchoolHub catalog and find your essentials.', style: TextStyle(color: Color(0xFFB7C2D8), fontSize: 12)),
                    ])),
                    const SizedBox(width: 12),
                    IconButton.filled(onPressed: () => _openCatalog(context), icon: const Icon(Icons.arrow_forward_rounded), style: IconButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white)),
                  ]),
                ),
                const SizedBox(height: 24),
                const Center(child: Text('SCHOOLHUB  •  LEARN MORE. CREATE MORE.', style: TextStyle(fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: Color(0xFF98A2B3)))),
              ]),
            ),
          ),
        );
      }),
    );
  }

  Widget _hero(BuildContext context, bool wide) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(wide ? 38 : 25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF10172D), Color(0xFF1C3268), Color(0xFF315CFF)]),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: _blue.withOpacity(.22), blurRadius: 32, offset: const Offset(0, 14))],
      ),
      child: Stack(children: [
        Positioned(right: -22, top: -42, child: Container(width: 210, height: 210, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(.08), width: 30)))),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7), decoration: BoxDecoration(color: Colors.white.withOpacity(.12), borderRadius: BorderRadius.circular(9), border: Border.all(color: Colors.white.withOpacity(.12))),
              child: const Text('THE OFFICIAL CAMPUS STORE', style: TextStyle(color: Color(0xFFBBD1FF), fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w900))),
            const SizedBox(height: 19),
            Text(wide ? 'Make room for\nbig ideas.' : 'Make room for big ideas.', style: TextStyle(color: Colors.white, fontSize: wide ? 39 : 30, height: 1.08, letterSpacing: -1.1, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            const Text('Everything you need to learn, create, and do your best work — all in one place.',
              style: TextStyle(color: Color(0xFFD8E2FF), height: 1.55, fontSize: 14)),
            const SizedBox(height: 23),
            FilledButton.icon(
              onPressed: () => _openCatalog(context),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Explore full catalog'),
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _ink, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), textStyle: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ])),
          if (wide) ...[
            const SizedBox(width: 25),
            Container(width: 155, height: 155, decoration: BoxDecoration(color: Colors.white.withOpacity(.09), borderRadius: BorderRadius.circular(35), border: Border.all(color: Colors.white.withOpacity(.15))),
              child: const Icon(Icons.backpack_rounded, size: 82, color: Colors.white)),
          ],
        ]),
      ]),
    );
  }

  Widget _feature(IconData icon, String title, String subtitle, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE7EBF4))),
      child: Row(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: fg, size: 21)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 10, height: 1.3)),
        ])),
      ]),
    );
  }
}