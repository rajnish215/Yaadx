import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend/cloud_api.dart';
import '../reminder/reminder_model.dart';

class SuggestionOptions {
  String language, tone, budget, interests;
  bool ai;
  int variant;
  SuggestionOptions({
    this.language = 'Hinglish',
    this.tone = 'Warm',
    this.budget = 'Any',
    this.interests = '',
    this.ai = false,
    this.variant = 0,
  });
  Map<String, dynamic> toJson() => {
    'language': language,
    'tone': tone,
    'budget': budget,
    'interests': interests,
    'ai': ai,
    'variant': variant,
  };
  factory SuggestionOptions.fromJson(Map<String, dynamic> j) =>
      SuggestionOptions(
        language: ['English', 'Hindi', 'Hinglish'].contains(j['language'])
            ? j['language']
            : 'Hinglish',
        tone: ['Warm', 'Funny', 'Short'].contains(j['tone'])
            ? j['tone']
            : 'Warm',
        budget: ['Any', '500', '1000', '2500'].contains(j['budget'])
            ? j['budget']
            : 'Any',
        interests: j['interests'] is String ? j['interests'] : '',
        ai: j['ai'] == true,
        variant: j['variant'] is num
            ? (j['variant'] as num).toInt().clamp(0, 1000000)
            : 0,
      );
}

class GiftIdea {
  final String title, reason;
  GiftIdea(this.title, this.reason);
  Map<String, dynamic> toJson() => {'title': title, 'reason': reason};
}

class Suggestion {
  final String wish;
  final List<GiftIdea> gifts;
  final bool ai;
  final bool edited;
  final String? notice;
  Suggestion(
    this.wish,
    this.gifts, {
    this.ai = false,
    this.edited = false,
    this.notice,
  });
  Map<String, dynamic> toJson() => {
    'wish': wish,
    'gifts': gifts.map((g) => g.toJson()).toList(),
    'source': ai ? 'ai' : 'offline',
    'edited': edited,
  };
  factory Suggestion.fromJson(Map<String, dynamic> j) {
    final wish = j['wish'] as String;
    final gifts = (j['gifts'] as List)
        .map((g) => GiftIdea(g['title'] as String, g['reason'] as String))
        .toList();
    if (wish.isEmpty ||
        wish.length > 800 ||
        gifts.length < 3 ||
        gifts.length > 5 ||
        gifts.any((g) => g.title.length > 80 || g.reason.length > 240)) {
      throw const FormatException('Invalid suggestion');
    }
    return Suggestion(
      wish,
      gifts,
      ai: j['source'] == 'ai',
      edited: j['edited'] == true,
    );
  }
}

class SuggestionService {
  static Future<void>? _writes;
  Future<void> _mutate(String uid, void Function(Map<String, dynamic>) update) {
    final previous = _writes ?? Future<void>.value();
    final next = previous.then((_) async {
      final j = await _read(uid);
      update(j);
      final ok = await (await SharedPreferences.getInstance()).setString(
        _key(uid),
        jsonEncode(j),
      );
      if (!ok) throw StateError('Could not save suggestion');
    });
    final settled = next.catchError((Object _) {});
    _writes = settled;
    settled.then((_) {
      if (identical(_writes, settled)) _writes = null;
    });
    return next;
  }

  final CloudGateway? cloud;
  SuggestionService({this.cloud});
  String _key(String uid) => 'yaadx_suggestions_v1_${Uri.encodeComponent(uid)}';
  Future<Map<String, dynamic>> _read(String uid) async {
    final p = await SharedPreferences.getInstance();
    try {
      return Map<String, dynamic>.from(
        jsonDecode(p.getString(_key(uid)) ?? '{}'),
      );
    } catch (_) {
      return {};
    }
  }

  Future<SuggestionOptions> options(String uid, String eventId) async {
    final j = await _read(uid);
    final event = Map<String, dynamic>.from(
      (j['events'] as Map?)?[eventId] ?? {},
    );
    return SuggestionOptions.fromJson({
      ...Map<String, dynamic>.from(j['defaults'] ?? {}),
      ...event,
      'ai': j['ai'] == true,
    });
  }

  Future<void> saveOptions(
    String uid,
    String eventId,
    SuggestionOptions o,
  ) async {
    final saved = SuggestionOptions.fromJson(o.toJson());
    await _mutate(uid, (j) {
      final events = Map<String, dynamic>.from(j['events'] ?? {});
      events.remove(eventId);
      events[eventId] = {
        'interests': saved.interests,
        'variant': saved.variant,
      };
      while (events.length > 50) {
        events.remove(events.keys.first);
      }
      j.addAll({
        'ai': saved.ai,
        'defaults': {
          'language': saved.language,
          'tone': saved.tone,
          'budget': saved.budget,
        },
        'events': events,
      });
    });
  }

