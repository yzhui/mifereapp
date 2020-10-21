import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:timeago/timeago.dart' as timeAgo;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import './globalStore.dart' as globalStore;

class BookmarksScreen extends StatefulWidget {
  BookmarksScreen({Key key}) : super(key: key);

  @override
  _BookmarksScreenState createState() => new _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  DataSnapshot snapshot;
  bool change = false;
  final FlutterWebviewPlugin flutterWebviewPlugin = new FlutterWebviewPlugin();

  Future updateSnapshot() async {
    var snap = await globalStore.articleDatabaseReference.once();
    this.setState(() {
      snapshot = snap;
    });
    return "Success!";
  }

  @override
  void initState() {
    super.initState();
    this.updateSnapshot();
  }

  _onBookmarkTap(article) {
    if (snapshot.value != null) {
      var value = snapshot.value;
      value.forEach((k, v) {
        if (v['url'].compareTo(article['url']) == 0) {
          globalStore.articleDatabaseReference.child(k).remove();
          Scaffold.of(context).showSnackBar(new SnackBar(
                content: new Text('Article removed'),
                backgroundColor: Colors.grey[600],
              ));
        }
      });
      this.updateSnapshot();
      this.setState(() {
        change = true;
      });
    }
  }

  Column buildButtonColumn(IconData icon) {
    Color color = Theme.of(context).primaryColor;
    return new Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        new Icon(icon, color: color),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      backgroundColor: Colors.grey[200],
      body: (snapshot != null && snapshot.value != null)
          ? new Column(
              children: <Widget>[
                                 
              ],
            )
          : new Center(
              child: new Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  new Icon(Icons.chrome_reader_mode,
                      color: Colors.grey, size: 60.0),
                  new Text(
                    "No articles saved",
                    style: new TextStyle(fontSize: 24.0, color: Colors.grey),
                  ),
                ],
              ),
            ),
    );
  }
}
