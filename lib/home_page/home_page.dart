import 'dart:async';

import 'package:flutter/material.dart';
import 'package:load_more_flutter/data/memory_person_data_source.dart';
import 'package:load_more_flutter/data/people_api.dart';
import 'package:load_more_flutter/home_page/people_bloc.dart';

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _scrollController = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  static const offsetVisibleThreshold = 50;

  ///
  /// pass [PeopleApi] or [MemoryPersonDataSource] to [PeopleBloc]'s constructor
  ///
  PeopleBloc _bloc;
  StreamSubscription<void> _subscriptionReachMaxItems;
  StreamSubscription<Object> _subscriptionError;

  @override
  void initState() {
    super.initState();

    _bloc = PeopleBloc(MemoryPersonDataSource(context: context))
      ..loadMore.add(null); // load first page
    // listen error, reach max items
    _subscriptionReachMaxItems = _bloc.loadedAllPeople.listen(_onReachMaxItem);
    _subscriptionError = _bloc.error.listen(_onError);

    // add listener to scroll controller
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() async {
    _scrollController.dispose();
    await Future.wait([
      _bloc.dispose(),
      _subscriptionError.cancel(),
      _subscriptionReachMaxItems.cancel(),
    ]);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text('Load more flutter'),
      ),
      body: RefreshIndicator(
        child: Container(
          constraints: BoxConstraints.expand(),
          child: StreamBuilder<PeopleListState>(
            stream: _bloc.peopleList,
            builder: (BuildContext context,
                AsyncSnapshot<PeopleListState> snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error ${snapshot.error}'),
                );
              }

              if (!snapshot.hasData) {
                return Center(
                  child: CircularProgressIndicator(),
                );
              }

              return _buildList(snapshot);
            },
          ),
        ),
        onRefresh: _bloc.refresh,
      ),
    );
  }

  ListView _buildList(AsyncSnapshot<PeopleListState> snapshot) {
    final people = snapshot.data.people;
    final isLoading = snapshot.data.isLoading;
    final error = snapshot.data.error;

    return ListView.separated(
      physics: AlwaysScrollableScrollPhysics(),
      controller: _scrollController,
      itemBuilder: (BuildContext context, int index) {
        if (index < people.length) {
          return ListTile(
            title: Text(people[index].name),
            subtitle: Text(people[index].bio),
            leading: CircleAvatar(
              child: Text(people[index].emoji),
              foregroundColor: Colors.white,
              backgroundColor: Colors.purple,
            ),
          );
        }

        if (isLoading) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (error != null) {
          return ListTile(
            title: Text(
              'Error while loading data...',
              style: Theme.of(context).textTheme.body1.copyWith(fontSize: 16.0),
            ),
            isThreeLine: false,
            leading: CircleAvatar(
              child: Text(':('),
              foregroundColor: Colors.white,
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return Container();
      },
      itemCount: people.length + 1,
      separatorBuilder: (BuildContext context, int index) => Divider(),
    );
  }

  Future<void> makeAnimation() async {
    final offsetFromBottom =
        _scrollController.position.maxScrollExtent - _scrollController.offset;
    if (offsetFromBottom < offsetVisibleThreshold) {
      await _scrollController.animateTo(
        _scrollController.offset - (offsetVisibleThreshold - offsetFromBottom),
        duration: Duration(milliseconds: 1000),
        curve: Curves.easeOut,
      );
    }
  }

  void _onScroll() {
    // if scroll to bottom of list, then load next page
    if (_scrollController.offset + offsetVisibleThreshold >=
        _scrollController.position.maxScrollExtent) {
      _bloc.loadMore.add(null);
    }
  }

  void _onReachMaxItem(void _) async {
    // show animation when loaded all data
    await makeAnimation();
    await (_scaffoldKey.currentState
        ?.showSnackBar(
          SnackBar(
            content: Text('Got all data!'),
          ),
        )
        ?.closed);
  }

  void _onError(Object error) async {
    await (_scaffoldKey.currentState
        ?.showSnackBar(
          SnackBar(
            content: Text('Error occurred $error'),
          ),
        )
        ?.closed);
  }
}
