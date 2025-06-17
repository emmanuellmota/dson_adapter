// ignore_for_file: avoid_print

import 'dart:developer';

import 'package:dson_adapter/dson_adapter.dart';
import 'package:dson_adapter/src/extensions/iterable_extension.dart';

void main() {
  final jsonMap = {
    'id': 1,
    'name': 'MyHome',
    'owner': {
      'id': 1,
      'name': 'Joshua',
      'last_name': 'Clak',
      'age': 3,
      'profile': 'NON_PARENTS',
    },
    'parents': [
      {
        'id': 2,
        'name': 'Kepper',
        'last_name': 'Clak',
        'age': 25,
        'profile': 'PARENTS',
        'account': {
          'id': 0,
        },
      },
      {
        'id': 3,
        'name': 'Douglas',
        'last_name': 'Bisserra',
        'age': 23,
        'account': {
          'id': 1,
        },
      },
    ],
    'create_date': '2024-06-16',
    'updated_date': '2024-06-16',
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

  final aliases = {
    Home: {
      'createDate': 'create_date',
    },
    Person: {
      'surname': 'last_name',
    },
  };

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
    aliases: aliases,
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

  final map = home.toMap(propNameConverter: toKebabCase);
  final json = home.toJson(aliases: aliases);
  final str = home.toString();

  final copy = home.copyWith((_, __) {});
  final isEquals = home.equals(copy);

  final updated3 = home.copyWith((set, e) {
    set(e.id, 3);
    set(e.name, 'MyCustomHome3');
    set(e.owner, e.owner.copyWith((set, o) {
      set(o.name, 'Myself');
    }));
  });

  final isEqualsUpdate = home.equals(updated3);

  log(json);

  print(home);
}

enum Profile implements SerializableEnum {
  parents('PARENTS'),
  nonParents('NON_PARENTS');

  @override
  final String name;

  const Profile(this.name);
}

class Home extends Serializable {
  final int id;
  final String name;
  final Person owner;
  final List<Person> parents;
  final Map<String, dynamic> meta;
  final DateTime createDate;
  final DateTime updatedDate;

  Home({
    required this.id,
    required this.name,
    required this.owner,
    required this.parents,
    this.meta = const {},
    required this.createDate,
    required this.updatedDate,
  });
}

class Person extends Serializable {
  final int id;
  final String? name;
  final String? surname;
  final int age;
  final Profile profile;
  final Account? account;

  Person({
    required this.id,
    this.name,
    this.surname,
    this.age = 20,
    this.profile = Profile.nonParents,
    this.account,
  });
}

class Account extends Serializable {
  final int id;

  Account({
    required this.id,
  });
}
