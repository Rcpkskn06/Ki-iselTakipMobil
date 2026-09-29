import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';

// Bildirim eklentisi nesnesi
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bildirim ayarları (Android için)
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const AliskanlikTakipApp());
}

// Bildirim gönderme fonksiyonu
Future<void> bildirimGonder(String baslik, String aciklama) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'aliskanlik_kanal_id',
    'Alışkanlık Bildirimleri',
    channelDescription: 'Alışkanlık hatırlatıcı bildirimleri',
    importance: Importance.max,
    priority: Priority.high,
    ticker: 'ticker',
  );

  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  await flutterLocalNotificationsPlugin.show(
    0,
    baslik,
    aciklama,
    platformChannelSpecifics,
  );
}

class AliskanlikTakipApp extends StatefulWidget {
  const AliskanlikTakipApp({super.key});

  @override
  State<AliskanlikTakipApp> createState() => _AliskanlikTakipAppState();
}

class _AliskanlikTakipAppState extends State<AliskanlikTakipApp> {
  bool _isDarkMode = false;

  void _temaDegistir(bool degeri) {
    setState(() {
      _isDarkMode = degeri;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pro Alışkanlık Takip',
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
      ),
      home: AnaSayfa(
        isDarkMode: _isDarkMode,
        onThemeChanged: _temaDegistir,
      ),
    );
  }
}

class Aliskanlik {
  String isim;
  bool tamamlandi;
  int streak;
  String kategori;
  String sonTamamlananTarih;

  Aliskanlik({
    required this.isim,
    this.tamamlandi = false,
    this.streak = 0,
    this.kategori = 'Genel',
    this.sonTamamlananTarih = '',
  });

  Map<String, dynamic> toJson() => {
        'isim': isim,
        'tamamlandi': tamamlandi,
        'streak': streak,
        'kategori': kategori,
        'sonTamamlananTarih': sonTamamlananTarih,
      };

  factory Aliskanlik.fromJson(Map<String, dynamic> json) => Aliskanlik(
        isim: json['isim'],
        tamamlandi: json['tamamlandi'] ?? false,
        streak: json['streak'] ?? 0,
        kategori: json['kategori'] ?? 'Genel',
        sonTamamlananTarih: json['sonTamamlananTarih'] ?? '',
      );
}

