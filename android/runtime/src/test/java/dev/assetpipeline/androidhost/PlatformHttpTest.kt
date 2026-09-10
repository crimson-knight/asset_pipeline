package dev.assetpipeline.androidhost

import java.nio.ByteBuffer
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import mockwebserver3.MockWebServer
import mockwebserver3.MockResponse
import okhttp3.tls.HandshakeCertificates
import okhttp3.tls.HeldCertificate
import org.junit.Assert.*
import org.junit.Test

class PlatformHttpTest {
    private fun status(reply: ServiceReply): Int {
        assertEquals(ServiceStatus.OK, reply.status)
        val bytes = ByteBuffer.wrap(reply.data)
        assertEquals(1, bytes.int)
        return bytes.int
    }
    @Test fun binaryPostAndHttpErrorAreResponsesNotTransportFailures() {
        MockWebServer().use { server ->
            server.enqueue(MockResponse.Builder().code(422).body(okio.Buffer().write(byteArrayOf(0, -1, 42))).build())
            server.start()
            val input = byteArrayOf(0, -1, 13, 10)
            val reply = PlatformHttp().Operation(HttpWireTest.packet(server.url("/echo").toString(), "POST", body = input)).execute()
            assertEquals(422, status(reply))
            assertArrayEquals(input, server.takeRequest(1, TimeUnit.SECONDS)!!.body!!.toByteArray())
            assertArrayEquals(byteArrayOf(0, -1, 42), reply.data.takeLast(3).toByteArray())
        }
    }
    @Test fun redirectDoesNotForwardCredentialsOrContactTheNewOrigin() {
        MockWebServer().use { target -> MockWebServer().use { origin ->
            target.start(); origin.start()
            origin.enqueue(MockResponse.Builder().code(302).addHeader("Location", target.url("/private")).body("redirect").build())
            val reply = PlatformHttp().Operation(HttpWireTest.packet(origin.url("/").toString(), headers = listOf("Authorization" to "Bearer contract"))).execute()
            assertEquals(302, status(reply))
            assertEquals(0, target.requestCount)
        } }
    }
    @Test fun unknownLengthResponseIsStoppedAtTheDecompressedBodyLimit() {
        MockWebServer().use { server ->
            server.enqueue(MockResponse.Builder().chunkedBody("x".repeat(HttpWire.MAX_BODY + 1), 8192).build())
            server.start()
            val reply = PlatformHttp().Operation(HttpWireTest.packet(server.url("/").toString(), timeout = 5000)).execute()
            assertEquals(ServiceStatus.NETWORK, reply.status)
            assertTrue(reply.data.isEmpty())
        }
    }
    @Test fun wholeCallTimeoutStopsASlowBody() {
        MockWebServer().use { server ->
            server.enqueue(MockResponse.Builder().body("slow").bodyDelay(3, TimeUnit.SECONDS).build())
            server.start()
            val start = System.nanoTime()
            val reply = PlatformHttp().Operation(HttpWireTest.packet(server.url("/").toString(), timeout = 150)).execute()
            assertEquals(ServiceStatus.NETWORK, reply.status)
            assertTrue(TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - start) < 2000)
        }
    }
    @Test fun cancellingAnActiveReadReleasesItWithoutWaitingForTheServer() {
        MockWebServer().use { server ->
            server.enqueue(MockResponse.Builder().body("slow").bodyDelay(5, TimeUnit.SECONDS).build())
            server.start()
            val worker = Executors.newSingleThreadExecutor()
            try {
                val task = PlatformHttp().Operation(HttpWireTest.packet(server.url("/").toString(), timeout = 10000))
                val result = worker.submit<ServiceReply> { task.execute() }
                assertNotNull(server.takeRequest(2, TimeUnit.SECONDS))
                val start = System.nanoTime()
                task.cancel(); task.cancel()
                assertEquals(ServiceStatus.CANCELLED, result.get(2, TimeUnit.SECONDS).status)
                assertTrue(TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - start) < 1500)
            } finally { worker.shutdown(); assertTrue(worker.awaitTermination(2, TimeUnit.SECONDS)) }
        }
    }
    @Test fun cancellingBeforePublicationPreventsAnyRequest() {
        val task = PlatformHttp().Operation(HttpWireTest.packet())
        task.cancel(); task.cancel()
        assertEquals(ServiceStatus.CANCELLED, task.execute().status)
    }
    @Test fun untrustedCertificateIsRejectedByDefaultTrust() {
        val certificate = HeldCertificate.Builder().commonName("localhost").addSubjectAlternativeName("localhost").build()
        val tls = HandshakeCertificates.Builder().heldCertificate(certificate).build()
        MockWebServer().use { server ->
            server.useHttps(tls.sslSocketFactory()); server.start()
            val reply = PlatformHttp().Operation(HttpWireTest.packet(server.url("/").toString())).execute()
            assertEquals(ServiceStatus.NETWORK, reply.status)
            assertTrue(reply.data.isEmpty())
            assertEquals(0, server.requestCount)
        }
    }
}
