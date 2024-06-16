// ignore_for_file: avoid_print

import 'package:dson_adapter/dson_adapter.dart';
import 'package:dson_adapter/src/extensions/iterable_extension.dart';

void main() {
  final jsonMap = {
    'id': 1,
    'name': 'MyHome',
    'owner': {
      'id': 1,
      'name': 'Joshua Clak',
      'age': 3,
      'profile': 'PARENTS',
    },
    'parents': [
      {
        'id': 2,
        'name': 'Kepper Clak',
        'age': 25,
        'profile': 'PARENTS',
        'account': {
          'id': 0,
        },
      },
      {
        'id': 3,
        'name': 'Douglas Bisserra',
        'age': 23,
        'account': {
          'id': 1,
        },
      },
    ],
    'create_date': '2024-06-16',
    'meta': {
      'neghborhood': 'MyHome',
    },
  };

  final commonResolvers = [
    (key, value, type) {
      if (type == (DateTime).toString()) {
        value = DateTime.parse(value);
      }

      return value;
    }
  ];

  final home = DSON(resolvers: commonResolvers).fromJson<Home>(
    // json Map or List
    jsonMap,
    // Main constructor
    Home.new,
    // external types
    inner: {
      'owner': Person.new,
      'parents': ListParam<Person>(Person.new),
      'account': Account.new,
    },
    aliases: {
      Home: {'createDate': 'create_date'},
    },
    resolvers: [
      (key, value, type) {
        if (key == 'profile') {
          value = Profile.values
              .firstWhereOrNull((profile) => profile.name == value);
        }

        return value;
      }
    ],
  );

  print(home);
}

enum Profile {
  parents('PARENTS'),
  nonParents('NON_PARENTS');

  final String name;

  const Profile(this.name);
}

class Home {
  final int id;
  final String name;
  final Person owner;
  final List<Person> parents;
  final Map<String, dynamic> meta;
  final DateTime createDate;

  Home({
    required this.id,
    required this.name,
    required this.owner,
    required this.parents,
    this.meta = const {},
    required this.createDate,
  });
}

class Person {
  final int id;
  final String? name;
  final int age;
  final Profile profile;
  final Account? account;

  Person({
    required this.id,
    this.name,
    this.age = 20,
    this.profile = Profile.nonParents,
    this.account,
  });
}

class Account {
  final int id;

  Account({
    required this.id,
  });
}
