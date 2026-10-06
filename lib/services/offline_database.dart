import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class OfflineDatabase {
  OfflineDatabase._privateConstructor();

  static final OfflineDatabase instance =
  OfflineDatabase._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();

    return _database!;
  }

  // ============================================================
  // DATABASE INITIALIZATION
  // ============================================================

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();

    final path = join(
      databasesPath,
      'mednova_offline.db',
    );

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  // ============================================================
  // DATABASE UPGRADE
  // ============================================================

  Future<void> _upgradeDatabase(
      Database db,
      int oldVersion,
      int newVersion,
      ) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS offline_auth (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT NOT NULL UNIQUE,
          email TEXT NOT NULL UNIQUE,
          password_hash TEXT NOT NULL,
          last_login_at TEXT
        )
      ''');
    }
  }

  // ============================================================
  // CREATE DATABASE TABLES
  // ============================================================

  Future<void> _createDatabase(
      Database db,
      int version,
      ) async {
    // ----------------------------------------------------------
    // PROFILE
    // ----------------------------------------------------------

    await db.execute('''
      CREATE TABLE profiles (
        id TEXT PRIMARY KEY,
        full_name TEXT,
        email TEXT,
        phone TEXT,
        date_of_birth TEXT,
        gender TEXT,
        blood_group TEXT,
        allergies TEXT,
        current_medications TEXT,
        medical_conditions TEXT,
        medical_history TEXT,
        healthcare_provider TEXT,
        profile_photo_url TEXT,
        updated_at TEXT
      )
    ''');

    // ----------------------------------------------------------
    // OFFLINE AUTHENTICATION
    // ----------------------------------------------------------

    await db.execute('''
      CREATE TABLE offline_auth (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL UNIQUE,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        last_login_at TEXT
      )
    ''');

    // ----------------------------------------------------------
    // MEDICATIONS
    // ----------------------------------------------------------

    await db.execute('''
      CREATE TABLE medications (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        name TEXT,
        dosage TEXT,
        instruction TEXT,
        times TEXT,
        taken_index INTEGER,
        reminder_enabled INTEGER,
        start_date TEXT,
        duration_days INTEGER,
        end_date TEXT,
        created_at TEXT
      )
    ''');

    // ----------------------------------------------------------
    // MEDICATION DOSES
    // ----------------------------------------------------------

    await db.execute('''
      CREATE TABLE medication_doses (
        id TEXT PRIMARY KEY,
        medication_id TEXT,
        user_id TEXT,
        scheduled_date TEXT,
        scheduled_time TEXT,
        status TEXT,
        taken_at TEXT,
        created_at TEXT
      )
    ''');

    // ----------------------------------------------------------
    // APPOINTMENTS
    // ----------------------------------------------------------

    await db.execute('''
      CREATE TABLE appointments (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        title TEXT,
        hospital TEXT,
        doctor TEXT,
        date TEXT,
        time TEXT,
        upcoming INTEGER,
        created_at TEXT
      )
    ''');

    // ----------------------------------------------------------
    // REMINDERS
    // ----------------------------------------------------------

    await db.execute('''
      CREATE TABLE reminders (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        title TEXT,
        description TEXT,
        reminder_time TEXT,
        reminder_date TEXT,
        is_completed INTEGER,
        created_at TEXT
      )
    ''');

    // ----------------------------------------------------------
    // HEALTH FACILITIES
    // ----------------------------------------------------------

    await db.execute('''
      CREATE TABLE health_facilities (
        id INTEGER PRIMARY KEY,
        name TEXT,
        category TEXT,
        location TEXT,
        area TEXT,
        state TEXT,
        opening_hours TEXT,
        status TEXT,
        rating REAL,
        latitude REAL,
        longitude REAL,
        phone TEXT,
        ownership TEXT,
        created_at TEXT
      )
    ''');

    // ----------------------------------------------------------
    // MESSAGES
    // ----------------------------------------------------------

    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        sender_id TEXT,
        recipient_id TEXT,
        contact_name TEXT,
        contact_role TEXT,
        message TEXT,
        is_read INTEGER,
        created_at TEXT
      )
    ''');

    // ----------------------------------------------------------
    // SYNC QUEUE
    // ----------------------------------------------------------

    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        data TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  // ============================================================
  // OFFLINE AUTHENTICATION
  // ============================================================

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);

    return digest.toString();
  }

  Future<void> saveOfflineAuth({
    required String userId,
    required String email,
    required String password,
  }) async {
    final db = await database;

    final passwordHash = _hashPassword(password);

    await db.insert(
      'offline_auth',
      {
        'user_id': userId,
        'email': email.toLowerCase().trim(),
        'password_hash': passwordHash,
        'last_login_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getOfflineAuth(
      String email,
      ) async {
    final db = await database;

    final result = await db.query(
      'offline_auth',
      where: 'email = ?',
      whereArgs: [
        email.toLowerCase().trim(),
      ],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first;
  }

  Future<bool> verifyOfflineLogin({
    required String email,
    required String password,
  }) async {
    final auth = await getOfflineAuth(email);

    if (auth == null) {
      return false;
    }

    final passwordHash = _hashPassword(password);

    return auth['password_hash'] == passwordHash;
  }

  Future<void> updateOfflineLoginTime(
      String email,
      ) async {
    final db = await database;

    await db.update(
      'offline_auth',
      {
        'last_login_at': DateTime.now().toIso8601String(),
      },
      where: 'email = ?',
      whereArgs: [
        email.toLowerCase().trim(),
      ],
    );
  }

  Future<void> deleteOfflineAuth(
      String userId,
      ) async {
    final db = await database;

    await db.delete(
      'offline_auth',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Future<void> saveProfile(
      Map<String, dynamic> profile,
      ) async {
    final db = await database;

    await db.insert(
      'profiles',
      {
        'id': profile['id'],
        'full_name': profile['full_name'],
        'email': profile['email'],
        'phone': profile['phone'],
        'date_of_birth': profile['date_of_birth'],
        'gender': profile['gender'],
        'blood_group': profile['blood_group'],
        'allergies': profile['allergies'],
        'current_medications': profile['current_medications'],
        'medical_conditions': profile['medical_conditions'],
        'medical_history': profile['medical_history'],
        'healthcare_provider': profile['healthcare_provider'],
        'profile_photo_url': profile['profile_photo_url'],
        'updated_at': profile['updated_at'],
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getProfile(
      String userId,
      ) async {
    final db = await database;

    final result = await db.query(
      'profiles',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first;
  }

  // ============================================================
  // MEDICATIONS
  // ============================================================

  Future<void> saveMedication(
      Map<String, dynamic> medication,
      ) async {
    final db = await database;

    await db.insert(
      'medications',
      {
        'id': medication['id'],
        'user_id': medication['user_id'],
        'name': medication['name'],
        'dosage': medication['dosage'],
        'instruction': medication['instruction'],
        'times': medication['times']?.toString(),
        'taken_index': medication['taken_index'],
        'reminder_enabled':
        medication['reminder_enabled'] == true ? 1 : 0,
        'start_date':
        medication['start_date']?.toString(),
        'duration_days':
        medication['duration_days'],
        'end_date':
        medication['end_date']?.toString(),
        'created_at':
        medication['created_at']?.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getMedications(
      String userId,
      ) async {
    final db = await database;

    return await db.query(
      'medications',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> deleteMedication(
      String medicationId,
      ) async {
    final db = await database;

    await db.delete(
      'medications',
      where: 'id = ?',
      whereArgs: [medicationId],
    );
  }

  // ============================================================
  // MEDICATION DOSES
  // ============================================================

  Future<void> saveMedicationDose(
      Map<String, dynamic> dose,
      ) async {
    final db = await database;

    await db.insert(
      'medication_doses',
      {
        'id': dose['id'],
        'medication_id':
        dose['medication_id'],
        'user_id':
        dose['user_id'],
        'scheduled_date':
        dose['scheduled_date']?.toString(),
        'scheduled_time':
        dose['scheduled_time']?.toString(),
        'status':
        dose['status'],
        'taken_at':
        dose['taken_at']?.toString(),
        'created_at':
        dose['created_at']?.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getMedicationDoses(
      String userId,
      ) async {
    final db = await database;

    return await db.query(
      'medication_doses',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'scheduled_date ASC',
    );
  }

  // ============================================================
  // APPOINTMENTS
  // ============================================================

  Future<void> saveAppointment(
      Map<String, dynamic> appointment,
      ) async {
    final db = await database;

    await db.insert(
      'appointments',
      {
        'id': appointment['id'],
        'user_id': appointment['user_id'],
        'title': appointment['title'],
        'hospital': appointment['hospital'],
        'doctor': appointment['doctor'],
        'date': appointment['date'],
        'time': appointment['time'],
        'upcoming':
        appointment['upcoming'] == true ? 1 : 0,
        'created_at':
        appointment['created_at']?.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAppointments(
      String userId,
      ) async {
    final db = await database;

    return await db.query(
      'appointments',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> deleteAppointment(
      String appointmentId,
      ) async {
    final db = await database;

    await db.delete(
      'appointments',
      where: 'id = ?',
      whereArgs: [appointmentId],
    );
  }

  // ============================================================
  // REMINDERS
  // ============================================================

  Future<void> saveReminder(
      Map<String, dynamic> reminder,
      ) async {
    final db = await database;

    await db.insert(
      'reminders',
      {
        'id': reminder['id'],
        'user_id': reminder['user_id'],
        'title': reminder['title'],
        'description':
        reminder['description'],
        'reminder_time':
        reminder['reminder_time']?.toString(),
        'reminder_date':
        reminder['reminder_date']?.toString(),
        'is_completed':
        reminder['is_completed'] == true ? 1 : 0,
        'created_at':
        reminder['created_at']?.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getReminders(
      String userId,
      ) async {
    final db = await database;

    return await db.query(
      'reminders',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  // ============================================================
  // HEALTH FACILITIES
  // ============================================================

  Future<void> saveHealthFacility(
      Map<String, dynamic> facility,
      ) async {
    final db = await database;

    await db.insert(
      'health_facilities',
      {
        'id': facility['id'],
        'name': facility['name'],
        'category': facility['category'],
        'location': facility['location'],
        'area': facility['area'],
        'state': facility['state'],
        'opening_hours':
        facility['opening_hours'],
        'status': facility['status'],
        'rating': facility['rating'],
        'latitude': facility['latitude'],
        'longitude': facility['longitude'],
        'phone': facility['phone'],
        'ownership': facility['ownership'],
        'created_at':
        facility['created_at']?.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getHealthFacilities() async {
    final db = await database;

    return await db.query(
      'health_facilities',
      orderBy: 'name ASC',
    );
  }

  // ============================================================
  // MESSAGES
  // ============================================================

  Future<void> saveMessage(
      Map<String, dynamic> message,
      ) async {
    final db = await database;

    await db.insert(
      'messages',
      {
        'id': message['id'],
        'sender_id':
        message['sender_id'],
        'recipient_id':
        message['recipient_id'],
        'contact_name':
        message['contact_name'],
        'contact_role':
        message['contact_role'],
        'message':
        message['message'],
        'is_read':
        message['is_read'] == true ? 1 : 0,
        'created_at':
        message['created_at']?.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getMessages(
      String userId,
      ) async {
    final db = await database;

    return await db.query(
      'messages',
      where: 'sender_id = ? OR recipient_id = ?',
      whereArgs: [
        userId,
        userId,
      ],
      orderBy: 'created_at ASC',
    );
  }

  // ============================================================
  // SYNC QUEUE
  // ============================================================

  Future<void> addToSyncQueue({
    required String tableName,
    required String recordId,
    required String operation,
    String? data,
  }) async {
    final db = await database;

    await db.insert(
      'sync_queue',
      {
        'table_name': tableName,
        'record_id': recordId,
        'operation': operation,
        'data': data,
        'created_at':
        DateTime.now().toIso8601String(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final db = await database;

    return await db.query(
      'sync_queue',
      orderBy: 'created_at ASC',
    );
  }

  Future<void> removeFromSyncQueue(
      int id,
      ) async {
    final db = await database;

    await db.delete(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================
  // CLEAR LOCAL DATA
  // ============================================================

  Future<void> clearUserData(
      String userId,
      ) async {
    final db = await database;

    await db.delete(
      'profiles',
      where: 'id = ?',
      whereArgs: [userId],
    );

    await db.delete(
      'medications',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    await db.delete(
      'medication_doses',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    await db.delete(
      'appointments',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    await db.delete(
      'reminders',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    await db.delete(
      'messages',
      where: 'sender_id = ? OR recipient_id = ?',
      whereArgs: [
        userId,
        userId,
      ],
    );

    await db.delete(
      'offline_auth',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // ============================================================
  // CLOSE DATABASE
  // ============================================================

  Future<void> close() async {
    final db = await database;

    await db.close();

    _database = null;
  }
}