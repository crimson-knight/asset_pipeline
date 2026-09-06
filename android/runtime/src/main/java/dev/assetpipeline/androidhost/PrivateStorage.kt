package dev.assetpipeline.androidhost

import android.content.ContentValues
import android.content.Context
import android.database.DatabaseErrorHandler
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteDatabaseCorruptException
import android.database.sqlite.SQLiteOpenHelper
import android.os.Looper
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction

/** An ordinary app-private key/value store, NOT secrets or an ORM adapter.
 * SQLite access is serialized by CrystalServices, never performed on the UI thread.
 * A successful write/delete means the SQLite transaction has completed.
 */
class PrivateStorage(context: Context, name: String = "asset_pipeline_storage_v1.db") :
    SQLiteOpenHelper(context.applicationContext, name, null, 1, DatabaseErrorHandler {
        // Preserve corrupt files for explicit application recovery. Never run
        // the platform's default delete/recreate corruption handling here.
        throw SQLiteDatabaseCorruptException("App storage is corrupt; preserved for recovery")
    }) {
    init { require(name.matches(Regex("[A-Za-z0-9_-]+\\.db"))) { "Storage database name must be app-relative" } }
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE entries (key TEXT PRIMARY KEY NOT NULL, value BLOB NOT NULL)")
    }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        throw IllegalStateException("No storage schema migration registered")
    }
    override fun onConfigure(db: SQLiteDatabase) {
        db.execSQL("PRAGMA synchronous=FULL")
    }

    fun execute(operation: Int, keyBytes: ByteArray, value: ByteArray): ServiceReply {
        check(Looper.myLooper() != Looper.getMainLooper()) { "Storage must run off the main looper" }
        if (operation !in 1..3 || keyBytes.isEmpty() || keyBytes.size > 512 || value.size > 1_048_576) {
            return ServiceReply(ServiceStatus.INVALID_INPUT)
        }
        val decoder = Charsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT).onUnmappableCharacter(CodingErrorAction.REPORT)
        val key = try { decoder.decode(ByteBuffer.wrap(keyBytes)).toString() } catch (_: Exception) {
            return ServiceReply(ServiceStatus.INVALID_INPUT)
        }
        if (operation == 2) {
            try { decoder.reset().decode(ByteBuffer.wrap(value)) } catch (_: Exception) {
                return ServiceReply(ServiceStatus.INVALID_INPUT)
            }
        }
        val db = writableDatabase
        return when (operation) {
            1 -> db.query("entries", arrayOf("value"), "key = ?", arrayOf(key), null, null, null).use { cursor ->
                if (!cursor.moveToFirst()) ServiceReply(ServiceStatus.NOT_FOUND)
                else {
                    val bytes = cursor.getBlob(0)
                    if (bytes.size > 1_048_576) ServiceReply(ServiceStatus.IO) else try {
                        decoder.reset().decode(ByteBuffer.wrap(bytes))
                        ServiceReply(ServiceStatus.OK, bytes)
                    } catch (_: Exception) { ServiceReply(ServiceStatus.IO) }
                }
            }
            2 -> {
                val values = ContentValues().apply { put("key", key); put("value", value) }
                check(db.insertWithOnConflict("entries", null, values, SQLiteDatabase.CONFLICT_REPLACE) != -1L) { "Storage write failed" }
                ServiceReply(ServiceStatus.OK)
            }
            else -> { db.delete("entries", "key = ?", arrayOf(key)); ServiceReply(ServiceStatus.OK) }
        }
    }
}
