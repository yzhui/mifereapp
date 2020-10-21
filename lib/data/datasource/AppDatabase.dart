
import 'package:path/path.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sqflite/sqflite.dart';
import 'package:todo_app/domain/entity/Category.dart';
import 'package:todo_app/domain/entity/CheckPoint.dart';
import 'package:todo_app/domain/entity/DateInWeek.dart';
import 'package:todo_app/domain/entity/DayMemo.dart';
import 'package:todo_app/domain/entity/Pet.dart';
import 'package:todo_app/domain/entity/Pets.dart';
import 'package:todo_app/domain/entity/ToDo.dart';

class AppDatabase {
  static const String TABLE_CHECK_POINTS = 'checkpoints';
  static const String TABLE_TODOS = 'todos';
  static const String TABLE_DAY_MEMOS = 'daymemos';
  static const String TABLE_CATEGORIES = 'categories';
  static const String TABLE_MARKED_COMPLETED_DAYS = 'marked_completed_days';
  static const String TABLE_PET_USER_DATUM = 'pet_user_datum';
  static const String TABLE_THUMBED_UP_UIDS = 'thumbed_up_uids';

  static const String COLUMN_ID = '_id';
  static const String COLUMN_YEAR = 'year';
  static const String COLUMN_MONTH = 'month';
  static const String COLUMN_DAY = 'day';
  static const String COLUMN_NTH_WEEK = 'nth_week';
  static const String COLUMN_INDEX = '_index';
  static const String COLUMN_ORDER = '_order';
  static const String COLUMN_TEXT = 'text';
  static const String COLUMN_HINT = 'hint';
  static const String COLUMN_DONE = 'done';
  static const String COLUMN_EXPANDED = 'expanded';
  static const String COLUMN_NAME = 'name';
  static const String COLUMN_FILL_COLOR = 'fill_color';
  static const String COLUMN_BORDER_COLOR = 'border_color';
  static const String COLUMN_IMAGE_PATH = 'image_path';
  static const String COLUMN_CATEGORY_ID = 'category_id';
  static const String COLUMN_MILLIS_SINCE_EPOCH = 'millis_since_epoch';
  static const String COLUMN_STREAK_COUNT = 'streak_count';
  static const String COLUMN_KEY = '_key';
  static const String COLUMN_EXP = 'exp';
  static const String COLUMN_SELECTED_PHASE = 'selected_phase';
  static const String COLUMN_UID = '_uid';

  // ignore: close_sinks
  final _database = BehaviorSubject<Database>();