class AnaSayfa extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const AnaSayfa({super.key, required this.isDarkMode, required this.onThemeChanged});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  List<Aliskanlik> _aliskanliklar = [];
  final TextEditingController _controller = TextEditingController();
  String _secilenKategori = 'Spor';
  final List<String> _kategoriler = ['Spor', 'Sağlık', 'Eğitim', 'Kişisel', 'Genel'];

  static const String _storageKey = 'aliskanliklar_ana_liste';
  static const String _tarihKey = 'son_giris_tarihi';

  @override
  void initState() {
    super.initState();
    _verileriYukleVeKontrolEt();
  }

  String _bugununTarihi() {
    final simdi = DateTime.now();
    return "${simdi.year}-${simdi.month.toString().padLeft(2, '0')}-${simdi.day.toString().padLeft(2, '0')}";
  }

  Future<void> _verileriKaydet() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> listeJson = _aliskanliklar.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList(_storageKey, listeJson);
    await prefs.setString(_tarihKey, _bugununTarihi());
  }

  Future<void> _verileriYukleVeKontrolEt() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? listeJson = prefs.getStringList(_storageKey);
    String? sonGiris = prefs.getString(_tarihKey);
    String bugun = _bugununTarihi();

    if (listeJson != null) {
      setState(() {
        _aliskanliklar = listeJson.map((item) => Aliskanlik.fromJson(jsonDecode(item))).toList();
        
        // Eğer yeni bir güne geçildiyse kontrol yap
        if (sonGiris != null && sonGiris != bugun) {
          bool kacirilanVarMi = false;

          for (var aliskanlik in _aliskanliklar) {
            // Eğer dün yapılmadıysa seri yanar
            if (aliskanlik.sonTamamlananTarih != sonGiris) {
              aliskanlik.streak = 0;
              kacirilanVarMi = true;
            }
            // Yeni gün için tiki kaldır
            aliskanlik.tamamlandi = false;
          }
          
          _verileriKaydet();

          // OTOMATİK BİLDİRİM: Dün kaçırılan alışkanlık varsa otomatik tetikle
          if (kacirilanVarMi) {
            Future.delayed(const Duration(seconds: 2), () {
              bildirimGonder(
                "Seri Tehlikede! 🔥",
                "Dün bazı alışkanlıklarını tamamlamadın ve serin sıfırlandı. Bugün yeni bir başlangıç yap!",
              );
            });
          }
        }
      });
    }
  }

  Color _kategoriRengiGetir(String kategori) {
    switch (kategori) {
      case 'Spor':
        return Colors.orange;
      case 'Sağlık':
        return Colors.green;
      case 'Eğitim':
        return Colors.purple;
      case 'Kişisel':
        return Colors.teal;
      default:
        return Colors.blue;
    }
  }

  void _aliskanlikEkle(String isim, String kategori) {
    if (isim.trim().isNotEmpty) {
      setState(() {
        _aliskanliklar.add(Aliskanlik(isim: isim, kategori: kategori));
      });
      _verileriKaydet();
      _controller.clear();
    }
  }

  void _pencereyiGoster() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Yeni Alışkanlık Ekle'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: 'Örn: 30 dakika yürüyüş yap'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _secilenKategori,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: _kategoriler.map((kat) {
                      return DropdownMenuItem(value: kat, child: Text(kat));
                    }).toList(),
                    onChanged: (deger) {
                      setDialogState(() {
                        _secilenKategori = deger!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _aliskanlikEkle(_controller.text, _secilenKategori);
                    Navigator.pop(context);
                  },
                  child: const Text('Ekle'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _istatistikleriGoster() {
    int toplam = _aliskanliklar.length;
    int tamamlanan = _aliskanliklar.where((a) => a.tamamlandi).length;
    int toplamStreak = _aliskanliklar.fold(0, (sum, item) => sum + item.streak);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('📊 İstatistikler & Özet'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• Toplam Alışkanlık: $toplam', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text('• Bugün Tamamlanan: $tamamlanan', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text('• Toplam Seri Puanı: 🔥 $toplamStreak', style: const TextStyle(fontSize: 16)),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    int toplam = _aliskanliklar.length;
    int tamamlanan = _aliskanliklar.where((a) => a.tamamlandi).length;
    double ilerlemeOrani = toplam == 0 ? 0.0 : tamamlanan / toplam;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pro Alışkanlık Takip'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active),
            onPressed: () {
              bildirimGonder(
                "Hatırlatıcı 🔔",
                "Bugünkü alışkanlıklarını henüz tamamlamadın!",
              );
            },
            tooltip: 'Bildirim Test Et',
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: _istatistikleriGoster,
            tooltip: 'İstatistikler',
          ),
          Switch(
            value: widget.isDarkMode,
            onChanged: widget.onThemeChanged,
          ),
        ],
      ),
      body: Column(
        children: [
          if (toplam > 0)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Günlük İlerleme', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('%${(ilerlemeOrani * 100).toStringAsFixed(0)}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: ilerlemeOrani,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _aliskanliklar.isEmpty
                ? const Center(
                    child: Text(
                      'Henüz alışkanlık eklenmedi.\nSağ alttaki + butonuna basarak başlayın!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _aliskanliklar.length,
                    itemBuilder: (context, index) {
                      final aliskanlik = _aliskanliklar[index];
                      final renk = _kategoriRengiGetir(aliskanlik.kategori);

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: Checkbox(
                            value: aliskanlik.tamamlandi,
                            onChanged: (bool? deger) {
                              setState(() {
                                aliskanlik.tamamlandi = deger ?? false;
                                if (aliskanlik.tamamlandi) {
                                  aliskanlik.streak += 1;
                                  aliskanlik.sonTamamlananTarih = _bugununTarihi();
                                } else {
                                  if (aliskanlik.streak > 0) aliskanlik.streak -= 1;
                                  aliskanlik.sonTamamlananTarih = '';
                                }
                              });
                              _verileriKaydet();
                            },
                          ),
                          title: Text(
                            aliskanlik.isim,
                            style: TextStyle(
                              fontSize: 18,
                              decoration: aliskanlik.tamamlandi
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              color: aliskanlik.tamamlandi ? Colors.grey : null,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: renk.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  aliskanlik.kategori,
                                  style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '🔥 Seri: ${aliskanlik.streak}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _aliskanliklar.removeAt(index);
                              });
                              _verileriKaydet();
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pencereyiGoster,
        child: const Icon(Icons.add),
      ),
    );
  }
}