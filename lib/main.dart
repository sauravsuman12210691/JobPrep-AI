import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:google_fonts/google_fonts.dart';

import 'api_key.dart';

void main() {
  runApp(const MockInterviewApp());
}

class MockInterviewApp extends StatelessWidget {
  const MockInterviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mock Interview AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(),
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.grey[100],
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final roles = ['AI Engineer', 'Web Developer', 'Data Scientist'];
  String? selectedRole;
  String? question;
  String answer = '';
  String feedback = '';
  int? score;
  bool loading = false;
  List<String> history = [];

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool isListening = false;

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      history = prefs.getStringList('history') ?? [];
    });
  }

  Future<void> saveToHistory(String entry) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    history.add(entry);
    await prefs.setStringList('history', history);
  }

  Future<void> getQuestion() async {
    if (selectedRole == null) return;

    setState(() {
      loading = true;
      feedback = '';
      answer = '';
      score = null;
    });

    final prompt =
        "Give me an interview question for the role of $selectedRole.";
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$GEMINI_API_KEY',
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['candidates'][0]['content']['parts'][0]['text'];
        setState(() {
          question = content;
          loading = false;
        });
      } else {
        final err = jsonDecode(response.body)['error']['message'];
        showSnackBar("Error: $err");
        setState(() => loading = false);
      }
    } catch (e) {
      showSnackBar("Exception: $e");
      setState(() => loading = false);
    }
  }

  Future<void> getFeedback() async {
    setState(() => loading = true);

    final prompt =
        "You're an expert interviewer. A candidate answered the question: \"$question\" with \"$answer\". Give feedback and suggestions. Also give a score out of 10.";

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$GEMINI_API_KEY',
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['candidates'][0]['content']['parts'][0]['text'];

        final scoreMatch = RegExp(r'(\d{1,2})/10').firstMatch(content);
        final extractedScore = scoreMatch != null
            ? int.tryParse(scoreMatch.group(1)!)
            : null;

        setState(() {
          feedback = content;
          score = extractedScore;
          loading = false;
        });

        await saveToHistory("Q: $question\nA: $answer\nFeedback: $feedback\n");
      } else {
        final err = jsonDecode(response.body)['error']['message'];
        showSnackBar("Error: $err");
        setState(() => loading = false);
      }
    } catch (e) {
      showSnackBar("Exception: $e");
      setState(() => loading = false);
    }
  }

  void toggleListening() async {
    if (!isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => isListening = true);
        _speech.listen(
          onResult: (result) {
            setState(() => answer = result.recognizedWords);
          },
        );
      }
    } else {
      setState(() => isListening = false);
      _speech.stop();
    }
  }

  void showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.deepOrange),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.purpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text('🎙️ Mock Interview AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => showModalBottomSheet(
              context: context,
              builder: (_) => ListView(
                padding: const EdgeInsets.all(16),
                children: history
                    .map(
                      (h) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(h),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    hint: const Text("🎯 Select Role"),
                    onChanged: (val) => setState(() => selectedRole = val),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: roles
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: selectedRole == null ? null : getQuestion,
                    icon: const Icon(Icons.question_answer),
                    label: const Text('Get Interview Question'),
                  ),
                  const SizedBox(height: 24),
                  if (question != null) ...[
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          "🧠 $question",
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (val) => answer = val,
                      maxLines: 4,
                      controller: TextEditingController(text: answer),
                      decoration: InputDecoration(
                        labelText: "Your Answer",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isListening ? Icons.mic : Icons.mic_none_outlined,
                          ),
                          onPressed: toggleListening,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: answer.isEmpty ? null : getFeedback,
                      icon: const Icon(Icons.send),
                      label: const Text("Submit Answer & Get Feedback"),
                    ),
                  ],
                  if (feedback.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Card(
                      color: Colors.white,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          "📝 $feedback",
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                    if (score != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "🔢 Score: $score / 10",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text("Retry"),
                            onPressed: getFeedback,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.skip_next),
                            label: const Text("Next Question"),
                            onPressed: getQuestion,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