  Map<String, dynamic> _input(ReminderModel r, SuggestionOptions o) => {
    'name': r.name,
    'eventType': r.eventType,
    'relation': r.relation,
    'language': o.language,
    'tone': o.tone,
    'budget': o.budget,
    'interests': o.interests,
    'variant': o.variant,
  };
  String _fingerprint(ReminderModel r, SuggestionOptions o) {
    final now = DateTime.now();
    final year = r.occursOn(now) ? now.year : r.nextOccurrence(now).year;
    return jsonEncode([
      r.id,
      r.date.toIso8601String(),
      year,
      _input(r, o),
      o.ai,
    ]);
  }

  Future<void> _store(String uid, String fingerprint, Suggestion result) =>
      _mutate(uid, (j) {
        final cache = Map<String, dynamic>.from(j['cache'] ?? {});
        cache.remove(fingerprint);
        cache[fingerprint] = result.toJson();
        while (cache.length > 16) {
          cache.remove(cache.keys.first);
        }
        j['cache'] = cache;
      });
  Future<Suggestion> saveEdited(
    String uid,
    ReminderModel r,
    SuggestionOptions o,
    Suggestion original,
    String wish,
  ) async {
    final text = wish.trim();
    if (text.isEmpty || text.length > 800) {
      throw const FormatException('Invalid wish');
    }
    final edited = Suggestion(
      text,
      original.gifts,
      ai: original.ai,
      edited: true,
    );
    await _store(uid, _fingerprint(r, o), edited);
    return edited;
  }

  Future<Suggestion> generate(
    String uid,
    ReminderModel r,
    SuggestionOptions o,
  ) async {
    final input = _input(r, o);
    final fingerprint = _fingerprint(r, o);
    final j = await _read(uid);
    try {
      final hit = (j['cache'] as Map?)?[fingerprint];
      if (hit != null) {
        return Suggestion.fromJson(Map<String, dynamic>.from(hit));
      }
    } catch (_) {}
    Suggestion result;
    if (o.ai && cloud != null) {
      try {
        result = Suggestion.fromJson(
          await cloud!.request(uid, 'POST', '/v1/suggestions', input),
        );
      } catch (e) {
        final fallback = offline(r, o);
        final reason = e is CloudFailure && e.code == 'ai_not_configured'
            ? 'AI is not set up yet. Showing offline ideas.'
            : e is CloudFailure && e.status == 429
            ? 'AI request limit reached. Showing offline ideas.'
            : 'AI could not connect. Showing offline ideas; try again later.';
        return Suggestion(fallback.wish, fallback.gifts, notice: reason);
      }
    } else {
      result = offline(r, o);
      if (o.ai) {
        return Suggestion(
          result.wish,
          result.gifts,
          notice: 'Connect the app backend to use AI. Offline ideas are ready.',
        );
      }
    }
    await _store(uid, fingerprint, result);
    return result;
  }