  AppDatabase() {
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    final dbPath = join(await getDatabasesPath(), 'todo5.db');
    _database.value = await openDatabase(
      dbPath,
      onCreate: (db, version) async {
        await db.execute(
          """
          CREATE TABLE $TABLE_CHECK_POINTS(
            $COLUMN_YEAR INTEGER NOT NULL,
            $COLUMN_MONTH INTEGER NOT NULL,
            $COLUMN_NTH_WEEK INTEGER NOT NULL,
            $COLUMN_INDEX INTEGER NOT NULL,
            $COLUMN_TEXT TEXT NOT NULL,
            $COLUMN_HINT TEXT NOT NULL,
            PRIMARY KEY ($COLUMN_YEAR, $COLUMN_MONTH, $COLUMN_NTH_WEEK, $COLUMN_INDEX)
          );
          """
        );
        await db.execute(
          """
          CREATE TABLE $TABLE_TODOS(
            $COLUMN_YEAR INTEGER NOT NULL,
            $COLUMN_MONTH INTEGER NOT NULL,
            $COLUMN_DAY INTEGER NOT NULL,
            $COLUMN_ORDER INTEGER NOT NULL,
            $COLUMN_TEXT TEXT NOT NULL,
            $COLUMN_DONE INTEGER NOT NULL,
            $COLUMN_CATEGORY_ID INTEGER NOT NULL,
            PRIMARY KEY ($COLUMN_YEAR, $COLUMN_MONTH, $COLUMN_DAY, $COLUMN_ORDER)
          );
          """
        );
        await db.execute(
          """
          CREATE TABLE $TABLE_CATEGORIES(
            $COLUMN_ID INTEGER PRIMARY KEY AUTOINCREMENT,
            $COLUMN_NAME TEXT NOT NULL,
            $COLUMN_FILL_COLOR INTEGER NOT NULL,
            $COLUMN_BORDER_COLOR INTEGER NOT NULL,
            $COLUMN_IMAGE_PATH TEXT NOT NULL
          );
          """
        );
        await db.execute(
          """
          CREATE TABLE $TABLE_MARKED_COMPLETED_DAYS(
            $COLUMN_YEAR INTEGER NOT NULL,
            $COLUMN_MONTH INTEGER NOT NULL,
            $COLUMN_DAY INTEGER NOT NULL,
            $COLUMN_MILLIS_SINCE_EPOCH INTEGER NOT NULL,
            $COLUMN_STREAK_COUNT INTEGER NOT NULL,
            PRIMARY KEY ($COLUMN_YEAR, $COLUMN_MONTH, $COLUMN_DAY)
          );
          """
        );
        await db.execute(
          """
          CREATE TABLE $TABLE_PET_USER_DATUM(
            $COLUMN_KEY TEXT NOT NULL PRIMARY KEY,
            $COLUMN_EXP INTEGER NOT NULL,
            $COLUMN_SELECTED_PHASE INTEGER NOT NULL
           );
           """
        );
        await db.execute(
          """
          CREATE TABLE $TABLE_THUMBED_UP_UIDS(
            $COLUMN_UID TEXT NOT NULL PRIMARY KEY
          );
          """
        );
        return db.execute(
          """
          CREATE TABLE $TABLE_DAY_MEMOS(
            $COLUMN_YEAR INTEGER NOT NULL,
            $COLUMN_MONTH INTEGER NOT NULL,
            $COLUMN_DAY INTEGER NOT NULL,
            $COLUMN_TEXT TEXT NOT NULL,
            $COLUMN_HINT TEXT NOT NULL,
            $COLUMN_EXPANDED INTEGER NOT NULL,
            PRIMARY KEY ($COLUMN_YEAR, $COLUMN_MONTH, $COLUMN_DAY)
          );
          """
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion == 1 && newVersion == 2) {
          return db.execute('DROP TABLE IF EXISTS locks');
        } else if (oldVersion == 2 && newVersion == 3) {
          await db.execute(
          """
          CREATE TABLE $TABLE_MARKED_COMPLETED_DAYS(
            $COLUMN_YEAR INTEGER NOT NULL,
            $COLUMN_MONTH INTEGER NOT NULL,
            $COLUMN_DAY INTEGER NOT NULL,
            $COLUMN_MILLIS_SINCE_EPOCH INTEGER NOT NULL,
            $COLUMN_STREAK_COUNT INTEGER NOT NULL,
            PRIMARY KEY ($COLUMN_YEAR, $COLUMN_MONTH, $COLUMN_DAY)
          );
          """
          );
          await db.execute(
            """
          CREATE TABLE $TABLE_PET_USER_DATUM(
            $COLUMN_KEY TEXT NOT NULL PRIMARY KEY,
            $COLUMN_EXP INTEGER NOT NULL,
            $COLUMN_SELECTED_PHASE INTEGER NOT NULL
          );
          """
          );
          return db.execute(
            """
          CREATE TABLE $TABLE_THUMBED_UP_UIDS(
            $COLUMN_UID TEXT NOT NULL PRIMARY KEY
          );
          """
          );
        } else {
          return null;
        }
      },
      onDowngrade: (db, oldVersion, newVersion) async {
        if (oldVersion == 5 && newVersion == 3) {
          await db.execute(
            """
          CREATE TABLE $TABLE_MARKED_COMPLETED_DAYS(
            $COLUMN_YEAR INTEGER NOT NULL,
            $COLUMN_MONTH INTEGER NOT NULL,
            $COLUMN_DAY INTEGER NOT NULL,
            $COLUMN_MILLIS_SINCE_EPOCH INTEGER NOT NULL,
            $COLUMN_STREAK_COUNT INTEGER NOT NULL,
            PRIMARY KEY ($COLUMN_YEAR, $COLUMN_MONTH, $COLUMN_DAY)
          );
          """
          );
          await db.execute(
            """
          CREATE TABLE $TABLE_PET_USER_DATUM(
            $COLUMN_KEY TEXT NOT NULL PRIMARY KEY,
            $COLUMN_EXP INTEGER NOT NULL,
            $COLUMN_SELECTED_PHASE INTEGER NOT NULL
          );
          """
          );
          return db.execute(
            """
          CREATE TABLE $TABLE_THUMBED_UP_UIDS(
            $COLUMN_UID TEXT NOT NULL PRIMARY KEY
          );
          """
          );
        }
      },
      version: 3,
    );
  }

  Future<List<ToDo>> getToDos(DateTime date) async {
    final db = await _database.first;
    final List<Map<String, dynamic>> maps = await db.query(
      TABLE_TODOS,
      where: ToDo.createWhereQueryForToDos(),
      whereArgs: ToDo.createWhereArgsForToDos(date),
    );

    return maps.map((map) => ToDo.fromDatabase(map)).toList()
      ..sort((a, b) => a.order - b.order);
  }

