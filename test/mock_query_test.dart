import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:test/test.dart';

import 'document_snapshot_matcher.dart';
import 'fake_cloud_firestore_test.dart';
import 'query_snapshot_matcher.dart';

const uid = 'abc';

extension ToData<T> on List<QueryDocumentSnapshot<T>> {
  List<T?> toData() => map((snapshot) => snapshot.data()).toList();
}

void main() {
  test('size', () async {
    final instance = FakeFirebaseFirestore();
    expect((await instance.collection('messages').get()).size, 0);
    await instance.collection('messages').add({
      'content': 'hello!',
    });
    expect((await instance.collection('messages').get()).size, 1);
  });

  test('Where(field, isGreaterThan: ...)', () async {
    final instance = FakeFirebaseFirestore();
    final now = DateTime.now();
    await instance.collection('messages').add({
      'content': 'hello!',
      'uid': uid,
      'timestamp': now,
    });
    // Test that there is one result.
    expect(
        instance
            .collection('messages')
            .where('timestamp',
                isGreaterThan: now.subtract(Duration(seconds: 1)))
            .snapshots(),
        emits(QuerySnapshotMatcher([
          DocumentSnapshotMatcher.onData({
            'content': 'hello!',
            'uid': uid,
            'timestamp': Timestamp.fromDate(now),
          })
        ])));
    // Filter out everything and check that there is no result.
    expect(
        instance
            .collection('messages')
            .where('timestamp', isGreaterThan: now.add(Duration(seconds: 1)))
            .snapshots(),
        emits(QuerySnapshotMatcher([])));
    // Test on missing properties.
    expect(
        instance
            .collection('messages')
            .where('length', isGreaterThan: 5)
            .snapshots(),
        emits(QuerySnapshotMatcher([])));
  });

  test('isLessThanOrEqualTo', () async {
    final instance = FakeFirebaseFirestore();
    final now = DateTime.now();
    final before = now.subtract(Duration(seconds: 1));
    final after = now.add(Duration(seconds: 1));
    await instance.collection('messages').add({
      'content': 'before',
      'timestamp': before,
    });
    await instance.collection('messages').add({
      'content': 'during',
      'timestamp': now,
    });
    await instance.collection('messages').add({
      'content': 'after',
      'timestamp': after,
    });
    // Test filtering.
    expect(
        instance
            .collection('messages')
            .where('timestamp', isLessThanOrEqualTo: now)
            .snapshots(),
        emits(QuerySnapshotMatcher([
          DocumentSnapshotMatcher.onData({
            'content': 'before',
            'timestamp': Timestamp.fromDate(before),
          }),
          DocumentSnapshotMatcher.onData({
            'content': 'during',
            'timestamp': Timestamp.fromDate(now),
          }),
        ])));
    expect(
        instance
            .collection('messages')
            .where('timestamp',
                isLessThanOrEqualTo: now.subtract(Duration(seconds: 2)))
            .snapshots(),
        emits(QuerySnapshotMatcher([])));
    expect(
        instance
            .collection('messages')
            .where('timestamp', isLessThan: now)
            .snapshots(),
        emits(QuerySnapshotMatcher([
          DocumentSnapshotMatcher.onData({
            'content': 'before',
            'timestamp': Timestamp.fromDate(before),
          }),
        ])));
    expect(
        instance
            .collection('messages')
            .where('timestamp', isLessThan: now.subtract(Duration(seconds: 2)))
            .snapshots(),
        emits(QuerySnapshotMatcher([])));
    expect(
        instance
            .collection('messages')
            .where('timestamp', isGreaterThanOrEqualTo: now)
            .snapshots(),
        emits(QuerySnapshotMatcher([
          DocumentSnapshotMatcher.onData({
            'content': 'during',
            'timestamp': Timestamp.fromDate(now),
          }),
          DocumentSnapshotMatcher.onData({
            'content': 'after',
            'timestamp': Timestamp.fromDate(after),
          }),
        ])));
    expect(
        instance
            .collection('messages')
            .where('timestamp',
                isGreaterThanOrEqualTo: now.add(Duration(seconds: 2)))
            .snapshots(),
        emits(QuerySnapshotMatcher([])));
  });

  test('isEqualTo, orderBy, limit and getDocuments', () async {
    final instance = FakeFirebaseFirestore();
    final now = DateTime.now();
    final bookmarks =
        instance.collection('users').doc(uid).collection('bookmarks');
    await bookmarks.add({
      'hidden': false,
      'timestamp': now,
    });
    await bookmarks.add({
      'tag': 'mostrecent',
      'hidden': false,
      'timestamp': now.add(Duration(days: 1)),
    });
    await bookmarks.add({
      'hidden': false,
      'timestamp': now,
    });
    await bookmarks.add({
      'hidden': true,
      'timestamp': now,
    });
    final snapshot = (await instance
        .collection('users')
        .doc(uid)
        .collection('bookmarks')
        .where('hidden', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .limit(2)
        .get());
    expect(snapshot.docs.length, equals(2));
    expect(snapshot.docs.first.get('tag'), equals('mostrecent'));
  });

  test('isNotEqualTo where clause', () async {
    final instance = FakeFirebaseFirestore();
    final collection = instance.collection('test');
    await collection.add({'hidden': false, 'id': 'HIDDEN'});
    await collection.add({'hidden': true, 'id': 'VISIBLE'});

    final visibleSnapshot = (await instance
        .collection('test')
        .where('hidden', isNotEqualTo: false)
        .get());
    expect(visibleSnapshot.docs.length, equals(1));
    expect(visibleSnapshot.docs.first.get('id'), equals('VISIBLE'));

    final hiddenSnapshot = (await instance
        .collection('test')
        .where('hidden', isNotEqualTo: true)
        .get());
    expect(hiddenSnapshot.docs.length, equals(1));
    expect(hiddenSnapshot.docs.first.get('id'), equals('HIDDEN'));
  });

  group('isNotEqualTo where clause for non existent', () {
    test('with no nesting', () async {
      final instance = FakeFirebaseFirestore();
      final collection = instance.collection('test');
      await collection.add({'a': 'b'});

      final visibleSnapshot = (await instance
          .collection('test')
          .where('a', isNotEqualTo: '')
          .get());
      expect(visibleSnapshot.docs.length, equals(1));
      expect(visibleSnapshot.docs.first.get('a'), equals('b'));

      final emptySnapshot = (await instance
          .collection('test')
          .where('c', isNotEqualTo: '')
          .get());
      expect(emptySnapshot.docs.length, equals(0));
    });

    test('with string path nesting', () async {
      final instance = FakeFirebaseFirestore();
      final collection = instance.collection('test');
      await collection.add({
        'a': {'b': 'c'}
      });

      final visibleSnapshot = (await instance
          .collection('test')
          .where('a.b', isNotEqualTo: '')
          .get());
      expect(visibleSnapshot.docs.length, equals(1));
      expect(visibleSnapshot.docs.first.get('a.b'), equals('c'));

      final emptySnapshot = (await instance
          .collection('test')
          .where('a.c', isNotEqualTo: '')
          .get());
      expect(emptySnapshot.docs.length, equals(0));
    });

    test('with FieldPath', () async {
      final instance = FakeFirebaseFirestore();
      final collection = instance.collection('test');
      await collection.add({
        'users': {'test@example.com': 'I exist'}
      });

      final visibleSnapshot = (await instance
          .collection('test')
          .where(FieldPath(['users', 'test@example.com']), isNotEqualTo: '')
          .get());
      expect(visibleSnapshot.docs.length, equals(1));
      expect(
          visibleSnapshot.docs.first
              .get(FieldPath(['users', 'test@example.com'])),
          equals('I exist'));

      final emptySnapshot = (await instance
          .collection('test')
          .where(FieldPath(['users', 'bogus@example.com']), isNotEqualTo: '')
          .get());
      expect(emptySnapshot.docs.length, equals(0));
    });
  });

  test('isNull where clause', () async {
    final instance = FakeFirebaseFirestore();
    await instance
        .collection('contestants')
        .add({'name': 'Alice', 'country': 'USA', 'experience': '5'});

    await instance
        .collection('contestants')
        .add({'name': 'Tom', 'country': 'USA'});

    final nonNullFieldSnapshot = (await instance
        .collection('contestants')
        .where('country', isNull: false)
        .get());
    expect(nonNullFieldSnapshot.docs.length, equals(2));

    final isNotNullFieldSnapshot = (await instance
        .collection('contestants')
        .where('experience', isNull: false)
        .get());
    expect(isNotNullFieldSnapshot.docs.length, equals(1));
    expect(isNotNullFieldSnapshot.docs.first.get('name'), equals('Alice'));

    final isNullFieldSnapshot = (await instance
        .collection('contestants')
        .where('experience', isNull: true)
        .get());
    expect(isNullFieldSnapshot.docs.length, equals(1));
    expect(isNullFieldSnapshot.docs.first.get('name'), equals('Tom'));
  });

  test('orderBy returns documents with null fields first', () async {
    final instance = FakeFirebaseFirestore();
    await instance
        .collection('usercourses')
        .add({'completed_at': Timestamp.fromDate(DateTime.now())});
    await instance.collection('usercourses').add({'completed_at': null});

    var query = instance.collection('usercourses').orderBy('completed_at');

    query.snapshots().listen(expectAsync1(
      (event) {
        expect(event.docs.first.get('completed_at'), isNull);
        expect(event.docs[1].get('completed_at'), isNotNull);
        expect(event.docs.length, greaterThan(0));
      },
    ));
  });

  test('orderBy returns documents sorted by documentID', () async {
    final instance = FakeFirebaseFirestore();
    await instance.collection('users').doc('3').set({'value': 3});
    await instance.collection('users').doc('2').set({'value': 2});
    await instance.collection('users').doc('1').set({'value': 1});

    final query = instance.collection('users').orderBy(FieldPath.documentId);
    query.snapshots().listen(expectAsync1(
      (event) {
        expect(event.docs.first.id, ('1'));
        expect(event.docs[1].id, ('2'));
        expect(event.docs[2].id, ('3'));
        expect(event.docs.length, greaterThan(0));
      },
    ));
  });

  test('orderBy works with nested values', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('test').add({
      'nested': {
        'value': 5,
      }
    });
    await firestore.collection('test').add({
      'nested': {
        'value': 2,
      }
    });

    final data =
        await firestore.collection('test').orderBy('nested.value').get();
    expect(data.docs.first.get('nested.value'), 2);
    expect(data.docs.first.data()['nested']['value'], 2);
  });

  test('Where clause resolves composed keys', () async {
    final instance = FakeFirebaseFirestore();
    await instance.collection('contestants').add({
      'name': 'Alice',
      'country': 'USA',
      'skills': {'cycling': '1', 'running': ''}
    });

    instance
        .collection('contestants')
        .where('skills.cycling', isGreaterThan: '')
        .snapshots()
        .listen(expectAsync1((QuerySnapshot snapshot) {
      expect(snapshot.docs.length, equals(1));
    }));

    instance
        .collection('contestants')
        .where('skills.cycling', isEqualTo: '1')
        .snapshots()
        .listen(expectAsync1((QuerySnapshot snapshot) {
      expect(snapshot.docs.length, equals(1));
    }));

    instance
        .collection('contestants')
        .where('skills.running', isGreaterThan: '')
        .snapshots()
        .listen(expectAsync1((QuerySnapshot snapshot) {
      expect(snapshot.docs.length, equals(0));
    }));

    instance
        .collection('contestants')
        .where('skills.swimming', isEqualTo: '1')
        .snapshots()
        .listen(expectAsync1((QuerySnapshot snapshot) {
      expect(snapshot.docs.length, equals(0));
    }));

    instance
        .collection('contestants')
        .where('skills.swimming', isGreaterThanOrEqualTo: '1')
        .snapshots()
        .listen(expectAsync1((QuerySnapshot snapshot) {
      expect(snapshot.docs.length, equals(0));
    }));
  });

  test('arrayContains', () async {
    final instance = FakeFirebaseFirestore();
    await instance.collection('posts').add({
      'name': 'Post #1',
      'tags': ['mostrecent', 'interesting'],
    });
    await instance.collection('posts').add({
      'name': 'Post #2',
      'tags': ['mostrecent'],
    });
    await instance.collection('posts').add({
      'name': 'Post #3',
      'tags': ['mostrecent'],
    });
    await instance.collection('posts').add({
      'name': 'Post #4',
      'tags': ['mostrecent', 'interesting'],
    });
    instance
        .collection('posts')
        .where('tags', arrayContains: 'interesting')
        .snapshots()
        .listen(expectAsync1((QuerySnapshot snapshot) {
      expect(snapshot.docs.length, equals(2));

      /// verify the matching documents were returned
      snapshot.docs.forEach((returnedDocument) {
        expect(returnedDocument.get('tags'), contains('interesting'));
      });
    }));
  });

  test('arrayContainsAny', () async {
    final instance = FakeFirebaseFirestore();
    await instance.collection('posts').add({
      'name': 'Post #1',
      'tags': ['mostrecent', 'interesting', 'coolstuff'],
      'commenters': [111, 222, 333],
    });
    await instance.collection('posts').add({
      'name': 'Post #2',
      'tags': ['mostrecent'],
      'commenters': [111, 222],
    });
    await instance.collection('posts').add({
      'name': 'Post #3',
      'tags': ['mostrecent'],
      'commenters': [111],
    });
    await instance.collection('posts').add({
      'name': 'Post #4',
      'tags': ['mostrecent', 'interesting'],
      'commenters': [222, 333]
    });
    instance
        .collection('posts')
        .where('tags', arrayContainsAny: ['interesting', 'mostrecent'])
        .snapshots()
        .listen(expectAsync1((QuerySnapshot snapshot) {
          expect(snapshot.docs.length, equals(4));
        }));
    instance
        .collection('posts')
        .where('commenters', arrayContainsAny: [222, 333])
        .snapshots()
        .listen(expectAsync1((QuerySnapshot snapshot) {
          expect(snapshot.docs.length, equals(3));
        }));
    instance
        .collection('posts')
        .where(
          'commenters',
          arrayContainsAny: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
        )
        .snapshots()
        .listen(null, onError: expectAsync1((error) {
          expect(error, isA<ArgumentError>());
        }));
  });

  test('whereIn', () async {
    final instance = FakeFirebaseFirestore();
    await instance.collection('contestants').add({
      'name': 'Alice',
      'country': 'USA',
      'skills': ['cycling', 'running']
    });
    await instance.collection('contestants').add({
      'name': 'Bob',
      'country': 'Japan',
      'skills': ['gymnastics', 'swimming']
    });
    await instance.collection('contestants').add({
      'name': 'Celina',
      'country': 'India',
      'skills': ['swimming', 'running']
    });
    instance
        .collection('contestants')
        .where('country', whereIn: ['Japan', 'India'])
        .snapshots()
        .listen(expectAsync1((QuerySnapshot snapshot) {
          expect(snapshot.docs.length, equals(2));
        }));
    instance
        .collection('contestants')
        .where('country', whereIn: ['USA'])
        .snapshots()
        .listen(expectAsync1((QuerySnapshot snapshot) {
          expect(snapshot.docs.length, equals(1));
        }));
    instance
        .collection('contestants')
        .where(
          'country',
          whereIn: ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L'],
        )
        .snapshots()
        .listen(null, onError: expectAsync1((error) {
          expect(error, isA<ArgumentError>());
        }));
    instance
        .collection('contestants')
        .where(
          'country',
          whereIn: ['India'],
          arrayContainsAny: ['USA'],
        )
        .snapshots()
        .listen(null, onError: expectAsync1((error) {
          expect(error, isFormatException);
        }));
  });

  test('whereNotIn', () async {
    final instance = FakeFirebaseFirestore();
    await instance.collection('contestants').add({
      'name': 'Alice',
      'country': 'USA',
      'skills': ['cycling', 'running']
    });
    await instance.collection('contestants').add({
      'name': 'Bob',
      'country': 'Japan',
      'skills': ['gymnastics', 'swimming']
    });
    await instance.collection('contestants').add({
      'name': 'Celina',
      'country': 'India',
      'skills': ['swimming', 'running']
    });
    instance
        .collection('contestants')
        .where('country', whereNotIn: ['Japan', 'India'])
        .snapshots()
        .listen(expectAsync1((QuerySnapshot snapshot) {
          expect(snapshot.docs.length, equals(1));
        }));
    instance
        .collection('contestants')
        .where('country', whereNotIn: ['USA'])
        .snapshots()
        .listen(expectAsync1((QuerySnapshot snapshot) {
          expect(snapshot.docs.length, equals(2));
        }));
    instance
        .collection('contestants')
        .where(
          'country',
          whereNotIn: ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L'],
        )
        .snapshots()
        .listen(null, onError: expectAsync1((error) {
          expect(error, isA<ArgumentError>());
        }));
    instance
        .collection('contestants')
        .where(
          'country',
          whereNotIn: ['India'],
          arrayContainsAny: ['USA'],
        )
        .snapshots()
        .listen(null, onError: expectAsync1((error) {
          expect(error, isFormatException);
        }));
  });

  test('where with FieldPath.documentID', () async {
    final instance = FakeFirebaseFirestore();
    await instance.collection('users').doc('1').set({'value': 1});
    await instance.collection('users').doc('2').set({'value': 2});
    await instance.collection('users').doc('3').set({'value': 3});

    final snapshot = await instance
        .collection('users')
        .where(FieldPath.documentId, isEqualTo: '1')
        .get();

    final documents = snapshot.docs;

    expect(documents.length, equals(1));
    expect(documents.first.id, equals('1'));
  });

  test('Collection.getDocuments', () async {
    final instance = FakeFirebaseFirestore();
    await instance.collection('users').add({
      'username': 'Bob',
    });
    final snapshot = await instance.collection('users').get();
    expect(snapshot.docs.length, equals(1));
  });

  test('Chained where queries return the correct snapshots', () async {
    final instance = FakeFirebaseFirestore();
    final bookmarks =
        instance.collection('users').doc(uid).collection('bookmarks');
    await bookmarks.add({
      'hidden': false,
    });
    await bookmarks.add({
      'tag': 'mostrecent',
      'hidden': false,
    });
    await bookmarks.add({
      'hidden': false,
    });
    await bookmarks.add({
      'tag': 'mostrecent',
      'hidden': true,
    });
    instance
        .collection('users')
        .doc(uid)
        .collection('bookmarks')
        .where('hidden', isEqualTo: false)
        .where('tag', isEqualTo: 'mostrecent')
        .snapshots()
        .listen(expectAsync1((QuerySnapshot snapshot) {
      expect(snapshot.docs.length, equals(1));
      expect(snapshot.docs.first.get('tag'), equals('mostrecent'));
    }));
  });

  test('Collection reference should not hold query result', () async {
    final instance = FakeFirebaseFirestore();

    final collectionReference = instance.collection('users');
    await collectionReference.add({
      'username': 'Bob',
    });
    final snapshot = await collectionReference.get();
    expect(snapshot.docs, hasLength(1));
  });

  test('Reference to subcollection should not hold query result', () async {
    final instance = FakeFirebaseFirestore();

    final collectionReference = instance.collection('users/1234/friends');
    await collectionReference.doc('abc').set({
      'username': 'Bob',
    });
    final snapshot = await collectionReference.get();
    expect(snapshot.docs, hasLength(1));

    await collectionReference.doc('abc').delete();
    final snapshotAfterDelete = await collectionReference.get();
    expect(snapshotAfterDelete.docs, hasLength(0));
  });

  test('Query should not hold query result', () async {
    final instance = FakeFirebaseFirestore();

    final collectionReference = instance.collection('users/1234/friends');
    final query1 = collectionReference.where('username', isGreaterThan: 'B');
    final query2 = query1.orderBy('username');
    final query3 = query2.limit(1);

    final snapshotBeforeAdd = await query3.get();
    expect(snapshotBeforeAdd.docs, isEmpty);

    await collectionReference.add({
      'username': 'Alex',
    });
    await collectionReference.add({
      'username': 'Charlie',
    });
    await collectionReference.add({
      'username': 'Brian',
    });

    final snapshotAfterAdd = await query3.get();
    expect(snapshotAfterAdd.docs, hasLength(1)); // limit 1
    // Alex is filtered out by 'where' query.
    // 'Brian' comes before 'Charlie'
    expect(snapshotAfterAdd.docs.first.get('username'), 'Brian');
  });

  group('Query modifiers', () {
    test('startAfterDocument', () async {
      final instance = FakeFirebaseFirestore();

      await instance.collection('messages').doc().set({'Username': 'Alice'});

      await instance.collection('messages').doc(uid).set({'Username': 'Bob'});

      await instance.collection('messages').doc().set({'Username': 'Cris'});

      await instance.collection('messages').doc().set({'Username': 'John'});

      final documentSnapshot =
          await instance.collection('messages').doc(uid).get();

      final snapshots = await instance
          .collection('messages')
          .startAfterDocument(documentSnapshot)
          .get();

      expect(snapshots.docs, hasLength(2));
      expect(
        snapshots.docs.where((doc) => doc.id == uid),
        hasLength(0),
      );
    });
    test('startAtDocument', () async {
      final instance = FakeFirebaseFirestore();

      await instance.collection('messages').doc().set({'Username': 'Alice'});

      await instance.collection('messages').doc(uid).set({'Username': 'Bob'});

      await instance.collection('messages').doc().set({'Username': 'Cris'});

      await instance.collection('messages').doc().set({'Username': 'John'});

      final documentSnapshot =
          await instance.collection('messages').doc(uid).get();

      final snapshots = await instance
          .collection('messages')
          .startAtDocument(documentSnapshot)
          .get();

      expect(snapshots.docs, hasLength(3));
      expect(
        snapshots.docs.where((doc) => doc.id == uid),
        hasLength(1),
      );
    });
    test('endAtDocument', () async {
      final instance = FakeFirebaseFirestore();

      await instance.collection('messages').doc().set({'Username': 'Alice'});

      await instance.collection('messages').doc(uid).set({'Username': 'Bob'});

      await instance.collection('messages').doc().set({'Username': 'Cris'});

      await instance.collection('messages').doc().set({'Username': 'John'});

      final documentSnapshot =
          await instance.collection('messages').doc(uid).get();

      final snapshots = await instance
          .collection('messages')
          .endAtDocument(documentSnapshot)
          .get();

      expect(snapshots.docs, hasLength(2));
      expect(
        snapshots.docs.where((doc) => doc.id == uid),
        hasLength(1),
      );
    });
    test('endBefore', () async {
      final instance = FakeFirebaseFirestore();

      await instance.collection('messages').doc().set({'Username': 'Alice'});

      await instance.collection('messages').doc(uid).set({'Username': 'Bob'});

      await instance.collection('messages').doc().set({'Username': 'Cris'});

      await instance.collection('messages').doc().set({'Username': 'John'});

      final snapshots = await instance
          .collection('messages')
          .orderBy('Username')
          .endBefore(['Bob']).get();

      expect(snapshots.docs, hasLength(1));
      expect(
        snapshots.docs.where((doc) => doc.id == uid),
        hasLength(0),
      );
    });
    test('endBeforeDocument', () async {
      final instance = FakeFirebaseFirestore();

      await instance.collection('messages').doc().set({'Username': 'Alice'});

      await instance.collection('messages').doc(uid).set({'Username': 'Bob'});

      await instance.collection('messages').doc().set({'Username': 'Cris'});

      await instance.collection('messages').doc().set({'Username': 'John'});

      final documentSnapshot =
          await instance.collection('messages').doc(uid).get();

      final snapshots = await instance
          .collection('messages')
          .endBeforeDocument(documentSnapshot)
          .get();

      expect(snapshots.docs, hasLength(1));
      expect(
        snapshots.docs.where((doc) => doc.id == uid),
        hasLength(0),
      );
    });
  });

  test('chaining where and startAfterDocument return correct documents',
      () async {
    final instance = FakeFirebaseFirestore();

    await instance.collection('messages').doc().set({'username': 'Bob'});

    await instance //Start after this doc
        .collection('messages')
        .doc(uid)
        .set({'username': 'Bob'});

    await instance.collection('messages').doc().set({'username': 'John'});

    await instance.collection('messages').doc().set({'username': 'Bob'});

    final documentSnapshot =
        await instance.collection('messages').doc(uid).get();

    final querySnapshot = await instance
        .collection('messages')
        .where('username', isEqualTo: 'Bob')
        .startAfterDocument(documentSnapshot)
        .get();

    expect(querySnapshot.docs, hasLength(1));
  });

  test('startAfterDocument throws if the document doesn\'t exist', () async {
    final instance = FakeFirebaseFirestore();

    await instance.collection('messages').doc(uid).set({'username': 'Bob'});

    final documentSnapshot =
        await instance.collection('messages').doc(uid).get();

    await instance.collection('123').doc().set({'tag': 'bike'});

    await instance.collection('123').doc().set({'tag': 'chess'});

    expect(
      () async => await instance
          .collection('123')
          .startAfterDocument(documentSnapshot)
          .get(),
      throwsA(TypeMatcher<PlatformException>()),
    );
  });

  test('startAfter on exact match works', () async {
    final instance = FakeFirebaseFirestore();

    await instance.collection('messages').add({'Username': 'Alice'});
    await instance.collection('messages').add({'Username': 'Bob'});
    await instance.collection('messages').add({'Username': 'Cris'});
    await instance.collection('messages').add({'Username': 'John'});

    final snapshots = await instance
        .collection('messages')
        .orderBy('Username')
        .startAfter(['Bob']).get();

    expect(snapshots.docs, hasLength(2));
  });

  test('startAfter on inexact match works', () async {
    final instance = FakeFirebaseFirestore();

    await instance.collection('messages').add({'Username': 'Alice'});
    await instance.collection('messages').add({'Username': 'Bob'});
    await instance.collection('messages').add({'Username': 'Cris'});
    await instance.collection('messages').add({'Username': 'John'});

    final snapshots = await instance
        .collection('messages')
        .orderBy('Username')
        .startAfter(['Brice']).get();

    expect(snapshots.docs, hasLength(2));
  });

  test('Continuous data receive via stream with where', () async {
    final instance = FakeFirebaseFirestore();
    instance
        .collection('messages')
        .where('archived', isEqualTo: false)
        .snapshots()
        .listen(expectAsync1((snapshot) {
          expect(snapshot.docs.length, inInclusiveRange(0, 2));
          for (final d in snapshot.docs) {
            expect(d.get('archived'), isFalse);
          }
        }, count: 3)); // initial [], when add 'hello!' and when add 'hola!'.

    instance
        .collection('messages')
        .where('archived', isEqualTo: true)
        .snapshots()
        .listen(expectAsync1((snapshot) {
          expect(snapshot.docs.length, inInclusiveRange(0, 1));
          for (final d in snapshot.docs) {
            expect(d.get('archived'), isTrue);
          }
        }, count: 2)); // initial [], when add 'bonjour!'.

    // this should be received.
    await instance.collection('messages').add({
      'content': 'hello!',
      'archived': false,
    });

    // this should not be received because of archived == true.
    await instance.collection('messages').add({
      'content': 'bonjour!',
      'archived': true,
    });

    // this should be received.
    await instance.collection('messages').add({
      'content': 'hola!',
      'archived': false,
    });

    // check new stream will receive the latest data.
    instance
        .collection('messages')
        .where('archived', isEqualTo: false)
        .snapshots()
        .listen(expectAsync1((snapshot) {
      expect(snapshot.docs.length, equals(2));
      for (final d in snapshot.docs) {
        expect(d.get('archived'), isFalse);
      }
    }));
  });

  test('Continuous data receive via stream with orderBy (asc and desc)',
      () async {
    final now = DateTime.now();
    final testData = <Map<String, dynamic>>[
      {'content': 'hello!', 'receivedAt': now, 'archived': false},
      {
        'content': 'bonjour!',
        'receivedAt': now.add(const Duration(seconds: 1)),
      },
      {
        'content': 'hola!',
        'receivedAt': now.subtract(const Duration(seconds: 1)),
      }
    ];

    final ascendingContents = [
      ['hello!'],
      ['hello!', 'bonjour!'],
      ['hola!', 'hello!', 'bonjour!'],
    ];

    final descendingContents = [
      ['hello!'],
      ['bonjour!', 'hello!'],
      ['bonjour!', 'hello!', 'hola!'],
    ];

    final instance = FakeFirebaseFirestore();
    var ascCalled = 0;
    instance
        .collection('messages')
        .orderBy('receivedAt')
        .snapshots()
        .listen(expectAsync1((snapshot) {
          final docs = snapshot.docs;
          try {
            if (ascCalled == 0) {
              expect(docs, isEmpty);
              return;
            } else {
              expect(docs.length, ascendingContents[ascCalled - 1].length);
            }
            for (var i = 0; i < docs.length; i++) {
              expect(
                docs[i].get('content'),
                equals(ascendingContents[ascCalled - 1][i]),
              );
            }
          } finally {
            ascCalled++;
          }
        }, count: testData.length + 1));
    var descCalled = 0;
    instance
        .collection('messages')
        .orderBy('receivedAt', descending: true)
        .snapshots()
        .listen(expectAsync1((snapshot) {
          final docs = snapshot.docs;
          try {
            if (descCalled == 0) {
              expect(docs, isEmpty);
              return;
            } else {
              expect(docs.length, descendingContents[descCalled - 1].length);
            }
            for (var i = 0; i < docs.length; i++) {
              expect(
                docs[i].get('content'),
                equals(descendingContents[descCalled - 1][i]),
              );
            }
          } finally {
            descCalled++;
          }
        }, count: testData.length + 1));

    await instance.collection('messages').add(testData[0]);
    await instance.collection('messages').add(testData[1]);
    await instance.collection('messages').add(testData[2]);
  });

  test('Continuous data receive via stream with orderBy and where', () async {
    final now = DateTime.now();
    final testData = <Map<String, dynamic>>[
      {'content': 'hello!', 'receivedAt': now, 'archived': false},
      {
        'content': 'bonjour!',
        'receivedAt': now.add(const Duration(seconds: 1)),
        'archived': true,
      },
      {
        'content': 'hola!',
        'receivedAt': now.subtract(const Duration(seconds: 1)),
        'archived': false,
      },
      {
        'content': 'Ciao!',
        'receivedAt': now.add(const Duration(seconds: 2)),
        'archived': false,
      },
    ];

    final unarchivedAscContents = [
      ['hello!'],
      ['hola!', 'hello!'],
      ['hola!', 'hello!', 'Ciao!'],
      ['hola!', 'hello!'],
      ['hello!'],
    ];

    final instance = FakeFirebaseFirestore();
    var called = 0;
    instance
        .collection('messages')
        .orderBy('receivedAt')
        .where('archived', isEqualTo: false)
        .snapshots()
        .listen(expectAsync1((snapshot) {
          final docs = snapshot.docs;
          try {
            if (called == 0) {
              expect(docs, isEmpty);
              return;
            } else {
              expect(docs.length, unarchivedAscContents[called - 1].length);
            }
            for (var i = 0; i < docs.length; i++) {
              expect(
                docs[i].get('content'),
                equals(unarchivedAscContents[called - 1][i]),
              );
            }
          } finally {
            called++;
          }
        }, count: unarchivedAscContents.length + 1));

    // add data
    await instance.collection('messages').add(testData[0]);
    await instance.collection('messages').add(testData[1]);
    final holaDoc = await instance.collection('messages').add(testData[2]);
    final chaoDoc = await instance.collection('messages').add(testData[3]);
    // update data
    await instance.collection('messages').doc(chaoDoc.id).update({
      'archived': true,
    });
    // delete data
    await instance.collection('messages').doc(holaDoc.id).delete();
  });

  test('Query to check metadata', () async {
    // Simple user data
    final testData = {'id': 22, 'username': 'Daniel', 'archived': false};

    final instance = FakeFirebaseFirestore();

    // add data to users collection
    await instance.collection('users').add(testData);

    // make the query
    final collectionReference = instance.collection('users');
    final query = collectionReference.where('username', isGreaterThan: 'B');

    // exec the query
    final snapshot = await query.get();

    // Checks that there is one value at least
    expect(snapshot.docs.length, greaterThan(0));

    // Checks that hasPendingWrites is false
    expect(snapshot.docs[0].metadata.hasPendingWrites, equals(false));

    // Checks that isFromCache is false
    expect(snapshot.docs[0].metadata.isFromCache, equals(false));
  });
  test('Query to check nested fields', () async {
    // Simple user data missing nested map
    final testData = {
      'id': 22,
      'reportBy': 'Ming',
      // 'user': {
      //   'name': 'Daniel',
      //   'age': 23,
      // },
    };

    final instance = FakeFirebaseFirestore();

    // add data to users collection
    await instance.collection('users').add(testData);

    // make the query
    final collectionReference = instance.collection('users');
    final query = collectionReference.where('user.age', isEqualTo: 18);

    // exec the query
    final snapshot = await query.get();

    // Checks that there is no docs returns
    expect(snapshot.docs.length, 0);
  });

  test('limitToLast', () async {
    final instance = FakeFirebaseFirestore();
    await instance.collection('cities').doc().set({'name': 'Chicago'});
    await instance.collection('cities').doc().set({'name': 'Los Angeles'});
    await instance.collection('cities').doc().set({'name': 'Springfield'});

    var baseQuery = instance.collection('cities').orderBy('name');

    var snapshots = await baseQuery.limitToLast(2).get();

    expect(snapshots.docs.toData(), [
      {'name': 'Los Angeles'},
      {'name': 'Springfield'}
    ]);

    snapshots = await baseQuery.limitToLast(1).get();

    expect(snapshots.docs.toData(), [
      {'name': 'Springfield'}
    ]);
  });

  test('orderBy', () async {
    final instance = FakeFirebaseFirestore();

    await instance.collection('cities').doc().set({
      'name': 'Los Angeles',
      'state': 'California',
    });

    await instance.collection('cities').doc().set({
      'name': 'Springfield',
      'state': 'Wisconsin',
    });

    await instance.collection('cities').doc().set({
      'name': 'Springfield',
      'state': 'Missouri',
    });

    await instance.collection('cities').doc().set({
      'name': 'Springfield',
      'state': 'Massachusetts',
    });

    await instance.collection('cities').doc().set({
      'name': 'Washington',
      'state': 'Washington',
    });

    final snapshots = await instance
        .collection('cities')
        .orderBy('name')
        .orderBy('state')
        .get();

    expect(snapshots.docs.toData(), [
      {
        'name': 'Los Angeles',
        'state': 'California',
      },
      {
        'name': 'Springfield',
        'state': 'Massachusetts',
      },
      {
        'name': 'Springfield',
        'state': 'Missouri',
      },
      {
        'name': 'Springfield',
        'state': 'Wisconsin',
      },
      {
        'name': 'Washington',
        'state': 'Washington',
      }
    ]);
  });

  test('startAt', () async {
    final instance = FakeFirebaseFirestore();

    await instance.collection('cities').doc().set({
      'name': 'Los Angeles',
      'state': 'California',
    });

    await instance.collection('cities').doc().set({
      'name': 'Springfield',
      'state': 'Wisconsin',
    });

    await instance.collection('cities').doc().set({
      'name': 'Springfield',
      'state': 'Missouri',
    });

    await instance.collection('cities').doc().set({
      'name': 'Springfield',
      'state': 'Massachusetts',
    });

    await instance.collection('cities').doc().set({
      'name': 'Washington',
      'state': 'Washington',
    });

    final baseQuery =
        instance.collection('cities').orderBy('name').orderBy('state');

    // should get everything because it is before any document in the DB
    var snapshots = await baseQuery.startAt(['Alaska']).get();

    expect(snapshots.docs.toData(), [
      {
        'name': 'Los Angeles',
        'state': 'California',
      },
      {
        'name': 'Springfield',
        'state': 'Massachusetts',
      },
      {
        'name': 'Springfield',
        'state': 'Missouri',
      },
      {
        'name': 'Springfield',
        'state': 'Wisconsin',
      },
      {
        'name': 'Washington',
        'state': 'Washington',
      }
    ]);

    snapshots = await baseQuery.startAt(['Springfield', 'Florida']).get();

    expect(snapshots.docs.toData(), [
      {
        'name': 'Springfield',
        'state': 'Massachusetts',
      },
      {
        'name': 'Springfield',
        'state': 'Missouri',
      },
      {
        'name': 'Springfield',
        'state': 'Wisconsin',
      },
      {
        'name': 'Washington',
        'state': 'Washington',
      }
    ]);

    snapshots = await baseQuery.startAt(['Springfield', 'Missouri']).get();

    expect(snapshots.docs.toData(), [
      {
        'name': 'Springfield',
        'state': 'Missouri',
      },
      {
        'name': 'Springfield',
        'state': 'Wisconsin',
      },
      {
        'name': 'Washington',
        'state': 'Washington',
      }
    ]);
    // should not get anything because wellington is alphabetically greater
    // than every document in db
    snapshots = await baseQuery.startAt(['Wellington']).get();
    expect(snapshots.docs.toData(), []);
  });

  test('endAt', () async {
    final instance = FakeFirebaseFirestore();

    await instance.collection('cities').doc().set({
      'name': 'Los Angeles',
      'state': 'California',
    });

    await instance.collection('cities').doc().set({
      'name': 'Springfield',
      'state': 'Wisconsin',
    });

    await instance.collection('cities').doc().set({
      'name': 'Springfield',
      'state': 'Missouri',
    });

    await instance.collection('cities').doc().set({
      'name': 'Springfield',
      'state': 'Massachusetts',
    });

    await instance.collection('cities').doc().set({
      'name': 'Washington',
      'state': 'Washington',
    });

    final baseQuery =
        instance.collection('cities').orderBy('name').orderBy('state');

    var snapshots = await baseQuery.endAt(['Arizona']).get();
    expect(snapshots.docs.toData(), []);

    snapshots = await baseQuery.endAt(['Springfield']).get();

    expect(snapshots.docs.toData(), [
      {
        'name': 'Los Angeles',
        'state': 'California',
      },
      {
        'name': 'Springfield',
        'state': 'Massachusetts',
      },
      {
        'name': 'Springfield',
        'state': 'Missouri',
      },
      {
        'name': 'Springfield',
        'state': 'Wisconsin',
      },
    ]);

    // Since there is no Springfield, Florida in our docs, it should ignore the second orderBy value
    snapshots = await baseQuery.endAt(['Springfield', 'Florida']).get();

    expect(snapshots.docs.toData(), [
      {
        'name': 'Los Angeles',
        'state': 'California',
      },
    ]);

    snapshots = await baseQuery.endAt(['Springfield', 'Missouri']).get();

    expect(snapshots.docs.toData(), [
      {
        'name': 'Los Angeles',
        'state': 'California',
      },
      {
        'name': 'Springfield',
        'state': 'Massachusetts',
      },
      {
        'name': 'Springfield',
        'state': 'Missouri',
      },
    ]);
    // should get everything because wellington is alphabetically greater
    // than every document in db
    snapshots = await baseQuery.endAt(['Wellington']).get();
    expect(snapshots.docs.toData(), [
      {
        'name': 'Los Angeles',
        'state': 'California',
      },
      {
        'name': 'Springfield',
        'state': 'Massachusetts',
      },
      {
        'name': 'Springfield',
        'state': 'Missouri',
      },
      {
        'name': 'Springfield',
        'state': 'Wisconsin',
      },
      {
        'name': 'Washington',
        'state': 'Washington',
      }
    ]);
  });

  test('startAt with converters', () async {
    final from = (snapshot, _) => Movie()..title = snapshot['title'];
    final to = (Movie movie, _) => {'title': movie.title};

    final firestore = FakeFirebaseFirestore();

    final moviesCollection = firestore
        .collection('movies')
        .withConverter(fromFirestore: from, toFirestore: to);
    await moviesCollection.add(Movie()..title = 'A long time ago');
    await moviesCollection.add(Movie()..title = 'Robot from the future');
    final searchResults =
        await moviesCollection.orderBy('title').startAt(['R']).get();
    expect(searchResults.size, equals(1));
    final movieFound = searchResults.docs.first.data();
    expect(movieFound.title, equals('Robot from the future'));
  });
}
