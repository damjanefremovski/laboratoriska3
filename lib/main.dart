import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('app_icon');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Exam Scheduler',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const AuthenticationPage(),
    );
  }
}

class AuthenticationPage extends StatefulWidget {
  const AuthenticationPage({super.key});

  @override
  _AuthenticationPageState createState() => _AuthenticationPageState();
}

class _AuthenticationPageState extends State<AuthenticationPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _register() async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      print('Registered user: ${userCredential.user!.uid}');
    } catch (e) {
      print('Failed to register user: $e');
    }
  }

  void _login() async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      print('Logged in user: ${userCredential.user!.uid}');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ExamSchedulePage(user: userCredential.user)),
      );
    } catch (e) {
      print('Failed to sign in: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Auth Demo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
              ),
            ),
            const SizedBox(height: 16.0),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _register,
                  child: const Text('Register'),
                ),
                ElevatedButton(
                  onPressed: _login,
                  child: const Text('Login'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showNotification(String title, String body, double? eventLatitude, double? eventLongitude) async {
  Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  double distanceInMeters = await Geolocator.distanceBetween(position.latitude, position.longitude, eventLatitude!, eventLongitude!);

  if (distanceInMeters < 1000) {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      '191009',
      'Exam Scheduler App',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Alert',
    );
    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: 'Exam X',
    );
  }
}

class ExamSchedulePage extends StatefulWidget {
  final User? user;

  const ExamSchedulePage({Key? key, required this.user}) : super(key: key);

  @override
  _ExamSchedulePageState createState() => _ExamSchedulePageState();
}

class _ExamSchedulePageState extends State<ExamSchedulePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();

  late CalendarFormat _calendarFormat;
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  double? eventLatitude;
  double? eventLongitude;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _calendarFormat = CalendarFormat.month;
  }

  Future<void> _addExam() async {
    try {
      await _firestore.collection('exams').add({
        'subject': _subjectController.text,
        'date': _dateController.text,
        'time': _timeController.text,
        'userId': widget.user!.uid,
      });
      _subjectController.clear();
      _dateController.clear();
      _timeController.clear();

      String googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=$eventLatitude,$eventLongitude';
      if (await canLaunchUrl(googleMapsUrl as Uri)) {
        await launchUrl(googleMapsUrl as Uri);
      } else {
        throw 'Could not launch $googleMapsUrl';
      }


      _showNotification('Exam Added', 'You have successfully added an exam', eventLatitude, eventLongitude);
    } catch (e) {
      print("Failed to add exam: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Schedule'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            const SizedBox(height: 8.0),
            TextField(
              controller: _dateController,
              decoration: const InputDecoration(labelText: 'Date'),
            ),
            const SizedBox(height: 8.0),
            TextField(
              controller: _timeController,
              decoration: const InputDecoration(labelText: 'Time'),
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _addExam,
              child: const Text('Add Exam'),
            ),
            const SizedBox(height: 16.0),
            TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: TextStyle(color: Colors.white),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(37.422, -122.084), // Initial map position
                  zoom: 10.0,
                ),
                markers: Set<Marker>.from([
                  Marker(
                    markerId: MarkerId('eventLocation'),
                    position: LatLng(eventLatitude ?? 0, eventLongitude ?? 0),
                    infoWindow: InfoWindow(
                      title: 'Event Location',
                      snippet: 'This is the event location',
                    ),
                  ),
                ]),
                onMapCreated: (GoogleMapController controller) {
                  controller.animateCamera(
                    CameraUpdate.newLatLngZoom(LatLng(eventLatitude!, eventLongitude!), 15),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
