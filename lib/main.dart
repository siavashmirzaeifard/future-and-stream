import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'dart:developer' as devtools show log;

extension Log on Object {
  void log() => devtools.log(toString());
}

@immutable
class Person {
  final String name;
  final int age;

  const Person({
    required this.name,
    required this.age,
  });

  Person.fromJson(Map<String, dynamic> json)
      : name = json["name"] as String,
        age = json["age"] as int;

  @override
  String toString() => "Person(name: $name, age: $age)";
}

/* for this purpose I used "Live Server" extension for "VSCode" and instead of using live server load the names from the "api" folder which contains a 
json file as a hard coded json object. so press "cmd + shift + p" on mac or "ctrl + shift + p" on windows or linux and type live server and select on
 "open live server" and go to api/people.json, the url is your base url. (http://127.0.0.1:5500/api/persons.json) */
const persons1Url = "http://127.0.0.1:5500/api/persons1.json";
const persons2Url = "http://127.0.0.1:5500/api/persons2.json";

/* future methods as their name indicates are async, it means you will get the result aftter a while. future methods are triggered only
one time and return your result after a while however streams can return values continuesly. future and async are achiving the same thing. future returns us
a package of data type which we define, and for exploring during this package we are using async and await functionality. await means you wait on it and let me open
it then see what is in the package.  */
Future<Iterable<Person>> parseJson(String url) => HttpClient()
    .getUrl(Uri.parse(url))
    .then((req) => req.close())
    .then((res) => res.transform(utf8.decoder).join())
    .then((str) => jsonDecode(str) as List<dynamic>)
    .then((json) => json.map((e) => Person.fromJson(e)));

void main() {
  runApp(const MyApp());
}

/* Stream: streams are like a pipe. async generator allows you to create stream by using "yield" keyword without using streamController, and for using yield our function
 should be async*. yield does not return or break the function. streams will stop when they close, or when return error. to unpack data in stream using "await for".
 with "asyncExpand()" keyword you can create another stream when the stream produce a value (like flat map in Rx). stream transformatioin means transfotm values of a stream
 to other values. sink in stream is the where the values of a stream come in (value holder).

  future: | ----- v |
  future: | ----- ex |
  stream: | ----- v ----- v ----- v ----- |
  stream: | ----- v ----- v ----- e ----- |
  stream: | ----------------------------- |
  stream: | ----- e |
  stream: | ----- v |
 */

Stream<Iterable<Person>> getPersons() async* {
  for (final url in Iterable.generate(
    2,
    (i) => "http://127.0.0.1:5500/api/persons${i + 1}.json",
  )) {
    yield await parseJson(url);
  }
}

/* next sample, get the list of person's api with an api and then fetch each person api again */
mixin ListOfThingsApi<T> {
  Future<Iterable<T>> get(String url) => HttpClient()
      .getUrl(Uri.parse(url))
      .then((req) => req.close())
      .then((res) => res.transform(utf8.decoder).join())
      .then((str) => json.decode(str) as List<dynamic>)
      .then((list) => list.cast());
}

class GetApiEndPoints with ListOfThingsApi<String> {}

class GetPeople with ListOfThingsApi<Map<String, dynamic>> {
  Future<Iterable<Person>> getPeople(String url) =>
      get(url).then((jsons) => jsons.map((json) => Person.fromJson(json)));
}

/* next sample, stream transformation */
const names = ["foo", "bar", "baz"];

extension RandomElement<T> on Iterable<T> {
  T getRandomElement() => elementAt(math.Random().nextInt(length));
}

class UpperCaseSink implements EventSink<String> {
  final EventSink<String> _sink;

  const UpperCaseSink(this._sink);

  @override
  void add(String event) => _sink.add(event.toUpperCase());

  @override
  void addError(Object error, [StackTrace? stackTrace]) => _sink.addError(
        error,
        stackTrace,
      );

  @override
  void close() => _sink.close();
}

class StreamTransformUpperCaseString
    extends StreamTransformerBase<String, String> {
  @override
  Stream<String> bind(Stream<String> stream) =>
      Stream<String>.eventTransformed(stream, (sink) => UpperCaseSink(sink));
}

/* for let the package to open by dart and see what is in the package we will use await keyword before the future method, and to use await our function should be async.
with Future.wait we can define a list of futures which return us a list of iterable of person, but when aone of those apis fails then unhandled exception will happen.
so we need error handling by adding catchError. we can do this error handling per future method or do this for all the package, better way is handling the error per future,
because if we do at the end of the package the entire list is empty! Future.forEach has the same functionality, if every thing's going fine successfully the return null.
*/
void tester() async {
  final person = await parseJson(persons2Url);
  person.log();
  final persons = await Future.wait([
    parseJson(persons1Url).emptyOnErrorOnFuture(),
    parseJson(persons2Url).emptyOnErrorOnFuture(),
  ]);
  persons.log();
  final result = await Future.forEach(
          Iterable.generate(
            2,
            (i) => "http://127.0.0.1:5500/api/persons${i + 1}.json",
          ),
          parseJson)
      .catchError((_, __) => -1);
  if (result != null) {
    "Error".log();
  }
  await for (final person in getPersons()) {
    person.log();
  }
  final people = await GetApiEndPoints()
      .get("http://127.0.0.1:5500/api/apis.json")
      .then(
          (urls) => Future.wait(urls.map((url) => GetPeople().getPeople(url))));
  people.log();
  // await for (final value
  //     in Stream.periodic(const Duration(seconds: 2), (_) => "Hello")) {
  //   value.log();
  // }
  // await for (final people in Stream.periodic(const Duration(seconds: 2))
  //     .asyncExpand((_) => GetPeople()
  //         .getPeople("http://127.0.0.1:5500/api/persons1.json")
  //         .asStream())) {
  //   people.log();
  // }
  await for (final people in Stream.periodic(
          const Duration(seconds: 2), (_) => names.getRandomElement())
      .transform(StreamTransformUpperCaseString())) {
    people.log();
  }
}

/* error handling for all future list */
extension EmptyOnError<E> on Future<List<Iterable<E>>> {
  Future<List<Iterable<E>>> emptyOnError() =>
      catchError((_, __) => List<Iterable<E>>.empty());
}

/* error handling per future in the list */
extension EmptyOnErrorOnFuture<E> on Future<Iterable<E>> {
  Future<Iterable<E>> emptyOnErrorOnFuture() =>
      catchError((_, __) => Iterable<E>.empty());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    tester();
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Page'),
        centerTitle: true,
      ),
    );
  }
}

/* in rx -> future = single & stream = observable */