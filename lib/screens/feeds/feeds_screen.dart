import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oyster/auth.dart';
import 'package:oyster/common/constant.dart';
import 'package:oyster/data/repository.dart';
import 'package:oyster/model/Feed.dart';
import 'package:oyster/model/FeedSource.dart';
import 'package:oyster/model/Feeds.dart';
import 'package:oyster/screens/feeds/feed_list_item.dart';
import 'package:oyster/screens/feeds/feeds_screen_presenter.dart';
import 'package:oyster/screens/login/login_screen.dart';
import 'package:oyster/screens/setting/setting_screen.dart';

class SelectedCategory {
  final String value;
  final String viewValue;

  const SelectedCategory({this.value, this.viewValue});
}

class FeedsPage extends StatefulWidget {
  static String tag = 'feeds-page';
  FeedsPage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  FeedsPageState createState() => new FeedsPageState();
}

class FeedsPageState extends State<FeedsPage> implements FeedsScreenContract, AuthStateListener {
  FeedsScreenPresenter _presenter;
  List<Feed> items = List();
  List<FeedSource> _sources = List();
  final scaffoldKey = new GlobalKey<ScaffoldState>();
  ScrollController _scrollController = new ScrollController();
  bool isPerformingRequest = false;
  AuthStateProvider _authStateProvider;

  Repository repository = Repository.get();

  var sourceListener;
  SelectedCategory _selectedCategory =
      SelectedCategory(value: '_all', viewValue: 'All');

  int offset = 0;
  final queryCount = 30;

  FeedsPageState() {
    _presenter = new FeedsScreenPresenter(this);
    _authStateProvider = new AuthStateProvider();
    _authStateProvider.subscribe(this);
  }

  @override
  void initState() {
    super.initState();

    repository.refreshFeedSource();

    sourceListener =
        repository.getFeedSource$().listen((List<FeedSource> sources) {
      setState(() {
        _sources = sources;
      });
    });

    _handleFirstFeedsQuery();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        _getMoreData();
      }
    });

    // _handleRealRefresh2();
  }

  @override
  onAuthStateChanged(AuthState state) {
    if (state == AuthState.LOGGED_OUT) {
      Navigator.of(context).pushReplacementNamed(LoginScreen.tag);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    sourceListener.cancel();
    super.dispose();
  }

  @override
  void onFeedReceived(List<Feed> newFeeds) {
    offset += queryCount;
    setState(() {
      items.addAll(newFeeds);
      isPerformingRequest = false;
    });
  }

  @override
  void onQueryFeedError(String errorText) {
    setState(() {
      isPerformingRequest = false;
    });
  }

  _getMoreData() {
    if (!isPerformingRequest) {
      setState(() => isPerformingRequest = true);
      _presenter.queryMoreFeeds(queryCount, offset, _selectedCategory.value, items.length > 0 ? items.last.id : 0);
    }
  }

  void _handleBack(Feed feed) {}

  // 下拉刷新
  Future<Null> _handleRealRefresh2() async {
    try {
      final Feeds feeds =
      await _presenter.queryLatestFeeds(_selectedCategory.value, items.length > 0 ? items.first.id : null);
      setState(() {
        if (feeds.items.length > 0) {
          final List<Feed> newItems = new List.from(feeds.items.reversed);
          newItems.addAll(items);
          items = newItems;
          // items.addAll(feeds.items);
          // offset = queryCount;
        }
      });
    } catch(e) {
      print(e);
      // print(e._stackTrace);
      _showSnackBar(e.toString());
    }
  }

  // 初始化刷新
  Future<Null> _handleFirstFeedsQuery() async {
    setState(() {
      items.clear();
    });
    try {
      final List<Feed> feeds =
      await _presenter.getHeadFeeds(queryCount, _selectedCategory.value);
      setState(() {
        items.addAll(feeds);
        offset = feeds.length;
      });
      _handleRealRefresh2(); // 刷新最新数据
    } catch(e) {
      print(e);
      // print(e._stackTrace);
      _showSnackBar(e.toString());
    }
  }

  void _showSnackBar(String text) {
    scaffoldKey.currentState
        .showSnackBar(new SnackBar(content: new Text(text)));
  }

  Future<Null> _handlePressSetting() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingScreen(),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return new Padding(
      padding: const EdgeInsets.all(8.0),
      child: new Center(
        child: new Opacity(
          opacity: isPerformingRequest ? 1.0 : 0.0,
          child: new CircularProgressIndicator(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final drawerSourcesList = _sources.map((FeedSource feedSource) {
      return ListTile(
          title: Text(feedSource.name),
          selected: _selectedCategory.value == feedSource.id,
          onTap: () {
            _selectedCategory = SelectedCategory(
                value: feedSource.id, viewValue: feedSource.name);
            _handleFirstFeedsQuery();
            Navigator.of(context).pop();
          });
    }).toList();

    final drawerChildren = [
          ListTile(
              leading: Icon(Icons.grain),
              title: Text('All'),
              selected: _selectedCategory.value == "_all",
              onTap: () {
                _selectedCategory =
                    SelectedCategory(value: '_all', viewValue: 'All');
                _handleFirstFeedsQuery();
                Navigator.of(context).pop();
              }),
          ListTile(
              leading: Icon(Icons.star, color: Colors.amber),
              title: Text('Star'),
              selected: _selectedCategory.value == '_favorite',
              onTap: () {
                _selectedCategory =
                    SelectedCategory(value: '_favorite', viewValue: 'Star');
                _handleFirstFeedsQuery();
                Navigator.of(context).pop();
              })
        ].toList() +
        drawerSourcesList;

    return new Scaffold(
        key: scaffoldKey,
        drawer: Drawer(
            child: new Column(
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            UserAccountsDrawerHeader(
                decoration: BoxDecoration(
                  color: PrimaryColor,
                ),
                currentAccountPicture: new CircleAvatar(
                  backgroundImage: new AssetImage("assets/icon.png"),
                ),
                accountName: Text(""),
                accountEmail: Text(""),
                margin: EdgeInsets.only(bottom: 0.0)),
            new Expanded(
              flex: 10,
              child: new Align(
                alignment: FractionalOffset.center,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: drawerChildren,
                ),
              ),
            ),
            new Expanded(
              child: ListTile(
                  leading: Icon(Icons.settings, color: Colors.grey),
                  title: Text('Setting'),
                  onTap: this._handlePressSetting),
            )
          ],
        )),
        appBar: AppBar(
            backgroundColor: Color(0xfffdad28),
            iconTheme: IconThemeData(color: Colors.white),
            title: Text("${_selectedCategory.viewValue} feeds",
                style: TextStyle(color: Colors.white))),
        body: new RefreshIndicator(
            child: ListView.builder(
              itemCount: items.length * 2,
              itemBuilder: (context, index) {
                if (items.length == 0) {
                    return _buildProgressIndicator();
                }
                if (index.isOdd) {
                  return Divider(
                    height: 8,
                  );
                }
                return FeedListItem(feed: items[index ~/ 2], onBack: _handleBack);
                // if (index == items.length) { // TODO
                //   return _buildProgressIndicator();
                // } else {
                // }
              },
              controller: _scrollController,
            ),
            onRefresh: _handleRealRefresh2));
  }
}