  Suggestion offline(ReminderModel r, SuggestionOptions o) {
    final hi = o.language == 'Hindi', en = o.language == 'English';
    final birthday = r.eventType.toLowerCase().contains('birthday');
    final anniversary = r.eventType.toLowerCase().contains('anniversary');
    final occasion = birthday
        ? (hi
              ? 'जन्मदिन'
              : en
              ? 'birthday'
              : 'birthday')
        : anniversary
        ? (hi
              ? 'सालगिरह'
              : en
              ? 'anniversary'
              : 'anniversary')
        : r.eventType;
    final opening = hi
        ? '${r.name}, $occasion की बहुत शुभकामनाएँ!'
        : en
        ? 'Happy $occasion, ${r.name}!'
        : '${r.name}, happy $occasion!';
    final colleague = RegExp(
      r'colleague|boss|manager|coworker',
      caseSensitive: false,
    ).hasMatch(r.relation);
    final endings = hi
        ? (o.tone == 'Funny'
              ? [
                  'आज खुशियाँ ज़्यादा और काम थोड़ा कम हो! 🎉',
                  'आज मुस्कुराने का कोई बहाना नहीं चाहिए! ✨',
                ]
              : [
                  'यह दिन खुशियों और खूबसूरत पलों से भरा हो। ✨',
                  'आने वाला समय नई खुशियाँ और सफलता लाए। 🌟',
                ])
        : en
        ? (o.tone == 'Funny'
              ? [
                  'Here’s to more celebrations and fewer boring plans! 🎉',
                  'Your only assignment today: enjoy yourself! ✨',
                ]
              : [
                  'Wishing you happiness, wonderful moments and a year full of possibilities. ✨',
                  'May this day bring you joy and plenty of reasons to smile. 🌟',
                ])
        : (o.tone == 'Funny'
              ? [
                  'Aaj khushiyan full aur boring plans cancel! 🎉',
                  'Aaj ka ek hi task: dil khol ke celebrate karo! ✨',
                ]
              : [
                  'Dua hai aage ka safar khushiyon aur khoobsurat palon se bhara rahe. ✨',
                  'Tumhare liye dher saari khushiyan aur naye sapnon ki shuruaat! 🌟',
                ]);
    var ending = endings[o.variant % endings.length];
    if (colleague && o.tone == 'Warm') {
      ending = hi
          ? 'आपको खुशियों और सफलता की शुभकामनाएँ।'
          : en
          ? 'Wishing you happiness and continued success.'
          : 'Aapko khushiyon aur success ki dher saari wishes.';
    }
    final wish = o.tone == 'Short' ? '$opening ✨' : '$opening $ending';
    final titles = hi
        ? [
            'हाथ से लिखा पत्र',
            'पसंदीदा पलों का फोटो फ्रेम',
            'छोटा पौधा',
            'नोटबुक और पेन',
            'पसंदीदा विषय की किताब',
          ]
        : en
        ? [
            'A handwritten letter',
            'A shared-memory photo frame',
            'A small desk plant',
            'A notebook and pen',
            'A book on their interests',
          ]
        : [
            'Handwritten letter',
            'Yaadon wala photo frame',
            'Chhota desk plant',
            'Notebook aur pen',
            'Unke interest ki book',
          ];
    final reasons = hi
        ? [
            'अपने शब्दों में एक सच्ची बात लिखें; कम खर्च में खास तोहफा।',
            'अगर आपके पास साथ की फोटो हो, तो उसमें एक निजी संदेश जोड़ें।',
            'अगर उन्हें पौधों की देखभाल पसंद हो, तो अच्छा विकल्प है।',
            'रोज़मर्रा में काम आने वाला सरल विकल्प।',
            'किताब चुनने से पहले उनकी पसंद जान लें।',
          ]
        : en
        ? [
            'Add a sincere message in your own words; thoughtful without a big spend.',
            'If you have a photo together, add a personal note alongside it.',
            'A gentle option if they enjoy caring for plants.',
            'A useful everyday option; choose a simple set within your budget.',
            'Check their reading preferences before choosing a title.',
          ]
        : [
            'Apne words mein dil ki baat likho; bade budget ki zaroorat nahi.',
            'Saath ki photo ho to ek personal message ke saath frame do.',
            'Agar plants ka shauk ho, to thoughtful option hai.',
            'Roz kaam aane wala simple set apne budget mein choose karo.',
            'Book choose karne se pehle unki reading pasand jaan lo.',
          ];
    final interest = o.interests.toLowerCase();
    void addInterest(String hindi, String english, String hinglish) {
      titles.add(
        hi
            ? hindi
            : en
            ? english
            : hinglish,
      );
      reasons.add(
        hi
            ? 'आपकी बताई पसंद से जुड़ा विकल्प; बजट और पसंद देखकर चुनें।'
            : en
            ? 'Inspired by the interests you entered; choose an option within your budget.'
            : 'Tumhare bataye interest se juda idea; budget aur pasand dekh kar choose karo.',
      );
    }

    if (RegExp(r'music|song|संगीत').hasMatch(interest)) {
      addInterest(
        'पसंदीदा गानों की प्लेलिस्ट और पत्र',
        'A personal playlist with a note',
        'Personal playlist aur ek note',
      );
    } else if (RegExp(r'art|draw|sketch|कला').hasMatch(interest)) {
      addInterest('स्केचबुक', 'A sketchbook', 'Sketchbook');
    } else if (RegExp(r'game|gaming').hasMatch(interest)) {
      addInterest(
        'गेम नाइट का निमंत्रण',
        'A planned game night together',
        'Saath mein game night ka plan',
      );
    } else if (RegExp(r'fitness|sport|yoga').hasMatch(interest)) {
      addInterest('वर्कआउट जर्नल', 'A workout journal', 'Workout journal');
    }
    final candidates = List.generate(
      titles.length,
      (i) => i,
    ).where((i) => !colleague || i != 1).toList();
    final offset = o.variant % candidates.length;
    final ids = List.generate(
      candidates.length,
      (i) => candidates[(offset + i) % candidates.length],
    );
    void prefer(int id) {
      ids.remove(id);
      ids.insert(0, id);
    }

    if (o.budget == '500') prefer(0);
    if (anniversary && !colleague) prefer(1);
    if (interest.contains('book') || interest.contains('किताब')) prefer(4);
    if (RegExp(r'plant|garden|पौध').hasMatch(interest)) prefer(2);
    if (titles.length > 5) prefer(titles.length - 1);
    return Suggestion(
      wish,
      ids.take(3).map((i) => GiftIdea(titles[i], reasons[i])).toList(),
    );
  }
}