  Future<void> setToDo(ToDo toDo) async {
    final db = await _database.first;
    return db.insert(
      TABLE_TODOS,
      toDo.toDatabase(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeToDo(ToDo toDo) async {
    final db = await _database.first;
    return db.delete(
      TABLE_TODOS,
      where: ToDo.createWhereQueryForToDo(),
      whereArgs: ToDo.createWhereArgsForToDo(toDo),
    );
  }

  Future<void> setDayMarkedCompleted(DateTime date) async {
    final year = date.year;
    final month = date.month;
    final day = date.day;
    final millis = date.millisecondsSinceEpoch;
    final prevDayStreak = await getStreakCount(date.subtract(const Duration(days: 1)));
    final db = await _database.first;

    return db.insert(
      TABLE_MARKED_COMPLETED_DAYS,
      {
        COLUMN_YEAR: year,
        COLUMN_MONTH: month,
        COLUMN_DAY: day,
        COLUMN_MILLIS_SINCE_EPOCH: millis,
        COLUMN_STREAK_COUNT: prevDayStreak + 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getMarkedCompletedDaysCount() async {
    final db = await _database.first;
    return Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM $TABLE_MARKED_COMPLETED_DAYS'
    ));
  }

  Future<int> getLatestStreakCount() async {
    final db = await _database.first;
    final maps = await db.query(
      TABLE_MARKED_COMPLETED_DAYS,
      orderBy: '$COLUMN_MILLIS_SINCE_EPOCH DESC',
      limit: 1,
    );
    return maps.isEmpty ? 0 : maps[0][COLUMN_STREAK_COUNT] ?? 0;
  }

  Future<int> getLatestStreakEndMillis() async {
    final db = await _database.first;
    final maps = await db.query(
      TABLE_MARKED_COMPLETED_DAYS,
      orderBy: '$COLUMN_MILLIS_SINCE_EPOCH DESC',
      limit: 1,
    );
    return maps.isEmpty ? 0 : maps[0][COLUMN_MILLIS_SINCE_EPOCH] ?? 0;
  }

  Future<int> getLongestStreakCount() async {
    final db = await _database.first;
    final maps = await db.query(
      TABLE_MARKED_COMPLETED_DAYS,
      orderBy: '$COLUMN_STREAK_COUNT DESC',
      limit: 1,
    );
    return maps.isEmpty ? 0 : maps[0][COLUMN_STREAK_COUNT] ?? 0;
  }

  Future<int> getLongestStreakEndMillis() async {
    final db = await _database.first;
    final maps = await db.query(
      TABLE_MARKED_COMPLETED_DAYS,
      orderBy: '$COLUMN_STREAK_COUNT DESC',
      limit: 1,
    );
    return maps.isEmpty ? 0 : maps[0][COLUMN_MILLIS_SINCE_EPOCH] ?? 0;
  }

  Future<int> getStreakCount(DateTime date) async {
    final year = date.year;
    final month = date.month;
    final day = date.day;
    final db = await _database.first;

    final maps = await db.query(
      TABLE_MARKED_COMPLETED_DAYS,
      where: '$COLUMN_YEAR = ? AND $COLUMN_MONTH = ? AND $COLUMN_DAY = ?',
      whereArgs: [year, month, day],
    );

    return maps.isEmpty ? 0 : maps[0][COLUMN_STREAK_COUNT] ?? 0;
  }

  Future<bool> isDayMarkedCompleted(DateTime date) async {
    final year = date.year;
    final month = date.month;
    final day = date.day;
    final db = await _database.first;

    final maps = await db.query(
      TABLE_MARKED_COMPLETED_DAYS,
      where: '$COLUMN_YEAR = ? AND $COLUMN_MONTH = ? AND $COLUMN_DAY = ?',
      whereArgs: [year, month, day],
    );
    return maps.isNotEmpty;
  }

  Future<int> getLastMarkedCompletedDayMillis(int maxMillis) async {
    final db = await _database.first;

    final maps = await db.query(
      TABLE_MARKED_COMPLETED_DAYS,
      where: '$COLUMN_MILLIS_SINCE_EPOCH <= ?',
      whereArgs: [maxMillis],
      orderBy: '$COLUMN_MILLIS_SINCE_EPOCH DESC',
      limit: 1,
    );
    return maps.isEmpty ? 0 : maps[0][COLUMN_MILLIS_SINCE_EPOCH] ?? 0;
  }

  Future<List<CheckPoint>> getCheckPoints(DateTime date) async {
    final db = await _database.first;
    final dateInWeek = DateInWeek.fromDate(date);
    final List<CheckPoint> checkPoints = [
      CheckPoint(year: dateInWeek.year, month: dateInWeek.month, nthWeek: dateInWeek.nthWeek, index: 0),
      CheckPoint(year: dateInWeek.year, month: dateInWeek.month, nthWeek: dateInWeek.nthWeek, index: 1),
      CheckPoint(year: dateInWeek.year, month: dateInWeek.month, nthWeek: dateInWeek.nthWeek, index: 2),
    ];
    final List<Map<String, dynamic>> maps = await db.query(
      TABLE_CHECK_POINTS,
      where: CheckPoint.createWhereQueryForCheckPoints(),
      whereArgs: CheckPoint.createWhereArgsForCheckPoints(dateInWeek),
    );
    maps.forEach((map) {
      final index = map[COLUMN_INDEX];
      checkPoints[index] = checkPoints[index].buildNew(text: map[COLUMN_TEXT]);
    });

    return checkPoints;
  }

  Future<void> setCheckPoint(CheckPoint checkPoint) async {
    final db = await _database.first;
    return db.insert(
      TABLE_CHECK_POINTS,
      checkPoint.toDatabase(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DayMemo> getDayMemo(DateTime date) async {
    final db = await _database.first;
    final Map<String, dynamic> map = await db.query(
      TABLE_DAY_MEMOS,
      where: DayMemo.createWhereQuery(),
      whereArgs: DayMemo.createWhereArgs(date),
    ).then((l) => l.isEmpty ? null : l[0]);
    return map != null ? DayMemo.fromDatabase(map)
      : DayMemo(year: date.year, month: date.month, day: date.day);
  }

  Future<void> setDayMemo(DayMemo dayMemo) async {
    final db = await _database.first;
    return db.insert(
      TABLE_DAY_MEMOS,
      dayMemo.toDatabase(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Category> getCategory(int id) async {
    final db = await _database.first;
    Map<String, dynamic> map = await db.query(
      TABLE_CATEGORIES,
      where: Category.createWhereQuery(),
      whereArgs: Category.createWhereArgs(id),
    ).then((l) => l.isEmpty ? null : l[0]);
    return map != null ? Category.fromDatabase(map) : Category();
  }

  Future<List<Category>> getAllCategories() async {
    final db = await _database.first;
    List<Map<String, dynamic>> maps = await db.query(
      TABLE_CATEGORIES
    );
    final List<Category> result = [];
    // add one default category cause we don't save it in DB
    result.add(Category());
    for (int i = 0; i < maps.length; i++) {
      final category = Category.fromDatabase(maps[i]);
      result.add(category);
    }
    result.sort((a, b) => a.id - b.id);
    return result;
  }

  Future<int> setCategory(Category category) async {
    if (category.id == Category.ID_DEFAULT) {
      return Category.ID_DEFAULT;
    } else {
      final db = await _database.first;
      return db.insert(
        TABLE_CATEGORIES,
        category.toDatabase(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> removeCategory(Category category) async {
    final db = await _database.first;
    return db.delete(
      TABLE_CATEGORIES,
      where: Category.createWhereQuery(),
      whereArgs: Category.createWhereArgs(category.id),
    );
  }

  Future<List<Pet>> getAllPets() async {
    final pets = Pets.getPetPrototypes();
    final db = await _database.first;

    List<Map<String, dynamic>> maps = await db.query(TABLE_PET_USER_DATUM);
    for (Map<String, dynamic> entry in maps) {
      final key = entry[COLUMN_KEY];
      final index = pets.indexWhere((it) => it.key == key);
      if (index >= 0) {
        // fill with user data
        pets[index] = pets[index].buildNew(
          exp: entry[COLUMN_EXP],
          currentPhaseIndex: entry[COLUMN_SELECTED_PHASE],
        );
      }
    }

    return pets;
  }

  Future<void> setPet(Pet pet) async {
    final db = await _database.first;
    return db.insert(
      TABLE_PET_USER_DATUM,
      pet.toUserDatumDatabase(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Pet> getPet(String key) async {
    final pet = Pets.getPetPrototype(key);
    if (!pet.isValid) {
      return pet;
    }

    final db = await _database.first;
    List<Map<String, dynamic>> maps = await db.query(
      TABLE_PET_USER_DATUM,
      where: '$COLUMN_KEY = ?',
      whereArgs: [key],
    );
    if (maps.isEmpty) {
      return pet;
    } else {
      final map = maps[0];
      return pet.buildNew(
        exp: map[COLUMN_EXP],
        currentPhaseIndex: map[COLUMN_SELECTED_PHASE],
      );
    }
  }

  Future<void> addThumbedUpUid(String uid) async {
    final db = await _database.first;
    return db.insert(
      TABLE_THUMBED_UP_UIDS,
      { COLUMN_UID: uid },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeThumbedUpUid(String uid) async {
    final db = await _database.first;
    return db.delete(
      TABLE_THUMBED_UP_UIDS,
      where: '$COLUMN_UID = ?',
      whereArgs: [uid]
    );
  }

  Future<bool> isThumbedUpUid(String uid) async {
    final db = await _database.first;
    final map = await db.query(
      TABLE_THUMBED_UP_UIDS,
      where: '$COLUMN_UID = ?',
      whereArgs: [uid],
    );
    return map.isNotEmpty;
  }
}