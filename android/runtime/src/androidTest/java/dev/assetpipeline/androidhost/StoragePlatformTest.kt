package dev.assetpipeline.androidhost

import android.content.Context
import android.os.Looper
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

@RunWith(AndroidJUnit4::class)
class StoragePlatformTest {
    @Test fun corruptDatabaseIsNotDeletedOrReplacedOnOpen() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val name = "ap_corrupt_contract_${UUID.randomUUID()}.db"
        val file = context.getDatabasePath(name)
        val original = "damaged-storage-preserve-for-recovery".repeat(128).toByteArray()
        val worker = Executors.newSingleThreadExecutor()
        try {
            worker.submit {
                requireNotNull(file.parentFile).mkdirs()
                file.writeBytes(original)
                PrivateStorage(context, name).use { store ->
                    assertThrows(android.database.sqlite.SQLiteException::class.java) { store.execute(1, "key".toByteArray(), byteArrayOf()) }
                }
                assertTrue("Corrupt store must remain available for recovery", file.exists())
                assertArrayEquals(original, file.readBytes())
            }.get(10, TimeUnit.SECONDS)
        } finally {
            worker.shutdown()
            assertTrue(worker.awaitTermination(10, TimeUnit.SECONDS))
            context.deleteDatabase(name)
        }
    }

    @Test fun appPrivateDatabaseIsDurableAndRejectsInvalidDataWithoutReplacingIt() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val name = "ap_contract_${UUID.randomUUID()}.db"
        val worker = Executors.newSingleThreadExecutor()
        try {
            worker.submit {
                assertNotEquals(Looper.getMainLooper(), Looper.myLooper())
                val key = "key/雪/😀\u0000end".toByteArray(Charsets.UTF_8)
                val value = "before\u0000after café 雪 😀".toByteArray(Charsets.UTF_8)
                PrivateStorage(context, name).use { store ->
                    assertEquals(ServiceStatus.NOT_FOUND, store.execute(1, key, byteArrayOf()).status)
                    assertEquals(ServiceStatus.OK, store.execute(2, key, value).status)
                    assertArrayEquals(value, store.execute(1, key, byteArrayOf()).data)
                    assertEquals(ServiceStatus.INVALID_INPUT, store.execute(2, key, byteArrayOf(0xff.toByte())).status)
                    assertArrayEquals(value, store.execute(1, key, byteArrayOf()).data)
                    assertEquals(ServiceStatus.INVALID_INPUT, store.execute(1, byteArrayOf(), byteArrayOf()).status)
                    assertEquals(ServiceStatus.INVALID_INPUT, store.execute(2, key, ByteArray(1_048_577)).status)
                }
                PrivateStorage(context, name).use { reopened ->
                    assertArrayEquals(value, reopened.execute(1, key, byteArrayOf()).data)
                    assertEquals(ServiceStatus.OK, reopened.execute(2, key, byteArrayOf()).status)
                    assertEquals(ServiceStatus.OK, reopened.execute(1, key, byteArrayOf()).status)
                    assertTrue(reopened.execute(1, key, byteArrayOf()).data.isEmpty())
                    assertEquals(ServiceStatus.OK, reopened.execute(3, key, byteArrayOf()).status)
                    assertEquals(ServiceStatus.NOT_FOUND, reopened.execute(1, key, byteArrayOf()).status)
                    assertEquals(ServiceStatus.OK, reopened.execute(3, key, byteArrayOf()).status)
                    reopened.writableDatabase.execSQL("INSERT INTO entries (key, value) VALUES (?, ?)", arrayOf("corrupt-value", byteArrayOf(0xff.toByte())))
                    assertEquals(ServiceStatus.IO, reopened.execute(1, "corrupt-value".toByteArray(), byteArrayOf()).status)
                    reopened.writableDatabase.execSQL("DROP TABLE entries")
                    assertThrows(android.database.sqlite.SQLiteException::class.java) { reopened.execute(1, key, byteArrayOf()) }
                }
            }.get(10, TimeUnit.SECONDS)
        } finally {
            worker.shutdown()
            assertTrue(worker.awaitTermination(10, TimeUnit.SECONDS))
            // Only this test's randomly named private database is removed.
            context.deleteDatabase(name)
        }
    }
}
