import 'package:engagefire/core/service.dart';
import 'package:engagefire/mobile.dart';
import 'package:engagefire/mobile/builders/formBuilder.dart';
import 'package:engagefire/mobile/screens/login.dart';
import 'package:example/utility/theme.dart';
import 'package:flutter/material.dart';

import 'firestore_sandbox.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EngageFire.init(
    name: 'EngageFire', 
    iosGoogleAppID: '1:255779484097:ios:39fd46c8f3dd17bb607f40', 
    androidGoogleAppID: '1:255779484097:android:4bc87aa266e1d66c607f40', 
    gcmSenderID: '255779484097', 
    apiKey: 'AIzaSyB0BO2DsW8udknAh0sfpvqNBHvU1vt-CY8', 
    projectID: 'engage-firebase',
    storageBucket: 'engage-firebase.appspot.com',
  );
  await EngageService.addServices([
    EngageService<EngageDoc>(
      name: 'users',
      path: 'users',
      // filters: EngageFilter(
      //   name: '',
      //   filter: {
      //     '': ''
      //   }
      // ),
      wrapper: EngageDoc,
    ),
  ]);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Firebase Analytics
      navigatorObservers: [
        // FirebaseAnalyticsObserver(analytics: FirebaseAnalytics()),
      ],

      // Named Routes
      routes: {
        '/': (context) => EngageLoginScreen(
          logo: Image.asset('assets/icon/logo.png', fit: BoxFit.fitWidth,),
          logoIcon: Image.asset('assets/icon/logo-icon.png', width: 133,),
          startBackground: AssetImage('assets/images/rope-pullup.jpg'),
          loginBackground: AssetImage('assets/images/lunge-with-dumbbell.jpg'),
          signupBackground: AssetImage('assets/images/lunge-with-dumbbell.jpg'),
          facebook: true,
          google: true,
          twitter: false,
        ),
        '/home': (context) => FirestoreSandbox(),
        // '/home': (context) => FormBuilder(),
        // '/addFood': (context) => AddFoodPage(),
      },
      title: 'EngageFire Example',
      theme: ThemeData(
        primaryColor: PRIMARY_COLOR,
        accentColor: ACCENT_COLOR,
        highlightColor: Colors.tealAccent,
        backgroundColor: BACKGROUND_COLOR,
//        gray: Colors.blueGrey[100],
//        altBackground: Colors.deepPurpleAccent[700],
        primarySwatch: Colors.blue,
      ),
      // home: new MyHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// class MyApp extends StatelessWidget {
//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Flutter Demo',
//       theme: ThemeData(
//         // This is the theme of your application.
//         //
//         // Try running your application with "flutter run". You'll see the
//         // application has a blue toolbar. Then, without quitting the app, try
//         // changing the primarySwatch below to Colors.green and then invoke
//         // "hot reload" (press "r" in the console where you ran "flutter run",
//         // or simply save your changes to "hot reload" in a Flutter IDE).
//         // Notice that the counter didn't reset back to zero; the application
//         // is not restarted.
//         primarySwatch: Colors.blue,
//       ),
//       home: EngageLoginScreen()// MyHomePage(title: 'Flutter Demo Home Page'),
//     );
//   }
// }

// class MyHomePage extends StatefulWidget {
//   MyHomePage({Key key, this.title}) : super(key: key);

//   // This widget is the home page of your application. It is stateful, meaning
//   // that it has a State object (defined below) that contains fields that affect
//   // how it looks.

//   // This class is the configuration for the state. It holds the values (in this
//   // case the title) provided by the parent (in this case the App widget) and
//   // used by the build method of the State. Fields in a Widget subclass are
//   // always marked "final".

//   final String title;

//   @override
//   _MyHomePageState createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   int _counter = 0;
//   EngageFirestore tests = EngageFirestore.getInstance('tests');

//   _MyHomePageState() {
//     init();
//   }

//   init() async {
//     EngageDoc doc = await tests.get('test_counter');
//     var data = doc.$doc;
//     // doc.setState([], () => setState(() {});
//     print(data);
//     setState(() {
//       // This call to setState tells the Flutter framework that something has
//       // changed in this State, which causes it to rerun the build method below
//       // so that the display can reflect the updated values. If we changed
//       // _counter without calling setState(), then the build method would not be
//       // called again, and so nothing would appear to happen.
//       _counter = doc.$doc['counter'];
//     });
//   }

//   void _incrementCounter() async {
//     EngageDoc doc = await tests.get('test_counter');
//     await doc.$('counter', increment: 1, done: (val) => setState(() => _counter = val));
//     // print(doc.$doc);
//     // doc.$save();
//     // setState(() {
//     //   // This call to setState tells the Flutter framework that something has
//     //   // changed in this State, which causes it to rerun the build method below
//     //   // so that the display can reflect the updated values. If we changed
//     //   // _counter without calling setState(), then the build method would not be
//     //   // called again, and so nothing would appear to happen.
//     //   _counter++;
//     // });
//   }

//   @override
//   Widget build(BuildContext context) {
//     // This method is rerun every time setState is called, for instance as done
//     // by the _incrementCounter method above.
//     //
//     // The Flutter framework has been optimized to make rerunning build methods
//     // fast, so that you can just rebuild anything that needs updating rather
//     // than having to individually change instances of widgets.
//     return Scaffold(
//       appBar: AppBar(
//         // Here we take the value from the MyHomePage object that was created by
//         // the App.build method, and use it to set our appbar title.
//         title: Text(widget.title),
//       ),
//       body: Center(
//         // Center is a layout widget. It takes a single child and positions it
//         // in the middle of the parent.
//         child: Column(
//           // Column is also a layout widget. It takes a list of children and
//           // arranges them vertically. By default, it sizes itself to fit its
//           // children horizontally, and tries to be as tall as its parent.
//           //
//           // Invoke "debug painting" (press "p" in the console, choose the
//           // "Toggle Debug Paint" action from the Flutter Inspector in Android
//           // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
//           // to see the wireframe for each widget.
//           //
//           // Column has various properties to control how it sizes itself and
//           // how it positions its children. Here we use mainAxisAlignment to
//           // center the children vertically; the main axis here is the vertical
//           // axis because Columns are vertical (the cross axis would be
//           // horizontal).
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             Text(
//               'You have pushed the button this many times:',
//             ),
//             Text(
//               '$_counter',
//               style: Theme.of(context).textTheme.display1,
//             ),
//           ],
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _incrementCounter,
//         tooltip: 'Increment',
//         child: Icon(Icons.add),
//       ), // This trailing comma makes auto-formatting nicer for build methods.
//     );
//   }
// }
