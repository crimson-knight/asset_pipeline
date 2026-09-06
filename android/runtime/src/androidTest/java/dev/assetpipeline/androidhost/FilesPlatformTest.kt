package dev.assetpipeline.androidhost

import android.app.Activity
import android.content.Context
import android.system.Os
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.nio.file.Files
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

@RunWith(AndroidJUnit4::class)
class FilesPlatformTest {
    private fun withStore(block: (Context, String, PrivateFiles, File, File) -> Unit) {
        val context = ApplicationProvider.getApplicationContext<Context>()
        var loaded = false
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            try { CrystalBridge.debugPendingServices(); loaded = true } catch (_: IllegalStateException) { }
        }
        if (!loaded) {
            val intent = requireNotNull(context.packageManager.getLaunchIntentForPackage(context.packageName))
            ActivityScenario.launch<Activity>(intent).close()
        }
        val name = "ap_files_test_${UUID.randomUUID()}"
        val worker = Executors.newSingleThreadExecutor()
        try {
            worker.submit {
                val directory = File(context.filesDir, name)
                val scratch = File(context.filesDir, "${name}_scratch")
                try { block(context, name, PrivateFiles(context, name), directory, scratch) } finally {
                    // All targets belong to this test's random private namespace.
                    for (owned in listOf(directory, scratch)) {
                        assertEquals(context.filesDir.canonicalFile, requireNotNull(owned.absoluteFile.parentFile).canonicalFile)
                        if (Files.isSymbolicLink(owned.toPath())) Files.delete(owned.toPath()) else owned.deleteRecursively()
                    }
                }
            }.get(45, TimeUnit.SECONDS)
        } finally { worker.shutdown(); assertTrue(worker.awaitTermination(45, TimeUnit.SECONDS)) }
    }

    @Test fun binaryFilesAreBoundedDurableAndDistinctFromMissingFiles() = withStore { context, name, store, directory, _ ->
        val path = "nested/雪/😀.bin".toByteArray()
        val data = ByteArray(FilePolicy.MAX_DATA) { (it % 256).toByte() }
        assertEquals(ServiceStatus.IO, store.execute(1, path, byteArrayOf()).status)
        assertEquals(ServiceStatus.OK, store.execute(3, path, byteArrayOf()).status)
        assertFalse(directory.exists())
        assertEquals(ServiceStatus.OK, store.execute(2, path, data).status)
        assertEquals(context.filesDir.canonicalFile, requireNotNull(directory.canonicalFile.parentFile))
        val reopened = PrivateFiles(context, name)
        val reply = reopened.execute(1, path, byteArrayOf())
        assertEquals(ServiceStatus.OK, reply.status)
        assertArrayEquals(data, reply.data)
        assertArrayEquals(data, File(directory, "nested/雪/😀.bin").readBytes())
        assertEquals(ServiceStatus.INVALID_INPUT, store.execute(2, path, ByteArray(FilePolicy.MAX_DATA + 1)).status)
        assertArrayEquals(data, store.execute(1, path, byteArrayOf()).data)
        assertEquals(ServiceStatus.OK, store.execute(2, path, byteArrayOf()).status)
        assertEquals(ServiceStatus.OK, store.execute(1, path, byteArrayOf()).status)
        assertTrue(store.execute(1, path, byteArrayOf()).data.isEmpty())
        assertEquals(ServiceStatus.OK, store.execute(3, path, byteArrayOf()).status)
        assertEquals(ServiceStatus.IO, store.execute(1, path, byteArrayOf()).status)
        assertEquals(ServiceStatus.OK, store.execute(3, path, byteArrayOf()).status)
        File(directory, "oversized").writeBytes(ByteArray(FilePolicy.MAX_DATA + 1))
        assertEquals(ServiceStatus.INVALID_INPUT, store.execute(1, "oversized".toByteArray(), byteArrayOf()).status)
    }

    @Test fun symlinksHardLinksDirectoriesAndFifosCannotRedirectOrBlockOperations() = withStore { _, _, store, directory, scratch ->
        val bytes = "original".toByteArray()
        assertEquals(ServiceStatus.OK, store.execute(2, "safe".toByteArray(), bytes).status)
        assertTrue(scratch.mkdir())
        val external = File(scratch, "untouched").apply { writeBytes(bytes) }
        val link = File(directory, "alias")
        try {
            Files.createSymbolicLink(link.toPath(), external.toPath())
            for (operation in 1..3) assertEquals(ServiceStatus.INVALID_INPUT, store.execute(operation, "alias".toByteArray(), byteArrayOf(9)).status)
        } finally { Files.deleteIfExists(link.toPath()) }
        try {
            Files.createSymbolicLink(link.toPath(), scratch.toPath())
            for (operation in 1..3) assertEquals(ServiceStatus.INVALID_INPUT, store.execute(operation, "alias/untouched".toByteArray(), byteArrayOf(9)).status)
            assertEquals(ServiceStatus.INVALID_INPUT, store.execute(2, "alias/new/file".toByteArray(), bytes).status)
            assertFalse(File(scratch, "new").exists())
        } finally { Files.deleteIfExists(link.toPath()) }
        assertTrue(link.mkdir())
        for (operation in 1..3) assertEquals(ServiceStatus.INVALID_INPUT, store.execute(operation, "alias".toByteArray(), bytes).status)
        assertTrue(link.delete())
        Os.mkfifo(link.absolutePath, 384)
        for (operation in 1..3) assertEquals(ServiceStatus.INVALID_INPUT, store.execute(operation, "alias".toByteArray(), bytes).status)
        assertTrue(link.delete())
        try {
            try {
                Files.createLink(link.toPath(), external.toPath())
                for (operation in 1..3) assertEquals(ServiceStatus.INVALID_INPUT, store.execute(operation, "alias".toByteArray(), byteArrayOf(9)).status)
            } catch (_: java.nio.file.AccessDeniedException) {
                // This Android app domain can prohibit creating a hard link at
                // all. Record that protection, not pretend the backend ran.
                assertFalse(link.exists())
                InstrumentationRegistry.getInstrumentation().sendStatus(0, android.os.Bundle().apply { putString("files_hardlink_policy", "creation denied by platform") })
            }
        } finally { Files.deleteIfExists(link.toPath()) }
        assertArrayEquals(bytes, external.readBytes())
        assertArrayEquals(bytes, File(directory, "safe").readBytes())
    }

    @Test fun staleTemporaryWritesNeverReplaceCommittedDataAndUnsafeInternalsFailClosed() = withStore { _, _, store, directory, scratch ->
        val path = "file".toByteArray()
        val original = "original".toByteArray()
        assertEquals(ServiceStatus.OK, store.execute(2, path, original).status)
        val pending = File(directory, ".ap-pending")
        pending.writeBytes("partial-uncommitted".toByteArray())
        assertArrayEquals(original, store.execute(1, path, byteArrayOf()).data)
        assertEquals(ServiceStatus.OK, store.execute(3, path, byteArrayOf()).status)
        assertEquals(ServiceStatus.IO, store.execute(1, path, byteArrayOf()).status)
        assertEquals(ServiceStatus.OK, store.execute(2, path, original).status)
        assertFalse(pending.exists())
        assertTrue(scratch.mkdir())
        val external = File(scratch, "untouched").apply { writeBytes(original) }
        for (filename in listOf(".ap-pending", ".ap-lock")) {
            val target = File(directory, filename)
            if (target.exists()) assertTrue(target.delete())
            try {
                Files.createSymbolicLink(target.toPath(), external.toPath())
                assertEquals(ServiceStatus.INVALID_INPUT, store.execute(2, path, byteArrayOf(9)).status)
                assertArrayEquals(original, File(directory, "file").readBytes())
                assertArrayEquals(original, external.readBytes())
            } finally { Files.deleteIfExists(target.toPath()) }
        }
    }

    @Test fun nativeBoundaryRejectsUnsafePathsAndReleasesAllNamespaceHandles() = withStore { context, name, store, directory, _ ->
        val native = PrivateFiles::class.java.getDeclaredMethod("executeNative", ByteArray::class.java, ByteArray::class.java, ByteArray::class.java, ByteArray::class.java, Int::class.javaPrimitiveType).apply { isAccessible = true }
        for (path in listOf("../escape", "/absolute", "a//b", "a/./b", "a/../b", ".ap-lock", "a\\b", "a\u0000b", "file:///uri", "x".repeat(256))) {
            val result = native.invoke(null, context.filesDir.absolutePath.toByteArray(), name.toByteArray(), path.toByteArray(), byteArrayOf(1), 2) as ByteArray
            assertEquals(ServiceStatus.INVALID_INPUT.wire, result[0].toInt())
        }
        assertFalse(directory.exists())
        fun handles(): List<String> = File("/proc/self/fd").listFiles().orEmpty().mapNotNull {
            try { Os.readlink(it.absolutePath) } catch (_: Exception) { null }
        }.filter { it == context.filesDir.absolutePath || it.contains("/$name") }
        val baseline = handles().sorted()
        repeat(100) {
            val path = "handle-check".toByteArray()
            assertEquals(ServiceStatus.OK, store.execute(2, path, byteArrayOf(0, -1)).status)
            assertArrayEquals(byteArrayOf(0, -1), store.execute(1, path, byteArrayOf()).data)
            assertEquals(ServiceStatus.OK, store.execute(3, path, byteArrayOf()).status)
        }
        assertEquals(baseline, handles().sorted())
    }

    @Test fun replacingAParentWithASymlinkCannotReadOutsideTheNamespace() = withStore { _, _, store, directory, scratch ->
        val path = "parent/file".toByteArray()
        val inside = "inside".toByteArray()
        val outside = "outside-never-readable".toByteArray()
        assertEquals(ServiceStatus.OK, store.execute(2, path, inside).status)
        assertTrue(scratch.mkdir()); File(scratch, "file").writeBytes(outside)
        val parent = File(directory, "parent").toPath()
        val parked = File(directory, "parked").toPath()
        val failure = AtomicReference<Throwable?>(null)
        val race = Thread {
            try {
                repeat(200) {
                    Files.move(parent, parked)
                    try { Files.createSymbolicLink(parent, scratch.toPath()); Thread.yield() } finally { Files.deleteIfExists(parent) }
                    Files.move(parked, parent)
                }
            } catch (error: Throwable) { failure.set(error) }
        }
        race.start()
        try {
            repeat(200) {
                val reply = store.execute(1, path, byteArrayOf())
                if (reply.status == ServiceStatus.OK) assertArrayEquals(inside, reply.data)
                else assertTrue(reply.status == ServiceStatus.IO || reply.status == ServiceStatus.INVALID_INPUT)
            }
        } finally { race.join(10000); assertFalse(race.isAlive) }
        failure.get()?.let { throw AssertionError("Filesystem race fixture failed", it) }
        assertArrayEquals(outside, File(scratch, "file").readBytes())
        assertArrayEquals(inside, store.execute(1, path, byteArrayOf()).data)
    }
}
